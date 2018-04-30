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

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('sql') && isset($_GET['sqld_id']) or View::showBadRequestErrorPage();

$sqldId = intval($_GET['sqld_id']);
$identity = Application::getInstance()->getAuthService()->getIdentity();

if (!deleteSqlDatabase(getCustomerMainDomainId($identity->getUserId()), $sqldId)) {
    writeLog(sprintf('Could not delete SQL database with ID %s. An unexpected error occurred.', $sqldId), E_USER_NOTICE);
    View::setPageMessage(tr('Could not delete SQL database. An unexpected error occurred.'), 'error');
    redirectTo('sql_manage.php');
}

View::setPageMessage(tr('SQL database successfully deleted.'), 'success');
writeLog(sprintf('%s deleted SQL database with ID %s', getProcessorUsername($identity), $sqldId), E_USER_NOTICE);
redirectTo('sql_manage.php');
