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

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::USER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('sql') && isset($_GET['sqlu_id']) or View::showBadRequestErrorPage();

$sqluId = intval($_GET['sqlu_id']);
$identity = Application::getInstance()->getAuthService()->getIdentity();

if (!deleteSqlUser(getCustomerMainDomainId($identity->getUserId()), $sqluId)) {
    writeLog(sprintf('Could not delete SQL user with ID %d. An unexpected error occurred.', $sqluId), E_USER_ERROR);
    View::setPageMessage(tr('Could not delete SQL user. An unexpected error occurred.'), 'error');
    redirectTo('sql_manage.php');
}

View::setPageMessage(tr('SQL user successfully deleted.'), 'success');
writeLog(sprintf('%s deleted SQL user with ID %d', getProcessorUsername($identity), $sqluId), E_USER_NOTICE);
redirectTo('sql_manage.php');
