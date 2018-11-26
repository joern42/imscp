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
 * Class ServerIpAddress
 * @ORM\Entity
 * @ORM\Table(name="imscp_server_ip_address", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class ServerIpAddress 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $serverIpAddressID;

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
    private $ipAddress;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $netmask;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $nic;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $configMode = 'manual';

    /**
     * @return int
     */
    public function getServerIpAddressID(): int
    {
        return $this->serverIpAddressID;
    }

    /**
     * @param int $serverIpAddressID
     * @return ServerIpAddress
     */
    public function setServerIpAddressID(int $serverIpAddressID): ServerIpAddress
    {
        $this->serverIpAddressID = $serverIpAddressID;
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
     * @return ServerIpAddress
     */
    public function setServer(Server $server): ServerIpAddress
    {
        $this->server = $server;
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
     * @return ServerIpAddress
     */
    public function setIpAddress(string $ipAddress): ServerIpAddress
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
     * @return ServerIpAddress
     */
    public function setNetmask(string $netmask): ServerIpAddress
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
     * @return ServerIpAddress
     */
    public function setNic(string $nic): ServerIpAddress
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
     * @return ServerIpAddress
     */
    public function setConfigMode(string $configMode): ServerIpAddress
    {
        $this->configMode = $configMode;
        return $this;
    }
}
