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
 * Provide couting and similar function which return integer or boolean.
 * 
 * @package iMSCP\Functions
 */
class Counting
{
    /**
     * Retrieve count of administrator accounts, exluding those that are being deleted
     *
     * @return int Count of administrator accounts
     */
    public static function getAdministratorsCount(): int
    {
        return static::getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'admin' AND admin_status <> 'todelete'");
    }

    /**
     * Retrieve count of reseller accounts, exluding those that are being deleted
     *
     * @return int Count of reseller accounts
     */
    public static function getResellersCount(): int
    {
        return static::getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'reseller' AND admin_status <> 'todelete'");
    }

    /**
     * Retrieve count of customers accounts, exluding those that are being deleted
     *
     * @return int Count of customer accounts
     */
    public static function getCustomersCount(): int
    {
        return static::getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'user' AND admin_status <> 'todelete'");
    }

    /**
     * Retrieve count of domains, exluding those that are being deleted
     *
     * @return int Count of domains
     */
    public static function getDomainsCount(): int
    {
        return static::getObjectsCount('domain', 'domain_id', "WHERE domain_status <> 'todelete'");
    }

    /**
     * Retrieve count of subdomains, exluding those that are being deleted
     *
     *
     * @return int Count of subdomains
     */
    public static function getSubdomainsCount(): int
    {
        return static::getObjectsCount('subdomain', 'subdomain_id', "WHERE subdomain_status <> 'todelete'")
            + static::getObjectsCount('subdomain_alias', 'subdomain_alias_id', "WHERE subdomain_alias_status <> 'todelete'");
    }

    /**
     * Retrieve count of domain aliases, excluding those that are ordered or being deleted
     *
     * @return int Count of domain aliases
     */
    public static function getDomainAliasesCount(): int
    {
        return static::getObjectsCount('domain_aliases', 'alias_id', "WHERE alias_status NOT IN('ordered', 'todelete')");
    }

    /**
     * Retrieve count of mail accounts, exluding those that are being deleted
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @return int Count of mail accounts
     */
    public static function getMailAccountsCount(): int
    {
        $where = '';

        if (!Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
            # A default mail account is composed of a name matching with:
            # - abuse, hostmaster, postmaster or webmaster for a domain
            # - webmaster for a subdomain
            # and is set as forward mail account. If the customeer turn a default
            # mail account into a normal mail account, it is no longer seen as
            # default mail account.
            $where .= "
                WHERE ! (
                    mail_acc IN('abuse', 'hostmaster', 'postmaster', 'webmaster')
                    AND
                    mail_type IN('" . Mail::MT_NORMAL_FORWARD . "', '" . Mail::MT_ALIAS_FORWARD . "')
                )
                AND !(mail_acc = 'webmaster' AND mail_type IN('" . Mail::MT_SUBDOM_FORWARD . "', '" . Mail::MT_ALSSUB_FORWARD . "'))
            ";
        }

        $where .= ($where == '' ? 'WHERE ' : 'AND ') . "status <> 'todelete'";

        return static::getObjectsCount('mail_users', 'mail_id', $where);
    }

    /**
     * Retrieve count of FTP users, exluding those that are being deleted
     *
     * @return int Count of FTP users
     */
    public static function getFtpUsersCount(): int
    {
        return static::getObjectsCount('ftp_users', 'userid', "WHERE status <> 'todelete'");
    }

    /**
     * Retrieve count of SQL databases
     *
     * @return int Count of SQL databases;
     */
    public static function getSqlDatabasesCount(): int
    {
        return static::getObjectsCount('sql_database', 'sqld_id');
    }

    /**
     * Retrieve count of SQL users
     *
     * @return int Count of SQL users
     */
    public static function getSqlUsersCount(): int
    {
        return static::getObjectsCount('sql_user', 'sqlu_name');
    }

    /**
     * Retrieve count of objects from the given table using the given identifier field and optional WHERE clause
     *
     * @param string $table
     * @param string $idField Identifier field
     * @param string $where OPTIONAL Where clause
     * @return int Count of objects
     */
    public static function getObjectsCount(string $table, string $idField, string $where = ''): int
    {
        $table = quoteIdentifier($table);
        $idField = quoteIdentifier($idField);
        return execQuery("SELECT COUNT(DISTINCT $idField) FROM $table $where")->fetchColumn();
    }

