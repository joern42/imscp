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

use iMSCP\TemplateEngine;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    $stmt = execQuery('SELECT userid, status FROM ftp_users WHERE admin_id = ?', [$_SESSION['user_id']]);

    if (!$stmt->rowCount()) {
        setPageMessage(tr('You do not have FTP accounts.'), 'static_info');
        $tpl->assign('FTP_ACCOUNTS', '');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'FTP_ACCOUNT'        => toHtml($row['userid']),
            'UID'                => toHtml($row['userid'], 'htmlAttr'),
            'FTP_ACCOUNT_STATUS' => humanizeDomainStatus($row['status'])
        ]);

        if ($row['status'] != 'ok') {
            $tpl->assign('FTP_ACTIONS', '');
        } else {
            $tpl->parse('FTP_ACTIONS', 'ftp_actions');
        }

        $tpl->parse('FTP_ITEM', '.ftp_item');
    }
}

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('ftp') or showBadRequestErrorPage();

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
Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['dataTable'] = getDataTablesPluginTranslations();
    $translations['core']['deletion_confirm_msg'] = tr('Are you sure you want to delete the `%%s` FTP user?');
});
generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
