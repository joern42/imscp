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
use iMSCP\Functions\SupportSystem;
use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
Counting::userHasFeature('supportSystem') && isset($_GET['ticket_id']) or View::showBadRequestErrorPage();

$ticketId = intval($_GET['ticket_id']);
$status = SupportSystem::getTicketStatus($ticketId);
$ticketLevel = SupportSystem::getUserLevel($ticketId);

if (($ticketLevel == 1 && ($status == 1 || $status == 4)) || ($ticketLevel == 2 && $status == 2)) {
    SupportSystem::changeTicketStatus($ticketId, 3);
}

$identity = Application::getInstance()->getAuthService()->getIdentity();

if (isset($_POST['uaction'])) {
    if ($_POST['uaction'] == 'close') {
        SupportSystem::closeTicket($ticketId);
        redirectTo('ticket_system.php');
    }

    if (isset($_POST['user_message'])) {
        if (empty($_POST['user_message'])) {
            View::setPageMessage(tr('Please type your message.'), 'error');
        } else {
            SupportSystem::updateTicket($ticketId, $identity->getUserId(), $_POST['urgency'], $_POST['subject'], $_POST['user_message'], 2, 3);
            redirectTo("ticket_view.php?ticket_id=$ticketId");
        }
    }
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/ui.tpl',
    'page'           => 'reseller/ticket_view.tpl',
    'page_message'   => 'layout',
    'ticket'         => 'page',
    'ticket_message' => 'ticket'
]);
$tpl->assign([
    'TR_PAGE_TITLE'       => tr('Reseller / Support / View Ticket'),
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
SupportSystem::showTicketContent($tpl, $ticketId, $identity->getUserId());
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
