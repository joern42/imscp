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
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    $stmt = execQuery('SELECT userid, status FROM ftp_users WHERE admin_id = ?', [
        Application::getInstance()->getAuthService()->getIdentity()->getUserId()
    ]);

    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('You do not have FTP accounts.'), 'static_info');
        $tpl->assign('FTP_ACCOUNTS', '');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'FTP_ACCOUNT'        => toHtml($row['userid']),
            'UID'                => toHtml($row['userid'], 'htmlAttr'),
            'FTP_ACCOUNT_STATUS' => humanizeItemStatus($row['status'])
        ]);

        if ($row['status'] != 'ok') {
            $tpl->assign('FTP_ACTIONS', '');
        } else {
            $tpl->parse('FTP_ACTIONS', 'ftp_actions');
        }

        $tpl->parse('FTP_ITEM', '.ftp_item');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('ftp') or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/ftp_accounts.tpl',
    'page_message' => 'layout',
    'ftp_message'  => 'page',
    'ftp_accounts' => 'page',
    'ftp_item'     => 'ftp_accounts',
    'ftp_actions'  => 'ftp_item'
]);
$tpl->assign([
    'TR_PAGE_TITLE'         => tr('Client / FTP / Overview'),
    'TR_FTP_ACCOUNT'        => tr('FTP account'),
    'TR_FTP_ACTIONS'        => tr('Actions'),
    'TR_FTP_ACCOUNT_STATUS' => tr('Status'),
    'TR_EDIT'               => tr('Edit'),
    'TR_DELETE'             => tr('Delete'),
    'TR_MESSAGE_DELETE'     => tr('Are you sure you want to delete the %s FTP account?', '%s'),
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['dataTable'] = View::getDataTablesPluginTranslations();
    $translations['core']['deletion_confirm_msg'] = tr('Are you sure you want to delete the `%%s` FTP user?');
});
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
