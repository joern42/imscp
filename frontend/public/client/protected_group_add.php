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
 * Adds Htaccess group
 *
 * @return void
 */
function client_addHtaccessGroup()
{
    if (!Application::getInstance()->getRequest()->isPost()) {
        return;
    }

    isset($_POST['groupname']) or View::showBadRequestErrorPage();

    $htgroupName = cleanInput($_POST['groupname']);

    if (!validateUsername($htgroupName)) {
        View::setPageMessage(tr('Invalid group name!'), 'error');
        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $domainId = getCustomerMainDomainId($identity->getUserId());

    $stmt = execQuery('SELECT id FROM htaccess_groups WHERE ugroup = ? AND dmn_id = ?', [$htgroupName, $domainId]);
    if ($stmt->rowCount()) {
        View::setPageMessage(tr('This htaccess group already exists.'), 'error');
    }

    execQuery("INSERT INTO htaccess_groups (dmn_id, ugroup, status) VALUES (?, ?, 'toadd')", [$domainId, $htgroupName]);
    Daemon::sendRequest();
    View::setPageMessage(tr('Htaccess group successfully scheduled for addition.'), 'success');
    writeLog(sprintf('%s added htaccess group: %s', getProcessorUsername($identity), $htgroupName), E_USER_NOTICE);
    redirectTo('protected_user_manage.php');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::USER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('protected_areas') or View::showBadRequestErrorPage();
client_addHtaccessGroup();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/puser_gadd.tpl',
    'page_message' => 'layout',
]);
$tpl->assign([
    'TR_PAGE_TITLE'     => tr('Client / Webtools / Protected Areas / Manage Users and Groups / Add Group'),
    'TR_HTACCESS_GROUP' => tr('Htaccess group'),
    'TR_GROUPNAME'      => tr('Group name'),
    'GROUPNAME'         => isset($_POST['groupname']) ? toHtml($_POST['groupname']) : '',
    'TR_ADD_GROUP'      => tr('Add'),
    'TR_CANCEL'         => tr('Cancel')
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
