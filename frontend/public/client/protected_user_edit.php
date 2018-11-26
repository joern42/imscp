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
 * Updates htaccess user
 *
 * @param int $domainId Domain unique identifier
 * @param int $htuserId Htaccess user unique identifier
 * @return void
 */
function client_updateHtaccessUser($domainId, $htuserId)
{
    if (!Application::getInstance()->getRequest()->isPost()) {
        return;
    }

    isset($_POST['pass']) && isset($_POST['pass_rep']) or View::showBadRequestErrorPage();

    if ($_POST['pass'] !== $_POST['pass_rep']) {
        View::setPageMessage(tr('Passwords do not match.'), 'error');
        return;
    }

    if (!checkPasswordSyntax($_POST['pass'])) {
        return;
    }

    execQuery('UPDATE htaccess_users SET upass = ?, status = ? WHERE id = ? AND dmn_id = ?', [
        Crypt::bcrypt($_POST['pass']), 'tochange', $htuserId, $domainId
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('%s updated htaccess user ID: %s', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity()), $htuserId), E_USER_NOTICE);
    redirectTo('protected_user_manage.php');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('webProtectedAreas') && isset($_REQUEST['uname']) or View::showBadRequestErrorPage();

$htuserId = intval($_REQUEST['uname']);
$domainId = getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
$stmt = execQuery('SELECT uname FROM htaccess_users WHERE id = ? AND dmn_id = ?', [$htuserId, $domainId]);
$stmt->rowCount() or View::showBadRequestErrorPage();
$row = $stmt->fetch();

client_updateHtaccessUser($domainId, $htuserId);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/puser_edit.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / Webtools / Protected Areas / Manage Users and Groups / Edit User'),
    'TR_HTACCESS_USER'   => tr('Htaccess user'),
    'TR_USERNAME'        => tr('Username'),
    'UNAME'              => toHtml($row['uname']),
    'TR_PASSWORD'        => tr('Password'),
    'TR_PASSWORD_REPEAT' => tr('Repeat password'),
    'UID'                => toHtml($htuserId),
    'TR_UPDATE'          => tr('Update'),
    'TR_CANCEL'          => tr('Cancel')
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
