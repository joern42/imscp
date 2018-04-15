<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

use iMSCP_Events as Events;
use iMSCP_Registry as Registry;

/**
 * Generates notice for support system
 *
 * @return void
 */
function generateSupportSystemNotices()
{
    $aCnt = exec_query("SELECT COUNT(ticket_id) FROM tickets WHERE ticket_from = ? AND ticket_status = '2' AND ticket_reply = '0'", [
        $_SESSION['user_id']
    ])->fetchColumn();

    if (!$aCnt) {
        return;
    }

    set_page_message(
        ntr('You have a new answer to your support ticket.', 'You have %d new answers to your support tickets.', $aCnt, $aCnt), 'static_info'
    );
}

require_once 'imscp-lib.php';
check_login('user', $cfg['PREVENT_EXTERNAL_LOGIN_CLIENT']);
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptStart);
define('SHARED_SCRIPT_NEEDED', true);
$_GET['client_id'] = $_SESSION['user_id'];
generateSupportSystemNotices();
require_once '../shared/account_details.php';
$tpl->assign('TR_PAGE_TITLE', tohtml(tr('Client / General / Overview')));
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
