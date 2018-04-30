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


use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::RESELLER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

if (isset($_GET['domain_id'])) {
    $domainId = intval($_GET['domain_id']);
    $resellerId = intval(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    $stmt = execQuery(
        'SELECT admin_id, created_by, domain_status FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE domain_id = ? AND created_by = ?',
        [$domainId, $resellerId]
    );

    if ($stmt->rowCount()) {
        $row = $stmt->fetch();
        if ($row['domain_status'] == 'ok') {
            changeDomainStatus($row['admin_id'], 'deactivate');
        } elseif ($row['domain_status'] == 'disabled') {
            changeDomainStatus($row['admin_id'], 'activate');
        } else {
            View::showBadRequestErrorPage();
        }

        redirectTo('users.php');
    }
}

View::showBadRequestErrorPage();
