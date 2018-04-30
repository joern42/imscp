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
Counting::customerHasFeature('domain_aliases') && isset($_GET['id']) or View::showBadRequestErrorPage();

$id = intval($_GET['id']);
$stmt = execQuery(
    '
        SELECT t1.domain_id, t1.alias_name, t1.alias_mount
        FROM domain_aliases AS t1
        JOIN domain AS t2 USING(domain_id)
        WHERE t1.alias_id = ?
        AND t2.domain_admin_id = ?
    ',
    [$id, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
);

$stmt->rowCount() or View::showBadRequestErrorPage();
$row = $stmt->fetch();
deleteDomainAlias(
    Application::getInstance()->getAuthService()->getIdentity()->getUserId(), $row['domain_id'], $id, $row['alias_name'], $row['alias_mount']
);
redirectTo('domains_manage.php');
