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
 * Get server traffic for the given period
 *
 * @param int $startDate UNIX timestamp representing a start date
 * @param int $endDate UNIX timestamp representing an end date
 * @return array
 */
function getServerTraffic($startDate, $endDate)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        $stmt = Application::getInstance()->getDb()->createStatement(
            '
                SELECT IFNULL(SUM(bytes_in), 0) AS sbin,
                    IFNULL(SUM(bytes_out), 0) AS sbout,
                    IFNULL(SUM(bytes_mail_in), 0) AS smbin,
                    IFNULL(SUM(bytes_mail_out), 0) AS smbout,
                    IFNULL(SUM(bytes_pop_in), 0) AS spbin,
                    IFNULL(SUM(bytes_pop_out), 0) AS spbout,
                    IFNULL(SUM(bytes_web_in), 0) AS swbin,
                    IFNULL(SUM(bytes_web_out), 0) AS swbout
                FROM server_traffic
                WHERE traff_time BETWEEN ? AND ?
            '
        );
        $stmt->prepare();
    }

    $result = $stmt->execute([$startDate, $endDate])->getResource();

    if (($row = $result->fetch()) === false) {
        return array_fill(0, 10, 0);
    }

    return [
        $row['swbin'], $row['swbout'], $row['smbin'], $row['smbout'], $row['spbin'], $row['spbout'],
        $row['sbin'] - ($row['swbin'] + $row['smbin'] + $row['spbin']),
        $row['sbout'] - ($row['swbout'] + $row['smbout'] + $row['spbout']),
        $row['sbin'], $row['sbout']
    ];
}

/**
 * Generate server statistics by day
 *
 * @param TemplateEngine $tpl
 * @param int $day Selected day
 * @param int $month Selected month
 * @param int $year Selected year
 */
function generateServerStatsByDay(TemplateEngine $tpl, $day, $month, $year)
{
    $stmt = execQuery(
        '
            SELECT traff_time AS period, bytes_in AS all_in, bytes_out AS all_out, bytes_mail_in AS mail_in,
                bytes_mail_out AS mail_out, bytes_pop_in AS pop_in, bytes_pop_out AS pop_out, bytes_web_in AS web_in,
                bytes_web_out AS web_out
            FROM server_traffic
            WHERE traff_time BETWEEN ? AND ?
        ',
        [mktime(0, 0, 0, $month, $day, $year), mktime(23, 59, 59, $month, $day, $year)]
    );

    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('No statistics found for the given period. Try another period.'), 'static_info');
        $tpl->assign('SERVER_STATS_BY_DAY', '');
        return;
    }

    $all = array_fill(0, 8, 0);

    while ($row = $stmt->fetch()) {
        $otherIn = $row['all_in'] - ($row['mail_in'] + $row['pop_in'] + $row['web_in']);
        $otherOut = $row['all_out'] - ($row['mail_out'] + $row['pop_out'] + $row['web_out']);

        $tpl->assign([
            'HOUR'      => toHtml(date('H:i', $row['period'])),
            'WEB_IN'    => toHtml(bytesHuman($row['web_in'])),
            'WEB_OUT'   => toHtml(bytesHuman($row['web_out'])),
            'SMTP_IN'   => toHtml(bytesHuman($row['mail_in'])),
            'SMTP_OUT'  => toHtml(bytesHuman($row['mail_out'])),
            'POP_IN'    => toHtml(bytesHuman($row['pop_in'])),
            'POP_OUT'   => toHtml(bytesHuman($row['pop_out'])),
            'OTHER_IN'  => toHtml(bytesHuman($otherIn)),
            'OTHER_OUT' => toHtml(bytesHuman($otherOut)),
            'ALL_IN'    => toHtml(bytesHuman($row['all_in'])),
            'ALL_OUT'   => toHtml(bytesHuman($row['all_out'])),
            'ALL'       => toHtml(bytesHuman($row['all_in'] + $row['all_out']))
        ]);

        $all[0] += $row['web_in'];
        $all[1] += $row['web_out'];
        $all[2] += $row['mail_in'];
        $all[3] += $row['mail_out'];
        $all[4] += $row['pop_in'];
        $all[5] += $row['pop_out'];
        $all[6] += $row['all_in'];
        $all[7] += $row['all_out'];

        $tpl->parse('SERVER_STATS_HOUR', '.server_stats_hour');
    }

    $allOtherIn = $all[6] - ($all[0] + $all[2] + $all[4]);
    $allOtherOut = $all[7] - ($all[1] + $all[3] + $all[5]);

    $tpl->assign([
        'WEB_IN_ALL'    => toHtml(bytesHuman($all[0])),
        'WEB_OUT_ALL'   => toHtml(bytesHuman($all[1])),
        'SMTP_IN_ALL'   => toHtml(bytesHuman($all[2])),
        'SMTP_OUT_ALL'  => toHtml(bytesHuman($all[3])),
        'POP_IN_ALL'    => toHtml(bytesHuman($all[4])),
        'POP_OUT_ALL'   => toHtml(bytesHuman($all[5])),
        'OTHER_IN_ALL'  => toHtml(bytesHuman($allOtherIn)),
        'OTHER_OUT_ALL' => toHtml(bytesHuman($allOtherOut)),
        'ALL_IN_ALL'    => toHtml(bytesHuman($all[6])),
        'ALL_OUT_ALL'   => toHtml(bytesHuman($all[7])),
        'ALL_ALL'       => toHtml(bytesHuman($all[6] + $all[7]))
    ]);
}

