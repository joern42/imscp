<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

namespace iMSCP;

use iMSCP\Functions\Counting;
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Login;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Statistics;
use iMSCP\Functions\View;
use Zend\Config;
use Zend\EventManager\Event;

/**
 * Synchronizes IP addresses of client's domains and subdomains with his new IP addresses list
 *
 * - Removes IP addresses assigned to domains or subdomains when those are no longer available
 *   for the client.
 * - If all IP addresses assigned to a domain or subdomain are no longer available, they are
 *   replaced with the first IP found in the new IP addresses list.
 *
 * @param int $domainId Customer primary domain unique identifier
 * @param array $clientIps Client new IP addresses list
 * @return void
 */
function syncClientDomainIps($domainId, array $clientIps)
{
    sort($clientIps, SORT_NUMERIC);

    // dmn IP addresses
    $domainIps = explode(',', execQuery('SELECT domain_ips FROM domain WHERE domain_id = ?', [$domainId])->fetchColumn());
    $commonIps = array_intersect($domainIps, $clientIps);
    if (count($commonIps) < count($domainIps)) {
        if (empty($commonIps)) {
            $commonIps[] = $clientIps[0];
        }
        execQuery('UPDATE domain SET domain_ips = ? WHERE domain_id = ?', [implode(',', $commonIps), $domainId]);
    }

    // sub IP addresses
    $stmt = execQuery('SELECT subdomain_id, subdomain_ips FROM subdomain WHERE domain_id = ?', [$domainId]);
    while ($row = $stmt->fetch()) {
        $domainIps = explode(',', $row['subdomain_ips']);
        $commonIps = array_intersect($domainIps, $clientIps);
        if (count($commonIps) < count($domainIps)) {
            if (empty($commonIps)) {
                $commonIps[] = $clientIps[0];
            }
            execQuery('UPDATE subdomain SET subdomain_ips = ? WHERE subdomain_id = ?', [implode(',', $commonIps), $row['subdomain_id']]);
        }
    }

    // als IP addresses
    $stmt = execQuery('SELECT alias_id, alias_ips FROM domain_aliases WHERE domain_id = ?', [$domainId]);
    while ($row = $stmt->fetch()) {
        $domainIps = explode(',', $row['alias_ips']);
        $commonIps = array_intersect($domainIps, $clientIps);
        if (count($commonIps) < count($domainIps)) {
            if (empty($commonIps)) {
                $commonIps[] = $clientIps[0];
            }
            execQuery('UPDATE domain_aliases SET alias_ips = ? WHERE alias_id = ?', [implode(',', $commonIps), $row['alias_id']]);
        }
    }

    // alssub IP addresses
    $stmt = execQuery(
        '
            SELECT t1.subdomain_alias_id, t1.subdomain_alias_ips
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            WHERE t2.domain_id = ?
        ',
        [$domainId]
    );
    while ($row = $stmt->fetch()) {
        $domainIps = explode(',', $row['subdomain_alias_ips']);
        $commonIps = array_intersect($domainIps, $clientIps);
        if (count($commonIps) < count($domainIps)) {
            if (empty($commonIps)) {
                $commonIps[] = $clientIps[0];
            }
            execQuery('UPDATE subdomain_alias SET subdomain_alias_ips = ? WHERE subdomain_alias_id = ?', [
                implode(',', $commonIps), $row['subdomain_alias_id']
            ]);
        }
    }
}

/**
 * Return client properties
 *
 * @param int $clientId Client unique identifier
 * @return array Array containing domain properties
 */
function getClientProperties($clientId)
{
    $stmt = execQuery(
        "
            SELECT t1.*, t2.admin_id, t2.admin_name
            FROM domain AS t1
            JOIN admin AS t2 ON(t1.domain_admin_id = t2.admin_id)
            WHERE t1.domain_admin_id = ?
            AND t1.domain_status <> 'disabled'
            AND t2.created_by = ? 
        ",
        [$clientId, Application::getInstance()->getSession()['user_id']]
    );

    $stmt->rowCount() or View::showBadRequestErrorPage();
    $data = $stmt->fetch();
    $data['mail_quota'] = $data['mail_quota'] / 1048576;
    $data['domainTraffic'] = Statistics::getClientMonthlyTrafficStats($data['domain_id'])[4];
    return $data;
}

/**
 * Return properties for the given reseller
 *
 * @param int $resellerId Reseller id
 * @return array Reseller properties
 */
function getResellerProperties($resellerId)
{
    return execQuery(
        '
            SELECT reseller_id, current_sub_cnt, max_sub_cnt, current_als_cnt, max_als_cnt, current_mail_cnt, max_mail_cnt, current_ftp_cnt,
                max_ftp_cnt, current_sql_db_cnt, max_sql_db_cnt, current_sql_user_cnt, max_sql_user_cnt, current_disk_amnt, max_disk_amnt,
                current_traff_amnt, max_traff_amnt, reseller_ips
            FROM reseller_props WHERE reseller_id = ?
        ',
        [$resellerId]
    )->fetch();
}

/**
 * Get mail data
 *
 * @param int $domainId Domain id
 * @param int $mailQuota Mail quota limit
 * @return array An array which contain in order sum of all mailbox quota, current quota limit, number of mailboxes)
 */
function getMailData($domainId, $mailQuota)
{
    static $mailData = NULL;

    if (NULL === $mailData) {
        $stmt = execQuery('SELECT IFNULL(SUM(quota), 0) AS quota, COUNT(mail_id) AS nb_mailboxes FROM mail_users WHERE domain_id = ?', [$domainId]);
        $row = $stmt->fetch();
        $mailData = [
            'quota_sum'    => bytesHuman($row['quota']),
            'quota_limit'  => $mailQuota == 0 ? '∞' : mebibytesHuman($mailQuota),
            'nb_mailboxes' => $row['nb_mailboxes']
        ];
    }

    return $mailData;
}

/**
 * Returns domain data
 *
 * @param int $clientId Client unique identifier
 * @param bool $forUpdate Tell whether or not data are fetched for update
 * @return array Reference to array of data
 */
