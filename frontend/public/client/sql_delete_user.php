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
use iMSCP\Functions\View;

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('sql') && isset($_GET['sqlu_id']) or View::showBadRequestErrorPage();

$sqluId = intval($_GET['sqlu_id']);

if (!deleteSqlUser(getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']), $sqluId)) {
    writeLog(sprintf('Could not delete SQL user with ID %d. An unexpected error occurred.', $sqluId), E_USER_ERROR);
    setPageMessage(tr('Could not delete SQL user. An unexpected error occurred.'), 'error');
    redirectTo('sql_manage.php');
}

setPageMessage(tr('SQL user successfully deleted.'), 'success');
writeLog(sprintf('%s deleted SQL user with ID %d', Application::getInstance()->getSession()['user_logged'], $sqluId), E_USER_NOTICE);
redirectTo('sql_manage.php');
