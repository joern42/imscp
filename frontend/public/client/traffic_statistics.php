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
use iMSCP\Functions\View;

/**
 * Get traffic for the given domain and the given period
 *
 * @param int $domainId Customer primary  domain unique identifier
 * @param int $startDate An UNIX timestamp representing a start date
 * @param int $endDate An UNIX timestamp representing an end date
 * @return array
 */
function getUserTraffic($domainId, $startDate, $endDate)
{
    static $stmt;

    if (NULL === $stmt) {
        $stmt = Application::getInstance()->getDb()->createStatement(
            '
                SELECT IFNULL(SUM(dtraff_web), 0) AS web_traffic, IFNULL(SUM(dtraff_ftp), 0) AS ftp_traffic,
                    IFNULL(SUM(dtraff_mail), 0) AS smtp_traffic, IFNULL(SUM(dtraff_pop),0) AS pop_traffic
                FROM domain_traffic
                WHERE domain_id = ?
                AND dtraff_time BETWEEN ? AND ?
            '
        );
        $stmt->prepare();
    }

    $result = $stmt->execute([$domainId, $startDate, $endDate])->getResource();

    if (!$result->rowCount()) {
        return array_fill(0, 4, 0);
    }

    $row = $result->fetch();
    return [$row['web_traffic'], $row['ftp_traffic'], $row['smtp_traffic'], $row['pop_traffic']];
}

/**
 * Generate statistics for the given period
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $domainId = getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    $month = isset($_GET['month']) ? filterDigits($_GET['month']) : date('n');
    $year = isset($_GET['year']) ? filterDigits($_GET['year']) : date('Y');
    $stmt = execQuery('SELECT dtraff_time FROM domain_traffic WHERE domain_id = ? ORDER BY dtraff_time ASC LIMIT 1', [$domainId]);
    $nPastYears = $stmt->rowCount() ? date('Y') - date('Y', $stmt->fetchColumn()) : 0;

    View::generateDMYlists($tpl, 0, $month, $year, $nPastYears);

    $stmt = execQuery('SELECT domain_id FROM domain_traffic WHERE domain_id = ? AND dtraff_time BETWEEN ? AND ? LIMIT 1', [
        $domainId, getFirstDayOfMonth($month, $year), getLastDayOfMonth($month, $year)
    ]);

    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('No statistics found for the given period. Try another period.'), 'static_info');
        $tpl->assign('STATISTICS_BLOCK', '');
        return;
    }

    $requestedPeriod = getLastDayOfMonth($month, $year);
    $toDay = $requestedPeriod < time() ? date('j', $requestedPeriod) : date('j');
    $all = array_fill(0, 8, 0);
    $dateFormat = Application::getInstance()->getConfig()['DATE_FORMAT'];

    for ($fromDay = 1; $fromDay <= $toDay; $fromDay++) {
        $startDate = mktime(0, 0, 0, $month, $fromDay, $year);
        $endDate = mktime(23, 59, 59, $month, $fromDay, $year);
        list($webTraffic, $ftpTraffic, $smtpTraffic, $popTraffic) = getUserTraffic($domainId, $startDate, $endDate);
        $tpl->assign([
            'DATE'       => toHtml(date($dateFormat, strtotime($year . '-' . $month . '-' . $fromDay))),
            'WEB_TRAFF'  => toHtml(bytesHuman($webTraffic)),
            'FTP_TRAFF'  => toHtml(bytesHuman($ftpTraffic)),
            'SMTP_TRAFF' => toHtml(bytesHuman($smtpTraffic)),
            'POP_TRAFF'  => toHtml(bytesHuman($popTraffic)),
            'SUM_TRAFF'  => toHtml(bytesHuman($webTraffic + $ftpTraffic + $smtpTraffic + $popTraffic))
        ]);
        $all[0] += $webTraffic;
        $all[1] += $ftpTraffic;
        $all[2] += $smtpTraffic;
        $all[3] += $popTraffic;
        $tpl->parse('TRAFFIC_TABLE_ITEM', '.traffic_table_item');
    }

    $tpl->assign([
        'WEB_ALL'  => toHtml(bytesHuman($all[0])),
        'FTP_ALL'  => toHtml(bytesHuman($all[1])),
        'SMTP_ALL' => toHtml(bytesHuman($all[2])),
        'POP_ALL'  => toHtml(bytesHuman($all[3])),
        'SUM_ALL'  => toHtml(bytesHuman(array_sum($all)))
    ]);

}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::USER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'client/traffic_statistics.tpl',
    'page_message'       => 'layout',
    'month_list'         => 'page',
    'year_list'          => 'page',
    'statistics_block'   => 'page',
    'traffic_table_item' => 'statistics_block'
]);
$tpl->assign([
    'TR_PAGE_TITLE' => toHtml(tr('Client / Statistics')),
    'TR_STATISTICS' => toHtml(tr('Statistics')),
    'TR_MONTH'      => toHtml(tr('Month')),
    'TR_YEAR'       => toHtml(tr('Year')),
    'TR_SHOW'       => toHtml(tr('Show')),
    'TR_WEB_TRAFF'  => toHtml(tr('Web traffic')),
    'TR_FTP_TRAFF'  => toHtml(tr('FTP traffic')),
    'TR_SMTP_TRAFF' => toHtml(tr('SMTP traffic')),
    'TR_POP_TRAFF'  => toHtml(tr('POP3/IMAP traffic')),
    'TR_SUM'        => toHtml(tr('All traffic')),
    'TR_ALL'        => toHtml(tr('All')),
    'TR_DATE'       => toHtml(tr('Date'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
