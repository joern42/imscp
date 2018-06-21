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

namespace iMSCP\Model\Store;

/**
 * Class Service
 * @package iMSCP\Model\Store
 */
class Service
{
    /**
     * @var string
     */
    private $name;

    /**
     * @var string
     */
    private $protocol;

    /**
     * @var string
     */
    private $ipAddress;

    /**
     * @var int
     */
    private $port;

    /**
     * @var bool
     */
    private $isHidden;

    /**
     * Service constructor.
     *
     * @param string $name Service name
     * @param string $protocol Service protocol
     * @param string $ipAddress Service IP address
     * @param int $port Service Port
     * @param bool $isHidden Flag indicating whether or not the service is hidden
     */
    public function __construct(string $name, string $protocol, string $ipAddress, int $port, bool $isHidden = false)
    {
        // TODO validation

        $this->name = $name;
        $this->protocol = $protocol;
        $this->ipAddress = $ipAddress;
        $this->port = $port;
    }

    /**
     * Return service name
     *
     * @return string
     */
    public function getName(): string
    {
        return $this->name;
    }

    /**
     * Set service name
     * @param string $name
     * @return Service
     */
    public function setName(string $name): Service
    {
        $this->name = $name;
        return $this;
    }

    /**
     * Return service protocol
     *
     * @return string
     */
    public function getProtocol(): string
    {
        return $this->protocol;
    }

    /**
     * Set service protocol
     *
     * @param string $protocol
     * @return Service
     */
    public function setProtocol(string $protocol): Service
    {
        $this->protocol = $protocol;
        return $this;
    }

    /**
     * Return service port
     *
     * @return int
     */
    public function getPort(): int
    {
        return $this->port;
    }

    /**
     * Set service port
     *
     * @param int $port
     * @return Service
     */
    public function setPort(int $port): Service
    {
        $this->port = $port;
        return $this;
    }

    /**
     * Return service IP address
     *
     * @return string
     */
    public function getIpAddress(): string
    {
        return $this->ipAddress;
    }

    /**
     * Set service IP address
     *
     * @param string $ipAddress
     * @return Service
     */
    public function setIpAddress(string $ipAddress): Service
    {
        $this->ipAddress = $ipAddress;
        return $this;
    }

    /**
     * Is the service hidden?
     *
     * @return bool
     */
    public function isHidden(): bool
    {
        return $this->isHidden;
    }

    /**
     * Set service visibility
     *
     * @param bool $isHidden
     * @return Service
     */
    public function setIsHidden(bool $isHidden): Service
    {
        $this->isHidden = $isHidden;
        return $this;
    }
}
