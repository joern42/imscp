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
 * Class FtpGroup
 * @ORM\Entity
 * @ORM\Table(name="imscp_ftp_group", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class FtpGroup 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $ftpGroupID;

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
     * @ORM\Column(type="string")
     * @var string
     */
    private $groupName;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $gid;

    /**
     * @ORM\Column(type="text")
     * @var string
     */
    private $members;

    /**
     * @return int
     */
    public function getFtpGroupID(): int
    {
        return $this->ftpGroupID;
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
     * @return FtpGroup
     */
    public function setUser(User $user): FtpGroup
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return Server
     */
    public function getServer(): Server
    {
        return $this->server;
    }

    /**
     * @param Server $server
     * @return FtpGroup
     */
    public function setServer(Server $server): FtpGroup
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return string
     */
    public function getGroupName(): string
    {
        return $this->groupName;
    }

    /**
     * @param string $groupName
     * @return FtpGroup
     */
    public function setGroupName(string $groupName): FtpGroup
    {
        $this->groupName = $groupName;
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
     * @return FtpGroup
     */
    public function setGid(int $gid): FtpGroup
    {
        $this->gid = $gid;
        return $this;
    }

    /**
     * @return string
     */
    public function getMembers(): string
    {
        return $this->members;
    }

    /**
     * @param string $members
     * @return FtpGroup
     */
    public function setMembers(string $members): FtpGroup
    {
        $this->members = $members;
        return $this;
    }
}
