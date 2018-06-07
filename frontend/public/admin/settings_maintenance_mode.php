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

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$request = Application::getInstance()->getRequest();

if ($request->isPost()) {
    $dbConfig = Application::getInstance()->getDbConfig();
    $dbConfig['MAINTENANCEMODE'] = intval($request->getPost('maintenancemode', 0));
    $dbConfig['MAINTENANCEMODE_MESSAGE'] = cleanHtml($request->getPost('maintenancemode_message', ''));

    // Force new merge or next request
    Application::getInstance()->getCache()->removeItem('merged_config');

    View::setPageMessage(toHtml(tr('Settings saved.')), 'success');
    redirectTo('settings_maintenance_mode.php');
}

$config = Application::getInstance()->getConfig();

if ($config['MAINTENANCEMODE']) {
    View::setPageMessage(toHtml(tr('Maintenance mode is currently activated. In this mode, only administrators can sign in.')), 'static_info');
} else {
    View::setPageMessage(toHtml(tr('In maintenance mode, only administrators can sign in.')), 'static_info');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/settings_maintenance_mode.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'          => toHtml(tr('Admin / System Tools / Maintenance Settings')),
    'TR_MAINTENANCEMODE'     => toHtml(tr('Maintenance mode')),
    'TR_MESSAGE'             => toHtml(tr('Message')),
    'MESSAGE_VALUE'          => toHtml($config['MAINTENANCEMODE_MESSAGE'] ?? tr('Service currently under maintenance. Only administrators can sign in.')),
    'SELECTED_ON'            => $config['MAINTENANCEMODE'] ? ' selected' : '',
    'SELECTED_OFF'           => $config['MAINTENANCEMODE'] ? '' : ' selected',
    'TR_ENABLED'             => toHtml(tr('Enabled')),
    'TR_DISABLED'            => toHtml(tr('Disabled')),
    'TR_APPLY'               => toHtml(tr('Apply')),
    'TR_MAINTENANCE_MESSAGE' => toHtml(tr('Maintenance message'))
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
