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

/**
 * Deletes an admin or reseller user
 *
 * @param int $userId User unique identifier
 */
function admin_deleteUser($userId)
{
    $userId = intval($userId);
    $cfg = Application::getInstance()->getConfig();
    $db = Application::getInstance()->getDb();

    $stmt = execQuery('SELECT a.admin_type, b.logo FROM admin a LEFT JOIN user_gui_props b ON (b.user_id = a.admin_id) WHERE admin_id = ?', [
        $userId
    ]);
    $row = $stmt->fetch();
    $userType = $row['admin_type'];

    if (empty($userType) || $userType == 'user') {
        View::showBadRequestErrorPage();
    }

    // Users (admins/resellers) common items to delete
    $itemsToDelete = [
        'admin'          => 'admin_id = ?',
        'email_tpls'     => 'owner_id = ?',
        'tickets'        => 'ticket_from = ? OR ticket_to = ?',
        'user_gui_props' => 'user_id = ?'
    ];

    if ($userType == 'reseller') {
        // Getting custom reseller isp logo if set
        $resellerLogo = $row['logo'];

        // Add specific reseller items to remove
        $itemsToDelete = array_merge(
            [
                'hosting_plans'  => 'reseller_id = ?',
                'reseller_props' => 'reseller_id = ?',
            ],
            $itemsToDelete
        );
    }

    // We are using transaction to ensure data consistency and prevent any garbage in
    // the database. If one query fail, the whole process is reverted.

    try {
        // Cleanup database
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteUser, NULL, ['userId' => $userId]);

        foreach ($itemsToDelete as $table => $where) {
            $query = "DELETE FROM " . quoteIdentifier($table) . ($where ? " WHERE $where" : '');
            execQuery($query, array_fill(0, substr_count($where, '?'), $userId));
        }

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteUser, NULL, ['userId' => $userId]);

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

        $userTr = $userType == 'reseller' ? tr('Reseller') : tr('Admin');
        setPageMessage(tr('%s account successfully deleted.', $userTr), 'success');
        writeLog(Application::getInstance()->getAuthService()->getIdentity()->getUsername() . ": deletes user " . $userId, E_USER_NOTICE);
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    redirectTo('users.php');
}

/**
 * Validates admin or reseller deletion
 *
 * @param int $userId User unique identifier
 * @return bool TRUE if deletion can be done, FALSE otherwise
 */
function admin_validateUserDeletion($userId)
{
    $stmt = execQuery('SELECT admin_type, created_by FROM admin WHERE admin_id = ?', [$userId]);
    $stmt->rowCount() or View::showBadRequestErrorPage(); # No user found; assume a bad request
    $row = $stmt->fetch();

    if ($row['created_by'] == 0) {
        setPageMessage(tr('You cannot delete the default administrator.'), 'error');
    }

    if (!in_array($row['admin_type'], ['admin', 'reseller'])) {
        View::showBadRequestErrorPage(); # Not an administrator, nor a reseller; assume a bad request
    }

    $stmt = execQuery('SELECT COUNT(admin_id) AS user_count FROM admin WHERE created_by = ?', [$userId]);
    $row2 = $stmt->fetch();

    if ($row2['user_count'] > 0) {
        if ($row['admin_type'] == 'admin') {
            setPageMessage(tr('Prior to removing this administrator, please move his resellers to another administrator.'), 'error');
        } else {
            setPageMessage(tr('You cannot delete a reseller that has customer accounts.'), 'error');
        }

        return false;
    }

    return true;
}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

if (isset($_GET['id'])) { # admin/reseller deletion
    if (admin_validateUserDeletion($_GET['id'])) {
        admin_deleteUser($_GET['id']);
    }
} elseif (isset($_GET['id'])) {
    $userId = intval($_GET['id']);

    try {
        deleteCustomer($userId) or View::showBadRequestErrorPage();
        setPageMessage(tr('Customer account successfully scheduled for deletion.'), 'success');
        writeLog(sprintf('%s scheduled deletion of the customer account with ID %d', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $userId), E_USER_NOTICE);
    } catch (\Exception $e) {
        setPageMessage(tr('Unable to schedule deletion of the customer account.'), 'error');
        writeLog(sprintf("System was unable to schedule deletion of customer account with ID %s: %s.", $userId, $e->getMessage()), E_USER_ERROR);
    }
}

redirectTo('users.php');
