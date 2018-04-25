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

/**
 * Generates support questions notice for reseller
 *
 * Notice reseller about any new support questions and answers.
 *
 * @return void
 */
function generateSupportQuestionsMessage()
{
    $ticketsCount = execQuery(
        'SELECT count(ticket_id) FROM tickets WHERE ticket_to = ? AND ticket_status IN (1, 4) AND ticket_reply = 0', [
            Application::getInstance()->getSession()['user_id']
    ])->fetchColumn();

    if ($ticketsCount > 0) {
        setPageMessage(ntr('You have a new support ticket.', 'You have %d new support tickets.', $ticketsCount, $ticketsCount), 'static_info');
    }
}

/**
 * Generates message for new domain aliases orders
 *
 * @return void
 */
function generateOrdersAliasesMessage()
{
    $countAliasOrders = execQuery(
        "
            SELECT COUNT(alias_id)
            FROM domain_aliases
            JOIN domain USING(domain_id)
            JOIN admin ON(admin_id = domain_admin_id)
            WHERE alias_status = 'ordered'
            AND created_by = ?
        ",
        [Application::getInstance()->getSession()['user_id']]
    )->fetchColumn();

    if ($countAliasOrders > 0) {
        setPageMessage(ntr('You have a new domain alias order.', 'You have %d new domain alias orders', $countAliasOrders, $countAliasOrders), 'static_info');
    }
}

/**
 * Generates traffic usage bar
 *
 * @param TemplateEngine $tpl Template engine
 * @param int $trafficUsageBytes Current traffic usage
 * @param int $trafficLimitBytes Traffic max usage
 * @return void
 */
function generateTrafficUsageBar($tpl, $trafficUsageBytes, $trafficLimitBytes)
{
    $trafficUsagePercent = Statistics::getPercentUsage($trafficUsageBytes, $trafficLimitBytes);
    $trafficUsageData = ($trafficLimitBytes > 0)
        ? sprintf('[%s / %s]', bytesHuman($trafficUsageBytes), bytesHuman($trafficLimitBytes))
        : sprintf('[%s / ∞]', bytesHuman($trafficUsageBytes), bytesHuman($trafficLimitBytes));
    $tpl->assign([
        'TRAFFIC_PERCENT_WIDTH' => toHtml($trafficUsagePercent, 'htmlAttr'),
        'TRAFFIC_PERCENT'       => toHtml($trafficUsagePercent),
        'TRAFFIC_USAGE_DATA'    => toHtml($trafficUsageData)
    ]);
}

/**
 * Generates disk usage bar
 *
 * @param TemplateEngine $tpl Template engine
 * @param int $diskspaceUsageBytes Disk usage
 * @param int $diskspaceLimitBytes Max disk usage
 * @return void
 */
