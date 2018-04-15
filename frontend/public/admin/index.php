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

use iMSCP\TemplateEngine;
use iMSCP\Update\UpdateVersion;
use iMSCP_Events as Events;
use iMSCP_Registry as Registry;

/**
 * Generates support questions notice for administrator
 *
 * @return void
 */
function admin_generateSupportQuestionsMessage()
{
    $ticketsCount = execQuery('SELECT COUNT(ticket_id) FROM tickets WHERE ticket_to = ? AND ticket_status IN (1, 2) AND ticket_reply = 0', [
        $_SESSION['user_id']
    ])->fetchColumn();

    if ($ticketsCount > 0) {
        setPageMessage(ntr('You have a new support ticket.', 'You have %d new support tickets.', $ticketsCount, $ticketsCount), 'static_info');
    }
}

/**
 * Generates update messages
 *
 * Generates update messages for both database updates and i-MSCP updates.
 *
 * @return void
 */
function admin_generateUpdateMessages()
{
    if (!Registry::get('config')['CHECK_FOR_UPDATES'] || stripos(Registry::get('config')['Version'], 'git') !== false) {
        return;
    }

    $updateVersion = new UpdateVersion();
    if ($updateVersion->isAvailableUpdate()) {
        setPageMessage('<a href="imscp_updates.php" class="link">' . tr('A new i-MSCP version is available') . '</a>', 'static_info');
    } elseif (($error = $updateVersion->getError())) {
        setPageMessage($error, 'error');
    }
}

/**
 * Generates admin general informations
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function admin_getAdminGeneralInfo($tpl)
{
    $tpl->assign([
        'ADMIN_USERS'     => toHtml(getAdministratorsCount()),
        'RESELLER_USERS'  => toHtml(getResellersCount()),
        'NORMAL_USERS'    => toHtml(getCustomersCount()),
        'DOMAINS'         => toHtml(getDomainsCount()),
        'SUBDOMAINS'      => toHtml(getSubdomainsCount()),
        'DOMAINS_ALIASES' => toHtml(getDomainAliasesCount()),
        'MAIL_ACCOUNTS'   => toHtml(getMailAccountsCount())
            . (!Registry::get('config')['COUNT_DEFAULT_EMAIL_ADDRESSES'] ? ' (' . toHtml('Excl. default mail accounts') . ')' : ''),
        'FTP_ACCOUNTS'    => toHtml(getFtpUsersCount()),
        'SQL_DATABASES'   => toHtml(getSqlDatabasesCount()),
        'SQL_USERS'       => toHtml(getSqlUsersCount())
    ]);
}

/**
 * Generates server traffic bar
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function admin_generateServerTrafficInfo($tpl)
{
    $cfg = Registry::get('config');
    $trafficLimitBytes = filterDigits($cfg['SERVER_TRAFFIC_LIMIT']) * 1048576;
    $trafficWarningBytes = filterDigits($cfg['SERVER_TRAFFIC_WARN']) * 1048576;

    if (!$trafficWarningBytes) {
        $trafficWarningBytes = $trafficLimitBytes;
    }

    // Get server traffic usage in bytes for the current month
    $trafficUsageBytes = $stmt = execQuery(
        'SELECT IFNULL(SUM(bytes_in), 0) + IFNULL(SUM(bytes_out), 0) FROM server_traffic WHERE traff_time BETWEEN ? AND ?',
        [getFirstDayOfMonth(), getLastDayOfMonth()]
    )->fetchColumn();

    // Get traffic usage in percent
    $trafficUsagePercent = getPercentUsage($trafficUsageBytes, $trafficLimitBytes);
    $trafficMessage = ($trafficLimitBytes > 0)
        ? sprintf('[%s / %s]', bytesHuman($trafficUsageBytes), bytesHuman($trafficLimitBytes)) : sprintf('[%s / ∞]', bytesHuman($trafficUsageBytes));

    // traffic warning 
    if ($trafficUsageBytes
        && ($trafficWarningBytes && $trafficUsageBytes > $trafficWarningBytes || $trafficLimitBytes && $trafficUsageBytes > $trafficLimitBytes)
    ) {
        setPageMessage(tr('You are exceeding the monthly server traffic limit.'), 'static_warning');
    }

    $tpl->assign([
        'TRAFFIC_WARNING'       => toHtml($trafficMessage),
        'TRAFFIC_PERCENT_WIDTH' => toHtml($trafficUsagePercent, 'htmlAttr'),
        'TRAFFIC_PERCENT'       => toHtml($trafficUsagePercent)
    ]);
}

require 'imscp-lib.php';

checkLogin('admin', Registry::get('config')['PREVENT_EXTERNAL_LOGIN_ADMIN']);
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                  => 'shared/layouts/ui.tpl',
    'page'                    => 'admin/index.tpl',
    'page_message'            => 'layout',
    'traffic_warning_message' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => toHtml(tr('Admin / General / Overview')),
    'TR_PROPERTIES'      => toHtml(tr('Properties')),
    'TR_VALUES'          => toHtml(tr('Values')),
    'TR_ADMIN_USERS'     => toHtml(tr('Admin users')),
    'TR_RESELLER_USERS'  => toHtml(tr('Reseller users')),
    'TR_NORMAL_USERS'    => toHtml(tr('Client users')),
    'TR_DOMAINS'         => toHtml(tr('Domains')),
    'TR_SUBDOMAINS'      => toHtml(tr('Subdomains')),
    'TR_DOMAINS_ALIASES' => toHtml(tr('Domain aliases')),
    'TR_MAIL_ACCOUNTS'   => toHtml(tr('Mail accounts')),
    'TR_FTP_ACCOUNTS'    => toHtml(tr('FTP accounts')),
    'TR_SQL_DATABASES'   => toHtml(tr('SQL databases')),
    'TR_SQL_USERS'       => toHtml(tr('SQL users')),
    'TR_SERVER_TRAFFIC'  => toHtml(tr('Monthly server traffic'))
]);
generateNavigation($tpl);
admin_generateSupportQuestionsMessage();
admin_generateUpdateMessages();
admin_getAdminGeneralInfo($tpl);
admin_generateServerTrafficInfo($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAdminScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
