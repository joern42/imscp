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
use iMSCP\Application;
use iMSCP\Net;

/**
 * Class CpMonitoredService
 * @package iMSCP\Model\Service
 * @ORM\Entity
 * @ORM\Table(name="imscp_monitored_service", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @ORM\ChangeTrackingPolicy("DEFERRED_EXPLICIT")
 */
class CpMonitoredService
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $monitoredServiceID;

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
    private $name;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $protocol;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $address;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $port;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $isActive = true;

    /**
     * Service constructor.
     *
     * @param Server $server
     * @param string $name Service name
     * @param string $protocol Service protocol
     * @param string $ipAddress Service IP address or hostname
     * @param int $port Service Port
     */
    public function __construct(Server $server, string $name, string $protocol, string $ipAddress, int $port)
    {
        $this->name = $name;
        $this->protocol = $protocol;
        $this->address = $ipAddress;
        $this->port = $port;
    }

    /**
     * Get monitored service ID
     *
     * @return int
     */
    public function getMonitoredServiceID()
    {
        return $this->monitoredServiceID;
    }

    /**
     * Get server
     *
     * @return Server
     */
    public function getServer(): Server
    {
        return $this->server;
    }

    /**
     * Set server
     * @param Server $server
     * @return $this
     */
    public function setServer(Server $server)
    {
        $this->server = $server;
        return $this;
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
     * @return CpMonitoredService
     */
    public function setName(string $name): CpMonitoredService
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
     * @return CpMonitoredService
     */
    public function setProtocol(string $protocol): CpMonitoredService
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
     * @return CpMonitoredService
     */
    public function setPort(int $port): CpMonitoredService
    {
        $this->port = $port;
        return $this;
    }

    /**
     * Return service address
     *
     * @return string
     */
    public function getAddress(): string
    {
        return $this->address;
    }

    /**
     * Set service IP address
     *
     * @param string $address
     * @return CpMonitoredService
     */
    public function setAddress(string $address): CpMonitoredService
    {
        $this->address = $address;
        return $this;
    }

    /**
     * Is the monitoring active for that service?
     *
     * @return bool
     */
    public function isActive(): bool
    {
        return $this->isActive;
    }

    /**
     * Set service visibility
     *
     * @param bool $isActive
     * @return CpMonitoredService
     */
    public function setActive(bool $isActive): CpMonitoredService
    {
        $this->isActive = (int)$isActive;
        return $this;
    }

    /**
     * Is this service running?
     *
     * @param bool $forceRefresh
     * @return bool
     */
    public function isRunning($forceRefresh = false)
    {
        $cache = Application::getInstance()->getCache();
        $identifier = spl_object_hash($this);

        if ($forceRefresh || !$cache->hasItem($identifier)) {
            $ip = $this->getAddress();
            if (Net::getVersion($ip) == 6) {
                $ip = '[' . $ip . ']';
            }

            $isRunning = false;
            if (($fp = @fsockopen($this->getProtocol() . '://' . $ip, $this->getPort(), $errno, $errstr, 5))) {
                fclose($fp);
                $isRunning = true;
            }

            // A bit messy... See https://github.com/zendframework/zendframework/pull/5386
            $ttl = $cache->getOptions()->getTtl();
            $cache->getOptions()->setTtl(300);
            $cache->setItem($identifier, $isRunning);
            $cache->getOptions()->setTtl($ttl);
        } else {
            $isRunning = $cache->getItem($identifier);
        }

        return $isRunning;
    }
}
