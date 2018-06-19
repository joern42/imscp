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
 * Class DnsRecord
 * @package iMSCP\Model
 */
class DnsRecord extends BaseModel
{
    /**
     * @var int
     */
    private $dnsRecordID;

    /**
     * @var int
     */
    private $dnsZoneID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $name;

    /**
     * @var string
     */
    private $type;

    /**
     * @var string
     */
    private $class;

    /**
     * @var int
     */
    private $ttl = 3600;

    /**
     * @var string
     */
    private $rdata;

    /**
     * @var string
     */
    private $owner = 'core';

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getDnsRecordID(): int
    {
        return $this->dnsRecordID;
    }

    /**
     * @param int $dnsRecordID
     * @return DnsRecord
     */
    public function setDnsRecordID(int $dnsRecordID): DnsRecord
    {
        $this->dnsRecordID = $dnsRecordID;
        return $this;
    }

    /**
     * @return int
     */
    public function getDnsZoneID(): int
    {
        return $this->dnsZoneID;
    }

    /**
     * @param int $dnsZoneID
     * @return DnsRecord
     */
    public function setDnsZoneID(int $dnsZoneID): DnsRecord
    {
        $this->dnsZoneID = $dnsZoneID;
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
     * @return DnsRecord
     */
    public function setServerID(int $serverID): DnsRecord
    {
        $this->serverID = $serverID;
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