    /**
     * Retrieve count of subdomains, domain aliases, mail accounts, FTP users, SQL database and SQL users that belong to the given reseller, excluding
     * those that are being deleted
     *
     * @return array An array containing in order, count of administrators, resellers, customers, domains, subdomains, domain aliases, mail accounts,
     *               FTP users, SQL databases and SQL users
     */
    public static function getObjectsCounts(): array
    {
        return [
            static::getAdministratorsCount(),
            static::getResellersCount(),
            static::getCustomersCount(),
            static::getDomainsCount(),
            static::getSubdomainsCount(),
            static::getDomainAliasesCount(),
            static::getMailAccountsCount(),
            static::getFtpUsersCount(),
            static::getSqlDatabasesCount(),
            static::getSqlUsersCount()
        ];
    }

    /**
     * Retrieve count of customer accounts that belong to the given reseller, excluding those that are being deleted
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerCustomersCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "SELECT COUNT(admin_id) FROM admin WHERE created_by = ? AND admin_status <> 'todelete'"
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of domains that belong to the given reseller, excluding those that are being deleted
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerDomainsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "SELECT COUNT(domain_id) FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ? AND domain_status <> 'todelete'"
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains that belong to the given reseller, excluding those that are being deleted
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of subdomains
     */
    public static function getResellerSubdomainsCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "
                    SELECT (
                        SELECT COUNT(subdomain_id)
                        FROM subdomain
                        JOIN domain USING(domain_id)
                        JOIN admin ON(admin_id = domain_admin_id)
                        WHERE created_by = ?
                        AND subdomain_status <> 'todelete'
                    ) + (
                        SELECT COUNT(subdomain_alias_id)
                        FROM subdomain_alias
                        JOIN domain_aliases USING(alias_id)
                        JOIN domain USING(domain_id)
                        JOIN admin ON(admin_id = domain_admin_id)
                        WHERE created_by = ?
                        AND subdomain_alias_status <> 'todelete'
                    )
                "
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId, $resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of domain aliases that belong to the given reseller, excluding those that are ordered or being deleted
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of domain aliases
     */
    public static function getResellerDomainAliasesCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "
                    SELECT COUNT(alias_id)
                    FROM domain_aliases
                    JOIN domain USING(domain_id)
                    JOIN admin ON(admin_id = domain_admin_id)
                    WHERE created_by = ?
                    AND alias_status <> 'todelete'
                "
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of mail accounts that belong to the given reseller, excluding those that are being deleted
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
            $query = 'SELECT COUNT(mail_id) FROM mail_users JOIN domain USING(domain_id) JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?';

            if (!Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
                # A default mail account is composed of a name matching with:
                # - abuse, hostmaster, postmaster or webmaster for a domain
                # - webmaster for a subdomain
                # and is set as forward mail account. If the customeer turn a default
                # mail account into a normal mail account, it is no longer seen as
                # default mail account.
                $query .= "
                    AND !(
                        mail_acc IN('abuse', 'hostmaster', 'postmaster', 'webmaster')
                        AND
                        mail_type IN('" . Mail::MT_NORMAL_FORWARD . "', '" . Mail::MT_ALIAS_FORWARD . "')
                    )    
                    AND !(mail_acc = 'webmaster' AND mail_type IN('" . Mail::MT_SUBDOM_FORWARD . "', '" . Mail::MT_ALSSUB_FORWARD . "'))
                ";
            }

            $query .= "AND status <> 'todelete'";