/**
 * Generate server statistics by month
 *
 * @param TemplateEngine $tpl
 * @param int $month Selected month
 * @param int $year Selected year
 */
function generateServerStatsByMonth(TemplateEngine $tpl, $month, $year)
{
    $stmt = execQuery('SELECT traff_time FROM server_traffic WHERE traff_time BETWEEN ? AND ? LIMIT 1', [
        getFirstDayOfMonth($month, $year), getLastDayOfMonth($month, $year)
    ]);

    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('No statistics found for the given period. Try another period.'), 'static_info');
        $tpl->assign('SERVER_STATS_BY_MONTH', '');
        return;
    }

    $curday = ($month == date('n') && $year == date('Y')) ? date('j') : date('j', getLastDayOfMonth($month, $year));
    $all = array_fill(0, 8, 0);

    for ($day = 1; $day <= $curday; $day++) {
        $startDate = mktime(0, 0, 0, $month, $day, $year);
        $endDate = mktime(23, 59, 59, $month, $day, $year);

        list($webIn, $webOut, $smtpIn, $smtpOut, $popIn, $popOut, $otherIn, $otherOut, $allIn, $allOut) = getServerTraffic($startDate, $endDate);

        $tpl->assign([
            'DAY'       => toHtml($day),
            'YEAR'      => toHtml($year),
            'MONTH'     => toHtml($month),
            'WEB_IN'    => toHtml(bytesHuman($webIn)),
            'WEB_OUT'   => toHtml(bytesHuman($webOut)),
            'SMTP_IN'   => toHtml(bytesHuman($smtpIn)),
            'SMTP_OUT'  => toHtml(bytesHuman($smtpOut)),
            'POP_IN'    => toHtml(bytesHuman($popIn)),
            'POP_OUT'   => toHtml(bytesHuman($popOut)),
            'OTHER_IN'  => toHtml(bytesHuman($otherIn)),
            'OTHER_OUT' => toHtml(bytesHuman($otherOut)),
            'ALL_IN'    => toHtml(bytesHuman($allIn)),
            'ALL_OUT'   => toHtml(bytesHuman($allOut)),
            'ALL'       => toHtml(bytesHuman($allIn + $allOut))
        ]);

        $all[0] += $webIn;
        $all[1] += $webOut;
        $all[2] += $smtpIn;
        $all[3] += $smtpOut;
        $all[4] += $popIn;
        $all[5] += $popOut;
        $all[6] += $allIn;
        $all[7] += $allOut;

        $tpl->parse('SERVER_STATS_DAY', '.server_stats_day');
    }

    $allOtherIn = $all[6] - ($all[0] + $all[2] + $all[4]);
    $allOtherOut = $all[7] - ($all[1] + $all[3] + $all[5]);
    $tpl->assign([
        'WEB_IN_ALL'    => toHtml(bytesHuman($all[0])),
        'WEB_OUT_ALL'   => toHtml(bytesHuman($all[1])),
        'SMTP_IN_ALL'   => toHtml(bytesHuman($all[2])),
        'SMTP_OUT_ALL'  => toHtml(bytesHuman($all[3])),
        'POP_IN_ALL'    => toHtml(bytesHuman($all[4])),
        'POP_OUT_ALL'   => toHtml(bytesHuman($all[5])),
        'OTHER_IN_ALL'  => toHtml(bytesHuman($allOtherIn)),
        'OTHER_OUT_ALL' => toHtml(bytesHuman($allOtherOut)),
        'ALL_IN_ALL'    => toHtml(bytesHuman($all[6])),
        'ALL_OUT_ALL'   => toHtml(bytesHuman($all[7])),
        'ALL_ALL'       => toHtml(bytesHuman($all[6] + $all[7]))
    ]);
}

