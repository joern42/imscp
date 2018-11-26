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
use iMSCP\Functions\View;

/**
 * Deletes an admin or reseller user
 *
 * @param int $userID User unique identifier
 * @return void
 */
function admin_deleteUser($userID)
{
    $cfg = Application::getInstance()->getConfig();
    $db = Application::getInstance()->getDb();
    $stmt = execQuery('SELECT t1.type, t2.layoutLogo FROM imscp_user AS t1 LEFT JOIN imscp_ui_props AS t2 USING(userID) WHERE t1.userID = ?', [
        $userID
    ]);
    $row = $stmt->fetch();
    $userType = $row['type'];

    if (empty($userType) || $userType == 'client') {
        View::showBadRequestErrorPage();
    }

    // Users (admins/resellers) common items to delete
    $itemsToDelete = [
        'imscp_user'           => 'userID = ?',
        'imscp_email_template' => 'userID = ?',
        'imscp_ticket'         => 'ticketFrom = ? OR ticketTo = ?',
        'imscp_ui_props'       => 'userID = ?'
    ];

    if ($userType == 'reseller') {
        // Getting custom reseller isp logo if set
        $resellerLogo = $row['layoutLogo'];

        // Add specific reseller items to remove
        $itemsToDelete = array_merge(
            [
                'imscp_hosting_plan'  => 'userID = ?',
                'imscp_reseller_props' => 'userID = ?',
            ],
            $itemsToDelete
        );
    }

    // We are using transaction to ensure data consistency and prevent any garbage in
    // the database. If one query fail, the whole process is reverted.

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteUser, NULL, ['userId' => $userID]);

        foreach ($itemsToDelete as $table => $where) {
            $query = "DELETE FROM " . quoteIdentifier($table) . ($where ? " WHERE $where" : '');
            execQuery($query, array_fill(0, substr_count($where, '?'), $userID));
        }

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteUser, NULL, ['userId' => $userID]);

        $db->getDriver()->getConnection()->commit();

        // Cleanup files system
        // We are safe here. We don't stop the process even if files cannot be removed. That can result in garbages but
        // the sysadmin can easily delete them through ssh.

        // Deleting user logo
        if (isset($resellerLogo) && !empty($resellerLogo)) {
            $logoPath = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/ispLogos/' . $resellerLogo;
            if (file_exists($logoPath) && @unlink($logoPath) == false) {
                writeLog(sprintf('Could not remove user logo %s', $logoPath), E_USER_ERROR);
            }
        }

        View::setPageMessage(tr('%s account successfully deleted.', $userType == 'reseller' ? tr('Reseller') : tr('Administrator')), 'success');
        writeLog(Application::getInstance()->getAuthService()->getIdentity()->getUsername() . ": deletes user " . $userID, E_USER_NOTICE);
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    redirectTo('users.php');
}

/**
 * Validates admin or reseller deletion
 *
 * @param int $userID User unique identifier
 * @return bool TRUE if deletion can be done, FALSE otherwise
 */
function admin_validateUserDeletion($userID)
{
    $stmt = execQuery('SELECT type, createdBy FROM imscp_user WHERE userID = ?', [$userID]);
    $stmt->rowCount() or View::showBadRequestErrorPage(); 
    $row = $stmt->fetch();

    if ($row['createdBy'] == 0) {
        View::setPageMessage(tr('You cannot delete the master administrator.'), 'error');
    }

    if (!in_array($row['admin_type'], ['admin', 'reseller'])) {
        // Not an administrator, nor a reseller; assume a bad request
        View::showBadRequestErrorPage();
    }

    $stmt = execQuery('SELECT COUNT(userID) AS usersCount FROM imscp_user WHERE createdBy = ?', [$userID]);
    $row2 = $stmt->fetch();

    if ($row2['usersCount'] > 0) {
        if ($row['type'] == 'admin') {
            View::setPageMessage(tr('Before deleting this administrator, please move all his resellers to another administrator.'), 'error');
        } else {
            View::setPageMessage(tr('Before deleting this reseller, please move all his client to another reseller.'), 'error');
        }

        return false;
    }

    return true;
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

if (isset($_GET['delete_id'])) {
    // admin/reseller deletion
    if (admin_validateUserDeletion($_GET['delete_id'])) {
        admin_deleteUser($_GET['delete_id']);
    }
} elseif (isset($_GET['id'])) {
    $userId = intval($_GET['id']);

    try {
        deleteCustomer($userId) or View::showBadRequestErrorPage();
        View::setPageMessage(tr('Client successfully scheduled for deletion.'), 'success');
        writeLog(sprintf('%s scheduled deletion of the client with ID %d', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $userId), E_USER_NOTICE);
    } catch (\Exception $e) {
        View::setPageMessage(tr('Unable to schedule deletion of the client.'), 'error');
        writeLog(sprintf("System was unable to schedule deletion of client with ID %s: %s.", $userId, $e->getMessage()), E_USER_ERROR);
    }

    redirectTo('users.php');
}

View::showBadRequestErrorPage();
