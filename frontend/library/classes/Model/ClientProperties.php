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
 * Class ClientProperties
 * @package iMSCP\Model
 */
class ClientProperties extends BaseModel
{
    /**
     * @var int
     */
    private $clientPropertiesID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var \DateTimeImmutable|null
     */
    private $accountExpireDate = NULL;

    /**
     * @var ServerIpAddress[]
     */
    private $ipAddresses = [];

    /**
     * @var int
     */
    private $domainsLimit = 0;

    /**
     * @var int
     */
    private $domainAliasesLimit = 0;

    /**
     * @var int
     */
    private $subdomainsLimit = 0;

    /**
     * @var int
     */
    private $mailboxesLimit = 0;

    /**
     * @var int
     */
    private $mailQuotaLimit = 0;

    /**
     * @var int
     */
    private $ftpUsersLimit = 0;

    /**
     * @var int
     */
    private $sqlDatabasesLimit = 0;

    /**
     * @var int
     */
    private $sqlUsersLimit = 0;

    /**
     * @var int
     */
    private $monthlyTrafficLimit = 0;

    /**
     * @var int
     */
    private $diskspaceLimit = 0;

    /**
     * @var int
     */
    private $php = 0;

    /**
     * @var int
     */
    private $phpEditor = 0;

    /**
     * @var string
     */
    private $phpConfigLevel = 'site';

    /**
     * @var UserPhpEditorPermission[]
     */
    private $phpEditorPermissions;

    /**
     * @var UserPhpEditorLimit[]
     */
    private $phpEditorLimits;

    /**
     * @var int
     */
    private $cgi = 0;

    /**
     * @var int
     */
    private $dns = 0;

    /**
     * @var int
     */
    private $dnsEditor = 0;

    /**
     * @var int
     */
    private $externalMailServer = 0;

    /**
     * @var string|null
     */
    private $backup;

    /**
     * @var int
     */
    private $protectedArea = 0;

    /**
     * @var int
     */
    private $customErrorPages = 0;

    /**
     * @var int
     */
    private $supportSystem = 1;

    /**
     * @var int
     */
    private $webFolderProtection = 1;

    /**
     * @var int
     */
    private $webstats = 0;

    /**
     * @return int
     */
    public function getClientPropertiesID(): int
    {
        return $this->clientPropertiesID;
    }

