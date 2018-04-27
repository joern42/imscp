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

use iMSCP\Functions\Login;
use iMSCP\Functions\View;

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/settings_maintenance_mode.tpl',
    'page_message' => 'layout'
]);

$cfg = Application::getInstance()->getConfig();

if (isset($_POST['uaction']) and $_POST['uaction'] == 'apply') {
    $maintenancemode = $_POST['maintenancemode'];
    $maintenancemode_message = cleanInput($_POST['maintenancemode_message']);
    $db_cfg = Application::getInstance()->getRegistry()->get('dbConfig');
    $db_cfg->MAINTENANCEMODE = $maintenancemode;
    $db_cfg->MAINTENANCEMODE_MESSAGE = $maintenancemode_message;
    $cfg->merge($db_cfg);
    setPageMessage(tr('Settings saved.'), 'success');
}

$selected_on = '';
$selected_off = '';

if ($cfg['MAINTENANCEMODE']) {
    $selected_on = ' selected';
    setPageMessage(tr('Maintenance mode is activated. In this mode, only administrators can login.'), 'static_info');
} else {
    $selected_off = ' selected';
    setPageMessage(tr('In maintenance mode, only administrators can login.'), 'static_info');
}

$tpl->assign([
    'TR_PAGE_TITLE'          => toHtml(tr('Admin / System Tools / Maintenance Settings')),
    'TR_MAINTENANCEMODE'     => toHtml(tr('Maintenance mode')),
    'TR_MESSAGE'             => toHtml(tr('Message')),
    'MESSAGE_VALUE'          => isset($cfg['MAINTENANCEMODE_MESSAGE'])
        ? toHtml($cfg['MAINTENANCEMODE_MESSAGE']) : toHtml(tr("We are sorry, but the system is currently under maintenance.")),
    'SELECTED_ON'            => $selected_on,
    'SELECTED_OFF'           => $selected_off,
    'TR_ENABLED'             => toHtml(tr('Enabled')),
    'TR_DISABLED'            => toHtml(tr('Disabled')),
    'TR_APPLY'               => toHtml(tr('Apply')),
    'TR_MAINTENANCE_MESSAGE' => toHtml(tr('Maintenance message'))
]);
View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
