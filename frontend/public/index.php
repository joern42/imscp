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

require_once 'application.php';

Application::getInstance()->getEventManager()->trigger(Events::onLoginScriptStart);

if (isset($_REQUEST['action'])) {
    Login::initLogin();
    $authService = Application::getInstance()->getAuthService();

    switch ($_REQUEST['action']) {
        case 'login':
            $authResult = $authService->authenticate();
            if ($authResult->isValid()) {
                writeLog(sprintf("%s logged in", $authService->getIdentity()->admin_name), E_USER_NOTICE);
            } elseif (($messages = $authResult->getMessages())) {
                $messages = formatMessage($messages);
                setPageMessage($messages, 'error');
                writeLog(sprintf('Authentication failed. Reason: %s', $messages), E_USER_NOTICE);
            }
            break;
        case 'logout':
            if ($authService->hasIdentity()) {
                $adminName = $authService->getIdentity()->admin_name;
                $authService->clearIdentity();
                setPageMessage(tr('You have been successfully logged out.'), 'success');
                writeLog(sprintf('%s logged out', decodeIdna($adminName)), E_USER_NOTICE);
            }

            redirectTo('index.php');
    }
}

Login::redirectToUiLevel();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/simple.tpl',
    'page_message'   => 'layout',
    'lostpwd_button' => 'page'
]);
$tpl->assign([
    'productLongName'  => toHtml(tr('internet Multi Server Control Panel')),
    'productLink'      => toHtml('https://www.i-mscp.net', 'htmlAttr'),
    'productCopyright' => tr('© 2010-2018 i-MSCP Team<br>All Rights Reserved')
]);

$cfg = Application::getInstance()->getConfig();

if ($cfg['MAINTENANCEMODE'] && !isset($_GET['admin'])) {
    $tpl->define('page', 'message.tpl');
    $tpl->assign([
        'TR_PAGE_TITLE'           => toHtml(tr('i-MSCP - Multi Server Control Panel / Maintenance')),
        'HEADER_BLOCK'            => '',
        'BOX_MESSAGE_TITLE'       => toHtml(tr('System under maintenance')),
        'BOX_MESSAGE'             => isset($cfg['MAINTENANCEMODE_MESSAGE'])
            ? preg_replace('/\s\s+/', '', nl2br(toHtml($cfg['MAINTENANCEMODE_MESSAGE'])))
            : toHtml(tr('We are sorry, but the system is currently under maintenance.')),
        'TR_BACK'                 => toHtml(tr('Administrator login'))
    ]);
} else {
    $tpl->define([
        'page'                  => 'index.tpl',
        'lost_password_support' => 'page',
        'ssl_support'           => 'page'
    ]);
    $tpl->assign([
        'TR_PAGE_TITLE' => toHtml(tr('i-MSCP - Multi Server Control Panel / Login')),
        'TR_LOGIN'      => toHtml(tr('Login')),
        'TR_USERNAME'   => toHtml(tr('Username')),
        'UNAME'         => isset($_POST['uname']) ? toHtml($_POST['uname'], 'htmlAttr') : '',
        'TR_PASSWORD'   => toHtml(tr('Password'))
    ]);

    if ($cfg['PANEL_SSL_ENABLED'] == 'yes' && $cfg['BASE_SERVER_VHOST_PREFIX'] != 'https://') {
        $isSecure = isSecureRequest() ? true : false;
        $uri = [
            ($isSecure ? 'http' : 'https') . '://',
            getRequestHost(),
            $isSecure
                ? (getRequestPort() != 443 ? ':' . $cfg['BASE_SERVER_VHOST_HTTP_PORT'] : '')
                : (getRequestPort() != 80 ? ':' . $cfg['BASE_SERVER_VHOST_HTTPS_PORT'] : '')
        ];

        $tpl->assign([
            'SSL_LINK'           => toHtml(implode('', $uri), 'htmlAttr'),
            'SSL_IMAGE_CLASS'    => $isSecure ? 'i_unlock' : 'i_lock',
            'TR_SSL'             => $isSecure ? toHtml(tr('Normal connection')) : toHtml(tr('Secure connection')),
            'TR_SSL_DESCRIPTION' => $isSecure
                ? toHtml(tr('Use normal connection (No SSL)'), 'htmlAttr') : toHtml(tr('Use secure connection (SSL)'), 'htmlAttr')
        ]);
    } else {
        $tpl->assign('SSL_SUPPORT', '');
    }

    if ($cfg['LOSTPASSWORD']) {
        $tpl->assign('TR_LOSTPW', toHtml(tr('Lost password')));
    } else {
        $tpl->assign('LOST_PASSWORD_SUPPORT', '');
    }
}

generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onLoginScriptEnd, null, ['templateEngine' => $tpl]);
$tpl->prnt();
