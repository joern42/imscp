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

require 'application.php';

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('domain_aliases') && isset($_GET['id']) or View::showBadRequestErrorPage();
$stmt = execQuery("DELETE FROM domain_aliases WHERE alias_id = ? AND domain_id = ? AND alias_status = 'ordered'", [
    intval($_GET['id']), getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId())
]);
$stmt->rowCount() or View::showBadRequestErrorPage();
setPageMessage(tr('Order successfully canceled.'), 'success');
redirectTo('domains_manage.php');
