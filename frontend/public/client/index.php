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

/**
 * Generates notice for support system
 *
 * @return void
 */
function generateSupportSystemNotices()
{
    $aCnt = execQuery("SELECT COUNT(ticket_id) FROM tickets WHERE ticket_from = ? AND ticket_status = '2' AND ticket_reply = '0'", [
        Application::getInstance()->getAuthService()->getIdentity()->getUserId()
    ])->fetchColumn();

    if (!$aCnt) {
        return;
    }

    View::setPageMessage(ntr('You have a new answer to your support ticket.', 'You have %d new answers to your support tickets.', $aCnt, $aCnt), 'static_info');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(
    AuthenticationService::USER_CHECK_AUTH_TYPE, Application::getInstance()->getConfig()['PREVENT_EXTERNAL_LOGIN_CLIENT']
);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
define('SHARED_SCRIPT_NEEDED', true);
$_GET['id'] = Application::getInstance()->getAuthService()->getIdentity()->getUserId();
generateSupportSystemNotices();
global $tpl;
require_once '../shared/account_details.php';
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Client / General / Overview')));
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
