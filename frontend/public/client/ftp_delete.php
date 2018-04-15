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

use iMSCP_Events as Events;
use iMSCP_Exception as iMSCPException;
use iMSCP_Registry as Registry;

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptStart);
customerHasFeature('ftp') && isset($_GET['id']) or showBadRequestErrorPage();

$userid = cleanInput($_GET['id']);
$stmt = execQuery('SELECT admin_name as groupname FROM ftp_users JOIN admin USING(admin_id) WHERE userid = ? AND admin_id = ?', [
    $userid, $_SESSION['user_id']
]);
$stmt->rowCount() or showBadRequestErrorPage();
$row = $stmt->fetch();
$groupname = $row['groupname'];

/** @var iMSCP_Database $db */
$db = Registry::get('iMSCP_Application')->getDatabase();

try {
    $db->beginTransaction();

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeDeleteFtp, ['ftpUserId' => $userid]);

    $stmt = execQuery('SELECT members FROM ftp_group WHERE groupname = ?', [$groupname]);

    if ($stmt->rowCount()) {
        $row = $stmt->fetch();
        $members = preg_split('/,/', $row['members'], -1, PREG_SPLIT_NO_EMPTY);
        $member = array_search($userid, $members);

        if (false !== $member) {
            unset($members[$member]);

            if (empty($members)) {
                execQuery('DELETE FROM ftp_group WHERE groupname = ?', [$groupname]);
                execQuery('DELETE FROM quotalimits WHERE name = ?', [$groupname]);
                execQuery('DELETE FROM quotatallies WHERE name = ?', [$groupname]);
            } else {
                execQuery('UPDATE ftp_group SET members = ? WHERE groupname = ?', [implode(',', $members), $groupname]);
            }
        }
    }

    execQuery("UPDATE ftp_users SET status = 'todelete' WHERE userid = ?", [$userid]);

    $cfg = Registry::get('config');
    if (in_array('Pydio', explode(',', $cfg['FILEMANAGERS']))) {
        $userPrefDir = $cfg['FRONTEND_ROOT_DIR'] . '/public/tools/ftp/data/plugins/auth.serial/' . $userid;
        if (is_dir($userPrefDir)) {
            removeDirectory($userPrefDir);
        }
    }

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterDeleteFtp, ['ftpUserId' => $userid]);
    $db->commit();
    sendDaemonRequest();
    writeLog(sprintf('An FTP account has been deleted by %s', $_SESSION['user_logged']), E_USER_NOTICE);
    setPageMessage(tr('FTP account successfully deleted.'), 'success');
} catch (iMSCPException $e) {
    $db->rollBack();
    throw $e;
}

redirectTo('ftp_accounts.php');
