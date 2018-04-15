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

use iMSCP_Registry as Registry;

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('protected_areas') && isset($_GET['uname']) or showBadRequestErrorPage();

/** @var iMSCP_Database $db */
$db = Registry::get('iMSCP_Application')->getDatabase();

try {
    $db->beginTransaction();
    $htuserId = intval($_GET['uname']);
    $domainId = getCustomerMainDomainId($_SESSION['user_id']);
    $stmt = execQuery('SELECT uname FROM htaccess_users WHERE dmn_id = ? AND id = ?', [$domainId, $htuserId]);
    $stmt->rowCount() or showBadRequestErrorPage();
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
    $db->commit();
    setPageMessage(tr('User scheduled for deletion.'), 'success');
    sendDaemonRequest();
    writeLog(sprintf('%s deletes user ID (protected areas): %s', $_SESSION['user_logged'], $htuserName), E_USER_NOTICE);
} catch (iMSCP_Exception_Database $e) {
    $db->rollBack();
    setPageMessage(tr('An unexpected error occurred. Please contact your reseller.'), 'error');
    writeLog(sprintf('Could not delete htaccess user: %s', $e->getMessage()));
}

redirectTo('protected_user_manage.php');
