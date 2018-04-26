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

namespace iMSCP\Plugin;

use iMSCP\Application;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Plugin\PluginManager as PluginManager;
use Zend\EventManager\Event;
use Zend\EventManager\EventManagerInterface;

/**
 * Class Bruteforce
 *
 * Provides countermeasures against brute-force and dictionary attacks.
 *
 * This class can be used in two different ways:
 *  - As a plugin that listen to the onBeforeAuthentication event which is triggered by authentication service class
 *  - As a simple component
 *
 * @package iMSCP\Plugin
 */
class Bruteforce extends AbstractPlugin
{
    /**
     * @var int Tells whether or not waiting time between login|captcha attempts is enabled
     */
    protected $waitTimeEnabled = 0;

    /**
     * @var int Blocking time in minutes
     */
    protected $blockingTime = 0;

    /**
     * @var int Waiting time in seconds between each login|captcha attempts
     */
    protected $waitingTime = 0;

    /**
     * @var int Max. login/captcha attempts before blocking time is taking effect
     */
    protected $maxAttemptsBeforeBlocking = 0;

    /**
     * @var string Client IP address
     */
    protected $clientIpAddr;

    /**
     * @var string Target form (login|captcha)
     */
    protected $targetForm = 'login';

    /**
     * @var int Time during which an IP address is blocked
     */
    protected $isBlockedFor = 0;

    /**
     * @var int Time to wait before a new login|captcha attempts
     */
    protected $isWaitingFor = 0;

    /**
     * @var int Max. attempts before waiting time is taking effect
     */
    protected $maxAttemptsBeforeWaitingTime = 0;

    /**
     * @var bool Tells whether or not a login attempt has been recorded
     */
    protected $recordExists = false;

    /**
     * @var string Session unique identifier
     */
    protected $sessionId;

    /**
     * @var string Last message raised
     */
    protected $message;

    /**
     * Constructor
     *
     * @param PluginManager $pluginManager
     * @param string $targetForm Target form (login|captcha)
     * @çeturn void
     */
    public function __construct(PluginManager $pluginManager, string $targetForm = 'login')
    {
        parent::__construct($pluginManager);

        $config = Application::getInstance()->getConfig();

        if ($targetForm == 'login') {
            $this->maxAttemptsBeforeBlocking = $config['BRUTEFORCE_MAX_LOGIN'];
        } elseif ($targetForm == 'captcha') {
            $this->maxAttemptsBeforeBlocking = $config['BRUTEFORCE_MAX_CAPTCHA'];
        } else {
            throw new \Exception(tr('Unknown bruteforce detection type: %s', $targetForm));
        }

        $this->clientIpAddr = getIpAddr();
        $this->targetForm = $targetForm;
        $this->sessionId = session_id();
        $this->waitTimeEnabled = $config['BRUTEFORCE_BETWEEN'];
        $this->maxAttemptsBeforeWaitingTime = $config['BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'];
        $this->waitingTime = $config['BRUTEFORCE_BETWEEN_TIME'];
        $this->blockingTime = $config['BRUTEFORCE_BLOCK_TIME'];

        execQuery('DELETE FROM login WHERE UNIX_TIMESTAMP() > (lastaccess + ?)', [$this->blockingTime * 60]);
    }

    /**
     * Returns plugin general information
     *
     * @return array
     */
    public function getInfo()
    {
        return [
            'author'      => 'Laurent Declercq',
            'email'       => 'l.declercq@nuxwin.com',
            'version'     => '1.0.0',
            'require_api' => '1.6.0',
            'date'        => '2018-04-26',
            'name'        => 'Bruteforce',
            'desc'        => 'Provides countermeasures against brute-force and dictionary attacks.',
            'url'         => 'http://www.i-mscp.net'
        ];
    }

    /**
     * @inheritdoc
     */
    public function attach(EventManagerInterface $events, $priority = 100): void
    {
        // That plugin must acts early in the authentication process
        $events->attach(AuthEvent::EVENT_BEFORE_AUTHENTICATION, [$this, 'onBeforeAuthentication'], $priority);
    }

    /**
     * onBeforeAuthentication event listener
     *
     * @param Event $event
     * @return null|string
     */
    public function onBeforeAuthentication($event): ?string
    {
        if ($this->isWaiting() || $this->isBlocked()) {
            $event->stopPropagation();
            return $this->getLastMessage();
        }

        $this->logAttempt();
        return NULL;
    }

    /**
     * Is waiting IP address?
     *
     * @return bool TRUE if the client have to wait for a next login/captcha attempts, FALSE otherwise
     */
    public function isWaiting(): bool
    {
        if ($this->isWaitingFor == 0) {
            return false;
        }

        $time = time();
        if ($time < $this->isWaitingFor) {
            $this->message = tr('You must wait %s minutes before the next attempt.', strftime('%M:%S', $this->isWaitingFor - $time));
            return true;
        }

        return false;
    }

    /**
     * Is blocked IP address?
     *
     * @return bool TRUE if the client is blocked, FALSE otherwise
     */
    public function isBlocked(): bool
    {
        if ($this->isBlockedFor == 0) {
            return false;
        }

        $time = time();
        if ($time < $this->isBlockedFor) {
            $this->message = tr('You have been blocked for %s minutes.', strftime('%M:%S', $this->isBlockedFor - $time));
            return true;
        }

        return false;
    }

    /**
     * Returns last message raised
     *
     * @return string
     */
    public function getLastMessage(): string
    {
        return $this->message;
    }

    /**
     * Log a login or captcha attempt
     *
     * @return void
     */
    public function logAttempt(): void
    {
        if (!$this->recordExists) {
            $this->createRecord();
            return;
        }

        $this->updateRecord();
    }

    /**
     * Create bruteforce detection record
     *
     * @return void
     */
    protected function createRecord(): void
    {
        execQuery(
            "REPLACE INTO login (session_id, ipaddr, {$this->targetForm}_count, user_name, lastaccess) VALUES (?, ?, 1, NULL, UNIX_TIMESTAMP())",
            [$this->sessionId, $this->clientIpAddr]
        );
    }

    /**
     * Increase login|captcha attempts by 1 for $_ipAddr
     *
     * @return void
     */
    protected function updateRecord(): void
    {
        execQuery(
            "
                UPDATE login
                SET lastaccess = UNIX_TIMESTAMP(), {$this->targetForm}_count = {$this->targetForm}_count + 1
                WHERE ipaddr= ?
                AND user_name IS NULL
            ",
            [$this->clientIpAddr]
        );
    }

    /**
     * Initialization
     *
     * @return void
     */
    protected function init(): void
    {
        $stmt = execQuery('SELECT lastaccess, login_count, captcha_count FROM login WHERE ipaddr = ? AND user_name IS NULL', [$this->clientIpAddr]);

        if (!$stmt->rowCount()) {
            return;
        }

        $row = $stmt->fetch();
        $this->recordExists = true;

        if ($row[$this->targetForm . '_count'] >= $this->maxAttemptsBeforeBlocking) {
            $this->isBlockedFor = $row['lastaccess'] + ($this->blockingTime * 60);
            return;
        }

        if ($this->waitTimeEnabled && $row[$this->targetForm . '_count'] >= $this->maxAttemptsBeforeWaitingTime) {
            $this->isWaitingFor = $row['lastaccess'] + $this->waitingTime;
            return;
        }
    }
}
