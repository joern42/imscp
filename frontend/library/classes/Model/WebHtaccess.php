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
 * Class WebHtaccess
 * @package iMSCP\Model
 */
class WebHtaccess extends BaseModel
{
    /**
     * @var int
     */
    private $webHtaccessID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var int|null
     */
    private $webHtpasswdID;

    /**
     * @var int|null
     */
    private $webHtgroupID;

    /**
     * @var string
     */
    private $authName;

    /**
     * @var string
     */
    private $authType;

    /**
     * @var string
     */
    private $path;

    /**
     * @return int
     */
    public function getWebHtaccessID(): int
    {
        return $this->webHtaccessID;
    }

    /**
     * @param int $webHtaccessID
     * @return WebHtaccess
     */
    public function setWebHtaccessID(int $webHtaccessID): WebHtaccess
    {
        $this->webHtaccessID = $webHtaccessID;
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
     * @return WebHtaccess
     */
    public function setUserID(int $userID): WebHtaccess
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
     * @return WebHtaccess
     */
    public function setServerID(int $serverID): WebHtaccess
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return int|null
     */
    public function getWebHtpasswdID(): ?int
    {
        return $this->webHtpasswdID;
    }

    /**
     * @param int|null $webHtpasswdID
     * @return WebHtaccess
     */
    public function setWebHtpasswdID(int $webHtpasswdID = NULL): WebHtaccess
    {
        $this->webHtpasswdID = $webHtpasswdID;
        return $this;
    }

    /**
     * @return int|null
     */
    public function getWebHtgroupID(): ?int
    {
        return $this->webHtgroupID;
    }

    /**
     * @param int|null $webHtgroupID
     * @return WebHtaccess
     */
    public function setWebHtgroupID(int $webHtgroupID = NULL): WebHtaccess
    {
        $this->webHtgroupID = $webHtgroupID;
        return $this;
    }

    /**
     * @return string
     */
    public function getAuthName(): string
    {
        return $this->authName;
    }

    /**
     * @param string $authName
     * @return WebHtaccess
     */
    public function setAuthName(string $authName): WebHtaccess
    {
        $this->authName = $authName;
        return $this;
    }

    /**
     * @return string
     */
    public function getAuthType(): string
    {
        return $this->authType;
    }

    /**
     * @param string $authType
     * @return WebHtaccess
     */
    public function setAuthType(string $authType): WebHtaccess
    {
        $this->authType = $authType;
        return $this;
    }

    /**
     * @return string
     */
    public function getPath(): string
    {
        return $this->path;
    }

    /**
     * @param string $path
     * @return WebHtaccess
     */
    public function setPath(string $path): WebHtaccess
    {
        $this->path = $path;
        return $this;
    }
}
