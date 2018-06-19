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
 * Class ResellerProperties
 * @package iMSCP\Model
 */
class ResellerProperties extends BaseModel
{
    /**
     * @var int
     */
    private $resellerPropertiesID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var IpAddress[]
     */
    private $ipAddresses = [];

    /**
     * @var int
     */
    private $domainsLimit = 0;

    /**
     * @var int
     */
    private $domainsAssigned = 0;

    /**
     * @var int
     */
    private $domainAliasesLimit = 0;

    /**
     * @var int
     */
    private $domainAliasesAssigned = 0;

    /**
     * @var int
     */
    private $subdomainsLimit = 0;

    /**
     * @var int
     */
    private $subdomainsAssigned = 0;

    /**
     * @var int
     */
    private $mailboxesLimit = 0;

    /**
     * @var int
     */
    private $mailaccountsAssigned = 0;

    /**
     * @var int
     */
    private $ftpUsersLimit = 0;

    /**
     * @var int
     */
    private $ftpUsersAssigned = 0;

    /**
     * @var int
     */
    private $sqlDatabasesLimit = 0;

    /**
     * @var int
     */
    private $sqlDatabasesAssigned = 0;

    /**
     * @var int
     */
    private $sqlUsersLimit = 0;

    /**
     * @var int
     */
    private $sqlUsersAssigned = 0;

    /**
     * @var int
     */
    private $diskspaceLimit = 0;

    /**
     * @var int
     */
    private $diskspaceAssigned = 0;

    /**
     * @var int
     */
    private $monthlyTrafficLimit = 0;

    /**
     * @var int
     */
    private $monthlyTrafficAssigned = 0;

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
    private $phpEditorPermissions = [];

    /**
     * @var UserPhpEditorLimit[]
     */
    private $phpEditorLimits = [];

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
     * @var int
     */
    private $supportSystem = 0;

    /**
     * @var int
     */
    private $backup = 0;

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
    private $webFolderProtection = 0;

    /**
     * @var int
     */
    private $webstats = 0;

    /**
     * @return int
     */
    public function getResellerPropertiesID(): int
    {
        return $this->resellerPropertiesID;
    }

