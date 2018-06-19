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

namespace iMSCP\Model;

/**
 * Class WebHtpasswd
 * @package iMSCP\Model
 */
class WebHtpasswd extends BaseModel
{
    /**
     * @var int
     */
    private $webHtpasswdID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $username;

    /**
     * @var string
     */
    private $passwordHash;

    /**
     * @return int
     */
    public function getWebHtpasswdID(): int
    {
        return $this->webHtpasswdID;
    }

    /**
     * @param int $webHtpasswdID
     * @return WebHtpasswd
     */
    public function setWebHtpasswdID(int $webHtpasswdID): WebHtpasswd
    {
        $this->webHtpasswdID = $webHtpasswdID;
        return $this;
    }

    /**
     * @return int
     */
    public function getUserID(): int
    {
        return $this->userID;
    }

    /**
     * @param int $userID
     * @return WebHtpasswd
     */
    public function setUserID(int $userID): WebHtpasswd
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return int
     */
    public function getServerID(): int
    {
        return $this->serverID;
    }

    /**
     * @param int $serverID
     * @return WebHtpasswd
     */
    public function setServerID(int $serverID): WebHtpasswd
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getUsername(): string
    {
        return $this->username;
    }

    /**
     * @param string $username
     * @return WebHtpasswd
     */
    public function setUsername(string $username): WebHtpasswd
    {
        $this->username = $username;
        return $this;
    }

    /**
     * @return string
     */
    public function getPasswordHash(): string
    {
        return $this->passwordHash;
    }

    /**
     * @param string $passwordHash
     * @return WebHtpasswd
     */
    public function setPasswordHash(string $passwordHash): WebHtpasswd
    {
        $this->passwordHash = $passwordHash;
        return $this;
    }
}
