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
 * Class WebDomain
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_domain", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebDomain 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webDomainID;

    /**
     * @var int
     */
    private $webDomainPID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $domainName;

    /**
     * @var ServerIpAddress[]
     */
    private $ipAddresses = [];

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasAutomaticDNS = true;

    /**
     * @var WebDomainAlias[]
     */
    private $domainAliases = [];

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasPHP = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasCGI = false;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $documentRoot = '/htdocs';

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string|null
     */
    private $forwardURL;

    /**
     * @ORM\Column(type="enumforwardtype", nullable=true)
     * @var string|null
     */
    private $forwardType;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $forwardKeepHost = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $webFolderProtection = true;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isActive = true;

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
     * @return User
     */
    public function getUser(): User
    {
        return $this->user;
    }

    /**
     * @param User $user
     * @return WebDomain
     */
    public function setUser(User $user): WebDomain
    {
        $this->user = $user;
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
     * @return bool
     */
    public function getHasAutomaticDNS(): bool
    {
        return $this->hasAutomaticDNS;
    }

    /**
     * @param bool $hasAutomaticDNS
     * @return WebDomain
     */
    public function setHasAutomaticDNS(bool $hasAutomaticDNS): WebDomain
    {
        $this->hasAutomaticDNS = $hasAutomaticDNS;
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
     * @return bool
     */
    public function getHasPHP(): bool
    {
        return $this->hasPHP;
    }

    /**
     * @param bool $hasPHP
     * @return WebDomain
     */
    public function setHasPHP(bool $hasPHP): WebDomain
    {
        $this->hasPHP = $hasPHP;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasCGI(): bool
    {
        return $this->hasCGI;
    }

    /**
     * @param bool $hasCGI
     * @return WebDomain
     */
    public function setHasCGI(bool $hasCGI): WebDomain
    {
        $this->hasCGI = $hasCGI;
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
     * @return bool
     */
    public function getForwardKeepHost(): bool
    {
        return $this->forwardKeepHost;
    }

    /**
     * @param bool $forwardKeepHost
     * @return WebDomain
     */
    public function setForwardKeepHost(bool $forwardKeepHost): WebDomain
    {
        $this->forwardKeepHost = $forwardKeepHost;
        return $this;
    }

    /**
     * @return bool
     */
    public function getWebFolderProtection(): bool
    {
        return $this->webFolderProtection;
    }

    /**
     * @param bool $webFolderProtection
     * @return WebDomain
     */
    public function setWebFolderProtection(bool $webFolderProtection): WebDomain
    {
        $this->webFolderProtection = $webFolderProtection;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsActive(): bool
    {
        return $this->isActive;
    }

    /**
     * @param bool $isActive
     * @return WebDomain
     */
    public function setIsActive(bool $isActive): WebDomain
    {
        $this->isActive = $isActive;
        return $this;
    }
}
