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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('webProtectedAreas') && isset($_GET['uname']) or View::showBadRequestErrorPage();

$db = Application::getInstance()->getDb();

try {
    $db->getDriver()->getConnection()->beginTransaction();
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $htuserId = intval($_GET['uname']);
    $domainId = getCustomerMainDomainId($identity->getUserId());
    $stmt = execQuery('SELECT uname FROM htaccess_users WHERE dmn_id = ? AND id = ?', [$domainId, $htuserId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();
    $htuserName = $row['uname'];

    // Remove the user from any group for which it is member and schedule .htgroup file change
    $stmt = execQuery('SELECT id, members FROM htaccess_groups WHERE dmn_id = ?', [$domainId]);
    while ($row = $stmt->fetch()) {
        $htuserList = explode(',', $row['members']);
        $candidate = array_search($row['id'], $htuserList);

        if ($candidate === false) {
            continue;
        }

        unset($htuserList[$candidate]);

        execQuery("UPDATE htaccess_groups SET members = ?, status = 'tochange' WHERE id = ?", [implode(',', $htuserList), $row['id']]);
    }

    // Schedule deletion or update of any .htaccess files in which the htuser was used
    $stmt = execQuery('SELECT * FROM htaccess WHERE dmn_id = ?', [$domainId]);
    while ($row = $stmt->fetch()) {
        $htuserList = explode(',', $row['user_id']);
        $candidate = array_search($htuserId, $htuserList);

        if ($candidate == false) {
            continue;
        }

        unset($htuserList[$candidate]);

        if (empty($htuserList)) {
            $status = 'todelete';
        } else {
            $htuserList = implode(',', $htuserList);
            $status = 'tochange';
        }

        execQuery('UPDATE htaccess SET user_id = ?, status = ? WHERE id = ?', [$htuserList, $status, $row['id']]);
    }

    // Schedule htuser deletion
    execQuery("UPDATE htaccess_users SET status = 'todelete' WHERE id = ? AND dmn_id = ?", [$htuserId, $domainId]);
    $db->getDriver()->getConnection()->commit();
    View::setPageMessage(tr('User scheduled for deletion.'), 'success');
    Daemon::sendRequest();
    writeLog(sprintf('%s deletes user ID (protected areas): %s', getProcessorUsername($identity), $htuserName), E_USER_NOTICE);
} catch (\Exception $e) {
    $db->getDriver()->getConnection()->rollBack();
    View::setPageMessage(tr('An unexpected error occurred. Please contact your reseller.'), 'error');
    writeLog(sprintf('Could not delete htaccess user: %s', $e->getMessage()));
}

redirectTo('protected_user_manage.php');
