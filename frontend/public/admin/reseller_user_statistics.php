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

use iMSCP\Authentication\AuthenticationService;
use iMSCP\Functions\Statistics;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Genrate statistics entry for the given user
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param int $adminId User unique identifier
 * @return void
 */
function _generateUserStatistics(TemplateEngine $tpl, $adminId)
{
    list($webTraffic, $ftpTraffic, $smtpTraffic, $pop3Traffic, $trafficUsage, $diskUsage
        ) = Statistics::getClientTrafficAndDiskStats($adminId);
    list($subCount, $subLimit, $alsCount, $alsLimit, $mailCount, $mailLimit, $ftpCount, $ftpLimit, $sqlDbCount,
        $sqlDbLimit, $sqlUsersCount, $sqlUsersLlimit, $trafficLimit, $diskLimit
        ) = Statistics::getClientObjectsCountAndLimits($adminId);
    $trafficUsagePercent = Statistics::getPercentUsage($trafficUsage, $trafficLimit);
    $diskspaceUsagePercent = Statistics::getPercentUsage($diskUsage, $diskLimit);
    $tpl->assign([
        'USER_NAME'             => toHtml(decodeIdna(getUsername($adminId))),
        'USER_ID'               => toHtml($adminId),
        'TRAFFIC_PERCENT_WIDTH' => toHtml($trafficUsagePercent, 'htmlAttr'),
        'TRAFFIC_PERCENT'       => toHtml($trafficUsagePercent),
        'TRAFFIC_MSG'           => $trafficLimit > 0
            ? toHtml(sprintf('%s / %s', bytesHuman($trafficUsage), bytesHuman($trafficLimit)))
            : toHtml(sprintf('%s / ∞', bytesHuman($trafficUsage))),
        'DISK_PERCENT_WIDTH'    => toHtml($diskspaceUsagePercent, 'htmlAttr'),
        'DISK_PERCENT'          => toHtml($diskspaceUsagePercent),
        'DISK_MSG'              => $diskLimit > 0
            ? toHtml(sprintf('%s / %s', bytesHuman($diskUsage), bytesHuman($diskLimit)))
            : toHtml(sprintf('%s / ∞', bytesHuman($diskUsage))),
        'WEB'                   => toHtml(bytesHuman($webTraffic)),
        'FTP'                   => toHtml(bytesHuman($ftpTraffic)),
        'SMTP'                  => toHtml(bytesHuman($smtpTraffic)),
        'POP3'                  => toHtml(bytesHuman($pop3Traffic)),
        'SUB_MSG'               => toHtml(sprintf('%s / %s', $subCount, humanizeDbValue($subLimit))),
        'ALS_MSG'               => toHtml(sprintf('%s / %s', $alsCount, humanizeDbValue($alsLimit))),
        'MAIL_MSG'              => toHtml(sprintf('%s / %s', $mailCount, humanizeDbValue($mailLimit))),
        'FTP_MSG'               => toHtml(sprintf('%s / %s', $ftpCount, humanizeDbValue($ftpLimit))),
        'SQL_DB_MSG'            => toHtml(sprintf('%s / %s', $sqlDbCount, humanizeDbValue($sqlDbLimit))),
        'SQL_USER_MSG'          => toHtml(sprintf('%s / %s', $sqlUsersCount, humanizeDbValue($sqlUsersLlimit)))
    ]);
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param int $resellerId Reseller unique identifier
 * @return void
 */
function generatePage(TemplateEngine $tpl, $resellerId)
{
    $stmt = execQuery('SELECT admin_id FROM admin WHERE created_by = ?', [$resellerId]);

    if (!$stmt->rowCount()) {
        $tpl->assign('RESELLER_USER_STATISTICS_BLOCK', '');
        return;
    }

    while ($row = $stmt->fetch()) {
        _generateUserStatistics($tpl, $row['admin_id']);
        $tpl->parse('RESELLER_USER_STATISTICS_BLOCK', '.reseller_user_statistics_block');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

if (isset($_GET['reseller_id'])) {
    $resellerId = intval($_GET['reseller_id']);
    Application::getInstance()->getSession()['stats_reseller_id'] = $resellerId;
} elseif (isset(Application::getInstance()->getSession()['stats_reseller_id'])) {
    redirectTo('reseller_user_statistics.php?reseller_id=' . Application::getInstance()->getSession()['stats_reseller_id']);
    exit;
} else {
    View::showBadRequestErrorPage();
    exit;
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                         => 'shared/layouts/ui.tpl',
    'page'                           => 'admin/reseller_user_statistics.tpl',
    'page_message'                   => 'layout',
    'reseller_user_statistics_block' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'             => toHtml(tr('Admin / Statistics / Reseller Statistics / User Statistics')),
    'TR_USERNAME'               => toHtml(tr('User')),
    'TR_TRAFF'                  => toHtml(tr('Monthly traffic usage')),
    'TR_DISK'                   => toHtml(tr('Disk usage')),
    'TR_WEB'                    => toHtml(tr('HTTP traffic')),
    'TR_FTP_TRAFF'              => toHtml(tr('FTP traffic')),
    'TR_SMTP'                   => toHtml(tr('SMTP traffic')),
    'TR_POP3'                   => toHtml(tr('POP3/IMAP traffic')),
    'TR_SUBDOMAIN'              => toHtml(tr('Subdomains')),
    'TR_ALIAS'                  => toHtml(tr('Domain aliases')),
    'TR_MAIL'                   => toHtml(tr('Mail accounts')),
    'TR_FTP'                    => toHtml(tr('FTP accounts')),
    'TR_SQL_DB'                 => toHtml(tr('SQL databases')),
    'TR_SQL_USER'               => toHtml(tr('SQL users')),
    'TR_DETAILED_STATS_TOOLTIP' => toHtml(tr('Show detailed statistics for this user'), 'htmlAttr')
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations(false);
});
View::generateNavigation($tpl);
generatePage($tpl, $resellerId);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
