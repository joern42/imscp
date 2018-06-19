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
 * Class IpAddress
 * @package iMSCP\Model
 */
class IpAddress extends BaseModel
{
    /**
     * @var int
     */
    private $ipAddressID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $ipAddress;

    /**
     * @var string
     */
    private $netmask;

    /**
     * @var string
     */
    private $nic;

    /**
     * @var string
     */
    private $configMode = 'manual';

    /**
     * @return int
     */
    public function getIpAddressID(): int
    {
        return $this->ipAddressID;
    }

    /**
     * @param int $ipAddressID
     * @return IpAddress
     */
    public function setIpAddressID(int $ipAddressID): IpAddress
    {
        $this->ipAddressID = $ipAddressID;
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
     * @return IpAddress
     */
    public function setServerID(int $serverID): IpAddress
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getIpAddress(): string
    {
        return $this->ipAddress;
    }

    /**
     * @param string $ipAddress
     * @return IpAddress
     */
    public function setIpAddress(string $ipAddress): IpAddress
    {
        $this->ipAddress = $ipAddress;
        return $this;
    }

    /**
     * @return string
     */
    public function getNetmask(): string
    {
        return $this->netmask;
    }

    /**
     * @param string $netmask
     * @return IpAddress
     */
    public function setNetmask(string $netmask): IpAddress
    {
        $this->netmask = $netmask;
        return $this;
    }

    /**
     * @return string
     */
    public function getNic(): string
    {
        return $this->nic;
    }

    /**
     * @param string $nic
     * @return IpAddress
     */
    public function setNic(string $nic): IpAddress
    {
        $this->nic = $nic;
        return $this;
    }

    /**
     * @return string
     */
    public function getConfigMode(): string
    {
        return $this->configMode;
    }

    /**
     * @param string $configMode
     * @return IpAddress
     */
    public function setConfigMode(string $configMode): IpAddress
    {
        $this->configMode = $configMode;
        return $this;
    }
}