    /**
     * @param int $resellerPropertiesID
     * @return ResellerProperties
     */
    public function setResellerPropertiesID(int $resellerPropertiesID): ResellerProperties
    {
        $this->resellerPropertiesID = $resellerPropertiesID;
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
     * @return ResellerProperties
     */
    public function setUserID(int $userID): ResellerProperties
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return IpAddress[]
     */
    public function getIpAddresses(): array
    {
        return $this->ipAddresses;
    }

    /**
     * @param IpAddress[] $ipAddresses
     * @return ResellerProperties
     */
    public function setIpAddresses(array $ipAddresses): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setDomainsLimit(int $domainsLimit): ResellerProperties
    {
        $this->domainsLimit = $domainsLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getDomainsAssigned(): int
    {
        return $this->domainsAssigned;
    }

    /**
     * @param int $domainsAssigned
     * @return ResellerProperties
     */
    public function setDomainsAssigned(int $domainsAssigned): ResellerProperties
    {
        $this->domainsAssigned = $domainsAssigned;
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
     * @return ResellerProperties
     */
    public function setSubdomainsLimit(int $subdomainsLimit): ResellerProperties
    {
        $this->subdomainsLimit = $subdomainsLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSubdomainsAssigned(): int
    {
        return $this->subdomainsAssigned;
    }

    /**
     * @param int $subdomainsAssigned
     * @return ResellerProperties
     */
    public function setSubdomainsAssigned(int $subdomainsAssigned): ResellerProperties
    {
        $this->subdomainsAssigned = $subdomainsAssigned;
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
     * @param int $domainAliasesLimit
     * @return ResellerProperties
     */
    public function setDomainAliasesLimit(int $domainAliasesLimit): ResellerProperties
    {
        $this->domainAliasesLimit = $domainAliasesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getDomainAliasesAssigned(): int
    {
        return $this->domainAliasesAssigned;
    }

    /**
     * @param int $domainAliasesAssigned
     * @return ResellerProperties
     */
    public function setDomainAliasesAssigned(int $domainAliasesAssigned): ResellerProperties
    {
        $this->domainAliasesAssigned = $domainAliasesAssigned;
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
     * @return ResellerProperties
     */
    public function setMailboxesLimit(int $mailboxesLimit): ResellerProperties
    {
        $this->mailboxesLimit = $mailboxesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMailaccountsAssigned(): int
    {
        return $this->mailaccountsAssigned;
    }

    /**
     * @param int $mailaccountsAssigned
     * @return ResellerProperties
     */
    public function setMailaccountsAssigned(int $mailaccountsAssigned): ResellerProperties
    {
        $this->mailaccountsAssigned = $mailaccountsAssigned;
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
     * @return ResellerProperties
     */
    public function setFtpUsersLimit(int $ftpUsersLimit): ResellerProperties
    {
        $this->ftpUsersLimit = $ftpUsersLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getFtpUsersAssigned(): int
    {
        return $this->ftpUsersAssigned;
    }

    /**
     * @param int $ftpUsersAssigned
     * @return ResellerProperties
     */
    public function setFtpUsersAssigned(int $ftpUsersAssigned): ResellerProperties
    {
        $this->ftpUsersAssigned = $ftpUsersAssigned;
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
     * @return ResellerProperties
     */
    public function setSqlDatabasesLimit(int $sqlDatabasesLimit): ResellerProperties
    {
        $this->sqlDatabasesLimit = $sqlDatabasesLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSqlDatabasesAssigned(): int
    {
        return $this->sqlDatabasesAssigned;
    }

    /**
     * @param int $sqlDatabasesAssigned
     * @return ResellerProperties
     */
    public function setSqlDatabasesAssigned(int $sqlDatabasesAssigned): ResellerProperties
    {
        $this->sqlDatabasesAssigned = $sqlDatabasesAssigned;
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
     * @return ResellerProperties
     */
    public function setSqlUsersLimit(int $sqlUsersLimit): ResellerProperties
    {
        $this->sqlUsersLimit = $sqlUsersLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getSqlUsersAssigned(): int
    {
        return $this->sqlUsersAssigned;
    }

    /**
     * @param int $sqlUsersAssigned
     * @return ResellerProperties
     */
    public function setSqlUsersAssigned(int $sqlUsersAssigned): ResellerProperties
    {
        $this->sqlUsersAssigned = $sqlUsersAssigned;
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
     * @return ResellerProperties
     */
    public function setDiskspaceLimit(int $diskspaceLimit): ResellerProperties
    {
        $this->diskspaceLimit = $diskspaceLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getDiskspaceAssigned(): int
    {
        return $this->diskspaceAssigned;
    }

    /**
     * @param int $diskspaceAssigned
     * @return ResellerProperties
     */
    public function setDiskspaceAssigned(int $diskspaceAssigned): ResellerProperties
    {
        $this->diskspaceAssigned = $diskspaceAssigned;
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
     * @return ResellerProperties
     */
    public function setMonthlyTrafficLimit(int $monthlyTrafficLimit): ResellerProperties
    {
        $this->monthlyTrafficLimit = $monthlyTrafficLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getMonthlyTrafficAssigned(): int
    {
        return $this->monthlyTrafficAssigned;
    }

    /**
     * @param int $monthlyTrafficAssigned
     * @return ResellerProperties
     */
    public function setMonthlyTrafficAssigned(int $monthlyTrafficAssigned): ResellerProperties
    {
        $this->monthlyTrafficAssigned = $monthlyTrafficAssigned;
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
     * @return ResellerProperties
     */
    public function setPhp(int $php): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setPhpEditor(int $phpEditor): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setPhpConfigLevel(string $phpConfigLevel): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setPhpEditorPermissions(array $phpEditorPermissions): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setPhpEditorLimits(array $phpEditorLimits): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setCgi(int $cgi): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setDns(int $dns): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setDnsEditor(int $dnsEditor): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setExternalMailServer(int $externalMailServer): ResellerProperties
    {
        $this->externalMailServer = $externalMailServer;
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
     * @return ResellerProperties
     */
    public function setSupportSystem(int $supportSystem): ResellerProperties
    {
        $this->supportSystem = $supportSystem;
        return $this;
    }

    /**
     * @return int
     */
    public function getBackup(): int
    {
        return $this->backup;
    }

    /**
     * @param int $backup
     * @return ResellerProperties
     */
    public function setBackup(int $backup): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setProtectedArea(int $protectedArea): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setCustomErrorPages(int $customErrorPages): ResellerProperties
    {
        $this->customErrorPages = $customErrorPages;
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
     * @return ResellerProperties
     */
    public function setWebFolderProtection(int $webFolderProtection): ResellerProperties
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
     * @return ResellerProperties
     */
    public function setWebstats(int $webstats): ResellerProperties
    {
        $this->webstats = $webstats;
        return $this;
    }
}