            $stmt = Application::getInstance()->getDb()->createStatement($query);
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of FTP users that belong to the given reseller, excluding those that are being deleted
     *
     * @param int $resellerId Reseller unique identifier
     * @return int Count of FTP users
     */
    public static function getResellerFtpUsersCount(int $resellerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "SELECT COUNT(userid) FROM ftp_users JOIN admin USING(admin_id) WHERE created_by = ? AND status <> 'todelete'"
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
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
                'SELECT COUNT(sqld_id) FROM sql_database JOIN domain USING(domain_id) JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
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
                '
                    SELECT COUNT(DISTINCT sqlu_name)
                    FROM sql_user
                    JOIN sql_database USING(sqld_id)
                    JOIN domain USING(domain_id)
                    JOIN admin ON(admin_id = domain_admin_id)
                    WHERE created_by = ?
                '
            );
            $stmt->prepare();
        }

        return $stmt->execute([$resellerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains, domain aliases, mail accounts, FTP users, SQL database and SQL users that belong to the given reseller, excluding
     * those that are being deleted
     *
     * @param int $resellerId Customer unique identifier
     * @return array An array containing count of customers, domains, subdomains,
     *               domain aliases, mail accounts, FTP users, SQL databases and
     *               SQL users
     */
    public static function getResellerObjectsCounts(int $resellerId): array
    {
        return [
            static::getResellerCustomersCount($resellerId),
            static::getResellerDomainsCount($resellerId),
            static::getResellerSubdomainsCount($resellerId),
            static::getResellerDomainAliasesCount($resellerId),
            static::getResellerMailAccountsCount($resellerId),
            static::getResellerFtpUsersCount($resellerId),
            static::getResellerSqlDatabasesCount($resellerId),
            static::getResellerSqlUsersCount($resellerId)
        ];
    }

    /**
     * Retrieve count of subdomains that belong to the given customer, excluding those that are being deleted
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return int Count of subdomains
     */
    public static function getCustomerSubdomainsCount(int $domainId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "
                    SELECT (
                        SELECT COUNT(subdomain_id) FROM subdomain WHERE domain_id = ? AND subdomain_status <> 'todelete'
                    ) + (
                        SELECT COUNT(subdomain_alias_id)
                        FROM subdomain_alias
                        JOIN domain_aliases USING(alias_id)
                        WHERE domain_id = ?
                        AND subdomain_alias_status <> 'todelete'
                    )
                "
            );
            $stmt->prepare();
        }

        return $stmt->execute([$domainId, $domainId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of domain aliases that belong to the given customer, excluding those that are ordered or being deleted
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return int Count of domain aliases
     */
    public static function getCustomerDomainAliasesCount(int $domainId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "SELECT COUNT(alias_id) FROM domain_aliases WHERE domain_id = ? AND alias_status NOT IN('ordered', 'todelete')"
            );
            $stmt->prepare();
        }

        return $stmt->execute([$domainId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of mail accounts that belong to the given customer, excluding those that are being deleted
     *
     * Default mail accounts are counted or not, depending of administrator settings.
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return int Count of mail accounts
     */
    public static function getCustomerMailAccountsCount(int $domainId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $query = 'SELECT COUNT(mail_id) FROM mail_users WHERE domain_id = ?';

            if (!Application::getInstance()->getConfig()['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
                # A default mail account is composed of a name matching with:
                # - abuse, hostmaster, postmaster or webmaster for a domain
                # - webmaster for a subdomain
                # and is set as forward mail account. If the customeer turn a default
                # mail account into a normal mail account, it is no longer seen as
                # default mail account.
                $query .= "
                    AND !(
                        mail_acc IN('abuse', 'hostmaster', 'postmaster', 'webmaster')
                        AND
                        mail_type IN('" . Mail::MT_NORMAL_FORWARD . "', '" . Mail::MT_ALIAS_FORWARD . "')
                    )    
                    AND !(mail_acc = 'webmaster' AND mail_type IN('" . Mail::MT_SUBDOM_FORWARD . "', '" . Mail::MT_ALSSUB_FORWARD . "'))
                ";
            }

            $query .= "AND status <> 'todelete'";

            $stmt = Application::getInstance()->getDb()->createStatement($query);
            $stmt->prepare();
        }

        return $stmt->execute([$domainId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of FTP users that belong to the given customer, excluding those that are being deleted
     *
     * @param int $customerId Customer unique identifier
     * @return int Count of FTP users
     */
    public static function getCustomerFtpUsersCount(int $customerId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                "SELECT COUNT(userid) FROM ftp_users WHERE admin_id = ? AND status <> 'todelete'"
            );
            $stmt->prepare();
        }

        return $stmt->execute([$customerId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of SQL databases that belong to the given customer
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return int Count of SQL databases
     */
    public static function getCustomerSqlDatabasesCount(int $domainId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT COUNT(sqld_id) FROM sql_database WHERE domain_id = ?');
            $stmt->prepare();
        }

        return $stmt->execute([$domainId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of SQL users that belong to the given customer
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return int Count of SQL users
     */
    public static function getCustomerSqlUsersCount(int $domainId): int
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT COUNT(DISTINCT sqlu_name) FROM sql_user JOIN sql_database USING(sqld_id) WHERE domain_id = ?'
            );
            $stmt->prepare();
        }

        return $stmt->execute([$domainId])->getResource()->fetchColumn();
    }

    /**
     * Retrieve count of subdomains, domain aliases, mail accounts, FTP users, SQL database and SQL users that belong to the given customer, excluding
     * those that are being deleted
     *
     * @param int $customerId Customer unique identifier
     * @return array An array containing count of subdomains, domain aliases, mail
     *               accounts, FTP users, SQL databases and SQL users
     */
    public static function getCustomerObjectsCounts(int $customerId): array
    {
        $domainId = getCustomerMainDomainId($customerId, true);

        return [
            static::getCustomerSubdomainsCount($domainId),
            static::getCustomerDomainAliasesCount($domainId),
            static::getCustomerMailAccountsCount($domainId),
            static::getCustomerFtpUsersCount($customerId),
            static::getCustomerSqlDatabasesCount($domainId),
            static::getCustomerSqlUsersCount($domainId)
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
            $count = execQuery("SELECT COUNT(admin_id) FROM admin WHERE admin_type = 'reseller'")->fetchColumn();
        }

        return $count >= $minResellers;
    }

    /**
     * Whether or not the system has a least the given number of registered customers
     *
     * @param int $minCustomers Minimum number of customers
     * @return bool TRUE if system has a least the given number of registered customers, FALSE otherwise
     */
    public static function systemHasCustomers(int $minCustomers = 1): bool
    {
        static $count = NULL;

        if (NULL === $count) {
            $count = execQuery("SELECT COUNT(admin_id) FROM admin WHERE admin_type = 'user' AND admin_status <> 'todelete'")->fetchColumn();
        }

        return $count >= $minCustomers;
    }

    /**
     * Whether or not system has registered admins (many), resellers or customers
     *
     * @return bool
     */
    public static function systemHasAdminsOrResellersOrCustomers(): bool
    {
        return static::systemHasManyAdmins() || static::systemHasResellers() || static::systemHasCustomers();
    }

    /**
     * Whether or not system has registered resellers or customers
     *
     * @return bool
     */
    public static function systemHasResellersOrCustomers(): bool
    {
        return static::systemHasResellers() || static::systemHasCustomers();
    }

    /**
     * Whether or not system as many admins
     *
     * @return bool
     */
    public static function systemHasManyAdmins(): bool
    {
        static $hasManyAdmins = NULL;

        if (NULL === $hasManyAdmins) {
            $hasManyAdmins = execQuery("SELECT COUNT(admin_id) FROM admin WHERE admin_type = 'admin'")->fetchColumn() > 1;
        }

        return $hasManyAdmins;
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
     * Whether or not the logged-in reseller has a least the given number of registered customers
     *
     * @param int $minNbCustomers Minimum number of customers
     * @return bool TRUE if the logged-in reseller has a least the given number of registered customer, FALSE otherwise
     */
    public static function resellerHasCustomers(int $minNbCustomers = 1): bool
    {
        static $customerCount = NULL;

        if (NULL === $customerCount) {
            $customerCount = execQuery(
                "SELECT COUNT(admin_id) FROM admin WHERE admin_type = 'user' AND created_by = ? AND admin_status <> 'todelete'",
                [Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
            )->fetchColumn();
        }

        return $customerCount >= $minNbCustomers;
    }

    /**
     * Tells whether or not the given feature is available for the reseller
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
                'domains'            => $resellerProps['max_dmn_cnt'] != '-1',
                'subdomains'         => $resellerProps['max_sub_cnt'] != '-1',
                'domain_aliases'     => $resellerProps['max_als_cnt'] != '-1',
                'mail'               => $resellerProps['max_mail_cnt'] != '-1',
                'ftp'                => $resellerProps['max_ftp_cnt'] != '-1',
                'sql'                => $resellerProps['max_sql_db_cnt'] != '-1', // TODO to be removed
                'sql_db'             => $resellerProps['max_sql_db_cnt'] != '-1',
                'sql_user'           => $resellerProps['max_sql_user_cnt'] != '-1',
                'php'                => true,
                'php_editor'         => $resellerProps['php_ini_system'] == 'yes',
                'cgi'                => true,
                'custom_dns_records' => $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'external_mail'      => true,
                'backup'             => $config['BACKUP_DOMAINS'] != 'no',
                'support'            => $config['IMSCP_SUPPORT_SYSTEM'] && $resellerProps['support_system'] == 'yes'
            ];
        }

        if (!array_key_exists($featureName, $availableFeatures)) {
            throw new \InvalidArgumentException(sprintf("Feature %s is not known by the resellerHasFeature() function.", $featureName));
        }

        return $availableFeatures[$featureName];
    }

    /**
     * Tells whether or not the current customer can access to the given feature(s)
     *
     * @param array|string $featureNames Feature name(s) (insensitive case)
     * @param bool $forceReload If true force data to be reloaded
     * @return bool TRUE if $featureName is available for customer, FALSE otherwise
     */
    public static function customerHasFeature(string $featureNames, bool $forceReload = false): bool
    {
        static $availableFeatures = NULL;

        if (NULL === $availableFeatures || $forceReload) {
            $identity = Application::getInstance()->getAuthService()->getIdentity();
            $config = Application::getInstance()->getConfig();
            $dmnProps = getCustomerProperties($identity->getUserId());
            $availableFeatures = [
                'external_mail'      => $dmnProps['domain_external_mail'] == 'yes',
                'php'                => $dmnProps['domain_php'] == 'yes',
                'php_editor'         => $dmnProps['phpini_perm_system'] == 'yes' && $dmnProps['phpini_perm_allow_url_fopen'] == 'yes'
                    || $dmnProps['phpini_perm_display_errors'] == 'yes' || in_array($dmnProps['phpini_perm_disable_functions'], ['yes', 'exec']),
                'cgi'                => $dmnProps['domain_cgi'] == 'yes',
                'ftp'                => $dmnProps['domain_ftpacc_limit'] != '-1',
                'sql'                => $dmnProps['domain_sqld_limit'] != '-1',
                'mail'               => $dmnProps['domain_mailacc_limit'] != '-1',
                'subdomains'         => $dmnProps['domain_subd_limit'] != '-1',
                'domain_aliases'     => $dmnProps['domain_alias_limit'] != '-1',
                'custom_dns_records' => $dmnProps['domain_dns'] != 'no' && $config['iMSCP::Servers::Named'] != 'iMSCP::Servers::NoServer',
                'webstats'           => $config['WEBSTATS'] != 'no',
                'backup'             => $config['BACKUP_DOMAINS'] != 'no' && $dmnProps['allowbackup'] != '',
                'protected_areas'    => true,
                'custom_error_pages' => true,
                'ssl'                => $config['ENABLE_SSL'] == 1
            ];

            if ($config['IMSCP_SUPPORT_SYSTEM']) {
                $stmt = execQuery('SELECT support_system FROM reseller_props WHERE reseller_id = ?', [$identity->getUserCreatedBy()]);
                $availableFeatures['support'] = $stmt->fetchColumn() == 'yes';
            } else {
                $availableFeatures['support'] = false;
            }
        }

        $canAccess = true;
        foreach ((array)$featureNames as $featureName) {
            $featureName = strtolower($featureName);
            if (!array_key_exists($featureName, $availableFeatures)) {
                throw new \InvalidArgumentException(sprintf("Feature %s is not known by the customerHasFeature() function.", $featureName));
            }

            if (!$availableFeatures[$featureName]) {
                $canAccess = false;
                break;
            }
        }

        return $canAccess;
    }

    /**
     * Tells whether or not the current customer can access the mail or external mail feature.
     * @return bool
     */
    public static function customerHasMailOrExtMailFeatures(): bool
    {
        return static::customerHasFeature('mail') || static::customerHasFeature('external_mail');
    }

    /**
     * Does the given customer is the owner of the given domain?
     *
     * @param string $domainName Domain name (dmn,sub,als,alssub)
     * @param int $customerId Customer unique identifier
     * @return bool TRUE if the given customer is the owner of the given domain, FALSE otherwise
     */
    public static function customerHasDomain(string $domainName, int $customerId): bool
    {
        $domainName = encodeIdna($domainName);

        $db = Application::getInstance()->getDb();

        // Check in domain table
        $stmt = $db->createStatement('SELECT 1 FROM domain WHERE domain_admin_id = ? AND domain_name = ?');
        $result = $stmt->execute([$customerId, $domainName])->getResource();
        if ($result->rowCount()) {
            return true;
        }

        // Check in domain_aliases table
        $stmt = $db->createStatement(
            '
                SELECT 1 FROM domain AS t1
                JOIN domain_aliases AS t2 ON(t2.domain_id = t1.domain_id)
                WHERE t1.domain_admin_id = ?
                AND t2.alias_name = ?
            '
        );
        $result = $stmt->execute([$customerId, $domainName])->getResource();
        if ($result->rowCount()) {
            return true;
        }

        // Check in subdomain table
        $stmt = $db->createStatement(
            "
                SELECT 1
                FROM domain AS t1
                JOIN subdomain AS t2 ON (t2.domain_id = t1.domain_id)
                WHERE t1.domain_admin_id = ?
                AND CONCAT(t2.subdomain_name, '.', t1.domain_name) = ?
        "
        );
        $result = $stmt->execute([$customerId, $domainName])->getResource();
        if ($result->rowCount()) {
            return true;
        }

        // Check in subdomain_alias table
        $stmt = $db->createStatement(
            "
                SELECT 1
                FROM domain AS t1
                JOIN domain_aliases AS t2 ON(t2.domain_id = t1.domain_id)
                JOIN subdomain_alias AS t3 ON(t3.alias_id = t2.alias_id)
                WHERE t1.domain_admin_id = ? AND CONCAT(t3.subdomain_alias_name, '.', t2.alias_name) = ?
            "
        );
        return (bool)$stmt->execute([$customerId, $domainName])->getResource()->rowCount();
    }
}
