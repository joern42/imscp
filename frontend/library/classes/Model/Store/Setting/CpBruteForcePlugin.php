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

namespace iMSCP\Model\Store\Setting;

use iMSCP\Model\Store\Service\SettingInterface;

/**
 * Class CpBruteForcePlugin
 * @package iMSCP\Model\Store\Setting
 */
class CpBruteForcePlugin implements SettingInterface
{
    const NAME = 'BruteForcePlugin';

    /**
     * @var bool 
     */
    private $isActiveWaitingTime = true;

    /**
     * @var int 
     */
    private $maxAttemptsBeforeWaitingTime = 2;

    /**
     * @var int 
     */
    private $waitingTimeInSeconds = 30;

    /**
     * @var int 
     */
    private $blockingTimeInMinutes = 15;

    /**
     * @var int 
     */
    private $maxLoginAuthAttempts = 5;

    /**
     * @var int 
     */
    private $maxCaptchaAttempts = 5;

    /**
     * @var bool 
     */
    private $isActive = true;

    /**
     * Return setting name
     *
     * @return string
     */
    public function getName()
    {
        return self::NAME;
    }

    /**
     * @return bool
     */
    public function isIsActiveWaitingTime(): bool
    {
        return $this->isActiveWaitingTime;
    }

    /**
     * @param bool $isActiveWaitingTime
     * @return CpBruteForcePlugin
     */
    public function setIsActiveWaitingTime(bool $isActiveWaitingTime): CpBruteForcePlugin
    {
        $this->isActiveWaitingTime = $isActiveWaitingTime;
        return $this;
    }

    /**
     * @return int
     */
    public function getMaxAttemptsBeforeWaitingTime(): int
    {
        return $this->maxAttemptsBeforeWaitingTime;
    }

    /**
     * @param int $maxAttemptsBeforeWaitingTime
     * @return CpBruteForcePlugin
     */
    public function setMaxAttemptsBeforeWaitingTime(int $maxAttemptsBeforeWaitingTime): CpBruteForcePlugin
    {
        $this->maxAttemptsBeforeWaitingTime = $maxAttemptsBeforeWaitingTime;
        return $this;
    }

    /**
     * @return int
     */
    public function getWaitingTimeInSeconds(): int
    {
        return $this->waitingTimeInSeconds;
    }

    /**
     * @param int $waitingTimeInSeconds
     * @return CpBruteForcePlugin
     */
    public function setWaitingTimeInSeconds(int $waitingTimeInSeconds): CpBruteForcePlugin
    {
        $this->waitingTimeInSeconds = $waitingTimeInSeconds;
        return $this;
    }

    /**
     * @return int
     */
    public function getBlockingTimeInMinutes(): int
    {
        return $this->blockingTimeInMinutes;
    }

    /**
     * @param int $blockingTimeInMinutes
     * @return CpBruteForcePlugin
     */
    public function setBlockingTimeInMinutes(int $blockingTimeInMinutes): CpBruteForcePlugin
    {
        $this->blockingTimeInMinutes = $blockingTimeInMinutes;
        return $this;
    }

    /**
     * @return int
     */
    public function getMaxLoginAuthAttempts(): int
    {
        return $this->maxLoginAuthAttempts;
    }

    /**
     * @param int $maxLoginAuthAttempts
     * @return CpBruteForcePlugin
     */
    public function setMaxLoginAuthAttempts(int $maxLoginAuthAttempts): CpBruteForcePlugin
    {
        $this->maxLoginAuthAttempts = $maxLoginAuthAttempts;
        return $this;
    }

    /**
     * @return int
     */
    public function getMaxCaptchaAttempts(): int
    {
        return $this->maxCaptchaAttempts;
    }

    /**
     * @param int $maxCaptchaAttempts
     * @return CpBruteForcePlugin
     */
    public function setMaxCaptchaAttempts(int $maxCaptchaAttempts): CpBruteForcePlugin
    {
        $this->maxCaptchaAttempts = $maxCaptchaAttempts;
        return $this;
    }

    /**
     * @return bool
     */
    public function isActive(): bool
    {
        return $this->isActive;
    }

    /**
     * @param bool $isActive
     * @return CpBruteForcePlugin
     */
    public function setIsActive(bool $isActive): CpBruteForcePlugin
    {
        $this->isActive = $isActive;
        return $this;
    }
}
