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
use iMSCP\Authentication\AuthenticationService;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Authentication\AuthResult;
use iMSCP\Functions\View;

/**
 * Class LostPasswordLink
 *
 * Show link for password recovery if the lost password feature is enabled and
 * if authentication result isn't valid due to invalid credentials.
 * Expects to listen on the AuthEvent::EVENT_AFTER_AUTHENTICATION
 *
 * @package iMSCP\Authentication\Listener
 */
class PasswordRecovery implements AuthenticationListenerInterface
{
    /**
     * @inheritdoc
     */
    public function __invoke(AuthEvent $event): void
    {
        if (!$event->hasAuthenticationResult()) {
            // Return early if no authentication result has been set
            return;
        }

        $authResult = $event->getAuthenticationResult();
        if ($authResult->isValid() || $authResult->getCode() != AuthResult::FAILURE_CREDENTIAL_INVALID) {
            // Return early if authentication result is valid or if authentication
            // code doesn't denote a failure due to invalid credentials
            return;
        }

        $config = Application::getInstance()->getConfig();
        if (!$config['LOSTPASSWORD']) {
            return;
        }

        Application::getInstance()->getEventManager()->attach(AuthenticationService::EVENT_AFTER_SIGN_IN, function () {
            View::setPageMessage('<strong><a href="/lostpassword.php">' . tr('Password lost?') . '</a></strong>', 'static_error');
        }, -99);
    }
}
