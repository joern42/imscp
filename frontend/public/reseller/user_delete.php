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
use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::RESELLER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
isset($_GET['user_id']) or View::showBadRequestErrorPage();
$customerId = intval($_GET['client_id']);

try {
    deleteCustomer($customerId, true) or View::showBadRequestErrorPage();
    View::setPageMessage(tr('Customer account successfully scheduled for deletion.'), 'success');
    writeLog(sprintf('%s scheduled deletion of the customer account with ID %d', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity()), $customerId), E_USER_NOTICE);
} catch (\Exception $e) {
    View::setPageMessage(tr('Unable to schedule deletion of the customer account. A message has been sent to the administrator.'), 'error');
    writeLog(sprintf("System was unable to schedule deletion of the customer account with ID %s. Message was: %s", $customerId, $e->getMessage()), E_USER_ERROR);
}

redirectTo('users.php');
