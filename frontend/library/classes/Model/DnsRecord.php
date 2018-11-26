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
 * Class DnsRecord
 * @ORM\Entity
 * @ORM\Table(name="imscp_dns_record", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class DnsRecord
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $dnsRecordID;

    /**
     * @ORM\ManyToOne(targetEntity="DnsZone")
     * @ORM\JoinColumn(name="dnsZoneID", referencedColumnName="dnsZoneID", onDelete="CASCADE")
     * @var DnsZone
     */
    private $dnsZone;

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
    private $type;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $class;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $ttl = 3600;

    /**
     * @ORM\Column(type="text")
     * @var string
     */
    private $rdata;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $owner = 'core';

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isActive = true;

    /**
     * @return int
     */
    public function getDnsRecordID(): int
    {
        return $this->dnsRecordID;
    }

    /**
     * @return DnsZone
     */
    public function getDnsZone(): DnsZone
    {
        return $this->dnsZone;
    }

    /**
     * @param DnsZone $dnsZone
     * @return DnsRecord
     */
    public function setDnsZone(DnsZone $dnsZone): DnsRecord
    {
        $this->dnsZone = $dnsZone;
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
     * @return DnsRecord
     */
    public function setServer(Server $server): DnsRecord
    {
        $this->server = $server;
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
     * @return DnsRecord
     */
    public function setName(string $name): DnsRecord
    {
        $this->name = $name;
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
     * @return DnsRecord
     */
    public function setType(string $type): DnsRecord
    {
        $this->type = $type;
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
     * @return DnsRecord
     */
    public function setClass(string $class): DnsRecord
    {
        $this->class = $class;
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
     * @return DnsRecord
     */
    public function setTtl(int $ttl): DnsRecord
    {
        $this->ttl = $ttl;
        return $this;
    }

    /**
     * @return string
     */
    public function getRdata(): string
    {
        return $this->rdata;
    }

    /**
     * @param string $rdata
     * @return DnsRecord
     */
    public function setRdata(string $rdata): DnsRecord
    {
        $this->rdata = $rdata;
        return $this;
    }

    /**
     * @return string
     */
    public function getOwner(): string
    {
        return $this->owner;
    }

    /**
     * @param string $owner
     * @return DnsRecord
     */
    public function setOwner(string $owner): DnsRecord
    {
        $this->owner = $owner;
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
     * @return DnsRecord
     */
    public function setIsActive(int $isActive): DnsRecord
    {
        $this->isActive = $isActive;
        return $this;
    }
}
