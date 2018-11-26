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
 * Class DnsZone
 * @ORM\Entity
 * @ORM\Table(name="imscp_dns_zone", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class DnsZone 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $dnsZoneID;

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
    private $zoneType = 'master';
    
    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $zoneTTL = 10800;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $origin;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $name = '@';

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $class = 'IN';

    /**
     * @ORM\Column(type="string")
     * @var int string
     */
    private $mname;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $rname;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $serial;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $refresh = 10800;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $retry = 3600;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $expire = 1209600;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $ttl = 3600;

    /**
     * @ORM\Column(type="boolean")
     * @var bool 
     */
    private $isActive = true;

    /**
     * @return int
     */
    public function getDnsZoneID(): int
    {
        return $this->dnsZoneID;
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
     * @return DnsZone
     */
    public function setUser(User $user): DnsZone
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
     * @return DnsZone
     */
    public function setServer(Server $server): DnsZone
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return string
     */
    public function getZoneType(): string
    {
        return $this->zoneType;
    }

    /**
     * @param string $zoneType
     * @return DnsZone
     */
    public function setZoneType(string $zoneType): DnsZone
    {
        $this->zoneType = $zoneType;
        return $this;
    }

    /**
     * @return int
     */
    public function getZoneTTL(): int
    {
        return $this->zoneTTL;
    }

    /**
     * @param int $zoneTTL
     * @return DnsZone
     */
    public function setZoneTTL(int $zoneTTL): DnsZone
    {
        $this->zoneTTL = $zoneTTL;
        return $this;
    }

    /**
     * @return string
     */
    public function getOrigin(): string
    {
        return $this->origin;
    }

    /**
     * @param string $origin
     * @return DnsZone
     */
    public function setOrigin(string $origin): DnsZone
    {
        $this->origin = $origin;
        return $this;
    }

    /**
     * @return string
     */
    public function getName(): string
    {
        return $this->name;
    }

    /**
     * @param string $name
     * @return DnsZone
     */
    public function setName(string $name): DnsZone
    {
        $this->name = $name;
        return $this;
    }

    /**
     * @return string
     */
    public function getClass(): string
    {
        return $this->class;
    }

    /**
     * @param string $class
     * @return DnsZone
     */
    public function setClass(string $class): DnsZone
    {
        $this->class = $class;
        return $this;
    }

    /**
     * @return int
     */
    public function getMname(): int
    {
        return $this->mname;
    }

    /**
     * @param int $mname
     * @return DnsZone
     */
    public function setMname(int $mname): DnsZone
    {
        $this->mname = $mname;
        return $this;
    }

    /**
     * @return string
     */
    public function getRname(): string
    {
        return $this->rname;
    }

    /**
     * @param string $rname
     * @return DnsZone
     */
    public function setRname(string $rname): DnsZone
    {
        $this->rname = $rname;
        return $this;
    }

    /**
     * @return int
     */
    public function getSerial(): int
    {
        return $this->serial;
    }

    /**
     * @param int $serial
     * @return DnsZone
     */
    public function setSerial(int $serial): DnsZone
    {
        $this->serial = $serial;
        return $this;
    }

    /**
     * @return int
     */
    public function getRefresh(): int
    {
        return $this->refresh;
    }

    /**
     * @param int $refresh
     * @return DnsZone
     */
    public function setRefresh(int $refresh): DnsZone
    {
        $this->refresh = $refresh;
        return $this;
    }

    /**
     * @return int
     */
    public function getRetry(): int
    {
        return $this->retry;
    }

    /**
     * @param int $retry
     * @return DnsZone
     */
    public function setRetry(int $retry): DnsZone
    {
        $this->retry = $retry;
        return $this;
    }

    /**
     * @return int
     */
    public function getExpire(): int
    {
        return $this->expire;
    }

    /**
     * @param int $expire
     * @return DnsZone
     */
    public function setExpire(int $expire): DnsZone
    {
        $this->expire = $expire;
        return $this;
    }

    /**
     * @return int
     */
    public function getTtl(): int
    {
        return $this->ttl;
    }

    /**
     * @param int $ttl
     * @return DnsZone
     */
    public function setTtl(int $ttl): DnsZone
    {
        $this->ttl = $ttl;
        return $this;
    }

    /**
     * @return int
     */
    public function getisActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return DnsZone
     */
    public function setIsActive(int $isActive): DnsZone
    {
        $this->isActive = $isActive;
        return $this;
    }
}