function &getData($clientId, $forUpdate = false)
{
    static $data = NULL;

    if (NULL !== $data) {
        return $data;
    }

    $clientProps = getClientProperties($clientId);
    $resellerProps = getResellerProperties(Application::getInstance()->getSession()['user_id']);
    $resellerProps['reseller_ips'] = explode(',', $resellerProps['reseller_ips']);

    list($subCount, $alsCount, $mailCount, $ftpCount, $sqlDbCount, $sqlUsersCount) = Counting::getCustomerObjectsCounts($clientProps['admin_id']);

    $data['nbSubdomains'] = $subCount;
    $data['nbAliases'] = $alsCount;
    $data['nbMailAccounts'] = $mailCount;
    $data['nbFtpAccounts'] = $ftpCount;
    $data['nbSqlDatabases'] = $sqlDbCount;
    $data['nbSqlUsers'] = $sqlUsersCount;
    $data = array_merge($data, $clientProps, $resellerProps);

    // Fallback values
    $data['fallback_domain_expires'] = $data['domain_expires'];
    $data['fallback_domain_client_ips'] = $data['domain_client_ips'] = explode(',', $data['domain_client_ips']);
    $data['fallback_domain_subd_limit'] = $data['domain_subd_limit'];
    $data['fallback_domain_alias_limit'] = $data['domain_alias_limit'];
    $data['fallback_domain_mailacc_limit'] = $data['domain_mailacc_limit'];
    $data['fallback_domain_ftpacc_limit'] = $data['domain_ftpacc_limit'];
    $data['fallback_domain_sqld_limit'] = $data['domain_sqld_limit'];
    $data['fallback_domain_sqlu_limit'] = $data['domain_sqlu_limit'];
    $data['fallback_domain_traffic_limit'] = $data['domain_traffic_limit'];
    $data['fallback_domain_disk_limit'] = $data['domain_disk_limit'];
    $data['fallback_domain_php'] = $data['domain_php'];
    $data['fallback_domain_cgi'] = $data['domain_cgi'];
    $data['fallback_domain_dns'] = $data['domain_dns'];
    $data['fallback_allowbackup'] = $data['allowbackup'] = explode('|', $data['allowbackup']);
    $data['fallback_domain_external_mail'] = $data['domain_external_mail'];
    $data['fallback_web_folder_protection'] = $data['web_folder_protection'];
    $data['fallback_mail_quota'] = $data['mail_quota'];

    $phpini = PhpIni::getInstance();
    $phpini->loadResellerPermissions(Application::getInstance()->getSession()['user_id']); // Load reseller PHP permissions
    $phpini->loadClientPermissions($data['admin_id']); // Load client PHP permissions
    $phpini->loadIniOptions($data['admin_id'], $data['domain_id'], 'dmn'); // Load domain PHP configuration options

    if ($forUpdate) { // Post request
        foreach (
            [
                'domain_subd_limit'    => 'max_sub_cnt',
                'domain_alias_limit'   => 'max_als_cnt',
                'domain_mailacc_limit' => 'max_mail_cnt',
                'mail_quota'           => 'max_mail_cnt',
                'domain_ftpacc_limit'  => 'max_ftp_cnt',
                'domain_sqld_limit'    => 'max_sql_db_cnt',
                'domain_sqlu_limit'    => 'max_sql_user_cnt',
                'domain_traffic_limit' => 'max_traff_amnt',
                'domain_disk_limit'    => 'max_disk_amnt'
            ] as $customerLimit => $resellerMaxLimit
        ) {
            if (array_key_exists($customerLimit, $_POST) && $data[$resellerMaxLimit] != -1) {
                $data[$customerLimit] = cleanInput($_POST[$customerLimit]);
            }
        }

        if (isset($_POST['domain_client_ips']) && is_array($_POST['domain_client_ips'])) {
            $data['domain_client_ips'] = $_POST['domain_client_ips'];
        }

        foreach (['domain_expires', 'domain_php', 'domain_cgi', 'domain_dns', 'domain_external_mail', 'web_folder_protection'] as $field) {
            if (isset($_POST[$field])) {
                $data[$field] = cleanInput($_POST[$field]);
            }
        }

        if (Application::getInstance()->getConfig()['BACKUP_DOMAINS'] == 'yes') {
            $data['allowbackup'] = isset($_POST['allowbackup']) && is_array($_POST['allowbackup'])
                ? array_intersect($_POST['allowbackup'], ['dmn', 'sql', 'mail']) : [];
        } else {
            $data['allowbackup'] = [];
        }
    }

    return $data;
}

/**
 * Update account of the given client
 *
 * @param int $clientId Client unique identifier
 * @return bool
 */
