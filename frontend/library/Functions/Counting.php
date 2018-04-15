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

use iMSCP_Registry as Registry;

// Global counting functions

/**
 * Retrieve count of administrator accounts, exluding those that are being
 * deleted
 *
 * @return int Count of administrator accounts
 */
function getAdministratorsCount()
{
    return getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'admin' AND admin_status <> 'todelete'");
}

/**
 * Retrieve count of reseller accounts, exluding those that are being deleted
 *
 * @return int Count of reseller accounts
 */
function getResellersCount()
{
    return getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'reseller' AND admin_status <> 'todelete'");
}

/**
 * Retrieve count of customers accounts, exluding those that are being deleted
 *
 * @return int Count of customer accounts
 */
function getCustomersCount()
{
    return getObjectsCount('admin', 'admin_id', "WHERE admin_type = 'user' AND admin_status <> 'todelete'");
}

/**
 * Retrieve count of domains, exluding those that are being deleted
 *
 * @return int Count of domains
 */
function getDomainsCount()
{
    return getObjectsCount('domain', 'domain_id', "WHERE domain_status <> 'todelete'");
}

/**
 * Retrieve count of subdomains, exluding those that are being deleted
 *
 *
 * @return int Count of subdomains
 */
function getSubdomainsCount()
{
    return getObjectsCount('subdomain', 'subdomain_id', "WHERE subdomain_status <> 'todelete'")
        + getObjectsCount('subdomain_alias', 'subdomain_alias_id', "WHERE subdomain_alias_status <> 'todelete'");
}

/**
 * Retrieve count of domain aliases, excluding those that are ordered or being deleted
 *
 * @return int Count of domain aliases
 */
function getDomainAliasesCount()
{
    return getObjectsCount('domain_aliases', 'alias_id', "WHERE alias_status NOT IN('ordered', 'todelete')");
}

/**
 * Retrieve count of mail accounts, exluding those that are being deleted
 *
 * Default mail accounts are counted or not, depending of administrator settings.
 *
 * @return int Count of mail accounts
 */
function getMailAccountsCount()
{
    $where = '';

    if (!Registry::get('config')['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
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
                mail_type IN('" . MT_NORMAL_FORWARD . "', '" . MT_ALIAS_FORWARD . "')
            )
            AND !(mail_acc = 'webmaster' AND mail_type IN('" . MT_SUBDOM_FORWARD . "', '" . MT_ALSSUB_FORWARD . "'))
        ";
    }

    $where .= ($where == '' ? 'WHERE ' : 'AND ') . "status <> 'todelete'";

    return getObjectsCount('mail_users', 'mail_id', $where);
}

/**
 * Retrieve count of FTP users, exluding those that are being deleted
 *
 * @return int Count of FTP users
 */
function getFtpUsersCount()
{
    return getObjectsCount('ftp_users', 'userid', "WHERE status <> 'todelete'");
}

/**
 * Retrieve count of SQL databases
 *
 * @return int Count of SQL databases;
 */
function getSqlDatabasesCount()
{
    return getObjectsCount('sql_database', 'sqld_id');
}

/**
 * Retrieve count of SQL users
 *
 * @return int Count of SQL users
 */
function getSqlUsersCount()
{
    return getObjectsCount('sql_user', 'sqlu_name');
}

/**
 * Retrieve count of objects from the given table using the given identifier
 * field and optional WHERE clause
 *
 * @param string $table
 * @param string $idField Identifier field
 * @param string $where OPTIONAL Where clause
 * @return int Count of objects
 */
function getObjectsCount($table, $idField, $where = '')
{
    $table = quoteIdentifier($table);
    $idField = quoteIdentifier($idField);
    return executeQuery("SELECT COUNT(DISTINCT $idField) FROM $table $where")->fetchColumn();
}

/**
 * Retrieve count of subdomains, domain aliases, mail accounts, FTP users,
 * SQL database and SQL users that belong to the given reseller, excluding
 * those that are being deleted
 *
 * @return array An array containing in order, count of administrators,
 *              resellers, customers, domains, subdomains, domain aliases,
 *              mail accounts, FTP users, SQL databases and SQL users
 */