    /**
     * @param int $clientPropertiesID
     * @return ClientProperties
     */
    public function setClientPropertiesID(int $clientPropertiesID): ClientProperties
    {
        $this->clientPropertiesID = $clientPropertiesID;
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
     * @return ClientProperties
     */
    public function setUserID(int $userID): ClientProperties
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getAccountExpireDate(): ?\DateTimeImmutable
    {
        return $this->accountExpireDate;
    }

    /**
     * @param \DateTimeImmutable|null $accountExpireDate
     * @return ClientProperties
     */
    public function setAccountExpireDate(\DateTimeImmutable $accountExpireDate = NULL): ClientProperties
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
     * @return ClientProperties
     */
    public function setIpAddresses(array $ipAddresses): ClientProperties
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
     * @return ClientProperties
     */
    public function setDomainsLimit(int $domainsLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setDomainALiasesLimit(int $domainALiasesLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setSubdomainsLimit(int $subdomainsLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setMailboxesLimit(int $mailboxesLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setMailQuotaLimit(int $mailQuotaLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setFtpUsersLimit(int $ftpUsersLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setSqlDatabasesLimit(int $sqlDatabasesLimit): ClientProperties
    {
        $this->sqlDatabasesLimit = $sqlDatabasesLimit;
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
     * @return ClientProperties
     */
    public function setSqlUsersLimit(int $sqlUsersLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setMonthlyTrafficLimit(int $monthlyTrafficLimit): ClientProperties
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
     * @return ClientProperties
     */
    public function setDiskspaceLimit(int $diskspaceLimit): ClientProperties
    {
        $this->diskspaceLimit = $diskspaceLimit;
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
     * @return ClientProperties
     */
    public function setPhp(int $php): ClientProperties
    {
        $this->php = $php;
        return $this;
    }

    /**
     * @return int
     */
    public function getPhpEditor(): int
    {
        return $this->phpEditor;
    }

    /**
     * @param int $phpEditor
     * @return ClientProperties
     */
    public function setPhpEditor(int $phpEditor): ClientProperties
    {
        $this->phpEditor = $phpEditor;
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
     * @return ClientProperties
     */
    public function setPhpConfigLevel(string $phpConfigLevel): ClientProperties
    {
        $this->phpConfigLevel = $phpConfigLevel;
        return $this;
    }

    /**
     * @return UserPhpEditorPermission[]
     */
    public function getPhpEditorPermissions(): array
    {
        return $this->phpEditorPermissions;
    }

    /**
     * @param UserPhpEditorPermission[] $phpEditorPermissions
     * @return ClientProperties
     */
    public function setPhpEditorPermissions(array $phpEditorPermissions): ClientProperties
    {
        $this->phpEditorPermissions = $phpEditorPermissions;
        return $this;
    }

    /**
     * @return UserPhpEditorLimit[]
     */
    public function getPhpEditorLimits(): array
    {
        return $this->phpEditorLimits;
    }

    /**
     * @param UserPhpEditorLimit[] $phpEditorLimits
     * @return ClientProperties
     */
    public function setPhpEditorLimits(array $phpEditorLimits): ClientProperties
    {
        $this->phpEditorLimits = $phpEditorLimits;
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
     * @return ClientProperties
     */
    public function setCgi(int $cgi): ClientProperties
    {
        $this->cgi = $cgi;
        return $this;
    }

    /**
     * @return int
     */
    public function getDns(): int
    {
        return $this->dns;
    }

    /**
     * @param int $dns
     * @return ClientProperties
     */
    public function setDns(int $dns): ClientProperties
    {
        $this->dns = $dns;
        return $this;
    }

    /**
     * @return int
     */
    public function getDnsEditor(): int
    {
        return $this->dnsEditor;
    }

    /**
     * @param int $dnsEditor
     * @return ClientProperties
     */
    public function setDnsEditor(int $dnsEditor): ClientProperties
    {
        $this->dnsEditor = $dnsEditor;
        return $this;
    }

    /**
     * @return int
     */
    public function getExternalMailServer(): int
    {
        return $this->externalMailServer;
    }

    /**
     * @param int $externalMailServer
     * @return ClientProperties
     */
    public function setExternalMailServer(int $externalMailServer): ClientProperties
    {
        $this->externalMailServer = $externalMailServer;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getBackup(): ?string
    {
        return $this->backup;
    }

    /**
     * @param string|null $backup
     * @return ClientProperties
     */
    public function setBackup(string $backup = NULL): ClientProperties
    {
        $this->backup = $backup;
        return $this;
    }

    /**
     * @return int
     */
    public function getProtectedArea(): int
    {
        return $this->protectedArea;
    }

    /**
     * @param int $protectedArea
     * @return ClientProperties
     */
    public function setProtectedArea(int $protectedArea): ClientProperties
    {
        $this->protectedArea = $protectedArea;
        return $this;
    }

    /**
     * @return int
     */
    public function getCustomErrorPages(): int
    {
        return $this->customErrorPages;
    }

    /**
     * @param int $customErrorPages
     * @return ClientProperties
     */
    public function setCustomErrorPages(int $customErrorPages): ClientProperties
    {
        $this->customErrorPages = $customErrorPages;
        return $this;
    }

    /**
     * @return int
     */
    public function getSupportSystem(): int
    {
        return $this->supportSystem;
    }

    /**
     * @param int $supportSystem
     * @return ClientProperties
     */
    public function setSupportSystem(int $supportSystem): ClientProperties
    {
        $this->supportSystem = $supportSystem;
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
     * @return ClientProperties
     */
    public function setWebFolderProtection(int $webFolderProtection): ClientProperties
    {
        $this->webFolderProtection = $webFolderProtection;
        return $this;
    }

    /**
     * @return int
     */
    public function getWebstats(): int
    {
        return $this->webstats;
    }

    /**
     * @param int $webstats
     * @return ClientProperties
     */
    public function setWebstats(int $webstats): ClientProperties
    {
        $this->webstats = $webstats;
        return $this;
    }
}
