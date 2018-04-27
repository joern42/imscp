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
use iMSCP\Functions\Support;
use iMSCP\Functions\View;

require 'application.php';

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('support') && isset($_GET['ticket_id']) or View::showBadRequestErrorPage();

$ticketId = intval($_GET['ticket_id']);
$status = Support::getTicketStatus($ticketId);
$ticketLevel = Support::getUserLevel($ticketId);

if (Support::getTicketStatus($ticketId) == 2) {
    Support::changeTicketStatus($ticketId, 3);
}

if (isset($_POST['uaction'])) {
    if ($_POST['uaction'] == 'close') {
        Support::closeTicket($ticketId);
        redirectTo('ticket_system.php');
    }

    if (isset($_POST['user_message'])) {
        if (empty($_POST['user_message'])) {
            setPageMessage(tr('Please type your message.'), 'error');
        } else {
            Support::updateTicket(
                $ticketId,
                Application::getInstance()->getAuthService()->getIdentity()->getUserId(),
                $_POST['urgency'],
                $_POST['subject'],
                $_POST['user_message'],
                1,
                1
            );
            redirectTo("ticket_view.php?ticket_id=$ticketId");
        }
    }
}

$tpl = new TemplateEngine();
$tpl->define('layout', 'shared/layouts/ui.tpl');
$tpl->define([
    'page'           => 'client/ticket_view.tpl',
    'page_message'   => 'layout',
    'ticket'         => 'page',
    'ticket_message' => 'ticket'
]);
$tpl->assign([
    'TR_PAGE_TITLE'       => tr('Client / Support / View Ticket'),
    'TR_TICKET_INFO'      => tr('Ticket information'),
    'TR_TICKET_URGENCY'   => tr('Priority'),
    'TR_TICKET_SUBJECT'   => tr('Subject'),
    'TR_TICKET_FROM'      => tr('From'),
    'TR_TICKET_DATE'      => tr('Date'),
    'TR_TICKET_CONTENT'   => tr('Message'),
    'TR_TICKET_NEW_REPLY' => tr('Reply'),
    'TR_TICKET_REPLY'     => tr('Send reply')
]);
View::generateNavigation($tpl);
Support::showTicketContent($tpl, $ticketId, Application::getInstance()->getAuthService()->getIdentity()->getUserId());
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