function updateClientAccount($clientId)
{
    $db = Application::getInstance()->getDb();

    $errFieldsStack = [];

    try {
        $data =& getData($clientId, true);

        // Check for account expiration date
        if ($data['domain_expires'] !== '') {
            if (!preg_match('%^\d{2}/\d{2}/\d{4}$%', $data['domain_expires']) || ($timestamp = strtotime($data['domain_expires'])) === false) {
                setPageMessage(tr("Wrong syntax for the account expiration date. Date must be provided in form 'dd/mm/yyyy'."), 'error');
                $errFieldsStack[] = 'domain_expires';
            } elseif ($timestamp != 0 && $timestamp <= time()) {
                $data['domain_expires'] = $timestamp;
                setPageMessage(tr('You cannot set account expiration date in past.'), 'error');
                $errFieldsStack[] = 'domain_expires';
            } else {
                $data['domain_expires'] = $timestamp;
            }
        } else {
            $data['domain_expires'] = 0;
        }

        // Check for client IP addresses
        if (array_diff($data['domain_client_ips'], $data['reseller_ips'])) {
            print "god";
            $data['domain_client_ips'] = $data['fallback_domain_client_ips'];
        }

        // Check for the subdomains limit
        if ($data['fallback_domain_subd_limit'] != -1) {
            if (!validateLimit($data['domain_subd_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('subdomains')), 'error');
                $errFieldsStack[] = 'domain_subd_limit';
            } elseif (!isValidServiceLimit($data['domain_subd_limit'], $data['nbSubdomains'], $data['fallback_domain_subd_limit'],
                $data['current_sub_cnt'], $data['max_sub_cnt'], $data['nbSubdomains'] > 1 ? tr('subdomains') : tr('subdomain'))
            ) {
                $errFieldsStack[] = 'domain_subd_limit';
            }
        }

        // Check for the domain aliases limit
        if ($data['fallback_domain_alias_limit'] != -1) {
            if (!validateLimit($data['domain_alias_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('domain aliases')), 'error');
                $errFieldsStack[] = 'domain_alias_limit';
            } elseif (!isValidServiceLimit($data['domain_alias_limit'], $data['nbAliases'], $data['fallback_domain_alias_limit'],
                $data['current_als_cnt'], $data['max_als_cnt'], $data['nbAliases'] > 1 ? tr('domain aliases') : tr('domain alias'))
            ) {
                $errFieldsStack[] = 'domain_alias_limit';
            }
        }

        // Check for the mail accounts limit
        if ($data['fallback_domain_mailacc_limit'] != -1) {
            if (!validateLimit($data['domain_mailacc_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('mail accounts')), 'error');
                $errFieldsStack[] = 'domain_mailacc_limit';
            } elseif (!isValidServiceLimit($data['domain_mailacc_limit'], $data['nbMailAccounts'], $data['fallback_domain_mailacc_limit'],
                $data['current_mail_cnt'], $data['max_mail_cnt'], $data["nbMailAccounts"] > 1 ? tr('mail accounts') : tr('mail account'))
            ) {
                $errFieldsStack[] = 'domain_mailacc_limit';
            }
        }

        // Check for the Ftp accounts limit
        if ($data['fallback_domain_ftpacc_limit'] != -1) {
            if (!validateLimit($data['domain_ftpacc_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('Ftp accounts')), 'error');
                $errFieldsStack[] = 'domain_ftpacc_limit';
            } elseif (!isValidServiceLimit($data['domain_ftpacc_limit'], $data['nbFtpAccounts'], $data['fallback_domain_ftpacc_limit'],
                $data['current_ftp_cnt'], $data['max_ftp_cnt'], $data['nbFtpAccounts'] > 1 ? tr('Ftp accounts') : tr('Ftp account'))
            ) {
                $errFieldsStack[] = 'domain_ftpacc_limit';
            }
        }

        // Check for the Sql databases limit
        if ($data['fallback_domain_sqld_limit'] != -1) {
            if (!validateLimit($data['domain_sqld_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('SQL databases')), 'error');
                $errFieldsStack[] = 'domain_sqld_limit';
            } elseif (!isValidServiceLimit($data['domain_sqld_limit'], $data['nbSqlDatabases'], $data['fallback_domain_sqld_limit'],
                $data['current_sql_db_cnt'], $data['max_sql_db_cnt'], $data['nbSqlDatabases'] > 1 ? tr('SQL databases') : tr('SQL database'))
            ) {
                $errFieldsStack[] = 'domain_sqld_limit';
            } elseif ($data['domain_sqld_limit'] != -1 && $data['domain_sqlu_limit'] == -1) {
                setPageMessage(tr('SQL users limit is disabled.'), 'error');
                $errFieldsStack[] = 'domain_sqld_limit';
                $errFieldsStack[] = 'domain_sqlu_limit';
            }
        }

        // Check for the Sql users limit
        if ($data['fallback_domain_sqlu_limit'] != -1) {
            if (!validateLimit($data['domain_sqlu_limit'])) {
                setPageMessage(tr('Wrong syntax for the %s limit.', tr('SQL users')), 'error');
                $errFieldsStack[] = 'domain_sqlu_limit';
            } elseif (!isValidServiceLimit($data['domain_sqlu_limit'], $data['nbSqlUsers'], $data['fallback_domain_sqlu_limit'],
                $data['current_sql_user_cnt'], $data['max_sql_user_cnt'], $data['nbSqlUsers'] > 1 ? tr('SQL users') : tr('SQL user'))
            ) {
                $errFieldsStack[] = 'domain_sqlu_limit';
            } elseif ($data['domain_sqlu_limit'] != -1 && $data['domain_sqld_limit'] == -1) {
                setPageMessage(tr('SQL databases limit is disabled.'), 'error');
                $errFieldsStack[] = 'domain_sqlu_limit';
                $errFieldsStack[] = 'domain_sqld_limit';
            }
        }

        // Check for the monthly traffic limit
        if (!validateLimit($data['domain_traffic_limit'], NULL)) {
            setPageMessage(tr('Wrong syntax for the %s limit.', tr('traffic')), 'error');
            $errFieldsStack[] = 'domain_traffic_limit';
        } elseif (!isValidServiceLimit($data['domain_traffic_limit'], $data['domainTraffic'] / 1048576, $data['fallback_domain_traffic_limit'],
            $data['current_traff_amnt'], $data['max_traff_amnt'], tr('traffic'))
        ) {
            $errFieldsStack[] = 'domain_traffic_limit';
        }

        // Check for the disk space limit
        if (!validateLimit($data['domain_disk_limit'], NULL)) {
            setPageMessage(tr('Wrong syntax for the %s limit.', tr('disk space')), 'error');
            $errFieldsStack[] = 'domain_disk_limit';
        } elseif (!isValidServiceLimit($data['domain_disk_limit'], $data['domain_disk_usage'] / 1048576, $data['fallback_domain_disk_limit'],
            $data['current_disk_amnt'], $data['max_disk_amnt'], tr('disk space'))
        ) {
            $errFieldsStack[] = 'domain_disk_limit';
        }

        // Check for mail quota
        if ($data['fallback_domain_mailacc_limit'] != -1) {
            if (!validateLimit($data['mail_quota'], NULL)) {
                setPageMessage(tr('Wrong syntax for the mail quota value.'), 'error');
                $errFieldsStack[] = 'mail_quota';
            } elseif ($data['domain_disk_limit'] != 0 && $data['mail_quota'] > $data['domain_disk_limit']) {
                setPageMessage(tr('Mail quota cannot be bigger than disk space limit.'), 'error');
                $errFieldsStack[] = 'mail_quota';
            } elseif ($data['domain_disk_limit'] != 0 && $data['mail_quota'] == 0) {
                setPageMessage(tr('Mail quota cannot be unlimited. Max value is %d MiB.', $data['domain_disk_limit']), 'error');
                $errFieldsStack[] = 'mail_quota';
            } else {
                $mailData = getMailData($data['domain_id'], $data['fallback_mail_quota']);

                if ($data['mail_quota'] != 0 && $data['mail_quota'] < $mailData['nb_mailboxes']) {
                    setPageMessage(tr('Mail quota cannot be lower than %d. Each mail account must have a least 1 MiB quota.', $mailData['nb_mailboxes']), 'error');
                    $errFieldsStack[] = 'mail_quota';
                }
            }
        } else {
            $data['mail_quota'] = 0;
        }

        // Check for PHP support
        $data['domain_php'] = in_array($data['domain_php'], ['no', 'yes'], true) ? $data['domain_php'] : $data['fallback_domain_php'];

        // PHP editor
        $phpini = PhpIni::getInstance();
        $phpConfigLevel = $phpini->getClientPermission('phpiniConfigLevel');

        if (isset($_POST['php_ini_system']) && $data['domain_php'] == 'yes' && $phpini->resellerHasPermission('phpiniSystem')) {
            $phpini->setClientPermission('phpiniSystem', cleanInput($_POST['php_ini_system']));

            if ($phpini->clientHasPermission('phpiniSystem')) {
                if (isset($_POST['phpini_perm_config_level'])) {
                    $phpini->setClientPermission('phpiniConfigLevel', cleanInput($_POST['phpini_perm_config_level']));
                }

                if (isset($_POST['phpini_perm_allow_url_fopen'])) {
                    $phpini->setClientPermission('phpiniAllowUrlFopen', cleanInput($_POST['phpini_perm_allow_url_fopen']));
                }

                if (isset($_POST['phpini_perm_display_errors'])) {
                    $phpini->setClientPermission('phpiniDisplayErrors', cleanInput($_POST['phpini_perm_display_errors']));
                }

                if (isset($_POST['phpini_perm_disable_functions'])) {
                    $phpini->setClientPermission('phpiniDisableFunctions', cleanInput($_POST['phpini_perm_disable_functions']));
                }

                if (isset($_POST['phpini_perm_mail_function'])) {
                    $phpini->setClientPermission('phpiniMailFunction', cleanInput($_POST['phpini_perm_mail_function']));
                }

                if (isset($_POST['memory_limit'])) {
                    // Must be set before phpiniPostMaxSize
                    $phpini->setIniOption('phpiniMemoryLimit', cleanInput($_POST['memory_limit']));
                }

                if (isset($_POST['post_max_size'])) {
                    // Must be set before phpiniUploadMaxFileSize
                    $phpini->setIniOption('phpiniPostMaxSize', cleanInput($_POST['post_max_size']));
                }

                if (isset($_POST['upload_max_filesize'])) {
                    $phpini->setIniOption('phpiniUploadMaxFileSize', cleanInput($_POST['upload_max_filesize']));
                }

                if (isset($_POST['max_execution_time'])) {
                    $phpini->setIniOption('phpiniMaxExecutionTime', cleanInput($_POST['max_execution_time']));
                }

                if (isset($_POST['max_input_time'])) {
                    $phpini->setIniOption('phpiniMaxInputTime', cleanInput($_POST['max_input_time']));
                }
            } else {
                // Reset client permissions to their default values
                $phpini->loadClientPermissions();
            }
        } else {
            // Reset client permissions to their default values
            $phpini->loadClientPermissions();
        }

        // Check for CGI support
        $data['domain_cgi'] = in_array($data['domain_cgi'], ['no', 'yes']) ? $data['domain_cgi'] : $data['fallback_domain_cgi'];

        // Check for custom DNS records support
        $data['domain_dns'] = in_array($data['domain_dns'], ['no', 'yes']) ? $data['domain_dns'] : $data['fallback_domain_dns'];

        // Check for External mail server support
        $data['domain_external_mail'] = in_array($data['domain_external_mail'], ['no', 'yes'])
            ? $data['domain_external_mail'] : $data['fallback_domain_external_mail'];

        // Check for backup support
        $data['allowbackup'] = is_array($data['allowbackup'])
            ? array_intersect($data['allowbackup'], ['dmn', 'sql', 'mail']) : $data['fallback_allowbackup'];

        // Check for Web folder protection support
        $data['web_folder_protection'] = in_array($data['web_folder_protection'], ['no', 'yes'])
            ? $data['web_folder_protection'] : $data['fallback_web_folder_protection'];

        if (empty($errFieldsStack)) { // Update process begin here
            $db->getDriver()->getConnection()->beginTransaction();

            Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditCustomerAccountProps, NULL, [
                'customerId'          => $clientId,
                'expirationDate'      => $data['domain_expires'],
                'ips'                 => $data['domain_client_ips'],
                'php'                 => $data['domain_php'],
                'phpEditor'           => $phpini->getClientPermission('phpiniSystem'),
                'cgi'                 => $data['domain_cgi'],
                'dns'                 => $data['domain_dns'],
                'extMailServer'       => $data['domain_external_mail'],
                'backup'              => $data['allowbackup'],
                'webFolderProtection' => $data['web_folder_protection'],
                'subdomainLimit'      => $data['domain_subd_limit'],
                'domainAliasesLimit'  => $data['domain_alias_limit'],
                'mailAccountsLimit'   => $data['domain_mailacc_limit'],
                'mailQuota'           => $data['mail_quota'] * 1048576,
                'ftpAccountsLimit'    => $data['domain_ftpacc_limit'],
                'sqlDatabasesLimit'   => $data['domain_sqld_limit'],
                'sqlUsersLimit'       => $data['domain_sqlu_limit'],
                'monthlyTrafficLimit' => $data['domain_traffic_limit'],
                'diskspaceLimit'      => $data['domain_disk_limit']
            ]);

            $changeNeeded = false;

            if ($data['domain_dns'] != $data['fallback_domain_dns'] && $data['domain_dns'] == 'no') {
                // We must delete all custom DNS entries, except those that are protected
                execQuery("DELETE FROM domain_dns WHERE domain_id = ? AND owned_by = 'custom_dns_feature'", [$data['domain_id']]);
                $changeNeeded = true;
            }

            // Update client IP addresses, limits and permissions

            execQuery(
                '
                    UPDATE domain
                    SET domain_expires = ?, domain_last_modified = ?, domain_mailacc_limit = ?, domain_ftpacc_limit = ?, domain_traffic_limit = ?,
                        domain_sqld_limit = ?, domain_sqlu_limit = ?, domain_alias_limit = ?, domain_subd_limit = ?, domain_client_ips = ?,
                        domain_disk_limit = ?, domain_php = ?, domain_cgi = ?, allowbackup = ?, domain_dns = ?, domain_external_mail = ?,
                        web_folder_protection = ?, mail_quota = ?
                    WHERE domain_admin_id = ?
                ',
                [
                    $data['domain_expires'], time(), $data['domain_mailacc_limit'], $data['domain_ftpacc_limit'], $data['domain_traffic_limit'],
                    $data['domain_sqld_limit'], $data['domain_sqlu_limit'], $data['domain_alias_limit'], $data['domain_subd_limit'],
                    implode(',', $data['domain_client_ips']), $data['domain_disk_limit'], $data['domain_php'], $data['domain_cgi'],
                    implode('|', $data['allowbackup']), $data['domain_dns'], $data['domain_external_mail'], $data['web_folder_protection'],
                    $data['mail_quota'] * 1048576, $clientId
                ]
            );

            $phpini->saveClientPermissions($data['admin_id']);
            $phpini->updateClientIniOptions($data['admin_id'], $phpConfigLevel != $phpini->getClientPermission('phpiniConfigLevel'));

            // If an IP address from the old list of IP addresses is not
            // present in the new list of IP addresses, we need to synchronize
            // the the client's domains and subdomains IP addresses with the
            // new list of IP addresses
            if (array_diff($data['fallback_domain_client_ips'], $data['domain_client_ips'])) {
                syncClientDomainIps($data['domain_id'], $data['domain_client_ips']);
                $changeNeeded = true;
            }

            if ($data['fallback_mail_quota'] != ($data['mail_quota'] * 1048576)) {
                // Sync mailboxes quota
                Mail::syncMailboxesQuota($data['domain_id'], $data['mail_quota'] * 1048576);
            }

            if ($data['domain_disk_limit'] != $data['fallback_domain_disk_limit']) {
                // Update FTP quota limit
                execQuery(
                    "
                        REPLACE INTO quotalimits (
                            name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail,
                            files_out_avail, files_xfer_avail
                        ) VALUES (
                            ?, 'group', 'false', 'hard', ?, 0, 0, 0, 0, 0
                        )
                    ",
                    [$data['domain_name'], $data['domain_disk_limit'] * 1048576]
                );
            }

            recalculateResellerAssignments($data['reseller_id']);

            Application::getInstance()->getEventManager()->trigger(Events::onAfterEditCustomerAccountProps, NULL, [
                'customerId'          => $clientId,
                'expirationDate'      => $data['domain_expires'],
                'ips'                 => $data['domain_client_ips'],
                'php'                 => $data['domain_php'],
                'phpEditor'           => $phpini->getClientPermission('phpiniSystem'),
                'cgi'                 => $data['domain_cgi'],
                'dns'                 => $data['domain_dns'],
                'extMailServer'       => $data['domain_external_mail'],
                'backup'              => $data['allowbackup'],
                'webFolderProtection' => $data['web_folder_protection'],
                'subdomainLimit'      => $data['domain_subd_limit'],
                'domainAliasesLimit'  => $data['domain_alias_limit'],
                'mailAccountsLimit'   => $data['domain_mailacc_limit'],
                'mailQuota'           => $data['mail_quota'] * 1048576,
                'ftpAccountsLimit'    => $data['domain_ftpacc_limit'],
                'sqlDatabasesLimit'   => $data['domain_sqld_limit'],
                'sqlUsersLimit'       => $data['domain_sqlu_limit'],
                'monthlyTrafficLimit' => $data['domain_traffic_limit'],
                'diskspaceLimit'      => $data['domain_disk_limit']
            ]);

            // Schedule change of customer's domains, including subdomains if one of the following condition is met:
            // - Client IP addresses were changed
            // - Custom DNS records feature has been disabled
            // - Mail feature has been enabled or disabled
            // - PHP feature has been enabled or disabled
            // - CGI feature has been enabled or disabled
            // - Web folder protection has been enabled or disabled
            if ($changeNeeded || ($data['domain_mailacc_limit'] == '-1' && $data['fallback_domain_mailacc_limit'] != '-1'
                    || $data['domain_mailacc_limit'] != '-1' && $data['fallback_domain_mailacc_limit'] == '-1')
                || $data['domain_php'] != $data['fallback_domain_php']
                || $data['domain_cgi'] != $data['fallback_domain_cgi']
                || $data['web_folder_protection'] != $data['fallback_web_folder_protection']
            ) {
                // FIXME: There could be a race condition if there is already a task in progress for some domains or subdomains
                // FIXME: This issue should be addressed by making use of a job queue instead of realying on the entity status

                // Update dmn
                execQuery(
                    "UPDATE domain SET domain_status = 'tochange' WHERE domain_id = ? AND domain_status NOT IN('disabled', 'todisable', 'todelete')",
                    [$data['domain_id']]
                );
                // Update sub, except those that disabled, being disabled or deleted
                execQuery(
                    "
                        UPDATE subdomain
                        SET subdomain_status = 'tochange'
                        WHERE domain_id = ?
                        AND subdomain_status NOT IN('disabled', 'todisable', 'todelete')
                    ",
                    [$data['domain_id']]
                );
                // Update als, except those that ordered, disabled, being disabled or deleted
                execQuery(
                    "
                        UPDATE domain_aliases
                        SET alias_status = 'tochange'
                        WHERE domain_id = ?
                        AND alias_status NOT IN('ordered', 'disabled', 'todisable', 'todelete')
                    ",
                    [$data['domain_id']]
                );

                // Update alssub, except those that are disabled, being disabled or deleted
                execQuery(
                    "
                        UPDATE subdomain_alias AS t1
                        JOIN domain_aliases AS t2 USING(alias_id)
                        SET t1.subdomain_alias_status = 'tochange'
                        WHERE t2.domain_id = ?
                        AND t1.subdomain_alias_status NOT IN('disabled', 'todisable', 'todelete')
                    ",
                    [$data['domain_id']]
                );

                $changeNeeded = true;
            }

            $db->getDriver()->getConnection()->commit();

            if ($changeNeeded) {
                Daemon::sendRequest();
            }

            setPageMessage(tr('Domain successfully updated.'), 'success');
            $userLogged = isset(Application::getInstance()->getSession()['logged_from']) ? Application::getInstance()->getSession()['logged_from'] : Application::getInstance()->getSession()['user_logged'];
            writeLog(sprintf('%s account properties were updated by %s', decodeIdna($data['admin_name']), $userLogged), E_USER_NOTICE);
            return true;
        }

        Application::getInstance()->getRegistry()->set('errFieldsStack', $errFieldsStack);
        return false;
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }
}

/**
 * Validates a new service limit
 *
 * @param int $newCustomerLimit New customer service limit
 * @param int $customerConsumption Customer consumption
 * @param int $customerLimit Limit for customer
 * @param int $resellerConsumption Reseller consumption
 * @param int $resellerLimit Limit for reseller
 * @param int $translatedServiceName Translation of service name
 * @return bool TRUE if new limit is valid, FALSE otherwise
 */
function isValidServiceLimit($newCustomerLimit, $customerConsumption, $customerLimit, $resellerConsumption, $resellerLimit, $translatedServiceName)
{
    // Please, don't change test order.
    if (($resellerLimit == -1 || $resellerLimit > 0) && $newCustomerLimit == 0) {
        setPageMessage(
            tr('The %s limit for this customer cannot be unlimited because your are limited for this service.', $translatedServiceName), 'error'
        );
        return false;
    }

    if ($newCustomerLimit == -1 && $customerConsumption > 0) {
        setPageMessage(
            tr(
                "The %s limit for this customer cannot be set to 'disabled' because he has already %d %s.", $translatedServiceName,
                $customerConsumption, $translatedServiceName
            ),
            'error'
        );
        return false;
    }

    if ($resellerLimit != 0
        && $newCustomerLimit > ($resellerLimit - $resellerConsumption) + $customerLimit
    ) {
        setPageMessage(
            tr(
                'The %s limit for this customer cannot be greater than %d, your calculated limit.', $translatedServiceName,
                ($resellerLimit - $resellerConsumption) + $customerLimit
            ),
            'error'
        );
        return false;
    }

    if ($newCustomerLimit != -1 && $newCustomerLimit != 0 && $newCustomerLimit < $customerConsumption) {
        setPageMessage(
            tr(
                'The %s limit for this customer cannot be lower than %d, the total of %s already used by him.', $translatedServiceName,
                round($customerConsumption), $translatedServiceName
            ),
            'error'
        );
        return false;
    }

    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param int $clientId Client unique identifer
 * @return void
 */
function generatePage(TemplateEngine $tpl, $clientId)
{
    $data =& getData($clientId);

    $tpl->assign([
        'CLIENT_ID'                      => toHtml($clientId, 'htmlAttr'),
        'TR_ACCOUNT'                     => toHtml(tr('Account')),
        'TR_ACCOUNT_NAME'                => toHtml(tr('Name')),
        'ACCOUNT_NAME'                   => toHtml(decodeIdna($data['domain_name'])),
        'TR_EXPIRY_DATE'                 => toHtml(tr('Expiration date')),
        'TR_TOOLTIP_ACCOUNT_EXPIRY_DATE' => toHtml(tr('Leave blank for no expiry date.'), 'htmlAttr'),
        'ACCOUNT_EXPIRY_DATE'            => toHtml(
            isset($_POST['domain_expires']) ? $_POST['domain_expires'] : $data['domain_expires'] != 0 ? date('m/d/Y', $data['domain_expires']) : '',
            'htmlAttr'
        ),
        'TR_IPS'                         => toHtml(tr('IP addresses')),
        'TR_FEATURES_PERMISSIONS'        => toHtml(tr('Features / Permissions')),
        'TR_PHP'                         => toHtml(tr('PHP')),
        'PHP_YES'                        => $data['domain_php'] == 'yes' ? ' checked' : '',
        'PHP_NO'                         => $data['domain_php'] != 'yes' ? ' checked' : ''
    ]);

    View::generateResellerIpsList($tpl, Application::getInstance()->getSession()['user_id'], $data['domain_client_ips']);

    $phpini = PhpIni::getInstance();

    if (!$phpini->resellerHasPermission('phpiniSystem')) {
        $tpl->assign('PHP_EDITOR_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_PHP_SETTINGS'          => toHtml(tr('PHP Settings')),
            'TR_PHP_EDITOR'            => toHtml(tr('PHP Editor')),
            'TR_PHP_EDITOR_SETTINGS'   => toHtml(tr('PHP Settings')),
            'TR_PHP_PERMISSIONS'       => toHtml(tr('PHP Permissions')),
            'TR_PHP_DIRECTIVES_VALUES' => toHtml(tr('PHP directives values')),
            'TR_PHP_FIELDS_OK'         => toHtml(tr('All fields are valid.')),
            'TR_MIB'                   => toHtml(tr('MiB')),
            'TR_SEC'                   => toHtml(tr('Sec.')),
            'PHP_EDITOR_YES'           => $phpini->clientHasPermission('phpiniSystem') ? ' checked' : '',
            'PHP_EDITOR_NO'            => $phpini->clientHasPermission('phpiniSystem') ? '' : ' checked'
        ]);

        $permissionsBlock = false;

        if (!$phpini->resellerHasPermission('phpiniConfigLevel')) {
            $tpl->assign('PHPINI_PERM_CONFIG_LEVEL_BLOCK', '');
        } else {
            if ($phpini->getResellerPermission('phpiniConfigLevel') == 'per_site') {
                $tpl->assign([
                    'TR_PHPINI_PERM_CONFIG_LEVEL'         => tr('PHP configuration level'),
                    'TR_PHPINI_PERM_CONFIG_LEVEL_HELP'    => toHtml(tr('Per site: Different PHP configuration for each customer domain, including subdomains<br>Per domain: Identical PHP configuration for each customer domain, including subdomains<br>Per user: Identical PHP configuration for all customer domains, including subdomains'), 'htmlAttr'),
                    'TR_PER_DOMAIN'                       => toHtml(tr('Per domain')),
                    'TR_PER_SITE'                         => toHtml(tr('Per site')),
                    'TR_PER_USER'                         => toHtml(tr('Per user')),
                    'PHPINI_PERM_CONFIG_LEVEL_PER_DOMAIN' => $phpini->getClientPermission('phpiniConfigLevel') == 'per_domain' ? ' checked' : '',
                    'PHPINI_PERM_CONFIG_LEVEL_PER_SITE'   => $phpini->getClientPermission('phpiniConfigLevel') == 'per_site' ? ' checked' : '',
                    'PHPINI_PERM_CONFIG_LEVEL_PER_USER'   => $phpini->getClientPermission('phpiniConfigLevel') == 'per_user' ? ' checked' : '',
                ]);
            } else {
                $tpl->assign([
                    'PHPINI_PERM_CONFIG_LEVEL_PER_SITE_BLOCK' => '',
                    'TR_PHPINI_PERM_CONFIG_LEVEL'             => toHtml(tr('PHP configuration level')),
                    'TR_PHPINI_PERM_CONFIG_LEVEL_HELP'        => toHtml(tr('Per domain: Identical PHP configuration for each customer domain, including subdomains<br>Per user: Identical PHP configuration for all customer domains, including subdomains'), 'htmlAttr'),
                    'TR_PER_DOMAIN'                           => toHtml(tr('Per domain')),
                    'TR_PER_USER'                             => toHtml(tr('Per user')),
                    'PHPINI_PERM_CONFIG_LEVEL_PER_DOMAIN'     => $phpini->getClientPermission('phpiniConfigLevel') == 'per_domain' ? ' checked' : '',
                    'PHPINI_PERM_CONFIG_LEVEL_PER_SITE'       => $phpini->getClientPermission('phpiniConfigLevel') == 'per_site' ? ' checked' : '',
                    'PHPINI_PERM_CONFIG_LEVEL_PER_USER'       => $phpini->getClientPermission('phpiniConfigLevel') == 'per_user' ? ' checked' : '',
                ]);
            }

            $permissionsBlock = true;
        }

        if (!$phpini->resellerHasPermission('phpiniAllowUrlFopen')) {
            $tpl->assign('PHP_EDITOR_ALLOW_URL_FOPEN_BLOCK', '');
        } else {
            $tpl->assign([
                'TR_CAN_EDIT_ALLOW_URL_FOPEN' => tr('Can edit the PHP %s configuration option', '<strong>allow_url_fopen</strong>'),
                'ALLOW_URL_FOPEN_YES'         => $phpini->clientHasPermission('phpiniAllowUrlFopen') ? ' checked' : '',
                'ALLOW_URL_FOPEN_NO'          => $phpini->clientHasPermission('phpiniAllowUrlFopen') ? '' : ' checked'
            ]);
            $permissionsBlock = true;
        }

        if (!$phpini->resellerHasPermission('phpiniDisplayErrors')) {
            $tpl->assign('PHP_EDITOR_DISPLAY_ERRORS_BLOCK', '');
        } else {
            $tpl->assign([
                'TR_CAN_EDIT_DISPLAY_ERRORS' => tr('Can edit the PHP %s configuration option', '<b>display_errors</b>'),
                'DISPLAY_ERRORS_YES'         => $phpini->clientHasPermission('phpiniDisplayErrors') ? ' checked' : '',
                'DISPLAY_ERRORS_NO'          => $phpini->clientHasPermission('phpiniDisplayErrors') ? '' : ' checked'
            ]);
            $permissionsBlock = true;
        }

        if (strpos(Application::getInstance()->getConfig()['iMSCP::Servers::Httpd'], '::Apache2::') !== false) {
            $apacheConfig = Config\Factory::fromFile(normalizePath(Application::getInstance()->getConfig()['CONF_DIR'] . '/apache/apache.data'));
            $isApacheItk = $apacheConfig['HTTPD_MPM'] == 'itk';
        } else {
            $isApacheItk = false;
        }

        if ($isApacheItk) {
            $tpl->assign([
                'PHP_EDITOR_DISABLE_FUNCTIONS_BLOCK' => '',
                'PHP_EDITOR_MAIL_FUNCTION_BLOCK'     => ''
            ]);
        } else {
            if ($phpini->resellerHasPermission('phpiniDisableFunctions')) {
                $tpl->assign([
                    'TR_CAN_EDIT_DISABLE_FUNCTIONS' => tr('Can edit the PHP %s configuration option', '<b>disable_functions</b>'),
                    'DISABLE_FUNCTIONS_YES'         => $phpini->getClientPermission('phpiniDisableFunctions') == 'yes' ? ' checked' : '',
                    'DISABLE_FUNCTIONS_NO'          => $phpini->getClientPermission('phpiniDisableFunctions') == 'no' ? ' checked' : '',
                    'TR_ONLY_EXEC'                  => tr('Only exec'),
                    'DISABLE_FUNCTIONS_EXEC'        => ($phpini->getClientPermission('phpiniDisableFunctions') == 'exec') ? ' checked' : ''
                ]);
            } else {
                $tpl->assign('PHP_EDITOR_DISABLE_FUNCTIONS_BLOCK', '');
            }

            if ($phpini->resellerHasPermission('phpiniMailFunction')) {
                $tpl->assign([
                    'TR_CAN_USE_MAIL_FUNCTION' => tr('Can use the PHP %s function', '<b>mail</b>'),
                    'MAIL_FUNCTION_YES'        => $phpini->clientHasPermission('phpiniMailFunction') == 'yes' ? ' checked' : '',
                    'MAIL_FUNCTION_NO'         => $phpini->clientHasPermission('phpiniMailFunction') == 'no' ? '' : ' checked'
                ]);
            } else {
                $tpl->assign('PHP_EDITOR_MAIL_FUNCTION_BLOCK', '');
            }

            $permissionsBlock = true;
        }

        if (!$permissionsBlock) {
            $tpl->assign('PHP_EDITOR_PERMISSIONS_BLOCK', '');
        }

        $tpl->assign([
            'TR_POST_MAX_SIZE'          => tr('PHP %s configuration option', '<b>post_max_size</b>'),
            'POST_MAX_SIZE'             => toHtml($phpini->getIniOption('phpiniPostMaxSize'), 'htmlAttr'),
            'TR_UPLOAD_MAX_FILEZISE'    => tr('PHP %s configuration option', '<b>upload_max_filesize</b>'),
            'UPLOAD_MAX_FILESIZE'       => toHtml($phpini->getIniOption('phpiniUploadMaxFileSize'), 'htmlAttr'),
            'TR_MAX_EXECUTION_TIME'     => tr('PHP %s configuration option', '<b>max_execution_time</b>'),
            'MAX_EXECUTION_TIME'        => toHtml($phpini->getIniOption('phpiniMaxExecutionTime'), 'htmlAttr'),
            'TR_MAX_INPUT_TIME'         => tr('PHP %s configuration option', '<b>max_input_time</b>'),
            'MAX_INPUT_TIME'            => toHtml($phpini->getIniOption('phpiniMaxInputTime'), 'htmlAttr'),
            'TR_MEMORY_LIMIT'           => tr('PHP %s configuration option', '<b>memory_limit</b>'),
            'MEMORY_LIMIT'              => toHtml($phpini->getIniOption('phpiniMemoryLimit'), 'htmlAttr'),
            'POST_MAX_SIZE_LIMIT'       => toHtml($phpini->getResellerPermission('phpiniPostMaxSize'), 'htmlAttr'),
            'UPLOAD_MAX_FILESIZE_LIMIT' => toHtml($phpini->getResellerPermission('phpiniUploadMaxFileSize'), 'htmlAttr'),
            'MAX_EXECUTION_TIME_LIMIT'  => toHtml($phpini->getResellerPermission('phpiniMaxExecutionTime'), 'htmlAttr'),
            'MAX_INPUT_TIME_LIMIT'      => toHtml($phpini->getResellerPermission('phpiniMaxInputTime'), 'htmlAttr'),
            'MEMORY_LIMIT_LIMIT'        => toHtml($phpini->getResellerPermission('phpiniMemoryLimit'), 'htmlAttr')
        ]);
    }

    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $translations = $e->getParam('translations');
        $translations['core']['close'] = tr('Close');
        $translations['core']['fields_ok'] = tr('All fields are valid.');
        $translations['core']['out_of_range_value_error'] = tr('Value for the PHP %%s directive must be in range %%d to %%d.');
        $translations['core']['lower_value_expected_error'] = tr('%%s cannot be greater than %%s.');
        $translations['core']['error_field_stack'] = Application::getInstance()->getRegistry()->has('errFieldsStack')
            ? Application::getInstance()->getRegistry()->get('errFieldsStack') : [];
    });

    $tpl->assign([
        'TR_CGI'  => toHtml(tr('CGI')),
        'CGI_YES' => $data['domain_cgi'] == 'yes' ? ' checked' : '',
        'CGI_NO'  => $data['domain_cgi'] != 'yes' ? ' checked' : ''
    ]);

    if (resellerHasFeature('custom_dns_records')) {
        $tpl->assign([
            'TR_DNS'  => toHtml(tr('Custom DNS records')),
            'DNS_YES' => $data['domain_dns'] == 'yes' ? ' checked' : '',
            'DNS_NO'  => $data['domain_dns'] != 'yes' ? ' checked' : ''
        ]);
    } else {
        $tpl->assign('CUSTOM_DNS_RECORDS_FEATURE', '');
    }

    if ($data['max_mail_cnt'] == '-1') {
        $tpl->assign('EXT_MAIL_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_EXTMAIL'  => toHtml(tr('External mail server')),
            'EXTMAIL_YES' => $data['domain_external_mail'] == 'yes' ? ' checked' : '',
            'EXTMAIL_NO'  => $data['domain_external_mail'] != 'yes' ? ' checked' : ''
        ]);
    }

    if (Application::getInstance()->getConfig()['BACKUP_DOMAINS'] == 'yes') {
        $tpl->assign([
            'TR_BACKUP'        => toHtml(tr('Backup')),
            'TR_BACKUP_DOMAIN' => toHtml(tr('Domain')),
            'BACKUP_DOMAIN'    => in_array('dmn', $data['allowbackup']) ? ' checked' : '',
            'TR_BACKUP_SQL'    => toHtml(tr('SQL')),
            'BACKUP_SQL'       => in_array('sql', $data['allowbackup']) ? ' checked' : '',
            'TR_BACKUP_MAIL'   => toHtml(tr('Mail')),
            'BACKUP_MAIL'      => in_array('mail', $data['allowbackup']) ? ' checked' : ''
        ]);
    } else {
        $tpl->assign('BACKUP_BLOCK', '');
    }

    $tpl->assign([
        'TR_WEB_FOLDER_PROTECTION'      => toHtml(tr('Web folder protection')),
        'TR_WEB_FOLDER_PROTECTION_HELP' => toHtml(tr('If set to `yes`, Web folders will be protected against deletion.'), 'htmlAttr'),
        'WEB_FOLDER_PROTECTION_YES'     => $data['web_folder_protection'] == 'yes' ? ' checked' : '',
        'WEB_FOLDER_PROTECTION_NO'      => $data['web_folder_protection'] != 'yes' ? ' checked' : '',
        'TR_YES'                        => toHtml(tr('Yes')),
        'TR_NO'                         => toHtml(tr('No'))
    ]);

    list(, $subdomainCount, $domainAliasesCount, $mailsCount, $ftpUsersCount, $sqlDbCount, $sqlUserCount, $trafficUsage, $diskUsage
        ) = Statistics::getResellerStats(Application::getInstance()->getSession()['user_id']);

    $tpl->assign([
        'TR_LIMITS'               => toHtml(tr('Limits')),
        'TR_VALUE'                => toHtml(tr('Value')),
        'TR_CUSTOMER_CONSUMPTION' => toHtml(tr('Customer consumption')),
        'TR_RESELLER_CONSUMPTION' => toHtml(isset(Application::getInstance()->getSession()['logged_from']) ? tr('Reseller consumption') : tr('Your consumption'))
    ]);

    // Subdomains limit
    if ($data['max_sub_cnt'] == -1) { // Reseller has no permissions on this service
        $tpl->assign('SUBDOMAIN_LIMIT_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_SUBDOMAINS_LIMIT'               => toHtml(tr('Subdomains limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'SUBDOMAIN_LIMIT'                   => toHtml($data['domain_subd_limit']),
            'TR_CUSTOMER_SUBDOMAINS_COMSUPTION' => $data['fallback_domain_subd_limit'] != -1 ? toHtml($data['nbSubdomains']) . ' / ' . (
                $data['fallback_domain_subd_limit'] != 0 ? toHtml($data['fallback_domain_subd_limit']) : '∞') : toHtml(tr('Disabled')),
            'TR_RESELLER_SUBDOMAINS_COMSUPTION' => toHtml($subdomainCount) . ' / ' . (
                $data['max_sub_cnt'] != 0 ? toHtml($data['max_sub_cnt']) : '∞')
        ]);
    }

    // Domain aliases limit
    if ($data['max_als_cnt'] == -1) { // Reseller has no permissions on this service
        $tpl->assign('DOMAIN_ALIASES_LIMIT_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_ALIASES_LIMIT'                      => toHtml(tr('Domain aliases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'DOMAIN_ALIASES_LIMIT'                  => toHtml($data['domain_alias_limit']),
            'TR_CUSTOMER_DOMAIN_ALIASES_COMSUPTION' => $data['fallback_domain_alias_limit'] != -1
                ? toHtml($data['nbAliases']) . ' / ' . ($data['fallback_domain_alias_limit'] != 0
                    ? toHtml($data['fallback_domain_alias_limit']) : '∞') : toHtml(tr('Disabled')),
            'TR_RESELLER_DOMAIN_ALIASES_COMSUPTION' => toHtml($domainAliasesCount) . ' / '
                . ($data['max_als_cnt'] != 0 ? toHtml($data['max_als_cnt']) : '∞')
        ]);
    }

    // Mail accounts limit
    if ($data['max_mail_cnt'] == -1) { // Reseller has no permissions on this service
        $tpl->assign('MAIL_ACCOUNTS_LIMIT_BLOCK', '');
    } else {
        $mailData = getMailData($data['domain_id'], $data['fallback_mail_quota']);

        $tpl->assign([
            'TR_MAIL_ACCOUNTS_LIMIT'               => toHtml(tr('Mail accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'MAIL_ACCOUNTS_LIMIT'                  => toHtml($data['domain_mailacc_limit']),
            'TR_CUSTOMER_MAIL_ACCOUNTS_COMSUPTION' => $data['fallback_domain_mailacc_limit'] != -1
                ? toHtml($data['nbMailAccounts']) . ' / ' . ($data['fallback_domain_mailacc_limit'] != 0
                    ? toHtml($data['fallback_domain_mailacc_limit']) : '∞') : tr('Disabled'),
            'TR_RESELLER_MAIL_ACCOUNTS_COMSUPTION' => toHtml($mailsCount) . ' / '
                . ($data['max_mail_cnt'] != 0 ? toHtml($data['max_mail_cnt']) : '∞'),
            'TR_MAIL_QUOTA'                        => toHtml(tr('Mail quota [MiB]')) . '<br/><i>(0 ∞)</i>',
            'MAIL_QUOTA'                           => $data['mail_quota'] != 0 ? toHtml($data['mail_quota']) : 0,
            'TR_CUSTOMER_MAIL_QUOTA_COMSUPTION'    => $mailData['quota_sum'] . ' / ' . $mailData['quota_limit'],
            'TR_NO_AVAILABLE'                      => toHtml(tr('N/A'))
        ]);
    }

    // FTP accounts limit
    if ($data['max_ftp_cnt'] == -1) { // Reseller has no permissions on this service
        $tpl->assign('FTP_ACCOUNTS_LIMIT_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_FTP_ACCOUNTS_LIMIT'               => toHtml(tr('FTP accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'FTP_ACCOUNTS_LIMIT'                  => toHtml($data['domain_ftpacc_limit']),
            'TR_CUSTOMER_FTP_ACCOUNTS_COMSUPTION' => $data['fallback_domain_ftpacc_limit'] != -1
                ? toHtml($data['nbFtpAccounts']) . ' / ' . ($data['fallback_domain_ftpacc_limit'] != 0
                    ? toHtml($data['fallback_domain_ftpacc_limit']) : '∞') : toHtml(tr('Disabled')),
            'TR_RESELLER_FTP_ACCOUNTS_COMSUPTION' => toHtml($ftpUsersCount) . ' / '
                . ($data['max_ftp_cnt'] != 0 ? toHtml($data['max_ftp_cnt']) : '∞')
        ]);
    }

    // SQL Database and SQL Users limits
    if ($data['max_sql_db_cnt'] == -1 || $data['max_sql_user_cnt'] == -1) { // Reseller has no permissions on this service
        $tpl->assign('SQL_DB_AND_USERS_LIMIT_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_SQL_DATABASES_LIMIT'               => toHtml(tr('SQL databases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'SQL_DATABASES_LIMIT'                  => toHtml($data['domain_sqld_limit']),
            'TR_CUSTOMER_SQL_DATABASES_COMSUPTION' => $data['fallback_domain_sqld_limit'] != -1
                ? toHtml($data['nbSqlDatabases']) . ' / ' . ($data['fallback_domain_sqld_limit'] != 0
                    ? toHtml($data['fallback_domain_sqld_limit']) : '∞') : tr('Disabled'),
            'TR_RESELLER_SQL_DATABASES_COMSUPTION' => toHtml($sqlDbCount) . ' / '
                . ($data['max_sql_db_cnt'] != 0 ? toHtml($data['max_sql_db_cnt']) : '∞'),
            'TR_SQL_USERS_LIMIT'                   => toHtml(tr('SQL users limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
            'SQL_USERS_LIMIT'                      => toHtml($data['domain_sqlu_limit']),
            'TR_CUSTOMER_SQL_USERS_COMSUPTION'     => $data['fallback_domain_sqlu_limit'] != -1
                ? toHtml($data['nbSqlUsers']) . ' / ' . ($data['fallback_domain_sqlu_limit'] != 0
                    ? toHtml($data['fallback_domain_sqlu_limit']) : '∞') : toHtml(tr('Disabled')),
            'TR_RESELLER_SQL_USERS_COMSUPTION'     => toHtml($sqlUserCount) . ' / '
                . ($data['max_sql_user_cnt'] != 0 ? toHtml($data['max_sql_user_cnt']) : '∞')
        ]);
    }

    // Traffic limit
    $tpl->assign([
        'TR_TRAFFIC_LIMIT'                => toHtml(tr('Monthly traffic limit [MiB]')) . '<br/><i>(0 ∞)</i>',
        'TRAFFIC_LIMIT'                   => toHtml($data['domain_traffic_limit']),
        'TR_CUSTOMER_TRAFFIC_COMSUPTION'  => toHtml(bytesHuman($data['domainTraffic'])) . ' / '
            . ($data['fallback_domain_traffic_limit'] != 0 ? toHtml(mebibytesHuman($data['fallback_domain_traffic_limit'])) : '∞'),
        'TR_RESELLER_TRAFFIC_COMSUPTION'  => toHtml(bytesHuman($trafficUsage)) . ' / '
            . ($data['max_traff_amnt'] != 0 ? toHtml(mebibytesHuman($data['max_traff_amnt'])) : '∞'),

        // Disk space limit
        'TR_DISK_LIMIT'                   => toHtml(tr('Disk space limit [MiB]')) . '<br/><i>(0 ∞)</span>',
        'DISK_LIMIT'                      => toHtml($data['domain_disk_limit']),
        'TR_CUSTOMER_DISKPACE_COMSUPTION' => toHtml(bytesHuman($data['domain_disk_usage'])) . ' / '
            . ($data['fallback_domain_disk_limit'] != 0 ? toHtml(mebibytesHuman($data['fallback_domain_disk_limit'])) : '∞'),
        'TR_RESELLER_DISKPACE_COMSUPTION' => toHtml(bytesHuman($diskUsage)) . ' / '
            . ($data['max_disk_amnt'] != 0 ? toHtml(mebibytesHuman($data['max_disk_amnt'])) : '∞')
    ]);
}

Login::checkLogin('reseller');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

isset($_GET['client_id']) or View::showBadRequestErrorPage();

$clientId = intval($_GET['client_id']);

if (!empty($_POST) && updateClientAccount($clientId)) {
    redirectTo('users.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                                  => 'shared/layouts/ui.tpl',
    'page'                                    => 'reseller/account_edit.tpl',
    'page_message'                            => 'layout',
    'ip_entry'                                => 'page',
    'subdomain_limit_block'                   => 'page',
    'domain_aliases_limit_block'              => 'page',
    'mail_accounts_limit_block'               => 'page',
    'ftp_accounts_limit_block'                => 'page',
    'sql_db_and_users_limit_block'            => 'page',
    'ext_mail_block'                          => 'page',
    'php_block'                               => 'page',
    'php_editor_block'                        => 'php_block',
    'php_editor_permissions_block'            => 'php_editor_block',
    'phpini_perm_config_level_block'          => 'php_editor_permissions_block',
    'phpini_perm_config_level_per_site_block' => 'phpini_perm_config_level_block',
    'php_editor_allow_url_fopen_block'        => 'php_editor_permissions_block',
    'php_editor_display_errors_block'         => 'php_editor_permissions_block',
    'php_editor_disable_functions_block'      => 'php_editor_permissions_block',
    'php_editor_mail_function_block'          => 'php_editor_permissions_block',
    'php_editor_default_values_block'         => 'php_directives_editor_block',
    'cgi_block'                               => 'page',
    'custom_dns_records_feature'              => 'page',
    'backup_block'                            => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE' => toHtml(tr('Reseller / Customers / Overview / Edit Account')),
    'TR_UPDATE'     => toHtml(tr('Update'), 'htmlAttr'),
    'TR_CANCEL'     => toHtml(tr('Cancel'))
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['available'] = tr('Available');
    $translations['core']['assigned'] = tr('Assigned');
});
View::generateNavigation($tpl);
generatePage($tpl, $clientId);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
