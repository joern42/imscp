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
use iMSCP\Config\DbConfig;
use iMSCP\Functions\View;

/**
 * Update server traffic settings
 *
 * @param int $trafficLimit Monthly traffic limit
 * @param int $trafficWarning Traffic warning
 * @return bool TRUE on success FALSE otherwise
 */
function admin_updateServerTrafficSettings($trafficLimit, $trafficWarning)
{
    $retVal = true;

    if (!is_numeric($trafficLimit)) {
        View::setPageMessage(tr('Monthly traffic limit must be a number.'), 'error');
        $retVal = false;
    }

    if (!is_numeric($trafficWarning)) {
        View::setPageMessage(tr('Monthly traffic warning must be a number.'), 'error');
        $retVal = false;
    }

    if ($retVal && $trafficWarning > $trafficLimit) {
        View::setPageMessage(tr('Monthly traffic warning cannot be bigger than monthly traffic limit.'), 'error');
        $retVal = false;
    }

    if ($retVal) {
        $dbConfig = Application::getInstance()->getDbConfig();
        $dbConfig['SERVER_TRAFFIC_LIMIT'] = $trafficLimit;
        $dbConfig['SERVER_TRAFFIC_WARN'] = $trafficWarning;
        // gets the number of queries that were been executed
        $updtCount = $dbConfig->countQueries(DbConfig::UPDATE_QUERY_COUNTER);
        $newCount = $dbConfig->countQueries(DbConfig::INSERT_QUERY_COUNTER);

        // An Update was been made in the database ?
        if ($updtCount || $newCount) {
            View::setPageMessage(tr('Monthly server traffic settings successfully updated.', $updtCount), 'success');
            writeLog(sprintf(
                'Server monthly traffic settings were updated by %s', Application::getInstance()->getAuthService()->getIdentity()->getUsername()),
                E_USER_NOTICE
            );
        } else {
            View::setPageMessage(tr('Nothing has been changed.'), 'info');
        }
    }

    return $retVal;
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param int $trafficLimit Monthly traffic limit
 * @param int $trafficWarning Traffic warning
 * @return void
 */
function admin_generatePage($tpl, $trafficLimit, $trafficWarning)
{
    $cfg = Application::getInstance()->getConfig();

    if (!Application::getInstance()->getRequest()->isPost()) {
        $trafficLimit = $cfg['SERVER_TRAFFIC_LIMIT'];
        $trafficWarning = $cfg['SERVER_TRAFFIC_WARN'];
    }

    $tpl->assign([
        'MAX_TRAFFIC'     => toHtml($trafficLimit),
        'TRAFFIC_WARNING' => toHtml($trafficWarning)
    ]);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$trafficLimit = $trafficWarning = 0;

if (Application::getInstance()->getRequest()->isPost()) {
    $trafficLimit = !isset($_POST['max_traffic']) ?: cleanInput($_POST['max_traffic']);
    $trafficWarning = !isset($_POST['traffic_warning']) ?: cleanInput($_POST['traffic_warning']);
    admin_updateServerTrafficSettings($trafficLimit, $trafficWarning);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/settings_server_traffic.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                  => toHtml(tr('Admin / Settings / Monthly Server Traffic')),
    'TR_SET_SERVER_TRAFFIC_SETTINGS' => toHtml(tr('Monthly server traffic settings')),
    'TR_MAX_TRAFFIC'                 => toHtml(tr('Max traffic')),
    'TR_WARNING'                     => toHtml(tr('Warning traffic')),
    'TR_MIB'                         => toHtml(tr('MiB')),
    'TR_UPDATE'                      => toHtml(tr('Update'), 'htmlAttr')
]);

View::generateNavigation($tpl);
admin_generatePage($tpl, $trafficLimit, $trafficWarning);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
