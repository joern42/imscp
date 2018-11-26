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

use Doctrine\ORM\Mapping as ORM;

/**
 * Class FtpUser
 * @ORM\Entity
 * @ORM\Table(name="imscp_ftp_user", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class FtpUser 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $ftpUserID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\ManyToOne(targetEntity="Server")
     * @ORM\JoinColumn(name="serverID", referencedColumnName="serverID", onDelete="CASCADE")
     * @var Server
     */
    private $server;

    /**
     * @var int
     */
    private $ftpGroupID;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $username;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $passwordHash;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $uid;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $gid;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $shell = '/bin/sh';

    /**
     * @ORM\Column(type="string")
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
     * @return User
     */
    public function getUser(): User
    {
        return $this->user;
    }

    /**
     * @param User $user
     * @return FtpUser
     */
    public function setUser(User $user): FtpUser
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return int
     */
    public function getServer(): Server
    {
        return $this->server;
    }

    /**
     * @param Server $server
     * @return FtpUser
     */
    public function setServer(Server $server): FtpUser
    {
        $this->server = $server;
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