function getObjectsCounts()
{
    return [
        getAdministratorsCount(), getResellersCount(), getCustomersCount(), getDomainsCount(), getSubdomainsCount(), getDomainAliasesCount(),
        getMailAccountsCount(), getFtpUsersCount(), getSqlDatabasesCount(), getSqlUsersCount()
    ];
}

// Per reseller counting functions

/**
 * Retrieve count of customer accounts that belong to the given reseller,
 * excluding those that are being deleted
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of subdomains
 */
function getResellerCustomersCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare("SELECT COUNT(admin_id) FROM admin WHERE created_by = ? AND admin_status <> 'todelete'");
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of domains that belong to the given reseller, excluding those
 * that are being deleted
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of subdomains
 */
function getResellerDomainsCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
            "SELECT COUNT(domain_id) FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?AND domain_status <> 'todelete'"
        );
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of subdomains that belong to the given reseller, excluding
 * those that are being deleted
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of subdomains
 */
function getResellerSubdomainsCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
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
    }

    $stmt->execute([$resellerId, $resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of domain aliases that belong to the given reseller,
 * excluding those that are ordered or being deleted
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of domain aliases
 */
function getResellerDomainAliasesCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
            "
                SELECT COUNT(alias_id)
                FROM domain_aliases
                JOIN domain USING(domain_id)
                JOIN admin ON(admin_id = domain_admin_id)
                WHERE created_by = ?
                AND alias_status <> 'todelete'
            "
        );
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of mail accounts that belong to the given reseller, excluding
 * those that are being deleted
 *
 * Default mail accounts are counted or not, depending of administrator settings.
 *
 * @param int $resellerId Domain unique identifier
 * @return int Count of mail accounts
 */
function getResellerMailAccountsCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        $query = 'SELECT COUNT(mail_id) FROM mail_users JOIN domain USING(domain_id) JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?';

        if (!Registry::get('config')['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
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
                    mail_type IN('" . MT_NORMAL_FORWARD . "', '" . MT_ALIAS_FORWARD . "')
                )    
                AND !(mail_acc = 'webmaster' AND mail_type IN('" . MT_SUBDOM_FORWARD . "', '" . MT_ALSSUB_FORWARD . "'))
            ";
        }

        $query .= "AND status <> 'todelete'";

        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare($query);
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of FTP users that belong to the given reseller, excluding
 * those that are being deleted
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of FTP users
 */
function getResellerFtpUsersCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare("SELECT COUNT(userid) FROM ftp_users JOIN admin USING(admin_id) WHERE created_by = ? AND status <> 'todelete'");
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of SQL databases that belong to the given reseller
 *
 * @param int $resellerId Reseller unique identifier
 * @return int Count of SQL databases
 */
function getResellerSqlDatabasesCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
            'SELECT COUNT(sqld_id) FROM sql_database JOIN domain USING(domain_id) JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?'
        );
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of SQL users that belong to the given reseller
 *
 * @param int $resellerId Domain unique identifier
 * @return int Count of SQL users
 */
