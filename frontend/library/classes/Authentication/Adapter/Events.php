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

namespace iMSCP\Authentication\Adapter;

use iMSCP\Application;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Authentication\AuthResult;
use Zend\Authentication\Adapter\AbstractAdapter;
use Zend\EventManager\EventManagerInterface;

/**
 * Class Events
 *
 * This adapter authenticate users by triggering authentication events.
 * Listeners of these events are responsible to implement authentication
 * logic and set authentication result on the authentication events.
 *
 * Various authentication listeners can be attached, making possible to
 * enable multi-factor authentication (MFA). These can also have specific
 * tasks such as checking an user account, blocking brute force login
 * attacks and so on...
 *
 * @package iMSCP\Authentication\Adapter
 */
class Events extends AbstractAdapter
{
    /**
     * @var EventManagerInterface
     */
    protected $events;

    /**
     * Event constructor.
     * @param EventManagerInterface $events
     */
    public function __construct(EventManagerInterface $events)
    {
        $this->events = $events;
    }

    /**
     * @inheritdoc
     */
    public function authenticate()
    {
        $authEvent = new AuthEvent();
        $authEvent->setTarget($this);

        foreach ([AuthEvent::EVENT_BEFORE_AUTHENTICATION, AuthEvent::EVENT_AUTHENTICATION, AuthEvent::EVENT_AFTER_AUTHENTICATION] as $event) {
            $authEvent->setName($event);
            $this->events->triggerEvent($authEvent);
        }

        if ($authEvent->hasAuthenticationResult()) {
            $authResult = $authEvent->getAuthenticationResult();
        } else {
            // Cover case where none of attached authentication listeners has set an authentication result
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, NULL, [tr('Unhandled authentication')]);
            $authEvent->setAuthenticationResult($authResult);
        }

        if ($authResult->isValid()) {
            Application::getInstance()->getSession()->getManager()->regenerateId();
        }

        return $authEvent->getAuthenticationResult();
    }
}
