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
use iMSCP\Functions\Counting;
use iMSCP\Functions\Daemon;
use iMSCP\Functions\View;

/**
 * Add Htaccess user
 *
 * @return void
 */
function client_addHtaccessUser()
{
    if (!Application::getInstance()->getRequest()->isPost()) {
        return;
    }

    isset($_POST['username']) && isset($_POST['pass']) && isset($_POST['pass_rep']) or View::showBadRequestErrorPage();

    $uname = cleanInput($_POST['username']);

    if (!validateUsername($_POST['username'])) {
        View::setPageMessage(tr('Wrong username.'), 'error');
        return;
    }

    $passwd = cleanInput($_POST['pass']);

    if ($passwd !== $_POST['pass_rep']) {
        View::setPageMessage(tr('Passwords do not match.'), 'error');
        return;
    }

    if (!checkPasswordSyntax($passwd)) {
        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $domainId = getCustomerMainDomainId($identity->getUserId());

    $stmt = execQuery('SELECT id FROM htaccess_users WHERE uname = ? AND dmn_id = ?', [$uname, $domainId]);
    if ($stmt->rowCount()) {
        View::setPageMessage(tr('This htaccess user already exist.'), 'error');
        return;
    }

    execQuery("INSERT INTO htaccess_users (dmn_id, uname, upass, status) VALUES (?, ?, ?, 'toadd')", [$domainId, $uname, Crypt::bcrypt($passwd)]);
    Daemon::sendRequest();
    View::setPageMessage(tr('Htaccess user successfully scheduled for addition.'), 'success');
    writeLog(sprintf('%s added new htaccess user: %s', $uname, getProcessorUsername($identity)), E_USER_NOTICE);
    redirectTo('protected_user_manage.php');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('webProtectedAreas') or View::showBadRequestErrorPage();
client_addHtaccessUser();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/puser_uadd.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / Webtools / Protected Areas / Manage Users and Groups / Add User'),
    'TR_HTACCESS_USER'   => tr('Htaccess user'),
    'TR_USERNAME'        => tr('Username'),
    'USERNAME'           => (isset($_POST['username'])) ? toHtml($_POST['username']) : '',
    'TR_PASSWORD'        => tr('Password'),
    'TR_PASSWORD_REPEAT' => tr('Repeat password'),
    'TR_ADD_USER'        => tr('Add'),
    'TR_CANCEL'          => tr('Cancel')
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
