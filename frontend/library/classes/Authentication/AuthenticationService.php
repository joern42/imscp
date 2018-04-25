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

namespace iMSCP\Authentication;

use iMSCP\Application;
use iMSCP\Events;
use Zend\EventManager\EventManagerInterface;

/**
 * Class AuthenticationService
 *
 * This a authenticate users by triggering the AuthEvent event. Listeners of that event are
 * authentication handlers which are responsible to implement real authentication logic.
 *
 * Any authentication handler should set the appropriate AuthResult on the AuthEvent.
 *
 * @package iMSCP\Authentication
 */
class AuthenticationService
{
    /**
     * Singleton instance
     *
     * @var AuthenticationService
     */
    protected static $instance;

    /**
     * @var EventManagerInterface
     */
    protected $eventManager;

    /**
     * Singleton pattern implementation -  makes "new" unavailable
     */
    protected function __construct()
    {

    }

    /**
     * Implements singleton design pattern
     *
     * @return AuthenticationService Provides a fluent interface, returns self
     */
    public static function getInstance()
    {
        if (NULL === self::$instance) {
            self::$instance = new self;
        }

        return self::$instance;
    }

    /**
     * Process authentication
     *
     * @trigger onBeforeAuthentication
     * @trigger onAuthentication
     * @trigger onAfterAuthentication
     * @return AuthResult
     */
    public function authenticate()
    {
        $em = $this->getEventManager();
        $response = $em->trigger(Events::onBeforeAuthentication, $this);

        if (!$response->stopped()) {
            $authEvent = new AuthEvent($this);

            // Process authentication through registered handlers
            $em->triggerEvent($authEvent);

            // Retrieve authentication result
            $authResult = $authEvent->getAuthenticationResult();

            // Covers case where none of authentication handlers has set an authentication result
            if (!$authResult instanceof AuthResult) {
                $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, NULL, tr('Unknown reason.'));
            }

            if ($authResult->isValid()) {
                // Prevent multiple successive calls from storing inconsistent results
                $this->unsetIdentity();
                $this->setIdentity($authResult->getIdentity());
            }
        } else {
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, NULL, $response->last());
        }

        $em->trigger(Events::onAfterAuthentication, $this, ['authResult' => $authResult]);
        return $authResult;
    }

    /**
     * Return an iMSCP_Events_Manager instance
     *
     * @param EventManagerInterface $events
     * @return EventManagerInterface
     */
    public function getEventManager(EventManagerInterface $events = NULL)
    {
        if (NULL !== $events) {
            $this->eventManager = $events;
            return $events;
        }

        if (NULL === $this->eventManager) {
            $this->eventManager = Application::getInstance()->getEventManager();
        }

        return $this->eventManager;
    }

    /**
     * Unset the current identity
     *
     * @trigger onBeforeUnsetIdentity
     * @trigger onAfterUnserIdentity
     * @return void
     */
    public function unsetIdentity()
    {
        $session = Application::getInstance()->getSession();

        $this->getEventManager()->trigger(Events::onBeforeUnsetIdentity, $this);

        execQuery('DELETE FROM login WHERE session_id = ?', [$session->getManager()->getId()]);

        // Preserve some items
        $session->exchangeArray(array_intersect_key($session->getArrayCopy(), array_fill_keys([
            'user_def_lang', 'user_theme', 'user_theme_color', 'show_main_menu_labels', 'pageMessages'], null
        )));

        $this->getEventManager()->trigger(Events::onAfterUnsetIdentity, $this);
    }

    /**
     * Set the given identity
     *
     * @trigger onBeforeSetIdentity
     * @trigger onAfterSetIdentify
     * @param \stdClass $identity Identity data
     * @return void
     */
    public function setIdentity($identity)
    {
        $session = Application::getInstance()->getSession();
        $response = $this->getEventManager()->trigger(Events::onBeforeSetIdentity, $this, ['identity' => $identity]);

        if ($response->stopped()) {
            $session->getManager()->destroy();
            return;
        }

        $session->getManager()->regenerateId();
        $lastAccess = time();

        execQuery('INSERT INTO login (session_id, ipaddr, lastaccess, user_name) VALUES (?, ?, ?, ?)', [
            $session->getManager()->getId(), getIpAddr(), $lastAccess, $identity->admin_name
        ]);

        $session['user_logged'] = decodeIdna($identity->admin_name);

        $session['user_type'] = $identity->admin_type;
        $session['user_login_time'] = $lastAccess;
        $session['user_identity'] = $identity;

        # Only for backward compatibility. Will be removed in a later version
        $session['user_id'] = $identity->admin_id;
        $session['user_email'] = $identity->email;
        $session['user_created_by'] = $identity->created_by;

        $this->getEventManager()->trigger(Events::onAfterSetIdentity, $this);
    }

    /**
     * Returns true if and only if an identity is available from storage
     *
     * @return boolean
     */
    public function hasIdentity()
    {
        $session = Application::getInstance()->getSession();

        if (!isset($session['user_id'])) {
            return false;
        }

        return execQuery('SELECT COUNT(session_id) FROM login WHERE session_id = ? AND ipaddr = ?', [
            $session->getManager()->getId(), getipaddr()]
        )->fetchColumn() > 0;
    }

    /**
     * Returns the identity from storage if any, redirect to login page otherwise
     *
     * @return \stdClass
     */
    public function getIdentity()
    {
        $session = Application::getInstance()->getSession();

        if (!isset($session['user_identity'])) {
            $this->unsetIdentity(); // Make sure that all identity data are removed
            redirectTo('/index.php');
        }

        return $session['user_identity'];
    }

    /**
     * Singleton pattern implementation -  makes "clone" unavailable
     *
     * @return void
     */
    protected function __clone()
    {

    }
}
