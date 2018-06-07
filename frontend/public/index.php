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

use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getEventManager()->trigger(Events::onLoginScriptStart);

$authService = Application::getInstance()->getAuthService();

if (Application::getInstance()->getRequest()->isPost()) {
    $authService->signIn();
} elseif (Application::getInstance()->getRequest()->getQuery('signout')) {
    $authService->signOut();
    redirectTo('/index.php');
}

// Covers newly signed in users and already signed in users
$authService->redirectToUserUi();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/simple.tpl',
    'page_message' => 'layout',
    'page'         => 'index.tpl',
    'ssl_block'    => 'page'
]);
$tpl->assign([
    'productLongName'  => toHtml(tr('internet Multi Server Control Panel')),
    'productLink'      => toHtml('https://www.i-mscp.net', 'htmlAttr'),
    'productCopyright' => toHtml(tr('© 2010-2018 i-MSCP - All Rights Reserved')),
    'TR_PAGE_TITLE'    => toHtml(tr('i-MSCP - Multi Server Control Panel / Sign In')),
    'TR_SIGN_IN'       => toHtml(tr('Sign in')),
    'TR_USERNAME'      => toHtml(tr('Username')),
    'UNAME'            => toHtml(Application::getInstance()->getRequest()->getPost('admin_name', ''), 'htmlAttr'),
    'TR_PASSWORD'      => toHtml(tr('Password'))
]);

$config = Application::getInstance()->getConfig();

if ($config['PANEL_SSL_ENABLED'] == 'yes' && $config['BASE_SERVER_VHOST_PREFIX'] != 'https://') {
    $isSecure = isSecureRequest() ? true : false;
    $uri = [
        ($isSecure ? 'http' : 'https') . '://', getRequestHost(), $isSecure
            ? (getRequestPort() != 443 ? ':' . $config['BASE_SERVER_VHOST_HTTP_PORT'] : '')
            : (getRequestPort() != 80 ? ':' . $config['BASE_SERVER_VHOST_HTTPS_PORT'] : '')
    ];
    $tpl->assign([
        'SSL_LINK'           => toHtml(implode('', $uri), 'htmlAttr'),
        'SSL_IMAGE_CLASS'    => $isSecure ? 'i_unlock' : 'i_lock',
        'TR_SSL'             => $isSecure ? toHtml(tr('Normal connection')) : toHtml(tr('Secure connection')),
        'TR_SSL_DESCRIPTION' => $isSecure
            ? toHtml(tr('Use normal connection (No SSL)'), 'htmlAttr') : toHtml(tr('Use secure connection (SSL)'), 'htmlAttr')
    ]);
} else {
    $tpl->assign('SSL_BLOCK', '');
}

View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onLoginScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