/**
 * Generates statistics page for the given period
 *
 * @param TemplateEngine $tpl template engine instance
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $day = isset($_GET['day']) ? filterDigits($_GET['day']) : 0;
    $month = isset($_GET['month']) ? filterDigits($_GET['month']) : date('n');
    $year = isset($_GET['year']) ? filterDigits($_GET['year']) : date('Y');
    $stmt = execQuery('SELECT traff_time FROM server_traffic ORDER BY traff_time ASC LIMIT 1');
    $nPastYears = $stmt->rowCount() ? date('Y') - date('Y', $stmt->fetchColumn()) : 0;

    View::generateDMYlists($tpl, $day, $month, $year, $nPastYears);

    if ($day == 0) {
        generateServerStatsByMonth($tpl, $month, $year);
        $tpl->assign('SERVER_STATS_BY_DAY', '');
        return;
    }

    $tpl->assign('SERVER_STATS_BY_MONTH', '');
    generateServerStatsByDay($tpl, $day, $month, $year);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                => 'shared/layouts/ui.tpl',
    'page'                  => 'admin/server_statistic.tpl',
    'page_message'          => 'layout',
    'day_list'              => 'page',
    'month_list'            => 'page',
    'year_list'             => 'page',
    'server_stats_by_month' => 'page',
    'server_stats_day'      => 'server_stats_by_month',
    'server_stats_by_day'   => 'page',
    'server_stats_hour'     => 'server_stats_by_day'
]);
$tpl->assign([
    'TR_PAGE_TITLE' => toHtml(tr('Admin / Statistics / Server Statistics')),
    'TR_MONTH'      => toHtml(tr('Month')),
    'TR_YEAR'       => toHtml(tr('Year')),
    'TR_DAY'        => toHtml(tr('Day')),
    'TR_HOUR'       => toHtml(tr('Hour')),
    'TR_WEB_IN'     => toHtml(tr('Web in')),
    'TR_WEB_OUT'    => toHtml(tr('Web out')),
    'TR_SMTP_IN'    => toHtml(tr('SMTP in')),
    'TR_SMTP_OUT'   => toHtml(tr('SMTP out')),
    'TR_POP_IN'     => toHtml(tr('POP3/IMAP in')),
    'TR_POP_OUT'    => toHtml(tr('POP3/IMAP out')),
    'TR_OTHER_IN'   => toHtml(tr('Other in')),
    'TR_OTHER_OUT'  => toHtml(tr('Other out')),
    'TR_ALL_IN'     => toHtml(tr('All in')),
    'TR_ALL_OUT'    => toHtml(tr('All out')),
    'TR_ALL'        => toHtml(tr('All'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
