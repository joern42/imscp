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
 * Class FtpUser
 * @package iMSCP\Model
 */
class FtpUser extends BaseModel
{
    /**
     * @var int
     */
    private $ftpUserID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var int
     */
    private $ftpGroupID;

    /**
     * @var string
     */
    private $username;

    /**
     * @var string
     */
    private $passwordHash;

    /**
     * @var int
     */
    private $uid;

    /**
     * @var int
     */
    private $gid;

    /**
     * @var string
     */
    private $shell = '/bin/sh';

    /**
     * @var string
     */
    private $homedir;

    /**
     * @return int
     */
    public function getFtpUserID(): int
    {
        return $this->ftpUserID;
    }

    /**
     * @param int $ftpUserID
     * @return FtpUser
     */
    public function setFtpUserID(int $ftpUserID): FtpUser
    {
        $this->ftpUserID = $ftpUserID;
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
     * @return FtpUser
     */
    public function setUserID(int $userID): FtpUser
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
     * @return FtpUser
     */
    public function setServerID(int $serverID): FtpUser
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return int
     */
    public function getFtpGroupID(): int
    {
        return $this->ftpGroupID;
    }

    /**
     * @param int $ftpGroupID
     * @return FtpUser
     */
    public function setFtpGroupID(int $ftpGroupID): FtpUser
    {
        $this->ftpGroupID = $ftpGroupID;
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
     * @return FtpUser
     */
    public function setUsername(string $username): FtpUser
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
     * @return FtpUser
     */
    public function setPasswordHash(string $passwordHash): FtpUser
    {
        $this->passwordHash = $passwordHash;
        return $this;
    }

    /**
     * @return int
     */
    public function getUid(): int
    {
        return $this->uid;
    }

    /**
     * @param int $uid
     * @return FtpUser
     */
    public function setUid(int $uid): FtpUser
    {
        $this->uid = $uid;
        return $this;
    }

    /**
     * @return int
     */
    public function getGid(): int
    {
        return $this->gid;
    }

    /**
     * @param int $gid
     * @return FtpUser
     */
    public function setGid(int $gid): FtpUser
    {
        $this->gid = $gid;
        return $this;
    }

    /**
     * @return string
     */
    public function getShell(): string
    {
        return $this->shell;
    }

    /**
     * @param string $shell
     * @return FtpUser
     */
    public function setShell(string $shell): FtpUser
    {
        $this->shell = $shell;
        return $this;
    }

    /**
     * @return string
     */
    public function getHomedir(): string
    {
        return $this->homedir;
    }

    /**
     * @param string $homedir
     * @return FtpUser
     */
    public function setHomedir(string $homedir): FtpUser
    {
        $this->homedir = $homedir;
        return $this;
    }
}
