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
 * Class WebHtgroup
 * @package iMSCP\Model
 */
class WebHtgroup extends BaseModel
{
    /**
     * @var int
     */
    private $webHtgroupID;

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
     * @var string|null
     */
    private $members;

    /**
     * @return int
     */
    public function getWebHtgroupID(): int
    {
        return $this->webHtgroupID;
    }

    /**
     * @param int $webHtgroupID
     * @return WebHtgroup
     */
    public function setWebHtgroupID(int $webHtgroupID): WebHtgroup
    {
        $this->webHtgroupID = $webHtgroupID;
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
     * @return WebHtgroup
     */
    public function setUserID(int $userID): WebHtgroup
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
     * @return WebHtgroup
     */
    public function setServerID(int $serverID): WebHtgroup
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
     * @return WebHtgroup
     */
    public function setGroupName(string $groupName): WebHtgroup
    {
        $this->groupName = $groupName;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getMembers(): ?string
    {
        return $this->members;
    }

    /**
     * @param string|null $members
     * @return WebHtgroup
     */
    public function setMembers(string $members = NULL): WebHtgroup
    {
        $this->members = $members;
        return $this;
    }
}
