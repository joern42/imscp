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

use iMSCP_Registry as Registry;

require_once 'imscp-lib.php';
require_once LIBRARY_PATH . '/Functions/Tickets.php';

checkLogin('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptStart);
resellerHasFeature('support') or showBadRequestErrorPage();

$previousPage = 'ticket_system';

if (isset($_GET['ticket_id']) && !empty($_GET['ticket_id'])) {
    $ticketId = intval($_GET['ticket_id']);
    $stmt = execQuery('SELECT ticket_status FROM tickets WHERE ticket_id = ? AND (ticket_from = ? OR ticket_to = ?)', [
        $ticketId, $_SESSION['user_id'], $_SESSION['user_id']
    ]);

    if (!$stmt->rowCount()) {
        setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketId), 'error');
        redirectTo($previousPage . '.php');
    }

    // The ticket status was 0 so we come from ticket_closed.php
    if ($stmt->fetchColumn() == 0) {
        $previousPage = 'ticket_closed';
    }

    deleteTicket($ticketId);
    setPageMessage(tr('Ticket successfully deleted.'), 'success');
    writeLog(sprintf("%s: deleted ticket %d", $_SESSION['user_logged'], $ticketId), E_USER_NOTICE);
} elseif (isset($_GET['delete']) && $_GET['delete'] == 'open') {
    deleteTickets('open', $_SESSION['user_id']);
    setPageMessage(tr('All open tickets were successfully deleted.'), 'success');
    writeLog(sprintf("%s: deleted all open tickets.", $_SESSION['user_logged']), E_USER_NOTICE);
} elseif (isset($_GET['delete']) && $_GET['delete'] == 'closed') {
    deleteTickets('closed', $_SESSION['user_id']);
    setPageMessage(tr('All closed tickets were successfully deleted.'), 'success');
    writeLog(sprintf("%s: deleted all closed tickets.", $_SESSION['user_logged']), E_USER_NOTICE);
    $previousPage = 'ticket_closed';
} else {
    setPageMessage(tr('Unknown action requested.'), 'error');
}

redirectTo($previousPage . '.php');
