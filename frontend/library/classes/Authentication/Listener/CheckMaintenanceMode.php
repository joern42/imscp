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
 * Class CheckMaintenanceMode
 *
 * In maintenance mode, only administrators can login. Other users are
 * immediately signed out and an explanation message is provided to them.
 * Expects to listen on the AuthEvent::EVENT_AFTER_AUTHENTICATION
 *
 * @package iMSCP\Authentication\Listener
 */
class CheckMaintenanceMode implements AuthenticationListenerInterface
{
    /**
     * @inheritdoc
     */
    public function __invoke(AuthEvent $event): void
    {
        if (!$event->hasAuthenticationResult() || !$event->getAuthenticationResult()->isValid()) {
            // Return early if no authentication result has been set of if it
            // is not valid
            return;
        }

        $identity = $event->getAuthenticationResult()->getIdentity();
        if ($identity->getUserType() == 'admin') {
            return;
        }

        $config = Application::getInstance()->getConfig();
        if (!$config['MAINTENANCEMODE']) {
            return;
        }

        $message = preg_replace('/\s\s+/', '', nl2br(toHtml(
            $config['MAINTENANCEMODE_MESSAGE'] ?? tr('We are sorry, but the system is currently under maintenance. In that mode, only administrators can sign in.')
        )));

        $event->setAuthenticationResult(new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [$message]));
    }
}
