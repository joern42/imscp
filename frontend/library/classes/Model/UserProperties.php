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
 * Class UserProperties
 * @ORM\Entity
 * @ORM\Table(name="imscp_user_properties", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class UserProperties
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $clientPropertiesID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="datetime", nullable=true)
     * @var \DateTime|null
     */
    private $accountExpireDate = NULL;

    /**
     * @var ServerIpAddress[]
     */
    private $ipAddresses = [];

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $domainsLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $domainAliasesLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $subdomainsLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $mailboxesLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $mailQuotaLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $ftpUsersLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $sqlDatabasesLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $sqlDatabasesQuota = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $sqlUsersLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $monthlyTrafficLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $diskspaceLimit = 0;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $maxBackups = 0;

    /**
     * @var @ORM\Column(type="setbackup")
     * @var array
     */
    private $hasBackupTypes;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasPhp = false;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $hasPhpEditor = false;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $phpConfigLevel = 'site';

    /**
     * @var WebPhpEditorPermission[]
     */
    private $phpEditorPermissions;

    /**
     * @var WebPhpEditorLimit[]
     */
    private $phpEditorLimits;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasCgi = false;

    /**
     * @ORM\Column(type="boolean")
     * @var boolean
     */
    private $hasDns = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasDnsEditor = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasMailCatchall = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasMailExternalServer = false;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $hasProtectedArea = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasCustomErrorPages = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $hasSupportSystem = false;

    /**
     * @ORM\Column(type="boolean")
     * @var boolean
     */
    private $webFolderProtection = false;

    /**
     * @ORM\Column(type="boolean")
     * @var boolean
     */
    private $hasWebstats = false;

    /**
     * @return int
     */
    public function getClientPropertiesID(): int
    {
        return $this->clientPropertiesID;
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
     * @return UserProperties
     */
    public function setUser(User $user): UserProperties
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getAccountExpireDate(): ?\DateTime
    {
        return $this->accountExpireDate;
    }

    /**
     * @param \DateTime|null $accountExpireDate
     * @return UserProperties
     */
    public function setAccountExpireDate(\DateTime $accountExpireDate = NULL): UserProperties
    {
        $this->accountExpireDate = $accountExpireDate;
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
     * @return UserProperties
     */
    public function setIpAddresses(array $ipAddresses): UserProperties
    {
        $this->ipAddresses = $ipAddresses;
        return $this;
    }

    /**
     * @return int
     */
    public function getDomainsLimit(): int
    {
        return $this->domainsLimit;
    }

    /**
     * @param int $domainsLimit
     * @return UserProperties
     */
    public function setDomainsLimit(int $domainsLimit): UserProperties
    {
        $this->domainsLimit = $domainsLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getDomainAliasesLimit(): int
    {
        return $this->domainAliasesLimit;
    }

    /**
     * @param int $domainALiasesLimit
     * @return UserProperties
     */
    public function setDomainALiasesLimit(int $domainALiasesLimit): UserProperties
    {
        $this->domainAliasesLimit = $domainALiasesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSubdomainsLimit(): int
    {
        return $this->subdomainsLimit;
    }

    /**
     * @param int $subdomainsLimit
     * @return UserProperties
     */
    public function setSubdomainsLimit(int $subdomainsLimit): UserProperties
    {
        $this->subdomainsLimit = $subdomainsLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMailboxesLimit(): int
    {
        return $this->mailboxesLimit;
    }

    /**
     * @param int $mailboxesLimit
     * @return UserProperties
     */
    public function setMailboxesLimit(int $mailboxesLimit): UserProperties
    {
        $this->mailboxesLimit = $mailboxesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMailQuotaLimit(): int
    {
        return $this->mailQuotaLimit;
    }

    /**
     * @param int $mailQuotaLimit
     * @return UserProperties
     */
    public function setMailQuotaLimit(int $mailQuotaLimit): UserProperties
    {
        $this->mailQuotaLimit = $mailQuotaLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getFtpUsersLimit(): int
    {
        return $this->ftpUsersLimit;
    }

    /**
     * @param int $ftpUsersLimit
     * @return UserProperties
     */
    public function setFtpUsersLimit(int $ftpUsersLimit): UserProperties
    {
        $this->ftpUsersLimit = $ftpUsersLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSqlDatabasesLimit(): int
    {
        return $this->sqlDatabasesLimit;
    }

    /**
     * @param int $sqlDatabasesLimit
     * @return UserProperties
     */
    public function setSqlDatabasesLimit(int $sqlDatabasesLimit): UserProperties
    {
        $this->sqlDatabasesLimit = $sqlDatabasesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSqlDatabasesQuota(): int
    {
        return $this->sqlDatabasesQuota;
    }

    /**
     * @param int $sqlDatabasesQuota
     * @return UserProperties
     */
    public function setSqlDatabasesQuota(int $sqlDatabasesQuota): UserProperties
    {
        $this->sqlDatabasesQuota = $sqlDatabasesQuota;
        return $this;
    }

    /**
     * @return int
     */
    public function getSqlUsersLimit(): int
    {
        return $this->sqlUsersLimit;
    }

    /**
     * @param int $sqlUsersLimit
     * @return UserProperties
     */
    public function setSqlUsersLimit(int $sqlUsersLimit): UserProperties
    {
        $this->sqlUsersLimit = $sqlUsersLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMonthlyTrafficLimit(): int
    {
        return $this->monthlyTrafficLimit;
    }

    /**
     * @param int $monthlyTrafficLimit
     * @return UserProperties
     */
    public function setMonthlyTrafficLimit(int $monthlyTrafficLimit): UserProperties
    {
        $this->monthlyTrafficLimit = $monthlyTrafficLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getDiskspaceLimit(): int
    {
        return $this->diskspaceLimit;
    }

    /**
     * @param int $diskspaceLimit
     * @return UserProperties
     */
    public function setDiskspaceLimit(int $diskspaceLimit): UserProperties
    {
        $this->diskspaceLimit = $diskspaceLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMaxBackups(): int
    {
        return $this->maxBackups;
    }

    /**
     * @param int $maxBackups
     * @return UserProperties
     */
    public function setMaxBackups(int $maxBackups): UserProperties
    {
        $this->maxBackups = $maxBackups;
        return $this;
    }

    /**
     * @return mixed
     */
    public function getHasBackupTypes()
    {
        return $this->hasBackupTypes;
    }

    /**
     * @param mixed $hasBackupTypes
     * @return UserProperties
     */
    public function setHasBackupTypes($hasBackupTypes)
    {
        $this->hasBackupTypes = $hasBackupTypes;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasPhp(): bool
    {
        return $this->hasPhp;
    }

    /**
     * @param bool $hasPhp
     * @return UserProperties
     */
    public function setHasPhp(bool $hasPhp): UserProperties
    {
        $this->hasPhp = $hasPhp;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasPhpEditor(): bool
    {
        return $this->hasPhpEditor;
    }

    /**
     * @param bool $hasPhpEditor
     * @return UserProperties
     */
    public function setHasPhpEditor(bool $hasPhpEditor): UserProperties
    {
        $this->hasPhpEditor = $hasPhpEditor;
        return $this;
    }

    /**
     * @return string
     */
    public function getPhpConfigLevel(): string
    {
        return $this->phpConfigLevel;
    }

    /**
     * @param string $phpConfigLevel
     * @return UserProperties
     */
    public function setPhpConfigLevel(string $phpConfigLevel): UserProperties
    {
        $this->phpConfigLevel = $phpConfigLevel;
        return $this;
    }

    /**
     * @return WebPhpEditorPermission[]
     */
    public function getPhpEditorPermissions(): array
    {
        return $this->phpEditorPermissions;
    }

    /**
     * @param WebPhpEditorPermission[] $phpEditorPermissions
     * @return UserProperties
     */
    public function setPhpEditorPermissions(array $phpEditorPermissions): UserProperties
    {
        $this->phpEditorPermissions = $phpEditorPermissions;
        return $this;
    }

    /**
     * @return WebPhpEditorLimit[]
     */
    public function getPhpEditorLimits(): array
    {
        return $this->phpEditorLimits;
    }

    /**
     * @param WebPhpEditorLimit[] $phpEditorLimits
     * @return UserProperties
     */
    public function setPhpEditorLimits(array $phpEditorLimits): UserProperties
    {
        $this->phpEditorLimits = $phpEditorLimits;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasCgi(): bool
    {
        return $this->hasCgi;
    }

    /**
     * @param bool $hasCgi
     * @return UserProperties
     */
    public function setHasCgi(bool $hasCgi): UserProperties
    {
        $this->hasCgi = $hasCgi;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasDns(): bool
    {
        return $this->hasDns;
    }

    /**
     * @param bool $hasDns
     * @return UserProperties
     */
    public function setHasDns(bool $hasDns): UserProperties
    {
        $this->hasDns = $hasDns;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasDnsEditor(): bool
    {
        return $this->hasDnsEditor;
    }

    /**
     * @param bool $hasDnsEditor
     * @return UserProperties
     */
    public function setHasDnsEditor(bool $hasDnsEditor): UserProperties
    {
        $this->hasDnsEditor = $hasDnsEditor;
        return $this;
    }

    /**
     * @return bool
     */
    public function isHasMailCatchall(): bool
    {
        return $this->hasMailCatchall;
    }

    /**
     * @param bool $hasMailCatchall
     * @return UserProperties
     */
    public function setHasMailCatchall(bool $hasMailCatchall): UserProperties
    {
        $this->hasMailCatchall = $hasMailCatchall;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasMailExternalServer(): bool
    {
        return $this->hasMailExternalServer;
    }

    /**
     * @param bool $hasMailExternalServer
     * @return UserProperties
     */
    public function setHasMailExternalServer(bool $hasMailExternalServer): UserProperties
    {
        $this->hasMailExternalServer = $hasMailExternalServer;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasProtectedArea(): bool
    {
        return $this->hasProtectedArea;
    }

    /**
     * @param bool $hasProtectedArea
     * @return UserProperties
     */
    public function setHasProtectedArea(bool $hasProtectedArea): UserProperties
    {
        $this->hasProtectedArea = $hasProtectedArea;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasCustomErrorPages(): bool
    {
        return $this->hasCustomErrorPages;
    }

    /**
     * @param bool $hasCustomErrorPages
     * @return UserProperties
     */
    public function setHasCustomErrorPages(bool $hasCustomErrorPages): UserProperties
    {
        $this->hasCustomErrorPages = $hasCustomErrorPages;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasSupportSystem(): bool
    {
        return $this->hasSupportSystem;
    }

    /**
     * @param bool $hasSupportSystem
     * @return UserProperties
     */
    public function setHasSupportSystem(bool $hasSupportSystem): UserProperties
    {
        $this->hasSupportSystem = $hasSupportSystem;
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
     * @return UserProperties
     */
    public function setWebFolderProtection(bool $webFolderProtection): UserProperties
    {
        $this->webFolderProtection = $webFolderProtection;
        return $this;
    }

    /**
     * @return bool
     */
    public function getHasWebstats(): bool
    {
        return $this->hasWebstats;
    }

    /**
     * @param bool $hasWebstats
     * @return UserProperties
     */
    public function setHasWebstats(bool $hasWebstats): UserProperties
    {
        $this->hasWebstats = $hasWebstats;
        return $this;
    }
}
