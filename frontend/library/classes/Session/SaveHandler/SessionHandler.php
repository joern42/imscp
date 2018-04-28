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

namespace iMSCP\Session\SaveHandler;

use iMSCP\Application;
use iMSCP\Model\UserIdentityInterface;
use Zend\Session\SaveHandler\SaveHandlerInterface;

/**
 * Class SessionHandler
 *
 * This session handler class is meant to override default write(), destroy()
 * and gc() methods as we want be able to track sessions of logged--in users
 * by storing their identifiers in database.
 *
 * @package iMSCP\Session\SaveHandler
 */
class SessionHandler extends \SessionHandler implements SaveHandlerInterface
{
    /**
     * @inheritdoc
     */
    public function write($session_id, $session_data)
    {
        $identity = Application::getInstance()->getAuthService()->getIdentity();

        try {
            if ($identity instanceof UserIdentityInterface) {
                Application::getInstance()->getDb()->createStatement(
                    'REPLACE INTO login (session_id, ipaddr, lastaccess, user_name) VALUES (?, ?, ?, ?)')->execute(
                    [$session_id, getIpAddr(), time(), $identity->getUsername()]
                );
            }

        } catch (\Throwable $e) {
            writeLog(sprintf("Couldn't write session identifier of logged-in user %s in database: %s", $identity->getUsername(), $e->getMessage()));
        }

        return parent::write($session_id, $session_data);
    }

    /**
     * @inheritdoc
     */
    public function destroy($session_id)
    {
        try {
            Application::getInstance()->getDb()->createStatement('DELETE FROM login WHERE session_id = ?')->execute([$session_id]);
        } catch (\Throwable $e) {
            writeLog(sprintf("Couldn't remove '%s' session data from database: %s", $session_id, $e->getMessage()));
        }

        return parent::destroy($session_id);
    }

    /**
     * @inheritdoc
     */
    public function gc($maxlifetime)
    {
        try {
            // We need ignore rows for which 'user_name' field is empty as this denote
            // data stored by 3rd-party components such as the Bruteforce plugin.
            Application::getInstance()->getDb()->createStatement('DELETE FROM login WHERE lastaccess < ? AND user_name IS NOT NULL')->execute(
                [$maxlifetime]
            );
        } catch (\Throwable $e) {
            writeLog(sprintf("Couldn't cleanup old session data in database: %s", $e->getMessage()));
        }

        return parent::gc($maxlifetime);
    }
}
