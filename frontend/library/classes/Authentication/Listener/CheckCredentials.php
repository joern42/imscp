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
use iMSCP\Crypt;
use iMSCP\Functions\Daemon;
use iMSCP\Model\CpUserIdentity;
use iMSCP\Model\UserIdentityInterface;
use Zend\Db\Adapter\Driver\ResultInterface;
use Zend\Db\ResultSet\HydratingResultSet;
use Zend\Hydrator\Reflection as ReflectionHydrator;

/**
 * Class CheckCredentials
 *
 * Default credentials authentication listener
 * Expects to listen on the AuthEvent::EVENT_AUTHENTICATION
 *
 * @package iMSCP\Authentication\Listener
 */
class CheckCredentials implements AuthenticationListenerInterface
{
    /**
     * @inheritdoc
     */
    public function __invoke(AuthEvent $event): void
    {
        if ($event->hasAuthenticationResult() && !$event->getAuthenticationResult()->isValid()) {
            // Return early if an authentication result is already set and is not valid
            return;
        }

        $request = Application::getInstance()->getRequest();
        $username = encodeIdna(cleanInput($request->getPost('username', '')));
        $password = cleanInput($request->getPost('password', ''));

        if ($username === '' || $password === '') {
            $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_CREDENTIAL_INVALID, NULL, [tr('Invalid credentials.')]));
            return;
        }

        $stmt = Application::getInstance()->getDb()->createStatement(
            'SELECT userId, username, passwordHash, type, email, createdBy FROM imscp_user WHERE username = ?'
        );
        $result = $stmt->execute([$username]);

        if ($result instanceof ResultInterface && $result->isQueryResult()) {
            $resultSet = new HydratingResultSet(new ReflectionHydrator, new CpUserIdentity());
            $resultSet->initialize($result);

            if (count($resultSet) < 1) {
                $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_CREDENTIAL_INVALID, NULL, [tr('Invalid credentials.')]));
                return;
            }

            /** @var UserIdentityInterface $identity */
            $identity = $resultSet->current();
            if (!Crypt::verify($password, $identity->getUserPassword())) {
                $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_CREDENTIAL_INVALID, NULL, [tr('Invalid credentials.')]));
                return;
            }

            // If not a Bcrypt hashed password, we need recreate the hash
            if (strpos($identity->getUserPassword(), '$2a$') !== 0) {
                Application::getInstance()->getEventManager()->attach(
                    AuthEvent::EVENT_AFTER_AUTHENTICATION,
                    function (AuthEvent $event) use ($password) {
                        $authResult = $event->getAuthenticationResult();
                        if (!$authResult->isValid()) {
                            // Return early if authentication process has failed somewhere else
                            return;
                        }

                        $identity = $authResult->getIdentity();
                        $stmt = Application::getInstance()->getDb()->createStatement('UPDATE imscp_user SET password = ? WHERE userID = ?');
                        $stmt->execute([Crypt::bcrypt($password), $identity->getUserId()]);
                        writeLog(sprintf('Password hash for user %s has been updated for use of Bcrypt algorithm', $identity->getUsername()), E_USER_NOTICE);
                        $identity->getUserType() != 'user' or Daemon::sendRequest();
                    },
                    -99
                );
            }

            // We do not want store password hash in session
            $identity->clearUserPassword();

            $event->setAuthenticationResult(new AuthResult(AuthResult::SUCCESS, $identity));
        }
    }
}
