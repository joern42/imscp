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
 * Class MailDomain
 * @package iMSCP\Model
 */
class MailDomain extends BaseModel
{
    /**
     * @var int
     */
    private $mailDomainID;

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
    private $domainName;

    /**
     * @var int
     */
    private $automaticDNS = 1;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getMailDomainID(): int
    {
        return $this->mailDomainID;
    }

    /**
     * @param int $mailDomainID
     * @return MailDomain
     */
    public function setMailDomainID(int $mailDomainID): MailDomain
    {
        $this->mailDomainID = $mailDomainID;
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
     * @return MailDomain
     */
    public function setUserID(int $userID): MailDomain
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
     * @return MailDomain
     */
    public function setServerID(int $serverID): MailDomain
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getDomainName(): string
    {
        return $this->domainName;
    }

    /**
     * @param string $domainName
     * @return MailDomain
     */
    public function setDomainName(string $domainName): MailDomain
    {
        $this->domainName = $domainName;
        return $this;
    }

    /**
     * @return int
     */
    public function getAutomaticDNS(): int
    {
        return $this->automaticDNS;
    }

    /**
     * @param string $automaticDNS
     * @return MailDomain
     */
    public function setAutomaticDNS(string $automaticDNS): MailDomain
    {
        $this->automaticDNS = $automaticDNS;
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
     * @return MailDomain
     */
    public function setIsActive(int $isActive): MailDomain
    {
        $this->isActive = $isActive;
        return $this;
    }
}
