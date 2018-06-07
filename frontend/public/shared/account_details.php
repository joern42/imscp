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
use iMSCP\Functions\Statistics;
use iMSCP\Functions\View;

/**
 * Generate mail quota date
 *
 * @param int $clientId Client unique identifier
 * @return array
 */
function generateMailQuotaData($clientId)
{
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $clientProps = getCustomerProperties($clientId, $identity->getUserType() == 'reseller' ? $identity->getUserId() : NULL);
    $mailQuota = execQuery('SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE domain_id = ?', [$clientProps['domain_id']])->fetchColumn();
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
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $stmt = execQuery(
        "
            SELECT t1.*, t2.admin_name, IFNULL(GROUP_CONCAT(t3.ip_number ORDER BY LENGTH(t3.ip_number), t3.ip_number), '0.0.0.0') AS client_ips
            FROM domain AS t1
            JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
            LEFT JOIN server_ips AS t3 ON(FIND_IN_SET(t3.ip_id, t1.domain_client_ips) AND t3.ip_status = 'ok')
            WHERE t1.domain_admin_id = ?
        "
        . ($identity->getUserType() == 'reseller' ? 'AND created_by = ?' : '')
        . ' GROUP BY domain_admin_id',
        $identity->getUserType() == 'reseller' ? [$clientId, $identity->getUserId()] : [$clientId]
    );

    $stmt->rowCount() or View::showBadRequestErrorPage();
    $clientData = $stmt->fetch();

    // Traffic data
    $trafficUsageBytes = Statistics::getClientMonthlyTrafficStats($clientData['domain_id'])[4];
    $trafficLimitBytes = $clientData['domain_traffic_limit'] * 1048576;
    $trafficUsagePercent = Statistics::getPercentUsage($trafficUsageBytes, $trafficLimitBytes);

    // Disk usage data
    $diskspaceLimitBytes = $clientData['domain_disk_limit'] * 1048576;
    $diskspaceUsagePercent = Statistics::getPercentUsage($clientData['domain_disk_usage'], $diskspaceLimitBytes);

    // Email quota
    list($mailQuotaValue, $mailQuotaLimit) = generateMailQuotaData($clientData['domain_admin_id']);

    if ($clientData['domain_expires'] > 0) {
        $nowDate = new \DateTime();
        $expireDate = new \DateTime();
        $expireDate->setTimestamp($clientData['domain_expires']);

        if ($expireDate < $nowDate) {
            Application::getInstance()->getSession()['user_type'] == 'user'
                ? View::setPageMessage(tr('Account expired. Please renew your subscription.'), 'static_warning')
                : View::setPageMessage(tr('Account expired.'), 'static_warning');
        } elseif ($rDays = $expireDate->diff($nowDate)->format('%a') < 15) {
            View::setPageMessage(tr('%d days remaining until account expiration.', $rDays), $rDays < 8 ? 'static_warning' : 'static_info');
        } else {
            unset($expireDate);
        }
    }

    $tpl->assign([
        'VL_ACCOUNT_NAME'            => toHtml(decodeIdna($clientData['admin_name'])),
        'VL_ACCOUNT_EXPIRY_DATE'     => isset($expireDate)
            ? '<span style="color:red;font-weight:bold;">' . $expireDate->format(Application::getInstance()->getConfig()['DATE_FORMAT']) . '</span>'
            : '<span style="color:green;font-weight:bold;">' . toHtml(tr('∞')) . '</span>',
        'VL_PRIMARY_DOMAIN_NAME'     => toHtml(decodeIdna($clientData['domain_name'])),
        'VL_CLIENT_IPS'              => $clientData['client_ips'] == '0.0.0.0' ? tr('Any') : implode(', ', explode(',', $clientData['client_ips'])),
        'VL_STATUS'                  => humanizeItemStatus($clientData['domain_status'], true, true),
        'VL_PHP_SUPP'                => humanizeDbValue($clientData['domain_php']),
        'VL_PHP_EDITOR_SUPP'         => humanizeDbValue($clientData['phpini_perm_system']),
        'VL_CGI_SUPP'                => humanizeDbValue($clientData['domain_cgi']),
        'VL_DNS_SUPP'                => humanizeDbValue($clientData['domain_dns']),
        'VL_EXT_MAIL_SUPP'           => humanizeDbValue($clientData['domain_external_mail']),
        'VL_BACKUP_SUPP'             => humanizeDbValue($clientData['allowbackup']),
        'VL_WEB_FOLDER_PROTECTION'   => humanizeDbValue($clientData['web_folder_protection']),
        'VL_SUBDOM_ACCOUNTS_USED'    => toHtml(Counting::getCustomerSubdomainsCount($clientData['domain_id'])),
        'VL_SUBDOM_ACCOUNTS_LIMIT'   => humanizeDbValue($clientData['domain_subd_limit']),
        'VL_DOMALIAS_ACCOUNTS_USED'  => toHtml(Counting::getCustomerDomainAliasesCount($clientData['domain_id'])),
        'VL_DOMALIAS_ACCOUNTS_LIMIT' => humanizeDbValue($clientData['domain_alias_limit']),
        'VL_FTP_ACCOUNTS_USED'       => toHtml(Counting::getCustomerFtpUsersCount($clientData['domain_admin_id'])),
        'VL_FTP_ACCOUNTS_LIMIT'      => humanizeDbValue($clientData['domain_ftpacc_limit']),
        'VL_SQL_DB_ACCOUNTS_USED'    => toHtml(Counting::getCustomerSqlDatabasesCount($clientData['domain_id'])),
        'VL_SQL_DB_ACCOUNTS_LIMIT'   => humanizeDbValue($clientData['domain_sqld_limit']),
        'VL_SQL_USER_ACCOUNTS_LIMIT' => humanizeDbValue($clientData['domain_sqlu_limit']),
        'VL_SQL_USER_ACCOUNTS_USED'  => toHtml(Counting::getCustomerSqlUsersCount($clientData['domain_id'])),
        'VL_MAIL_ACCOUNTS_USED'      => toHtml(Counting::getCustomerMailAccountsCount($clientData['domain_id'])),
        'VL_MAIL_ACCOUNTS_LIMIT'     => humanizeDbValue($clientData['domain_mailacc_limit']),
        'VL_MAIL_QUOTA_USED'         => toHtml($mailQuotaValue),
        'VL_MAIL_QUOTA_LIMIT'        => humanizeDbValue($mailQuotaLimit),
        'VL_TRAFFIC_PERCENT'         => toHtml($trafficUsagePercent, 'htmlAttr'),
        'VL_TRAFFIC_USED'            => toHtml(bytesHuman($trafficUsageBytes)),
        'VL_TRAFFIC_LIMIT'           => toHtml(bytesHuman($trafficLimitBytes)),
        'VL_DISK_PERCENT'            => toHtml($diskspaceUsagePercent, 'htmlAttr'),
        'VL_DISK_USED'               => toHtml(bytesHuman($clientData['domain_disk_usage'])),
        'VL_DISK_LIMIT'              => toHtml(bytesHuman($diskspaceLimitBytes)),
        'VL_WEB_DATA'                => toHtml(bytesHuman($clientData['domain_disk_file'])),
        'VL_SQL_DATA'                => toHtml(bytesHuman($clientData['domain_disk_sql'])),
        'VL_MAIL_DATA'               => toHtml(bytesHuman($clientData['domain_disk_mail']))
    ]);
}

