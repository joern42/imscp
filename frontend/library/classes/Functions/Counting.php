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

namespace iMSCP\Functions;

use iMSCP\Application;

/**
 * Class Counting
 *
 * Provide counting and similar functions which return integer or boolean.
 *
 * @package iMSCP\Functions
 */
class Counting
{
    /**
     * Retrieve count of administrator accounts
     *
     * @return int Count of administrator accounts
     */
    public static function getAdministratorsCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_user', 'userID', "type = 'admin'");
        }

        return $count;
    }

    /**
     * Retrieve count of reseller accounts
     *
     * @return int Count of reseller accounts
     */
    public static function getResellersCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_user', 'userID', "type = 'reseller'");
        }

        return $count;
    }

    /**
     * Retrieve count of client accounts
     *
     * @return int Count of client accounts
     */
    public static function getClientsCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_user', 'userID', "type = 'client'");
        }

        return $count;
    }

    /**
     * Retrieve count of domains
     *
     * @return int Count of domains
     */
    public static function getDomainsCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_web_domain', 'webDomainID', 'webDomainPID IS NULL');
        }

        return $count;
    }

    /**
     * Retrieve count of subdomains
     *
     *
     * @return int Count of subdomains
     */
    public static function getSubdomainsCount(): int
    {
        $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_web_domain', 'webDomainID', 'webDomainPID IS NOT NULL');
        }

        return $count;
    }

    /**
     * Retrieve count of mail accounts
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @return int Count of mail accounts
     */
    public static function getMailAccountsCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount(
                'imscp_mailbox', 'mailboxID', !Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES'] ? "isDefault = '0'" : NULL
            );
        }

        return $count;
    }

    /**
     * Retrieve count of FTP users
     *
     * @return int Count of FTP users
     */
    public static function getFtpUsersCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_ftp_user', 'ftpUserID');
        }

        return $count;
    }

    /**
     * Retrieve count of SQL databases
     *
     * @return int Count of SQL databases;
     */
    public static function getSqlDatabasesCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_sql_database', 'sqlDatabaseID');
        }

        return $count;
    }

    /**
     * Retrieve count of SQL users
     *
     * @return int Count of SQL users
     */
    public static function getSqlUsersCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount('imscp_sql_user', 'sqlUserID');
        }

        return $count;
    }

    /**
     * Retrieve count of objects from the given table using the given identifier field and optional WHERE clause
     *
     * @param string $table
     * @param string $objectIDfield Object identifier field
     * @param string|NULL $where OPTIONAL WHERE clause
     * @return int Count of objects
     */
    public static function getObjectsCount(string $table, string $objectIDfield, string $where = NULL): int
    {
        $table = quoteIdentifier($table);
        $objectIDfield = quoteIdentifier($objectIDfield);

        return Application::getInstance()
            ->getDb()
            ->createStatement("SELECT COUNT($objectIDfield) AS objectsCount FROM $table" . (!is_null($where) ? "WHERE $where" : ''))
            ->execute()
            ->current()['objectsCount'];
    }

    /**
     * Retrieve count of administrators, resellers, clients, domains, subdomains, mail accounts, FTP users, SQL databases and SQL users
     *
     * @return array An array containing in order, count of administrators, resellers, clients, domains, subdomains, mail accounts, FTP users,
     * SQL databases and SQL users
     */
    public static function getObjectsCounts(): array
    {
        return [
            self::getAdministratorsCount(), self::getResellersCount(), self::getClientsCount(),
            self::getDomainsCount(), self::getSubdomainsCount(),
            self::getMailAccountsCount(), self::getFtpUsersCount(),
            self::getSqlDatabasesCount(), self::getSqlUsersCount()
        ];
    }

    /**
     * Retrieve count of client accounts that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of clients
     */
    public static function getResellerClientsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT COUNT(userID) AS usersCount FROM imscp_user WHERE createdBy = ?');
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['usersCount'];
    }

    /**
     * Retrieve count of web domains that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerDomainsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                '
                  SELECT COUNT(webDomainID) AS webDomainsCount
                  FROM imscp_web_domain
                  JOIN imscp_user USING(userID)
                  WHERE createdBy = ?
                  AND webDomainPID IS NULL
                '
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['webDomainsCount'];
    }

    /**
     * Retrieve count of subdomains that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerSubdomainsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                '
                  SELECT COUNT(webDomainID) AS subdomainsCount
                  FROM imscp_web_domain
                  JOIN imscp_user USING(userID)
                  WHERE createdBy = ?
                  AND webDomainPID IS NOT NULL
                '
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['subdomainsCount'];
    }

    /**
     * Retrieve count of mail accounts that belong to the given reseller
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @param int $resellerId Domain unique identifier
     * @return int Count of mail accounts
     */
    public static function getResellerMailAccountsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $query = 'SELECT COUNT(t1.mailboxID) AS mailboxesCount FROM imscp_mailbox AS t1 JOIN imscp_user AS t2 USING(userID) WHERE t2.createdBy = ?';
            $query .= !Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES'] ? " AND isDefault = '0'" : '';
            $stmt = Application::getInstance()->getDb()->createStatement($query);
            $stmt->prepare();
        }
        return $stmt->execute([$resellerId])->current()['mailboxesCount'];
    }

    /**
     * Retrieve count of FTP users that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of FTP users
     */
    public static function getResellerFtpUsersCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(ftpUserID) AS ftpUsersCount FROM imscp_ftp_user JOIN user USING(userID) WHERE createdBy = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['ftpUsersCount'];
    }

    /**
     * Retrieve count of SQL databases that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of SQL databases
     */
    public static function getResellerSqlDatabasesCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(sqlDatabaseID) AS sqlDatabasesCount FROM imscp_sql_database AS t1 JOIN admin AS t2 USING(userID) WHERE t2.createdBy = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['sqlDatabasesCount'];
    }

    /**
     * Retrieve count of SQL users that belong to the given reseller
     *
     * @param int $resellerId Domain unique identifier
     * @return int Count of SQL users
     */
    public static function getResellerSqlUsersCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(t1.sqlUserID) AS sqlUsersCount FROM imscp_sql_user AS t1 JOIN imscp_user AS t2 USING(userID) WHERE t2.createdBy = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->current()['sqlUsersCount'];
    }

    /**
     * Retrieve count of subdomains, domain aliases, mail accounts, FTP users, SQL database and SQL users that belong to the given reseller
     *
     * @param int $resellerId Client unique identifier
     * @return array An array containing count of clients, domains, subdomains, mail accounts, FTP users, SQL databases and SQL users
     */
    public static function getResellerObjectsCounts(int $resellerId): array
    {
        return [
            self::getResellerClientsCount($resellerId),
            self::getResellerDomainsCount($resellerId), self::getResellerSubdomainsCount($resellerId),
            self::getResellerMailAccountsCount($resellerId), self::getResellerFtpUsersCount($resellerId),
            self::getResellerSqlDatabasesCount($resellerId), self::getResellerSqlUsersCount($resellerId)
        ];
    }

    /**
     * Retrieve count of subdomains that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of domains
     */
    public static function getClientDomainsCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(webDomainID) FROM imscp_web_domain WHERE webDomainPID IS NULL AND userID = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of subdomains
     */
    public static function getClientSubdomainsCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(webDomainID) FROM imscp_web_domain WHERE webDomainPID IS NOT NULL AND userID = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of mail accounts that belong to the given client
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @param int $clientID Client unique identifier
     * @return int Count of mail accounts
     */
    public static function getClientMailAccountsCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $query = 'SELECT COUNT(mailboxID) FROM imscp_mailbox WHERE userID = ?';
            $query .= !Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES'] ? " AND isDefault = '0'" : '';
            $stmt = Application::getInstance()->getDb()->createStatement($query);
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of FTP users that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of FTP users
     */
    public static function getClientFtpUsersCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT COUNT(ftpUserID) FROM imscp_ftp_user WHERE userID = ?');
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of SQL databases that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of SQL databases
     */
    public static function getClientSqlDatabasesCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT COUNT(sqlDatabaseID) FROM imscp_sql_database WHERE userID = ?');
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of SQL users that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of SQL users
     */
    public static function getClientSqlUsersCount(int $clientID): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT COUNT(sqlUserID) FROM imscp_sql_user WHERE userID = ?');
            $stmt->prepare();
        }

        return $stmt->execute([$clientID])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains, mail accounts, FTP users, SQL database and SQL users that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return array An array containing count of subdomains, domain aliases, mail
     *               accounts, FTP users, SQL databases and SQL users
     */
    public static function getClientObjectsCounts(int $clientID): array
    {
        return [
            self::getClientDomainsCount($clientID), self::getClientSubdomainsCount($clientID),
            self::getClientMailAccountsCount($clientID), self::getClientFtpUsersCount($clientID),
            self::getClientSqlDatabasesCount($clientID), self::getClientSqlUsersCount($clientID)
        ];
    }

    /**
     * Whether or not the system has a least the given number of registered resellers
     *
     * @param int $minResellers Minimum number of resellers
     * @return bool TRUE if the system has a least the given number of registered resellers, FALSE otherwise
     */
    public static function systemHasResellers(int $minResellers = 1): bool
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = Application::getInstance()
                ->getDb()
                ->createStatement("SELECT COUNT(userID) AS usersCount FROM imscp_user WHERE type = 'reseller'")
                ->execute()
                ->current()['usersCount'];
        }

        return $count >= $minResellers;
    }

    /**
     * Whether or not the system has a least the given number of registered clients
     *
     * @param int $minClients Minimum number of clients
     * @return bool TRUE if system has a least the given number of registered clients, FALSE otherwise
     */
    public static function systemHasClients(int $minClients = 1): bool
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = Application::getInstance()
                ->getDb()
                ->createStatement("SELECT COUNT(userID) as usersCount FROM imscp_user WHERE type = 'client'")
                ->execute()
                ->current()['usersCount'];
        }

        return $count >= $minClients;
    }

    /**
     * Whether or not system has registered admins (many), resellers or clients
     *
     * @return bool
     */
    public static function systemHasAdminsOrResellersOrClients(): bool
    {
        return self::systemHasManyAdmins() || self::systemHasResellers() || self::systemHasClients();
    }

    /**
     * Whether or not system has registered resellers or clients
     *
     * @return bool
     */
    public static function systemHasResellersOrClients(): bool
    {
        return self::systemHasResellers() || self::systemHasClients();
    }

    /**
     * Whether or not system as many admins
     *
     * @return bool
     */
    public static function systemHasManyAdmins(): bool
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = Application::getInstance()
                ->getDb()
                ->createStatement("SELECT COUNT(userID) AS usersCount FROM imscp_user WHERE type = 'admin'")
                ->execute()
                ->current()['usersCount'];
        }

        return $count > 1;
    }

    /**
     * Whether or not system has anti-rootkits
     *
     * @return bool
     */
    public static function systemHasAntiRootkits(): bool
    {
        $config = $db = Application::getInstance()->getConfig();
        if ((isset($config['ANTIROOTKITS']) && $config['ANTIROOTKITS'] != 'no' && $config['ANTIROOTKITS'] != ''
                && ((isset($config['CHKROOTKIT_LOG']) && $config['CHKROOTKIT_LOG'] != '')
                    || (isset($config['RKHUNTER_LOG']) && $config['RKHUNTER_LOG'] != '')))
            || isset($config['OTHER_ROOTKIT_LOG']) && $config['OTHER_ROOTKIT_LOG'] != ''
        ) {
            return true;
        }

        return false;
    }

    /**
     * Whether or not the logged-in reseller has a least the given number of registered clients
     *
     * @param int $minClientsCount Minimum clients count
     * @return bool TRUE if the logged-in reseller has a least the given number of registered clients, FALSE otherwise
     */
    public static function resellerHasClients(int $minClientsCount = 1): bool
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = Application::getInstance()
                ->getDb()
                ->createStatement("SELECT COUNT(userID) AS usersCount FROM imscp_user WHERE type = 'client' AND createdBy = ?")
                ->execute([Application::getInstance()->getAuthService()->getIdentity()->getUserId()])
                ->current()['usersCount'];
        }

        return $count >= $minClientsCount;
    }

    /**
     * Tells whether or not the logged-in reseller has permissions on the given feature
     *
     * @param string $featureName Feature name
     * @param bool $forceReload If true force data to be reloaded
     * @return bool TRUE if $featureName is available for reseller, FALSE otherwise
     */
    public static function resellerHasFeature(string $featureName, bool $forceReload = false): bool
    {
        static $availableFeatures = NULL;
        $featureName = strtolower($featureName);

        if (NULL == $availableFeatures || $forceReload) {
            $config = Application::getInstance()->getConfig();
            $resellerProps = getResellerProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
            $availableFeatures = [
                'domains'             => $resellerProps['domainsLimit'] != '-1',
                'subdomains'          => $resellerProps['subdomainsLimit'] != '-1',
                'mail'                => $resellerProps['mailAccountsLimit'] != '-1',
                'ftp'                 => $resellerProps['ftpAccountsLimit'] != '-1',
                'sql'                 => $resellerProps['sqlDatabasesLimit'] != '-1' && $resellerProps['sqlUsersLimit'] != '-1',
                'php'                 => $resellerProps['php'] == '1',
                'phpEditor'           => $resellerProps['phpEditor'] == '1',
                'cgi'                 => $resellerProps['cgi'] == '1',
                'dns'                 => $resellerProps['dns'] == '1',
                'dnsEditor'           => $resellerProps['dnsEditor'] == '1' && $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'supportSystem'       => $resellerProps['supportSystem'] == '1' && $config['IMSCP_SUPPORT_SYSTEM'],
                'externalMailServer'  => $resellerProps['externalMailServer'] == '1',
                'backup'              => $resellerProps['backup'] == '1' && $config['BACKUP_DOMAINS'] != 'no',
                'protectedArea'       => $resellerProps['protectedArea'] == '1',
                'customErrorPages'    => $resellerProps['customErrorPages'] == '1',
                'webFolderProtection' => $resellerProps['webFolderProtection'] == '1',
                'webstats'            => $resellerProps['webstats'] == '1'
            ];
        }

        if (!array_key_exists($featureName, $availableFeatures)) {
            throw new \InvalidArgumentException(sprintf("Feature %s is not known by the resellerHasFeature() function.", $featureName));
        }

        return $availableFeatures[$featureName];
    }

    /**
     * Tells whether or not the logged-in client has permissions on the given feature
     *
     * @param array|string $featureNames Feature name(s) (insensitive case)
     * @param bool $forceReload If true force data to be reloaded
     * @return bool TRUE if $featureName is available for client, FALSE otherwise
     */
    public static function clientHasFeature(string $featureNames, bool $forceReload = false): bool
    {
        static $availableFeatures = NULL;

        if (NULL === $availableFeatures || $forceReload) {
            $identity = Application::getInstance()->getAuthService()->getIdentity();
            $config = Application::getInstance()->getConfig();
            $clientProperties = getClientProperties($identity->getUserId());
            $availableFeatures = [
                'domains'             => $clientProperties['domainsLimit'] != '-1',
                'subdomains'          => $clientProperties['subdomainsLimit'] != '-1',
                'mail'                => $clientProperties['mailAccountsLimit'] != '-1',
                'ftp'                 => $clientProperties['ftpAccountsLimit'] != '-1',
                'sql'                 => $clientProperties['sqlDatabasesLimit'] != '-1' && $clientProperties['sqlUsersLimit'] != '-1',
                'php'                 => $clientProperties['php'] == '1',
                'phpEditor'           => $clientProperties['phpEditor'] == '1',
                'cgi'                 => $clientProperties['cgi'] == '1',
                'dns'                 => $clientProperties['dns'] == '1',
                'dnsEditor'           => $clientProperties['dnsEditor'] == '1' && $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'supportSystem'       => $clientProperties['supportSystem'] == '1' && $config['IMSCP_SUPPORT_SYSTEM'],
                'externalMailServer'  => $clientProperties['externalMailServer'] == '1',
                'backup'              => $clientProperties['backup'] == '1' && $config['BACKUP_DOMAINS'] != 'no',
                'protectedArea'       => $clientProperties['protectedArea'] == '1',
                'customErrorPages'    => $clientProperties['customErrorPages'] == '1',
                'webFolderProtection' => $clientProperties['webFolderProtection'] == '1',
                'webstats'            => $clientProperties['webstats'] == '1',
                'ssl'                 => $config['ENABLE_SSL'] == '1'
            ];
        }

        $canAccess = true;
        foreach ((array)$featureNames as $featureName) {
            $featureName = strtolower($featureName);
            if (!array_key_exists($featureName, $availableFeatures)) {
                throw new \InvalidArgumentException(sprintf("Feature %s is not known by the clientHasFeature() function.", $featureName));
            }

            if (!$availableFeatures[$featureName]) {
                $canAccess = false;
                break;
            }
        }

        return $canAccess;
    }

    /**
     * Tells whether or not the logged-in client has permissions on the mail or external mail server feature
     *
     * @return bool
     */
    public static function clientHasMailOrExtMailFeatures(): bool
    {
        return self::clientHasFeature('mail') || self::clientHasFeature('externalMailServer');
    }

    /**
     * Is the given client the owner of the given domain?
     *
     * @param int $clientID Client unique identifier
     * @param string $domainName Domain name
     * @return bool TRUE if the given client is the owner of the given domain, FALSE otherwise
     */
    public static function clientOwnDomain(int $clientID, string $domainName): bool
    {
        return (bool)Application::getInstance()
            ->getDb()
            ->createStatement('SELECT 1 FROM imscp_web_domain WHERE userID = ? AND domainName = ? LIMIT 1')
            ->execute([$clientID, encodeIdna($domainName)])
            ->count();
    }
}
