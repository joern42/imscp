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
 * Class SqlUser
 * @package iMSCP\Model
 */
class SqlUser extends BaseModel
{
    /**
     * @var int
     */
    private $sqlUserID;

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
    private $host;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getSqlUserID(): int
    {
        return $this->sqlUserID;
    }

    /**
     * @param int $sqlUserID
     * @return SqlUser
     */
    public function setSqlUserID(int $sqlUserID): SqlUser
    {
        $this->sqlUserID = $sqlUserID;
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
     * @return SqlUser
     */
    public function setUserID(int $userID): SqlUser
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
     * @return SqlUser
     */
    public function setServerID(int $serverID): SqlUser
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
     * @return SqlUser
     */
    public function setUsername(string $username): SqlUser
    {
        $this->username = $username;
        return $this;
    }

    /**
     * @return string
     */
    public function getHost(): string
    {
        return $this->host;
    }

    /**
     * @param string $host
     * @return SqlUser
     */
    public function setHost(string $host): SqlUser
    {
        $this->host = $host;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return SqlUser
     */
    public function setIsActive(int $isActive): SqlUser
    {
        $this->isActive = $isActive;
        return $this;
    }
}
