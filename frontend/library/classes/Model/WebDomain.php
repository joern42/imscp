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
 * Class WebDomain
 * @package iMSCP\Model
 */
class WebDomain extends BaseModel
{
    /**
     * @var int
     */
    private $webDomainID;

    /**
     * @var int
     */
    private $webDomainPID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var string
     */
    private $domainName;

    /**
     * @var ServerIpAddress[]
     */
    private $ipAddresses = [];

    /**
     * @var int
     */
    private $automaticDNS = 1;

    /**
     * @var WebDomainAlias[]
     */
    private $domainAliases = [];

    /**
     * @var int
     */
    private $php = 0;

    /**
     * @var int
     */
    private $cgi = 0;

    /**
     * @var string
     */
    private $documentRoot = '/htdocs';

    /**
     * @var string|null
     */
    private $forwardURL;

    /**
     * @var string|null
     */
    private $forwardType;

    /**
     * @var int
     */
    private $forwardKeepHost = 0;

    /**
     * @var int
     */
    private $webFolderProtection = 0;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getWebDomainID(): int
    {
        return $this->webDomainID;
    }

    /**
     * @param int $webDomainID
     * @return WebDomain
     */
    public function setWebDomainID(int $webDomainID): WebDomain
    {
        $this->webDomainID = $webDomainID;
        return $this;
    }

    /**
     * @return int
     */
    public function getWebDomainPID(): int
    {
        return $this->webDomainPID;
    }

    /**
     * @param int $webDomainPID
     * @return WebDomain
     */
    public function setWebDomainPID(int $webDomainPID): WebDomain
    {
        $this->webDomainPID = $webDomainPID;
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
     * @return WebDomain
     */
    public function setUserID(int $userID): WebDomain
    {
        $this->userID = $userID;
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
     * @return WebDomain
     */
    public function setDomainName(string $domainName): WebDomain
    {
        $this->domainName = $domainName;
        return $this;
    }

    /**
     * @return ServerIpAddress[]
     */
    public function getIpAddresses(): array
    {
        return $this->ipAddresses;
    }

    /**
     * @param ServerIpAddress[] $ipAddresses
     * @return WebDomain
     */
    public function setIpAddresses(array $ipAddresses): WebDomain
    {
        $this->ipAddresses = $ipAddresses;
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
     * @return WebDomain
     */
    public function setAutomaticDNS(string $automaticDNS): WebDomain
    {
        $this->automaticDNS = $automaticDNS;
        return $this;
    }

    /**
     * @return WebDomainAlias[]
     */
    public function getDomainAliases(): array
    {
        return $this->domainAliases;
    }

    /**
     * @param WebDomainAlias[] $domainAliases
     * @return WebDomain
     */
    public function setDomainAliases(array $domainAliases): WebDomain
    {
        $this->domainAliases = $domainAliases;
        return $this;
    }

    /**
     * @return int
     */
    public function getPhp(): int
    {
        return $this->php;
    }

    /**
     * @param int $php
     * @return WebDomain
     */
    public function setPhp(int $php): WebDomain
    {
        $this->php = $php;
        return $this;
    }

    /**
     * @return int
     */
    public function getCgi(): int
    {
        return $this->cgi;
    }

    /**
     * @param int $cgi
     * @return WebDomain
     */
    public function setCgi(int $cgi): WebDomain
    {
        $this->cgi = $cgi;
        return $this;
    }

    /**
     * @return string
     */
    public function getDocumentRoot(): string
    {
        return $this->documentRoot;
    }

    /**
     * @param string $documentRoot
     * @return WebDomain
     */
    public function setDocumentRoot(string $documentRoot): WebDomain
    {
        $this->documentRoot = $documentRoot;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getForwardURL(): ?string
    {
        return $this->forwardURL;
    }

    /**
     * @param string $forwardURL
     * @return WebDomain
     */
    public function setForwardURL(string $forwardURL = NULL): WebDomain
    {
        $this->forwardURL = $forwardURL;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getForwardType(): ?string
    {
        return $this->forwardType;
    }

    /**
     * @param string|null $forwardType
     * @return WebDomain
     */
    public function setForwardType(string $forwardType = NULL): WebDomain
    {
        $this->forwardType = $forwardType;
        return $this;
    }

    /**
     * @return int
     */
    public function getForwardKeepHost(): int
    {
        return $this->forwardKeepHost;
    }

    /**
     * @param int $forwardKeepHost
     * @return WebDomain
     */
    public function setForwardKeepHost(int $forwardKeepHost): WebDomain
    {
        $this->forwardKeepHost = $forwardKeepHost;
        return $this;
    }

    /**
     * @return int
     */
    public function getWebFolderProtection(): int
    {
        return $this->webFolderProtection;
    }

    /**
     * @param int $webFolderProtection
     * @return WebDomain
     */
    public function setWebFolderProtection(int $webFolderProtection): WebDomain
    {
        $this->webFolderProtection = $webFolderProtection;
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
     * @return WebDomain
     */
    public function setIsActive(int $isActive): WebDomain
    {
        $this->isActive = $isActive;
        return $this;
    }
}
