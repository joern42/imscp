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
use iMSCP\Functions\Login;
use iMSCP\Functions\Statistics;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generates statistics for the given reseller
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param int $resellerId Reseller unique identifier
 * @param string $resellerName Reseller name
 * @return void
 */
function _generateResellerStatistics(TemplateEngine $tpl, $resellerId, $resellerName)
{
    $resellerProps = getResellerProperties($resellerId, true);
    $rtraffLimit = $resellerProps['max_traff_amnt'] * 1048576;
    $rdiskLimit = $resellerProps['max_disk_amnt'] * 1048576;
    list($rdmnConsumed, $rsubConsumed, $ralsConsumed, $rmailConsumed, $rftpConsumed, $rsqlDbConsumed,
        $rsqlUserConsumed, $rtraffConsumed, $rdiskConsumed) = Statistics::getResellerStats($resellerId);

    $diskUsagePercent = Statistics::getPercentUsage($rdiskConsumed, $rdiskLimit);
    $trafficPercent = Statistics::getPercentUsage($rtraffConsumed, $rtraffLimit);

    $tpl->assign([
        'RESELLER_NAME'         => toHtml($resellerName),
        'RESELLER_ID'           => toHtml($resellerId),
        'DISK_PERCENT_WIDTH'    => toHtml($diskUsagePercent, 'htmlAttr'),
        'DISK_PERCENT'          => toHtml($diskUsagePercent),
        'DISK_MSG'              => ($rdiskLimit == 0)
            ? toHtml(sprintf('%s / ∞', bytesHuman($rdiskConsumed)))
            : toHtml(sprintf('%s / %s', bytesHuman($rdiskConsumed), bytesHuman($rdiskLimit))),
        'TRAFFIC_PERCENT_WIDTH' => toHtml($trafficPercent, 'htmlAttr'),
        'TRAFFIC_PERCENT'       => toHtml($trafficPercent),
        'TRAFFIC_MSG'           => ($rtraffLimit == 0)
            ? toHtml(sprintf('%s / ∞', bytesHuman($rtraffConsumed)))
            : toHtml(sprintf('%s / %s', bytesHuman($rtraffConsumed), bytesHuman($rtraffLimit))),
        'DMN_MSG'               => ($resellerProps['max_dmn_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rdmnConsumed))
            : ($resellerProps['max_dmn_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rdmnConsumed, $resellerProps['max_dmn_cnt']))),
        'SUB_MSG'               => ($resellerProps['max_sub_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rsubConsumed))
            : ($resellerProps['max_sub_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rsubConsumed, $resellerProps['max_sub_cnt']))),
        'ALS_MSG'               => ($resellerProps['max_als_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $ralsConsumed))
            : ($resellerProps['max_als_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $ralsConsumed, $resellerProps['max_als_cnt']))),
        'MAIL_MSG'              => ($resellerProps['max_mail_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rmailConsumed))
            : ($resellerProps['max_mail_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rmailConsumed, $resellerProps['max_mail_cnt']))),
        'FTP_MSG'               => ($resellerProps['max_ftp_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rftpConsumed))
            : ($resellerProps['max_ftp_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rftpConsumed, $resellerProps['max_ftp_cnt']))),
        'SQL_DB_MSG'            => ($resellerProps['max_sql_db_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rsqlDbConsumed))
            : ($resellerProps['max_sql_db_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rsqlDbConsumed, $resellerProps['max_sql_db_cnt']))),
        'SQL_USER_MSG'          => ($resellerProps['max_sql_user_cnt'] == 0)
            ? toHtml(sprintf('%s / ∞', $rsqlUserConsumed))
            : ($resellerProps['max_sql_user_cnt'] == -1
                ? '-' : toHtml(sprintf('%s / %s', $rsqlUserConsumed, $resellerProps['max_sql_user_cnt'])))
    ]);
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $stmt = execQuery("SELECT admin_id, admin_name FROM admin WHERE admin_type = 'reseller'");
    while ($row = $stmt->fetch()) {
        _generateResellerStatistics($tpl, $row['admin_id'], $row['admin_name']);
        $tpl->parse('RESELLER_STATISTICS_BLOCK', '.reseller_statistics_block');
    }
}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
Counting::systemHasResellers() or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                    => 'shared/layouts/ui.tpl',
    'page'                      => 'admin/reseller_statistics.tpl',
    'page_message'              => 'layout',
    'reseller_statistics_block' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'              => toHtml(tr('Admin / Statistics / Reseller Statistics')),
    'TR_RESELLER_NAME'           => toHtml(tr('Reseller')),
    'TR_TRAFFIC_USAGE'           => toHtml(tr('Monthly traffic usage')),
    'TR_DISK_USAGE'              => toHtml(tr('Disk usage')),
    'TR_DOMAINS'                 => toHtml(tr('Domains')),
    'TR_SUBDOMAINS'              => toHtml(tr('Subdomains')),
    'TR_DOMAIN_ALIASES'          => toHtml(tr('Domain aliases')),
    'TR_MAIL_ACCOUNTS'           => toHtml(tr('Mail accounts')),
    'TR_FTP_ACCOUNTS'            => toHtml(tr('FTP accounts')),
    'TR_SQL_DATABASES'           => toHtml(tr('SQL databases')),
    'TR_SQL_USERS'               => toHtml(tr('SQL users')),
    'TR_DETAILED_STATS_TOOLTIPS' => toHtml(tr('Show detailed statistics for this reseller'), 'htmlAttr')
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations(false);
});
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
