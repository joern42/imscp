<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2017 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

/** @noinspection PhpUnhandledExceptionInspection PhpDocMissingThrowsInspection */

/**
 * Class iMSCP_Plugin_Bruteforce
 *
 * Provides countermeasures against brute-force and dictionary attacks.
 *
 * This class can be used in two different ways:
 *  - As a plugin that listen to the onBeforeAuthentication event which is
 *    triggered by authentication service class
 *  - As a simple component
 */
class iMSCP_Plugin_Bruteforce extends iMSCP_Plugin_Action
{
    /**
     * @var int Tells whether or not waiting time between login|captcha attempts
     *          is enabled
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
     * @var int Max. login/captcha attempts before blocking time is taking
     *               effect
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
     * @param iMSCP_Plugin_Manager $pm
     * @param string $targetForm Target form (login|captcha)
     * @çeturn void
     */
    public function __construct(
        iMSCP_Plugin_Manager $pm, $targetForm = 'login'
    )
    {
        $cfg = iMSCP_Registry::get('config');

        if ($targetForm == 'login') {
            $this->maxAttemptsBeforeBlocking = $cfg['BRUTEFORCE_MAX_LOGIN'];
        } elseif ($targetForm == 'captcha') {
            $this->maxAttemptsBeforeBlocking = $cfg['BRUTEFORCE_MAX_CAPTCHA'];
        } else {
            throw new iMSCP_Plugin_Exception(tr(
                'Unknown bruteforce detection type: %s', $targetForm
            ));
        }

        $this->clientIpAddr = getIpAddr();
        $this->targetForm = $targetForm;
        $this->sessionId = session_id();
        $this->waitTimeEnabled = $cfg['BRUTEFORCE_BETWEEN'];
        $this->maxAttemptsBeforeWaitingTime =
            $cfg['BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'];
        $this->waitingTime = $cfg['BRUTEFORCE_BETWEEN_TIME'];
        $this->blockingTime = $cfg['BRUTEFORCE_BLOCK_TIME'];

        exec_query(
            '
                DELETE FROM `login` WHERE `lastaccess` < (UNIX_TIMESTAMP() - ?)
                AND `user_name` = ?
            ',
            [$this->blockingTime * 60, '__bruteforce__']
        );

        parent::__construct($pm);
    }

    /**
     * Initialization
     *
     * @return void
     */
    protected function init()
    {
        $stmt = exec_query(
            '
                SELECT `lastaccess`, `login_count`, `captcha_count`
                FROM `login`
                WHERE `ipaddr` = ?
                AND user_name = ?
            ',
            [$this->clientIpAddr, '__bruteforce__']
        );

        if (!$stmt->rowCount()) {
            return;
        }

        $row = $stmt->fetchRow();
        $this->recordExists = true;

        if ($row[$this->targetForm . '_count'] >= $this->maxAttemptsBeforeBlocking) {
            $this->isBlockedFor = $row['lastaccess'] + ($this->blockingTime * 60);
            return;
        }

        if ($this->waitTimeEnabled
            && $row[$this->targetForm . '_count']
            >= $this->maxAttemptsBeforeWaitingTime
        ) {
            $this->isWaitingFor = $row['lastaccess'] + $this->waitingTime;
            return;
        }
    }

    /**
     * Returns plugin general information
     *
     * @return array
     */
    public function &getInfo(): array
    {
        if (NULL === $this->info) {
            $this->info = [
                'name'        => 'Bruteforce',
                'author'      => 'Laurent Declercq',
                'email'       => 'l.declercq@nuxwin.com',
                'version'     => '0.0.7',
                'build'       => '2019062200',
                'require_api' => '1.0.0',
                'desc'        => 'Provides countermeasures against brute-force and dictionary attacks.',
                'url'         => 'http://www.i-mscp.net'
            ];
        }

        return $this->info;
    }

    /**
     * Register listeners
     *
     * @param iMSCP_Events_Manager_Interface $events
     */
    public function register(iMSCP_Events_Manager_Interface $events)
    {
        // That plugin must acts early in the authentication process
        $events->registerListener(
            iMSCP_Events::onBeforeAuthentication, $this, 100
        );
    }

    /**
     * onBeforeAuthentication event listener
     *
     * @param iMSCP_Events_Event $event
     * @return null|string
     */
    public function onBeforeAuthentication($event)
    {
        if ($this->isWaiting() || $this->isBlocked()) {
            $event->stopPropagation();
            return $this->getLastMessage();
        }

        $this->logAttempt();
        return NULL;
    }

    /**
     * Is blocked IP address?
     *
     * @return bool TRUE if the client is blocked
     */
    public function isBlocked()
    {
        if ($this->isBlockedFor == 0) {
            return false;
        }

        $time = time();
        if ($time < $this->isBlockedFor) {
            $this->message = tr(
                'You have been blocked for %s minutes.',
                strftime('%M:%S', $this->isBlockedFor - $time)
            );
            return true;
        }

        return false;
    }

    /**
     * Is waiting IP address?
     *
     * @return bool TRUE if the client have to wait for a next login/captcha
     *                   attempts, FALSE otherwise
     */
    public function isWaiting()
    {
        if ($this->isWaitingFor == 0) {
            return false;
        }

        $time = time();
        if ($time < $this->isWaitingFor) {
            $this->message = tr(
                'You must wait %s minutes before the next attempt.',
                strftime('%M:%S', $this->isWaitingFor - $time)
            );
            return true;
        }

        return false;
    }

    /**
     * Log a login or captcha attempt
     *
     * @return void
     */
    public function logAttempt()
    {
        if (!$this->recordExists) {
            $this->createRecord();
            return;
        }

        $this->updateRecord();
    }

    /**
     * Returns last message raised
     *
     * @return string
     */
    public function getLastMessage()
    {
        return $this->message;
    }

    /**
     * Increase login|captcha attempts by 1 for $_ipAddr
     *
     * @return void
     */
    protected function updateRecord()
    {
        exec_query(
            "
                UPDATE `login`
                SET `lastaccess` = UNIX_TIMESTAMP(),
                    {$this->targetForm}_count = {$this->targetForm}_count + 1
                WHERE `ipaddr` = ?
                AND `user_name` ?
            ",
            [$this->clientIpAddr, '__bruteforce__']
        );
    }

    /**
     * Create bruteforce detection record
     *
     * @return void
     */
    protected function createRecord()
    {
        exec_query(
            "
                REPLACE INTO `login` (
                    `session_id`, `ipaddr`, `{$this->targetForm}_count`,
                    `lastaccess`, `user_name` 
                ) VALUES (
                    ?, ?, 1, UNIX_TIMESTAMP(), ?
                )
            ",
            [$this->sessionId, $this->clientIpAddr, '__bruteforce__']
        );
    }
}
