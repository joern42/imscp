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

namespace iMSCP\Authentication\Listener;

use iMSCP\Application;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Authentication\AuthResult;

/**
 * Class checkUserAccount
 *
 * Check user account (status and expires date)
 * Expects to listen on the AuthEvent::EVENT_AFTER_AUTHENTICATION
 *
 * @package iMSCP\Authentication\Listener
 */
class checkUserAccount implements AuthenticationListenerInterface
{
    /**
     * @inheritdoc
     */
    public function __invoke(AuthEvent $event): void
    {
        if (!$event->hasAuthenticationResult() || !$event->getAuthenticationResult()->isValid()) {
            // Return early if no authentication result has been set or if it
            // is not valid
            return;
        }

        $identity = $event->getAuthenticationResult()->getIdentity();
        if ($identity->getUserType() !== 'user') {
            // Return early if user type is other than 'user'
            return;
        }

        $stmt = Application::getInstance()->getDb()->createStatement(
            '
                SELECT t1.domain_expires, t1.domain_status, t2.admin_status
                FROM domain AS t1
                JOIN admin AS t2. ON(t2.admin_id = t2.domain_admin_id)
                WHERE domain_admin_id = ?
            '
        );
        $result = $stmt->execute([$identity->getUserId()])->getResource();

        if (!$result->rowCount()) {
            writeLog(sprintf('Account data not found in database for the %s user', $identity->getUsername()), E_USER_ERROR);
            $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE, $identity, [
                tr('An unexpected error occurred. Please contact your reseller.')
            ]));
            return;
        }

        $row = $result->fetch();

        if ($row['admin_status'] == 'disabled' || $row['domain_status'] == 'disabled') {
            $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [
                tr('Your account has been suspended. Please contact your reseller.')
            ]));
            return;
        }

        if ($row['domain_expires'] > 0 && $row['domain_expires'] < time()) {
            $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [
                tr('Your account is expired. Please contact your reseller.')
            ]));
        }
    }
}