function generateDiskUsageBar($tpl, $diskspaceUsageBytes, $diskspaceLimitBytes)
{
    $diskspaceUsagePercent = Statistics::getPercentUsage($diskspaceUsageBytes, $diskspaceLimitBytes);
    $diskUsageData = ($diskspaceLimitBytes > 0)
        ? sprintf('[%s / %s]', bytesHuman($diskspaceUsageBytes), bytesHuman($diskspaceLimitBytes))
        : sprintf('[%s / ∞]', bytesHuman($diskspaceUsageBytes));
    $tpl->assign([
        'DISK_PERCENT_WIDTH' => toHtml($diskspaceUsagePercent, 'htmlAttr'),
        'DISK_PERCENT'       => toHtml($diskspaceUsagePercent),
        'DISK_USAGE_DATA'    => toHtml($diskUsageData)
    ]);
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine
 * @param int $resellerId Reseller unique identifier
 * @param string $resellerName Reseller name
 * @return void
 */
function generatePage($tpl, $resellerId, $resellerName)
{
    generateSupportQuestionsMessage();
    generateOrdersAliasesMessage();

    $resellerProperties = getResellerProperties($resellerId);
    $domainsCount = Counting::getResellerDomainsCount($resellerId);
    $subdomainsCount = Counting::getResellerSubdomainsCount($resellerId);
    $domainAliasesCount = Counting::getResellerDomainAliasesCount($resellerId);
    $mailAccountsCount = Counting::getResellerMailAccountsCount($resellerId);
    $ftpUsersCount = Counting::getResellerFtpUsersCount($resellerId);
    $sqlDatabasesCount = Counting::getResellerSqlDatabasesCount($resellerId);
    $sqlUsersCount = Counting::getResellerSqlUsersCount($resellerId);

    $domainIds = execQuery(
        'SELECT domain_id FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?', [Application::getInstance()->getSession()['user_id']]
    )->fetchAll(\PDO::FETCH_COLUMN);

    $totalConsumedMonthlyTraffic = 0;

    if (!empty($domainIds)) {
        $firstDayOfMonth = getFirstDayOfMonth();
        $lastDayOfMonth = getLastDayOfMonth();
        $stmt = Application::getInstance()->getDb()->createStatement(
            '
                SELECT
                    IFNULL(SUM(dtraff_web), 0) +
                    IFNULL(SUM(dtraff_ftp), 0) +
                    IFNULL(SUM(dtraff_mail), 0) +
                    IFNULL(SUM(dtraff_pop), 0)
                FROM domain_traffic
                WHERE domain_id = ?
                AND dtraff_time BETWEEN ? AND ?
            '
        );
        $stmt->prepare();
        $stmt->bindParam(1, $domainId);
        $stmt->bindParam(2, $firstDayOfMonth);
        $stmt->bindParam(3, $lastDayOfMonth);

        /** @noinspection PhpUnusedLocalVariableInspection $domainId */
        foreach ($domainIds as $domainId) {
            $stmt->execute();
            $totalConsumedMonthlyTraffic += $stmt->fetchColumn();
        }
    }

    $monthlyTrafficLimit = $resellerProperties['max_traff_amnt'] * 1048576;

    generateTrafficUsageBar($tpl, $totalConsumedMonthlyTraffic, $monthlyTrafficLimit);

    if ($monthlyTrafficLimit > 0 && $totalConsumedMonthlyTraffic > $monthlyTrafficLimit) {
        $tpl->assign('TR_TRAFFIC_WARNING', toHtml(tr('You are exceeding your monthly traffic limit.')));
    } else {
        $tpl->assign('TRAFFIC_WARNING_MESSAGE', '');
    }

    $totalDiskUsage = execQuery(
        '
            SELECT IFNULL(SUM(domain_disk_usage), 0) AS disk_usage
            FROM domain AS t1
            JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
            WHERE created_by = ?
        ',
        [Application::getInstance()->getSession()['user_id']]
    )->fetchColumn();
    $diskUsageLimit = $resellerProperties['max_disk_amnt'] * 1048576;
    generateDiskUsageBar($tpl, $totalDiskUsage, $diskUsageLimit);

    if ($diskUsageLimit > 0 && $totalDiskUsage > $diskUsageLimit) {
        $tpl->assign('TR_DISK_WARNING', toHtml(tr('You are exceeding your disk space limit.')));
    } else {
        $tpl->assign('DISK_WARNING_MESSAGE', '');
    }

    $tpl->assign([
        'TR_ACCOUNT_LIMITS' => toHtml(tr('Account limits')),
        'TR_FEATURES'       => toHtml(tr('Features')),
        'DOMAINS'           => toHtml(tr('Domain accounts')),
        'SUBDOMAINS'        => toHtml(tr('Subdomains')),
        'ALIASES'           => toHtml(tr('Domain aliases')),
        'MAIL_ACCOUNTS'     => toHtml(tr('Mail accounts')),
        'TR_FTP_ACCOUNTS'   => toHtml(tr('FTP accounts')),
        'SQL_DATABASES'     => toHtml(tr('SQL databases')),
        'SQL_USERS'         => toHtml(tr('SQL users')),
        'RESELLER_NAME'     => toHtml($resellerName),
        'DMN_MSG'           => toHtml(($resellerProperties['max_dmn_cnt'])
            ? sprintf('%s / %s', $domainsCount, $resellerProperties['max_dmn_cnt']) : sprintf('%s / ∞', $domainsCount)),
        'SUB_MSG'           => toHtml(($resellerProperties['max_sub_cnt'] > 0)
            ? sprintf('%s / %s', $subdomainsCount, $resellerProperties['max_sub_cnt'])
            : (($resellerProperties['max_sub_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $subdomainsCount))),
        'ALS_MSG'           => toHtml(($resellerProperties['max_als_cnt'] > 0)
            ? sprintf('%s / %s', $domainAliasesCount, $resellerProperties['max_als_cnt'])
            : (($resellerProperties['max_als_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $domainAliasesCount))),
        'MAIL_MSG'          => toHtml(($resellerProperties['max_mail_cnt'] > 0)
            ? sprintf('%s / %s', $mailAccountsCount, $resellerProperties['max_mail_cnt'])
            : (($resellerProperties['max_mail_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $mailAccountsCount))),
        'FTP_MSG'           => toHtml(($resellerProperties['max_ftp_cnt'] > 0)
            ? sprintf('%s / %s', $ftpUsersCount, $resellerProperties['max_ftp_cnt'])
            : (($resellerProperties['max_ftp_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $ftpUsersCount))),
        'SQL_DB_MSG'        => toHtml(($resellerProperties['max_sql_db_cnt'] > 0)
            ? sprintf('%s / %s', $sqlDatabasesCount, $resellerProperties['max_sql_db_cnt'])
            : (($resellerProperties['max_sql_db_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $sqlDatabasesCount))),
        'SQL_USER_MSG'      => toHtml(($resellerProperties['max_sql_db_cnt'] > 0)
            ? sprintf('%s / %s', $sqlUsersCount, $resellerProperties['max_sql_user_cnt'])
            : (($resellerProperties['max_sql_user_cnt'] == '-1') ? '-' : sprintf('%s / ∞', $sqlUsersCount))),
        'TR_SUPPORT'        => toHtml(tr('Support system')),
        'SUPPORT_STATUS'    => ($resellerProperties['support_system'] == 'yes')
            ? '<span style="color:green;">' . toHtml(tr('Enabled')) . '</span>'
            : '<span style="color:red;">' . toHtml(tr('Disabled')) . '</span>',
        'TR_PHP_EDITOR'     => toHtml(tr('PHP Editor')),
        'PHP_EDITOR_STATUS' => ($resellerProperties['php_ini_system'] == 'yes')
            ? '<span style="color:green;">' . toHtml(tr('Enabled')) . '</span>'
            : '<span style="color:red;">' . toHtml(tr('Disabled')) . '</span>',
        'TR_TRAFFIC_USAGE'  => toHtml(tr('Monthly traffic usage')),
        'TR_DISK_USAGE'     => toHtml(tr('Disk usage')),
    ]);
}

Login::checkLogin('reseller', Application::getInstance()->getConfig()['PREVENT_EXTERNAL_LOGIN_RESELLER']);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                  => 'shared/layouts/ui.tpl',
    'page'                    => 'reseller/index.tpl',
    'page_message'            => 'layout',
    'traffic_warning_message' => 'page',
    'disk_warning_message'    => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Reseller / General / Overview')));
View::generateNavigation($tpl);
generatePage($tpl, Application::getInstance()->getSession()['user_id'], Application::getInstance()->getSession()['user_logged']);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
