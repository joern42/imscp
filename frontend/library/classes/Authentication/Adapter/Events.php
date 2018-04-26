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

use iMSCP\Authentication\AuthEvent;
use iMSCP\Authentication\AuthResult;
use Zend\Authentication\Adapter\AbstractAdapter;
use Zend\EventManager\EventManagerInterface;

/**
 * Class Event
 *
 * This adapter authenticate users by triggering authentication events.
 * Listeners of these events are authentication handlers which are responsible
 * to implement authentication logic and set authentication result on authentication events.
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
        $authEvent->setName(AuthEvent::EVENT_BEFORE_AUTHENTICATION);

        $responses = $this->events->triggerEvent($authEvent);
        if (!$responses->stopped()) {
            $authEvent->setName(AuthEvent::EVENT_AUTHENTICATION);
            $this->events->triggerEvent($authEvent);

            if (!$authEvent->hasAuthenticationResult()) {
                $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, NULL, [tr('Unknown reason.')]);
                $authEvent->setAuthenticationResult($authResult);
            } else {
                $authResult = $authEvent->getAuthenticationResult();
            }
        } else {
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, NULL, $responses->last());
            $authEvent->setAuthenticationResult($authResult);
        }

        $authEvent->setTarget($this);
        $authEvent->setName(AuthEvent::EVENT_AFTER_AUTHENTICATION);
        $this->events->triggerEvent($authEvent);

        return $authResult;
    }
}
