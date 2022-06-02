<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2019 by Laurent Declercq <l.declercq@nuxwin.com>
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

/**
 * @noinspection
 * PhpDocMissingThrowsInspection
 * PhpUnhandledExceptionInspection
 * PhpIncludeInspection
 */

use iMSCP\Event\EventAggregator;
use iMSCP\Event\Events;
use iMSCP\Registry;
use iMSCP\TemplateEngine;

require_once 'imscp-lib.php';
require_once 'Tickets.php';

check_login('reseller');
EventAggregator::getInstance()->dispatch(Events::onResellerScriptStart);
resellerHasFeature('support') or showBadRequestErrorPage();

$_SESSION['previousPage'] = 'ticket_system.php';

// Checks if support ticket system is activated and if the reseller can access to it
if (!hasTicketSystem($_SESSION['user_id'])) {
    redirectTo('index.php');
} elseif (isset($_GET['ticket_id']) && !empty($_GET['ticket_id'])) {
    closeTicket(intval($_GET['ticket_id']));
}

if (isset($_GET['psi'])) {
    $start = $_GET['psi'];
} else {
    $start = 0;
}

$tpl = new TemplateEngine();
$tpl->define_dynamic([
    'layout'           => 'shared/layouts/ui.tpl',
    'page'             => 'reseller/ticket_system.tpl',
    'page_message'     => 'layout',
    'tickets_list'     => 'page',
    'tickets_item'     => 'tickets_list',
    'scroll_prev_gray' => 'page',
    'scroll_prev'      => 'page',
    'scroll_next_gray' => 'page',
    'scroll_next'      => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                 => tr('Reseller / Support / Open Tickets'),
    'TR_TICKET_STATUS'              => tr('Status'),
    'TR_TICKET_FROM'                => tr('From'),
    'TR_TICKET_SUBJECT'             => tr('Subject'),
    'TR_TICKET_URGENCY'             => tr('Priority'),
    'TR_TICKET_LAST_ANSWER_DATE'    => tr('Last reply date'),
    'TR_TICKET_ACTIONS'             => tr('Actions'),
    'TR_TICKET_DELETE'              => tr('Delete'),
    'TR_TICKET_CLOSE'               => tr('Close'),
    'TR_TICKET_READ_LINK'           => tr('Read ticket'),
    'TR_TICKET_DELETE_LINK'         => tr('Delete ticket'),
    'TR_TICKET_CLOSE_LINK'          => tr('Close ticket'),
    'TR_TICKET_DELETE_ALL'          => tr('Delete all tickets'),
    'TR_TICKETS_DELETE_MESSAGE'     => tr("Are you sure you want to delete the '%s' ticket?", '%s'),
    'TR_TICKETS_DELETE_ALL_MESSAGE' => tr('Are you sure you want to delete all tickets?'),
    'TR_PREVIOUS'                   => tr('Previous'),
    'TR_NEXT'                       => tr('Next')
]);

generateNavigation($tpl);
generateTicketList(
    $tpl, $_SESSION['user_id'], $start, Registry::get('config')['DOMAIN_ROWS_PER_PAGE'], 'reseller', 'open'
);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
EventAggregator::getInstance()->dispatch(
    Events::onResellerScriptEnd, ['templateEngine' => $tpl]
);
$tpl->prnt();

unsetMessages();
