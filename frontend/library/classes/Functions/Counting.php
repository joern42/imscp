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
     * Retrieve count of mailboxes
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @return int Count of mail accounts
     */
    public static function getMailboxesCount(): int
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = self::getObjectsCount(
                'imscp_mailbox',
                'mailboxID',
                !Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES'] ? "isDefault = 0" : NULL
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
     * @param array|null $params SQL query parameters
     * @return int Count of objects
     */
    public static function getObjectsCount(string $table, string $objectIDfield, string $where = NULL, ?$params = []): int
    {
        $qb = Application::getInstance()
            ->getEntityManager()
            ->getConnection()
            ->createQueryBuilder()
            ->select("COUNT($objectIDfield)")
            ->from($table);

        if ($where !== NULL) {
            $qb->where($where);
            if (!empty($params)) {
                $qb->setParameters($params);
            }
        }

        return $qb->execute()->fetchColumn();
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
            self::getAdministratorsCount(),
            self::getResellersCount(),
            self::getClientsCount(),
            self::getDomainsCount(),
            self::getSubdomainsCount(),
            self::getMailboxesCount(),
            self::getFtpUsersCount(),
            self::getSqlDatabasesCount(),
            self::getSqlUsersCount()
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
        return static::getObjectsCount('imscp_user', 'userID', 'createdBy = ?', [$resellerId]);
    }

    /**
     * Retrieve count of web domains that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerDomainsCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.webDomainID)')
                ->from('imscp_web_domain', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?')
                ->andWhere('t1.webDomainPID IS NULL');
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerSubdomainsCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.webDomainID)')
                ->from('imscp_web_domain', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?')
                ->andWhere('t1.webDomainPID IS NOT NULL');
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of mailboxes that belong to the given reseller
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @param int $resellerId Domain unique identifier
     * @return int Count of mail accounts
     */
    public static function getResellerMailboxesCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.mailboxID)')
                ->from('imscp_mailbox', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?');

            if (!Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
                $qb->andWhere('t1.isDefault = 0');
            }
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of FTP users that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of FTP users
     */
    public static function getResellerFtpUsersCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.ftpUserID')
                ->from('imscp_ftp_user', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?');
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of SQL databases that belong to the given reseller
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of SQL databases
     */
    public static function getResellerSqlDatabasesCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.sqlDatabaseID')
                ->from('imscp_sql_database', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?');
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of SQL users that belong to the given reseller
     *
     * @param int $resellerId Domain unique identifier
     * @return int Count of SQL users
     */
    public static function getResellerSqlUsersCount(int $resellerId): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(t1.sqlUserID')
                ->from('imscp_sql_user', 't1')
                ->join('t1', 'imscp_user', 't2', 't1.userID = t2.userID')
                ->where('t2.createdBy = ?');
        }

        return $qb->setParameter(0, $resellerId)->execute()->fetchColumn();
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
            self::getResellerDomainsCount($resellerId),
            self::getResellerSubdomainsCount($resellerId),
            self::getResellerMailboxesCount($resellerId),
            self::getResellerFtpUsersCount($resellerId),
            self::getResellerSqlDatabasesCount($resellerId),
            self::getResellerSqlUsersCount($resellerId)
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
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('imscp_web_domain')
                ->where('useID = ?')
                ->andWhere('webDomainID IS NULL');
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of subdomains
     */
    public static function getClientSubdomainsCount(int $clientID): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('imscp_web_domain')
                ->where('useID = ?')
                ->andWhere('webDomainID IS NOT NULL');
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of mailboxes that belong to the given client
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @param int $clientID Client unique identifier
     * @return int Count of mail accounts
     */
    public static function getClientMailboxesCount(int $clientID): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(mailboxID)')
                ->from('imscp_mailbox')
                ->where('userID = ?');

            if (!Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
                $qb->andWhere('isDefault = 0');
            }
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of FTP users that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of FTP users
     */
    public static function getClientFtpUsersCount(int $clientID): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(ftpUserID)')
                ->from('imscp_ftp_user')
                ->where('userID = ?');
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of SQL databases that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of SQL databases
     */
    public static function getClientSqlDatabasesCount(int $clientID): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(sqlDatabaseID)')
                ->from('imscp_sql_database')
                ->where('userID = ?');
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
    }

    /**
     * Retrieve count of SQL users that belong to the given client
     *
     * @param int $clientID Client unique identifier
     * @return int Count of SQL users
     */
    public static function getClientSqlUsersCount(int $clientID): int
    {
        static $qb = NULL;

        if (NULL === $qb) {
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $qb->select('COUNT(sqlUserID)')
                ->from('imscp_sql_user')
                ->where('userID = ?');
        }

        return $qb->setParameter(0, $clientID)->execute()->fetchColumn();
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
            self::getClientDomainsCount($clientID),
            self::getClientSubdomainsCount($clientID),
            self::getClientMailboxesCount($clientID),
            self::getClientFtpUsersCount($clientID),
            self::getClientSqlDatabasesCount($clientID),
            self::getClientSqlUsersCount($clientID)
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
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $count = $qb->select('COUNT(userID)')
                ->from('imscp_user')
                ->where("type = 'reseller'")
                ->execute()
                ->fetchColumn();
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
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $count = $qb->select('COUNT(userID)')
                ->from('imscp_user')
                ->where("type = 'client'")
                ->execute()
                ->fetchColumn();
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
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $count = $qb->select('COUNT(userID)')
                ->from('imscp_user')
                ->where("type = 'admin'")
                ->execute()
                ->fetchColumn();
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
            $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
            $count = $qb->select('COUNT(userID)')
                ->from('imscp_user')
                ->where("type = 'client'")
                ->andWhere('createdBy = ?')
                ->setParameter(0, Application::getInstance()->getAuthService()->getIdentity()->getUserId())
                ->execute()
                ->fetchColumn();
        }

        return $count >= $minClientsCount;
    }

    /**
     * Tells whether or not the logged-in reseller has the given feature
     *
     * @param string $featureName Feature name
     * @param bool $forceReload If true force data to be reloaded
     * @return bool TRUE if $featureName is available for the reseller, FALSE otherwise
     */
    public static function resellerHasFeature(string $featureName, bool $forceReload = false): bool
    {
        static $availableFeatures = NULL;

        if (NULL == $availableFeatures || $forceReload) {
            $config = Application::getInstance()->getConfig();
            $resellerProps = getResellerProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
            $availableFeatures = [
                'domains'             => $resellerProps['domainsLimit'] != -1,
                'subdomains'          => $resellerProps['subdomainsLimit'] != -1,
                'mail'                => $resellerProps['mailboxesLimit'] != -1,
                'ftp'                 => $resellerProps['ftpUsersLimit'] != -1,
                'sql'                 => $resellerProps['sqlDatabasesLimit'] != -1 && $resellerProps['sqlUsersLimit'] != -1,
                'php'                 => $resellerProps['php'] == 1,
                'phpEditor'           => $resellerProps['phpEditor'] == 1,
                'cgi'                 => $resellerProps['cgi'] == 1,
                'dns'                 => $resellerProps['dns'] == 1,
                'dnsEditor'           => $resellerProps['dnsEditor'] == 1 && $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'supportSystem'       => $resellerProps['supportSystem'] == 1 && $config['IMSCP_SUPPORT_SYSTEM'],
                'externalMailServer'  => $resellerProps['externalMailServer'] == 1,
                'backup'              => $resellerProps['backup'] == 1 && $config['BACKUP_DOMAINS'] != 'no',
                'protectedArea'       => $resellerProps['protectedArea'] == 1,
                'customErrorPages'    => $resellerProps['customErrorPages'] == 1,
                'webFolderProtection' => $resellerProps['webFolderProtection'] == 1,
                'webstats'            => $resellerProps['webstats'] == 1
            ];
        }

        $featureName = strtolower($featureName);
        if (!array_key_exists($featureName, $availableFeatures)) {
            throw new \InvalidArgumentException(sprintf('Unknown feature: %s', $featureName));
        }

        return $availableFeatures[$featureName];
    }

    /**
     * Tells whether or not the logged-in client has the given feature
     *
     * @param string $featureName Feature name
     * @param bool $forceReload If true force data to be reloaded
     * @return bool TRUE if $featureName is available for the client, FALSE otherwise
     */
    public static function clientHasFeature(string $featureName, bool $forceReload = false): bool
    {
        static $availableFeatures = NULL;

        if (NULL === $availableFeatures || $forceReload) {
            $config = Application::getInstance()->getConfig();
            $clientProps = getClientProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
            $availableFeatures = [
                'domains'             => $clientProps['domainsLimit'] != -1,
                'subdomains'          => $clientProps['subdomainsLimit'] != -1,
                'mail'                => $clientProps['mailboxesLimit'] != -1,
                'ftp'                 => $clientProps['ftpUsersLimit'] != -1,
                'sql'                 => $clientProps['sqlDatabasesLimit'] != -1 && $clientProps['sqlUsersLimit'] != -1,
                'php'                 => $clientProps['php'] == 1,
                'phpEditor'           => $clientProps['phpEditor'] == 1,
                'cgi'                 => $clientProps['cgi'] == 1,
                'dns'                 => $clientProps['dns'] == 1,
                'dnsEditor'           => $clientProps['dnsEditor'] == 1 && $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'supportSystem'       => $clientProps['supportSystem'] == 1 && $config['IMSCP_SUPPORT_SYSTEM'],
                'externalMailServer'  => $clientProps['externalMailServer'] == 1,
                'backup'              => $clientProps['backup'] == 1 && $config['BACKUP_DOMAINS'] != 'no',
                'protectedArea'       => $clientProps['protectedArea'] == 1,
                'customErrorPages'    => $clientProps['customErrorPages'] == 1,
                'webFolderProtection' => $clientProps['webFolderProtection'] == 1,
                'webstats'            => $clientProps['webstats'] == 1,
                'ssl'                 => $config['ENABLE_SSL'] == 1
            ];
        }

        $featureName = strtolower($featureName);
        if (!array_key_exists($featureName, $availableFeatures)) {
            throw new \InvalidArgumentException(sprintf('Unknown feature: %s', $featureName));
        }

        return $availableFeatures[$featureName];
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

        $qb = Application::getInstance()->getEntityManager()->getConnection()->createQueryBuilder();
        return (bool)$qb->select('COUNT(userID)')
            ->from('imscp_web_domain')
            ->where('userID = ?')
            ->andWhere('domainName = ?')
            ->setParameters([$clientID, encodeIdna($domainName)])
            ->execute()
            ->fetchColumn();
    }
}
