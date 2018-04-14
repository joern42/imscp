<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

use iMSCP\TemplateEngine;
use iMSCP_Registry as Registry;

/**
 * Generate mail quota date
 *
 * @param int $clientId Client unique identifier
 * @return array
 */
function generateMailQuotaData($clientId)
{
    $clientProps = get_domain_default_props($clientId, $_SESSION['user_type'] == 'reseller' ? $_SESSION['user_id'] : NULL);
    $mailQuota = exec_query('SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE domain_id = ?', [$clientProps['domain_id']])->fetchColumn();
    return [bytesHuman($mailQuota), $clientProps['mail_quota'] == 0 ? '∞' : bytesHuman($clientProps['mail_quota'])];
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template instance engine
 * @param int $clientId Client unique identifier
 * @return void
 */
function generatePage($tpl, $clientId)
{
    $stmt = exec_query(
        "
            SELECT t1.*, t2.admin_name, IFNULL(GROUP_CONCAT(t3.ip_number ORDER BY LENGTH(t3.ip_number), t3.ip_number), '0.0.0.0') AS client_ips
            FROM domain AS t1
            JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
            LEFT JOIN server_ips AS t3 ON(FIND_IN_SET(t3.ip_id, t1.domain_client_ips) AND t3.ip_status = 'ok')
            WHERE t1.domain_admin_id = ?
        " . ($_SESSION['user_type'] == 'reseller' ? 'AND created_by = ?' : '') . ' GROUP BY domain_admin_id',
        $_SESSION['user_type'] == 'reseller' ? [$clientId, $_SESSION['user_id']] : [$clientId]
    );

    $stmt->rowCount() or showBadRequestErrorPage();
    $clientData = $stmt->fetch();

    // Traffic data
    $trafficUsageBytes = getClientMonthlyTrafficStats($clientData['domain_id'])[4];
    $trafficLimitBytes = $clientData['domain_traffic_limit'] * 1048576;
    $trafficUsagePercent = getPercentUsage($trafficUsageBytes, $trafficLimitBytes);

    // Disk usage data
    $diskspaceLimitBytes = $clientData['domain_disk_limit'] * 1048576;
    $diskspaceUsagePercent = getPercentUsage($clientData['domain_disk_usage'], $diskspaceLimitBytes);

    // Email quota
    list($mailQuotaValue, $mailQuotaLimit) = generateMailQuotaData($clientData['domain_admin_id']);

    $date = new Zend_Date($clientData['domain_expires']);
    if ($clientData['domain_expires']) {
        $cDate = clone $date;
        $rDays = ceil($cDate->sub(Zend_Date::now())->toValue() / 60 / 60 / 24);

        if (!$rDays) {
            if ($_SESSION['user_type'] == 'user') {
                set_page_message(tr('Account expired. Please renew your subscription.'), 'static_warning');
            } else {
                set_page_message(tr('Account expired.'), 'static_warning');
            }
        } elseif ($rDays < 15) {
            set_page_message(
                ntr('%d day remaining until account expiration.', '%d days remaining until account expiration.', $rDays),
                $rDays < 8 ? 'static_warning' : 'static_info'
            );
        }
    } else {
        $rDays = 15;
    }

    $tpl->assign([
        'VL_ACCOUNT_NAME'            => tohtml(decode_idna($clientData['admin_name'])),
        'VL_ACCOUNT_EXPIRY_DATE'     => ($rDays < 15 ? '<span style="color:red;font-weight:bold;">' : '<span style="color:green;font-weight:bold;">')
            . tohtml($clientData['domain_expires'] ? $date->toString(Registry::get('config')['DATE_FORMAT'], 'php') : tr('∞')) . '</span>',
        'VL_PRIMARY_DOMAIN_NAME'     => tohtml(decode_idna($clientData['domain_name'])),
        'VL_CLIENT_IPS'              => $clientData['client_ips'] == '0.0.0.0' ? tr('Any') : implode(', ', explode(',', $clientData['client_ips'])),
        'VL_STATUS'                  => translate_dmn_status($clientData['domain_status'], true, true),
        'VL_PHP_SUPP'                => humanizeDbValue($clientData['domain_php']),
        'VL_PHP_EDITOR_SUPP'         => humanizeDbValue($clientData['phpini_perm_system']),
        'VL_CGI_SUPP'                => humanizeDbValue($clientData['domain_cgi']),
        'VL_DNS_SUPP'                => humanizeDbValue($clientData['domain_dns']),
        'VL_EXT_MAIL_SUPP'           => humanizeDbValue($clientData['domain_external_mail']),
        'VL_SOFTWARE_SUPP'           => humanizeDbValue($clientData['domain_software_allowed']),
        'VL_BACKUP_SUPP'             => humanizeDbValue($clientData['allowbackup']),
        'VL_WEB_FOLDER_PROTECTION'   => humanizeDbValue($clientData['web_folder_protection']),
        'VL_SUBDOM_ACCOUNTS_USED'    => tohtml(get_customer_subdomains_count($clientData['domain_id'])),
        'VL_SUBDOM_ACCOUNTS_LIMIT'   => humanizeDbValue($clientData['domain_subd_limit']),
        'VL_DOMALIAS_ACCOUNTS_USED'  => tohtml(get_customer_domain_aliases_count($clientData['domain_id'])),
        'VL_DOMALIAS_ACCOUNTS_LIMIT' => humanizeDbValue($clientData['domain_alias_limit']),
        'VL_FTP_ACCOUNTS_USED'       => tohtml(get_customer_ftp_users_count($clientData['domain_admin_id'])),
        'VL_FTP_ACCOUNTS_LIMIT'      => humanizeDbValue($clientData['domain_ftpacc_limit']),
        'VL_SQL_DB_ACCOUNTS_USED'    => tohtml(get_customer_sql_databases_count($clientData['domain_id'])),
        'VL_SQL_DB_ACCOUNTS_LIMIT'   => humanizeDbValue($clientData['domain_sqld_limit']),
        'VL_SQL_USER_ACCOUNTS_LIMIT' => humanizeDbValue($clientData['domain_sqlu_limit']),
        'VL_SQL_USER_ACCOUNTS_USED'  => tohtml(get_customer_sql_users_count($clientData['domain_id'])),
        'VL_MAIL_ACCOUNTS_USED'      => tohtml(get_customer_mail_accounts_count($clientData['domain_id'])),
        'VL_MAIL_ACCOUNTS_LIMIT'     => humanizeDbValue($clientData['domain_mailacc_limit']),
        'VL_MAIL_QUOTA_USED'         => tohtml($mailQuotaValue),
        'VL_MAIL_QUOTA_LIMIT'        => humanizeDbValue($mailQuotaLimit),
        'VL_TRAFFIC_PERCENT'         => tohtml($trafficUsagePercent, 'htmlAttr'),
        'VL_TRAFFIC_USED'            => tohtml(bytesHuman($trafficUsageBytes)),
        'VL_TRAFFIC_LIMIT'           => tohtml(bytesHuman($trafficLimitBytes)),
        'VL_DISK_PERCENT'            => tohtml($diskspaceUsagePercent, 'htmlAttr'),
        'VL_DISK_USED'               => tohtml(bytesHuman($clientData['domain_disk_usage'])),
        'VL_DISK_LIMIT'              => tohtml(bytesHuman($diskspaceLimitBytes)),
        'VL_WEB_DATA'                => tohtml(bytesHuman($clientData['domain_disk_file'])),
        'VL_SQL_DATA'                => tohtml(bytesHuman($clientData['domain_disk_sql'])),
        'VL_MAIL_DATA'               => tohtml(bytesHuman($clientData['domain_disk_mail']))
    ]);
}

require_once 'imscp-lib.php';

defined('SHARED_SCRIPT_NEEDED') or showNotFoundErrorPage();

isset($_GET['client_id']) or showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/account_details.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_ACCOUNT'               => tohtml(tr('Account')),
    'TR_ACCOUNT_NAME'          => tohtml(tr('Name')),
    'TR_ACCOUNT_EXPIRY_DATE'   => tohtml(tr('Expiry date')),
    'TR_PRIMARY_DOMAIN_NAME'   => tohtml(tr('Primary domain name')),
    'TR_CLIENT_IPS'            => tohtml(tr('IP addresses')),
    'TR_STATUS'                => tohtml(tr('Status')),
    'TR_FEATURES'              => tohtml(tr('Features')),
    'TR_PHP_SUPP'              => tohtml(tr('PHP')),
    'TR_PHP_EDITOR_SUPP'       => tohtml(tr('PHP Editor')),
    'TR_CGI_SUPP'              => tohtml(tr('CGI')),
    'TR_DNS_SUPP'              => tohtml(tr('Custom DNS records')),
    'TR_EXT_MAIL_SUPP'         => tohtml(tr('Ext. mail server')),
    'TR_BACKUP_SUPP'           => tohtml(tr('Backup')),
    'TR_WEB_FOLDER_PROTECTION' => tohtml(tr('Web folder protection')),
    'TR_LIMITS'                => tohtml(tr('Limits')),
    'TR_SUBDOM_ACCOUNTS'       => tohtml(tr('Subdomains')),
    'TR_DOMALIAS_ACCOUNTS'     => tohtml(tr('Domain aliases')),
    'TR_MAIL_ACCOUNTS'         => tohtml(tr('Mail accounts')),
    'TR_MAIL_QUOTA'            => tohtml(tr('Mail quota')),
    'TR_FTP_ACCOUNTS'          => tohtml(tr('FTP accounts')),
    'TR_SQL_DB_ACCOUNTS'       => tohtml(tr('SQL databases')),
    'TR_SQL_USER_ACCOUNTS'     => tohtml(tr('SQL users')),
    'TR_UPDATE_DATA'           => tohtml(tr('Submit changes')),
    'TR_SOFTWARE_SUPP'         => tohtml(tr('Software installer')),
    'TR_TRAFFIC_USAGE'         => tohtml(tr('Traffic usage')),
    'TR_DISK_USAGE'            => tohtml(tr('Disk usage')),
    'TR_DISK_USAGE_DETAILS'    => tohtml(tr('Details')),
    'TR_DISK_WEB_USAGE'        => tohtml(tr('Web data')),
    'TR_DISK_SQL_USAGE'        => tohtml(tr('SQL data')),
    'TR_DISK_MAIL_USAGE'       => tohtml(tr('Mail data'))
]);

generateNavigation($tpl);
generatePage($tpl, intval($_GET['client_id']));
generatePageMessage($tpl);