require_once 'application.php';

defined('SHARED_SCRIPT_NEEDED') or View::showNotFoundErrorPage();

isset($_GET['id']) or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/account_details.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_ACCOUNT'               => toHtml(tr('Account')),
    'TR_ACCOUNT_NAME'          => toHtml(tr('Name')),
    'TR_ACCOUNT_EXPIRY_DATE'   => toHtml(tr('Expiry date')),
    'TR_PRIMARY_DOMAIN_NAME'   => toHtml(tr('Primary domain name')),
    'TR_CLIENT_IPS'            => toHtml(tr('IP addresses')),
    'TR_STATUS'                => toHtml(tr('Status')),
    'TR_FEATURES'              => toHtml(tr('Features')),
    'TR_PHP_SUPP'              => toHtml(tr('PHP')),
    'TR_PHP_EDITOR_SUPP'       => toHtml(tr('PHP Editor')),
    'TR_CGI_SUPP'              => toHtml(tr('CGI')),
    'TR_DNS_SUPP'              => toHtml(tr('Custom DNS records')),
    'TR_EXT_MAIL_SUPP'         => toHtml(tr('Ext. mail server')),
    'TR_BACKUP_SUPP'           => toHtml(tr('Backup')),
    'TR_WEB_FOLDER_PROTECTION' => toHtml(tr('Web folder protection')),
    'TR_LIMITS'                => toHtml(tr('Limits')),
    'TR_SUBDOM_ACCOUNTS'       => toHtml(tr('Subdomains')),
    'TR_DOMALIAS_ACCOUNTS'     => toHtml(tr('Domain aliases')),
    'TR_MAIL_ACCOUNTS'         => toHtml(tr('Mail accounts')),
    'TR_MAIL_QUOTA'            => toHtml(tr('Mail quota')),
    'TR_FTP_ACCOUNTS'          => toHtml(tr('FTP accounts')),
    'TR_SQL_DB_ACCOUNTS'       => toHtml(tr('SQL databases')),
    'TR_SQL_USER_ACCOUNTS'     => toHtml(tr('SQL users')),
    'TR_UPDATE_DATA'           => toHtml(tr('Submit changes')),
    'TR_TRAFFIC_USAGE'         => toHtml(tr('Traffic usage')),
    'TR_DISK_USAGE'            => toHtml(tr('Disk usage')),
    'TR_DISK_USAGE_DETAILS'    => toHtml(tr('Details')),
    'TR_DISK_WEB_USAGE'        => toHtml(tr('Web data')),
    'TR_DISK_SQL_USAGE'        => toHtml(tr('SQL data')),
    'TR_DISK_MAIL_USAGE'       => toHtml(tr('Mail data'))
]);
View::generateNavigation($tpl);
generatePage($tpl, intval($_GET['id']));
View::generatePageMessages($tpl);
