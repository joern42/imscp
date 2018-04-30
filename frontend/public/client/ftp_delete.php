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
Counting::customerHasFeature('ftp') && isset($_GET['id']) or View::showBadRequestErrorPage();

$userid = cleanInput($_GET['id']);
$stmt = execQuery('SELECT admin_name as groupname FROM ftp_users JOIN admin USING(admin_id) WHERE userid = ? AND admin_id = ?', [
    $userid, Application::getInstance()->getAuthService()->getIdentity()->getUserId()
]);
$stmt->rowCount() or View::showBadRequestErrorPage();
$row = $stmt->fetch();
$groupname = $row['groupname'];

$db = Application::getInstance()->getDb();

try {
    $db->getDriver()->getConnection()->beginTransaction();

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteFtp, NULL, ['ftpUserId' => $userid]);

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

    $cfg = Application::getInstance()->getConfig();
    if (in_array('Pydio', explode(',', $cfg['FILEMANAGERS']))) {
        $userPrefDir = $cfg['FRONTEND_ROOT_DIR'] . '/public/tools/pydio/data/plugins/auth.serial/' . $userid;
        if (is_dir($userPrefDir)) {
            removeDirectory($userPrefDir);
        }
    }

    Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteFtp, NULL, ['ftpUserId' => $userid]);
    $db->getDriver()->getConnection()->commit();
    Daemon::sendRequest();
    writeLog(sprintf('An FTP account has been deleted by %s', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity())), E_USER_NOTICE);
    View::setPageMessage(tr('FTP account successfully deleted.'), 'success');
} catch (\Exception $e) {
    $db->getDriver()->getConnection()->rollBack();
    throw $e;
}

redirectTo('ftp_accounts.php');
