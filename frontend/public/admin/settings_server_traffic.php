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

use iMSCP\Config\DbConfig;
use iMSCP\Functions\Login;
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
        setPageMessage(tr('Monthly traffic limit must be a number.'), 'error');
        $retVal = false;
    }

    if (!is_numeric($trafficWarning)) {
        setPageMessage(tr('Monthly traffic warning must be a number.'), 'error');
        $retVal = false;
    }

    if ($retVal && $trafficWarning > $trafficLimit) {
        setPageMessage(tr('Monthly traffic warning cannot be bigger than monthly traffic limit.'), 'error');
        $retVal = false;
    }

    if ($retVal) {
        $dbConfig = Application::getInstance()->getDbConfig();
        $dbConfig['SERVER_TRAFFIC_LIMIT'] = $trafficLimit;
        $dbConfig['SERVER_TRAFFIC_WARN'] = $trafficWarning;
        // gets the number of queries that were been executed
        $updtCount = $dbConfig->countQueries('update');
        $newCount = $dbConfig->countQueries('insert');

        // An Update was been made in the database ?
        if ($updtCount || $newCount) {
            setPageMessage(tr('Monthly server traffic settings successfully updated.', $updtCount), 'success');
            writeLog(sprintf('Server monthly traffic settings were updated by %s', Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
        } else {
            setPageMessage(tr('Nothing has been changed.'), 'info');
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

    if (empty($_POST)) {
        $trafficLimit = $cfg['SERVER_TRAFFIC_LIMIT'];
        $trafficWarning = $cfg['SERVER_TRAFFIC_WARN'];
    }

    $tpl->assign([
        'MAX_TRAFFIC'     => toHtml($trafficLimit),
        'TRAFFIC_WARNING' => toHtml($trafficWarning)
    ]);
}

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$trafficLimit = $trafficWarning = 0;

if (!empty($_POST)) {
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
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