function getResellerSqlUsersCount($resellerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
            '
                SELECT COUNT(DISTINCT sqlu_name)
                FROM sql_user
                JOIN sql_database USING(sqld_id)
                JOIN domain USING(domain_id)
                JOIN admin ON(admin_id = domain_admin_id)
                WHERE created_by = ?
            '
        );
    }

    $stmt->execute([$resellerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of subdomains, domain aliases, mail accounts, FTP users,
 * SQL database and SQL users that belong to the given reseller, excluding
 * those that are being deleted
 *
 * @param int $resellerId Customer unique identifier
 * @return array An array containing count of customers, domains, subdomains,
 *               domain aliases, mail accounts, FTP users, SQL databases and
 *               SQL users
 */
function getResellerObjectsCounts($resellerId)
{
    return [
        getResellerCustomersCount($resellerId), getResellerDomainsCount($resellerId), getResellerSubdomainsCount($resellerId),
        getResellerDomainAliasesCount($resellerId), getResellerMailAccountsCount($resellerId), getResellerFtpUsersCount($resellerId),
        getResellerSqlDatabasesCount($resellerId), getResellerSqlUsersCount($resellerId)
    ];
}

// Per domain/customer counting functions

/**
 * Retrieve count of subdomains that belong to the given customer, excluding
 * those that are being deleted
 *
 * @param int $domainId Customer main domain unique identifier
 * @return int Count of subdomains
 */
function getCustomerSubdomainsCount($domainId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare(
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
    }

    $stmt->execute([$domainId, $domainId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of domain aliases that belong to the given customer,
 * excluding those that are ordered or being deleted
 *
 * @param int $domainId Customer main domain unique identifier
 * @return int Count of domain aliases
 */
function getCustomerDomainAliasesCount($domainId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare("SELECT COUNT(alias_id) FROM domain_aliases WHERE domain_id = ? AND alias_status NOT IN('ordered', 'todelete')");
    }

    $stmt->execute([$domainId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of mail accounts that belong to the given customer, excluding
 * those that are being deleted
 *
 * Default mail accounts are counted or not, depending of administrator settings.
 *
 * @param int $domainId Customer main domain unique identifier
 * @return int Count of mail accounts
 */
function getCustomerMailAccountsCount($domainId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        $query = 'SELECT COUNT(mail_id) FROM mail_users WHERE domain_id = ?';

        if (!Registry::get('config')['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
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
                    mail_type IN('" . MT_NORMAL_FORWARD . "', '" . MT_ALIAS_FORWARD . "')
                )    
                AND !(mail_acc = 'webmaster' AND mail_type IN('" . MT_SUBDOM_FORWARD . "', '" . MT_ALSSUB_FORWARD . "'))
            ";
        }

        $query .= "AND status <> 'todelete'";

        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare($query);
    }

    $stmt->execute([$domainId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of FTP users that belong to the given customer, excluding
 * those that are being deleted
 *
 * @param int $customerId Customer unique identifier
 * @return int Count of FTP users
 */
function getCustomerFtpUsersCount($customerId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare("SELECT COUNT(userid) FROM ftp_users WHERE admin_id = ? AND status <> 'todelete'");
    }

    $stmt->execute([$customerId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of SQL databases that belong to the given customer
 *
 * @param int $domainId Customer main domain unique identifier
 * @return int Count of SQL databases
 */
function getCustomerSqlDatabasesCount($domainId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare('SELECT COUNT(sqld_id) FROM sql_database WHERE domain_id = ?');
    }

    $stmt->execute([$domainId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of SQL users that belong to the given customer
 *
 * @param int $domainId Customer main domain unique identifier
 * @return int Count of SQL users
 */
function getCustomerSqlUsersCount($domainId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();
        $stmt = $db->prepare('SELECT COUNT(DISTINCT sqlu_name) FROM sql_user JOIN sql_database USING(sqld_id) WHERE domain_id = ?');
    }

    $stmt->execute([$domainId]);
    return $stmt->fetchColumn();
}

/**
 * Retrieve count of subdomains, domain aliases, mail accounts, FTP users,
 * SQL database and SQL users that belong to the given customer, excluding
 * those that are being deleted
 *
 * @param int $customerId Customer unique identifier
 * @return array An array containing count of subdomains, domain aliases, mail
 *               accounts, FTP users, SQL databases and SQL users
 */
function getCustomerObjectsCounts($customerId)
{
    $domainId = getCustomerMainDomainId($customerId, true);

    return [
        getCustomerSubdomainsCount($domainId), getCustomerDomainAliasesCount($domainId), getCustomerMailAccountsCount($domainId),
        getCustomerFtpUsersCount($customerId), getCustomerSqlDatabasesCount($domainId), getCustomerSqlUsersCount($domainId)
    ];
}
