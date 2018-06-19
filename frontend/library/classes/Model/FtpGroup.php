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
 * Class FtpGroup
 * @package iMSCP\Model
 */
class FtpGroup extends BaseModel
{
    /**
     * @var int
     */
    private $ftpGroupID;

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
    private $groupName;

    /**
     * @var int
     */
    private $gid;

    /**
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
     * @param int $ftpGroupID
     * @return FtpGroup
     */
    public function setFtpGroupID(int $ftpGroupID): FtpGroup
    {
        $this->ftpGroupID = $ftpGroupID;
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
     * @return FtpGroup
     */
    public function setUserID(int $userID): FtpGroup
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
     * @return FtpGroup
     */
    public function setServerID(int $serverID): FtpGroup
    {
        $this->serverID = $serverID;
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
