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
 * Class Server
 * @package iMSCP\Model
 */
class Server extends BaseModel
{
    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $description;

    /**
     * @var string
     */
    private $hostname;

    /**
     * @var string
     */
    private $type = 'host';

    /**
     * @var string
     */
    private $metadata;

    /**
     * @var string
     */
    private $hmacSharedSecret;

    /**
     * @var string
     */
    private $services = 'dns,ftp,http,mail,sql';

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @var string
     */
    private $apiVersion;

    /**
     * @return int
     */
    public function getServerID(): int
    {
        return $this->serverID;
    }

    /**
     * @param int $serverID
     * @return Server
     */
    public function setServerID(int $serverID): Server
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getDescription(): string
    {
        return $this->description;
    }

    /**
     * @param string $description
     * @return Server
     */
    public function setDescription(string $description): Server
    {
        $this->description = $description;
        return $this;
    }

    /**
     * @return string
     */
    public function getHostname(): string
    {
        return $this->hostname;
    }

    /**
     * @param string $hostname
     * @return Server
     */
    public function setHostname(string $hostname): Server
    {
        $this->hostname = $hostname;
        return $this;
    }

    /**
     * @return string
     */
    public function getType(): string
    {
        return $this->type;
    }

    /**
     * @param string $type
     * @return Server
     */
    public function setType(string $type): Server
    {
        $this->type = $type;
        return $this;
    }

    /**
     * @return string
     */
    public function getMetadata(): string
    {
        return $this->metadata;
    }

    /**
     * @param string $metadata
     * @return Server
     */
    public function setMetadata(string $metadata): Server
    {
        $this->metadata = $metadata;
        return $this;
    }

    /**
     * @return string
     */
    public function getHmacSharedSecret(): string
    {
        return $this->hmacSharedSecret;
    }

    /**
     * @param string $hmacSharedSecret
     * @return Server
     */
    public function setHmacSharedSecret(string $hmacSharedSecret): Server
    {
        $this->hmacSharedSecret = $hmacSharedSecret;
        return $this;
    }

    /**
     * @return string
     */
    public function getServices(): string
    {
        return $this->services;
    }

    /**
     * @param string $services
     * @return Server
     */
    public function setServices(string $services): Server
    {
        $this->services = $services;
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
     * @return Server
     */
    public function setIsActive(int $isActive): Server
    {
        $this->isActive = $isActive;
        return $this;
    }

    /**
     * @return string
     */
    public function getApiVersion(): string
    {
        return $this->apiVersion;
    }

    /**
     * @param string $apiVersion
     * @return Server
     */
    public function setApiVersion(string $apiVersion): Server
    {
        $this->apiVersion = $apiVersion;
        return $this;
    }
}
