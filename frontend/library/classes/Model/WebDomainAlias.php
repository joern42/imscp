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
 * Class WebDomainAlias
 * @package iMSCP\Model
 */
class WebDomainAlias extends BaseModel
{
    /**
     * @var int
     */
    private $webDomainAliasId;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var string
     */
    private $domainAliasName;

    /**
     * @var int
     */
    private $automaticDNS = 1;

    /**
     * @return int
     */
    public function getWebDomainAliasId(): int
    {
        return $this->webDomainAliasId;
    }

    /**
     * @param int $webDomainAliasId
     * @return WebDomainAlias
     */
    public function setWebDomainAliasId(int $webDomainAliasId): WebDomainAlias
    {
        $this->webDomainAliasId = $webDomainAliasId;
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
     * @return WebDomainAlias
     */
    public function setUserID(int $userID): WebDomainAlias
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return string
     */
    public function getDomainAliasName(): string
    {
        return $this->domainAliasName;
    }

    /**
     * @param string $domainAliasName
     * @return WebDomainAlias
     */
    public function setDomainAliasName(string $domainAliasName): WebDomainAlias
    {
        $this->domainAliasName = $domainAliasName;
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
     * @param int $automaticDNS
     * @return WebDomainAlias
     */
    public function setAutomaticDNS(int $automaticDNS): WebDomainAlias
    {
        $this->automaticDNS = $automaticDNS;
        return $this;
    }
}
