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

use iMSCP\Application;
use iMSCP\Events;
use iMSCP\Functions\View;
use iMSCP\Model\SuIdentityInterface;
use iMSCP\Model\UserIdentityInterface;
use Mso\IdnaConvert\IdnaConvert;

/**
 * Returns name of user matching the identifier
 *
 * @param int $userId User unique identifier
 * @return string|false Username
 */
function getUsername($userId)
{
    static $stmt = NULL;

    if (NULL === $stmt) {
        $stmt = Application::getInstance()->getDb()->createStatement('SELECT admin_name FROM admin WHERE admin_id = ?');
        $stmt->prepare();
    }

    return $stmt->execute([$userId])->getResource()->fetchColumn();
}

/**
 * Is the given domain a known domain name?
 *
 * Rules:
 *
 * A domain is known if:
 *
 * - It is found either in the domain table or in the domain_aliases table
 * - It is a subzone of another domain which doesn't belong to the given reseller
 * - It already exist as subdomain, whatever the subdomain type (sub,alssub)
 *
 * @param string $domainName Domain name to match
 * @param int $resellerId Reseller unique identifier
 * @return bool TRUE if the domain already exist, FALSE otherwise
 */
function isKnownDomain($domainName, $resellerId)
{
    // Be sure to work with ASCII domain name
    $domainName = encodeIdna($domainName);

    // $domainName already exist in the domain table?
    $stmt = execQuery('SELECT COUNT(domain_id) FROM domain WHERE domain_name = ?', [$domainName]);

    if ($stmt->fetchColumn() > 0) {
        return true;
    }

    // $domainName already exists in the domain_aliases table?
    $stmt = execQuery('SELECT COUNT(alias_id) FROM domain_aliases WHERE alias_name = ?', [$domainName]);
    if ($stmt->fetchColumn() > 0) {
        return true;
    }

    # $domainName is a subzone of another domain which doesn't belong to the given reseller?
    $queryDomain = 'SELECT COUNT(domain_id) FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE domain_name = ? AND created_by <> ?';
    $queryAliases = '
        SELECT COUNT(alias_id)
        FROM domain_aliases
        JOIN domain USING(domain_id)
        JOIN admin ON(admin_id = domain_admin_id)
        WHERE alias_name = ?
        AND created_by <> ?
    ';

    $domainLabels = explode('.', trim($domainName));
    $domainPartCnt = 0;

    for ($i = 0, $countDomainLabels = count($domainLabels) - 1; $i < $countDomainLabels; $i++) {
        $domainPartCnt = $domainPartCnt + strlen($domainLabels[$i]) + 1;
        $parentDomain = substr($domainName, $domainPartCnt);

        // Execute query the redefined queries for domains/accounts and aliases tables
        if (execQuery($queryDomain, [$parentDomain, $resellerId])->fetchColumn() > 0) {
            return true;
        }

        if (execQuery($queryAliases, [$parentDomain, $resellerId])->fetchColumn() > 0) {
            return true;
        }
    }

    // $domainName already exists as subdomain?
    $stmt = execQuery("SELECT COUNT(subdomain_id) FROM subdomain JOIN domain USING(domain_id) WHERE CONCAT(subdomain_name, '.', domain_name) = ?", [
        $domainName
    ]);
    if ($stmt->fetchColumn() > 0) {
        return true;
    }

    return (bool)execQuery(
        "
            SELECT COUNT(subdomain_alias_id)
            FROM subdomain_alias
            JOIN domain_aliases USING(alias_id)
            WHERE CONCAT(subdomain_alias_name, '.', alias_name) = ?
        ",
        [$domainName]
    )->fetchColumn();
}

/**
 * Returns properties of the given customer
 *
 * Note: For performance reasons, the data are retrieved once per request.
 *
 * @param int $domainAdminId Customer unique identifier
 * @param int|null $createdBy OPTIONAL reseller unique identifier
 * @return array Returns an associative array where each key is a domain propertie name.
 */
function getCustomerProperties($domainAdminId, $createdBy = NULL)
{
    static $domainProperties = NULL;

    if (NULL !== $domainProperties) {
        return $domainProperties;
    }

    if (is_null($createdBy)) {
        $stmt = execQuery('SELECT * FROM domain WHERE domain_admin_id = ?', [$domainAdminId]);
    } else {
        $stmt = execQuery('SELECT * FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE domain_admin_id = ? AND created_by = ?', [
            $domainAdminId, $createdBy
        ]);
    }

    if (!$stmt->rowCount()) {
        \iMSCP\Functions\View::showBadRequestErrorPage();
    }

    $domainProperties = $stmt->fetch();
    return $domainProperties;
}

/**
 * Return customer primary domain unique identifier
 *
 * @param int $customeId Customer unique identifier
 * @param bool $forceReload Flag indicating whether or not data must be fetched again from database
 * @return int Customer primary domain unique identifier
 */
function getCustomerMainDomainId($customeId, $forceReload = false)
{
    static $domainId = NULL;
    static $stmt = NULL;

    if (NULL === $stmt) {
        $stmt = Application::getInstance()->getDb()->createStatement('SELECT domain_id FROM domain WHERE domain_admin_id = ?');
        $stmt->prepare();
    }

    if (!$forceReload && NULL !== $domainId) {
        return $domainId;
    }

    $resut = $stmt->execute([$customeId]);

    if (($domainId = $resut->getResource()->fetchColumn()) === false) {
        throw new \Exception(sprintf("Couldn't find domain ID of user with ID %s", $customeId));
    }

    return $domainId;
}

/**
 * Returns translated item status
 *
 * @param string $status Item status to translate
 * @param bool $showError Whether or not show true error string
 * @param bool $colored Flag indicating whether or not translated status must be colored
 * @return string Translated status
 */
function humanizeDomainStatus($status, $showError = false, $colored = false)
{
    $statusOk = TRUE;

    switch ($status) {
        case 'ok':
            $status = toHtml(tr('Ok'));
            break;
        case 'toadd':
            $status = toHtml(tr('Addition in progress...'));
            break;
        case 'tochange':
        case 'torestore':
        case 'tochangepwd':
            $status = toHtml(tr('Modification in progress...'));
            break;
        case 'todelete':
            $status = toHtml(tr('Deletion in progress...'));
            break;
        case 'disabled':
            $status = toHtml(tr('Deactivated'));
            break;
        case 'toenable':
            $status = toHtml(tr('Activation in progress...'));
            break;
        case 'todisable':
            $status = toHtml(tr('Deactivation in progress...'));
            break;
        case 'ordered':
            $status = toHtml(tr('Awaiting for approval'));
            break;
        default:
            $statusOk = FALSE;
            $status = $showError ? $status : tr('Unexpected error');
    }

    if ($colored) {
        if ($statusOk) {
            $status = '<span style="color:green;font-weight: bold">' . $status . '</span>';
        } else {
            $status = '<span style="color:red;font-weight: bold">' . $status . '</span>';
        }
    }

    return $status;
}

/**
 * Recalculates reseller's assignments
 *
 * This is not based on the objects consumed by customers. This is based on objects assigned by the reseller to its customers.
 *
 * @param int $resellerId unique reseller identifier
 * @return void
 */
function recalculateResellerAssignments(int $resellerId)
{
    execQuery(
        "
            UPDATE reseller_props AS t1
            JOIN (
                SELECT COUNT(domain_id) AS dmn_count,
                    IFNULL(SUM(IF(domain_subd_limit >= 0, domain_subd_limit, 0)), 0) AS sub_limit,
                    IFNULL(SUM(IF(domain_alias_limit >= 0, domain_alias_limit, 0)), 0) AS als_limit,
                    IFNULL(SUM(IF(domain_mailacc_limit >= 0, domain_mailacc_limit, 0)), 0) AS mail_limit,
                    IFNULL(SUM(IF(domain_ftpacc_limit >= 0, domain_ftpacc_limit, 0)), 0) AS ftp_limit,
                    IFNULL(SUM(IF(domain_sqld_limit >= 0, domain_sqld_limit, 0)), 0) AS sqld_limit,
                    IFNULL(SUM(IF(domain_sqlu_limit >= 0, domain_sqlu_limit, 0)), 0) AS sqlu_limit,
                    IFNULL(SUM(domain_disk_limit), 0) AS disk_limit,
                    IFNULL(SUM(domain_traffic_limit), 0) AS traffic_limit
                FROM admin
                JOIN domain ON(domain_admin_id = admin_id)
                WHERE created_by = ?
                AND domain_status <> 'todelete'
            ) AS t2
            SET t1.current_dmn_cnt = t2.dmn_count, t1.current_sub_cnt = t2.sub_limit, t1.current_als_cnt = t2.als_limit,
                t1.current_mail_cnt = t2.mail_limit, t1.current_ftp_cnt = t2.ftp_limit, t1.current_sql_db_cnt = t2.sqld_limit,
                t1.current_sql_user_cnt = t2.sqlu_limit, t1.current_disk_amnt = t2.disk_limit, t1.current_traff_amnt = t2.traffic_limit
            WHERE t1.reseller_id = ?
        ",
        [$resellerId, $resellerId]
    );
}

/**
 * Activate or deactivate the given customer account
 *
 * @param int $customerId Customer unique identifier
 * @param string $action Action to schedule
 * @return void
 */
function changeDomainStatus($customerId, $action)
{
    ignore_user_abort(true);
    set_time_limit(0);

    if ($action == 'deactivate') {
        $newStatus = 'todisable';
    } else if ($action == 'activate') {
        $newStatus = 'toenable';
    } else {
        throw new \Exception("Unknown action: $action");
    }

    $stmt = execQuery('SELECT domain_id, admin_name FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE domain_admin_id = ?', [$customerId]);

    if (!$stmt->rowCount()) {
        throw new \Exception(sprintf("Couldn't find domain for user with ID %s", $customerId));
    }

    $row = $stmt->fetch();
    $domainId = $row['domain_id'];
    $adminName = decodeIdna($row['admin_name']);


    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeChangeDomainStatus, NULL, [
            'customerId' => $customerId,
            'action'     => $action
        ]);

        if ($action == 'deactivate') {
            if (Application::getInstance()->getConfig()['HARD_MAIL_SUSPENSION']) { # SMTP/IMAP/POP disabled
                execQuery("UPDATE mail_users SET status = 'todisable', po_active = 'no' WHERE domain_id = ?", [$domainId]);
            } else { # IMAP/POP disabled
                execQuery("UPDATE mail_users SET po_active = 'no' WHERE domain_id = ?", [$domainId]);
            }
        } else {
            execQuery(
                "
                    UPDATE mail_users
                    SET status = 'toenable', po_active = IF(mail_type LIKE '%_mail%', 'yes', po_active)
                    WHERE domain_id = ?
                    AND status = 'disabled'
                ",
                [$domainId]
            );
            execQuery(
                "UPDATE mail_users SET po_active = IF(mail_type LIKE '%_mail%', 'yes', po_active) WHERE domain_id = ? AND status <> 'disabled'",
                [$domainId]
            );
        }

        # TODO implements customer deactivation
        #exec_query('UPDATE admin SET admin_status = ? WHERE admin_id = ?', array($newStatus, $customerId));
        execQuery('UPDATE ftp_users SET status = ? WHERE admin_id = ?', [$newStatus, $customerId]);
        execQuery('UPDATE htaccess SET status = ? WHERE dmn_id = ?', [$newStatus, $domainId]);
        execQuery('UPDATE htaccess_groups SET status = ? WHERE dmn_id = ?', [$newStatus, $domainId]);
        execQuery('UPDATE htaccess_users SET status = ? WHERE dmn_id = ?', [$newStatus, $domainId]);
        execQuery("UPDATE domain SET domain_status = ? WHERE domain_id = ?", [$newStatus, $domainId]);
        execQuery("UPDATE subdomain SET subdomain_status = ? WHERE domain_id = ?", [$newStatus, $domainId]);
        execQuery("UPDATE domain_aliases SET alias_status = ? WHERE domain_id = ?", [$newStatus, $domainId]);
        execQuery('UPDATE subdomain_alias JOIN domain_aliases USING(alias_id) SET subdomain_alias_status = ? WHERE domain_id = ?', [
            $newStatus, $domainId
        ]);
        execQuery('UPDATE domain_dns SET domain_dns_status = ? WHERE domain_id = ?', [$newStatus, $domainId]);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterChangeDomainStatus, NULL, [
            'customerId' => $customerId,
            'action'     => $action
        ]);

        $db->getDriver()->getConnection()->commit();
        \iMSCP\Functions\Daemon::sendRequest();

        if ($action == 'deactivate') {
            writeLog(sprintf('%s: scheduled deactivation of customer account: %s', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $adminName), E_USER_NOTICE);
            View::setPageMessage(tr('Customer account successfully scheduled for deactivation.'), 'success');
        } else {
            writeLog(sprintf('%s: scheduled activation of customer account: %s', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $adminName), E_USER_NOTICE);
            View::setPageMessage(tr('Customer account successfully scheduled for activation.'), 'success');
        }
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }
}

/**
 * Deletes an SQL user
 *
 * @param int $dmnId Domain unique identifier
 * @param int $userId Sql user unique identifier
 * @return bool TRUE on success, FALSE otherwise
 */
function deleteSqlUser($dmnId, $userId)
{
    ignore_user_abort(true);
    set_time_limit(0);

    $stmt = execQuery(
        'SELECT sqlu_name, sqlu_host, sqld_name FROM sql_user JOIN sql_database USING(sqld_id) WHERE sqlu_id = ? AND domain_id = ?', [$userId, $dmnId]
    );

    if (!$stmt->rowCount()) {
        return false;
    }

    $row = $stmt->fetch();
    $user = $row['sqlu_name'];
    $host = $row['sqlu_host'];
    $dbName = $row['sqld_name'];

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteSqlUser, NULL, [
        'sqlUserId'   => $userId,
        'sqlUsername' => $user,
        'sqlUserhost' => $host
    ]);

    $stmt = execQuery('SELECT COUNT(sqlu_id) AS cnt FROM sql_user WHERE sqlu_name = ? AND sqlu_host = ?', [$user, $host]);
    $row = $stmt->fetch();

    if ($row['cnt'] < 2) {
        execQuery('DELETE FROM mysql.user WHERE User = ? AND Host = ?', [$user, $host]);
        execQuery('DELETE FROM mysql.db WHERE Host = ? AND User = ?', [$host, $user]);
    } else {
        $dbName = preg_replace('/([%_])/', '\\\\$1', $dbName);
        execQuery('DELETE FROM mysql.db WHERE Host = ? AND Db = ? AND User = ?', [$host, $dbName, $user]);
    }

    execQuery('DELETE FROM sql_user WHERE sqlu_id = ?', [$userId]);
    execQuery('FLUSH PRIVILEGES');

    Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteSqlUser, NULL, [
        'sqlUserId'   => $userId,
        'sqlUsername' => $user,
        'sqlUserhost' => $host
    ]);

    return true;
}

/**
 * Deletes the given SQL database
 *
 * @param int $dmnId Domain unique identifier
 * @param int $dbId Databse unique identifier
 * @return bool TRUE on success, false otherwise
 */
function deleteSqlDatabase($dmnId, $dbId)
{
    ignore_user_abort(true);
    set_time_limit(0);

    $stmt = execQuery('SELECT sqld_name FROM sql_database WHERE domain_id = ? AND sqld_id = ?', [$dmnId, $dbId]);
    if (($dbName = $stmt->fetchColumn()) === false) {
        return false;
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteSqlDb, NULL, [
        'sqlDbId'         => $dbId,
        'sqlDatabaseName' => $dbName
    ]);

    $stmt = execQuery('SELECT sqlu_id FROM sql_user JOIN sql_database USING(sqld_id) WHERE sqld_id = ? AND domain_id = ?', [$dbId, $dmnId]);

    while ($row = $stmt->fetch()) {
        if (!deleteSqlUser($dmnId, $row['sqlu_id'])) {
            return false;
        }
    }

    execQuery(sprintf('DROP DATABASE IF EXISTS %s', quoteIdentifier($dbName)));
    execQuery('DELETE FROM sql_database WHERE domain_id = ? AND sqld_id = ?', [$dmnId, $dbId]);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteSqlDb, NULL, [
        'sqlDbId'         => $dbId,
        'sqlDatabaseName' => $dbName
    ]);

    return true;
}

/**
 * Deletes the given customer
 *
 * @param integer $customerId Customer unique identifier
 * @param boolean $checkCreatedBy Tell whether or not customer must have been created by logged-in user
 * @return bool TRUE on success, FALSE otherwise
 */
function deleteCustomer($customerId, $checkCreatedBy = false)
{
    ignore_user_abort(true);
    set_time_limit(0);

    // Get username, uid and gid of domain user
    $query = 'SELECT admin_name, created_by, domain_id FROM admin JOIN domain ON(domain_admin_id = admin_id) WHERE admin_id = ?';

    if ($checkCreatedBy) {
        $query .= ' AND created_by = ?';
        $stmt = execQuery($query, [$customerId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]);
    } else {
        $stmt = execQuery($query, [$customerId]);
    }

    if (!$stmt->rowCount()) {
        return false;
    }

    $data = $stmt->fetch();

    $db = Application::getInstance()->getDb();

    try {
        // Delete customer session data
        execQuery('DELETE FROM login WHERE user_name = ?', [$data['admin_name']]);

        // Delete SQL databases and SQL users
        $stmt = execQuery('SELECT sqld_id FROM sql_database WHERE domain_id = ?', [$data['domain_id']]);
        while ($sqlId = $stmt->fetchColumn()) {
            deleteSqlDatabase($data['domain_id'], $sqlId);
        }

        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteCustomer, NULL, [
            'customerId' => $customerId
        ]);

        // Delete protected areas
        execQuery(
            '
                DELETE t2, t3, t4
                FROM domain AS t1
                LEFT JOIN htaccess AS t2 ON (t2.dmn_id = t1.domain_id)
                LEFT JOIN htaccess_users AS t3 ON (t3.dmn_id = t1.domain_id)
                LEFT JOIN htaccess_groups AS t4 ON (t4.dmn_id = t1.domain_id)
                WHERE t1.domain_id = ?
            ',
            [$data['domain_id']]
        );

        // Delete traffic data
        execQuery('DELETE FROM domain_traffic WHERE domain_id = ?', [$data['domain_id']]);

        // Delete custom DNS
        execQuery('DELETE FROM domain_dns WHERE domain_id = ?', [$data['domain_id']]);

        // Delete FTP group and FTP accounting/limit data
        execQuery('DELETE FROM ftp_group WHERE groupname = ?', [$data['admin_name']]);
        execQuery('DELETE FROM quotalimits WHERE name = ?', [$data['admin_name']]);
        execQuery('DELETE FROM quotatallies WHERE name = ?', [$data['admin_name']]);

        // Delete support tickets
        execQuery('DELETE FROM tickets WHERE ticket_from = ? OR ticket_to = ?', [$customerId, $customerId]);

        // Delete user frontend properties
        execQuery('DELETE FROM user_gui_props WHERE user_id = ?', [$customerId]);

        // Delete PHP ini
        execQuery('DELETE FROM php_ini WHERE admin_id = ?', [$customerId]);

        // Schedule FTP accounts deletion
        execQuery("UPDATE ftp_users SET status = 'todelete' WHERE admin_id = ?", [$customerId]);

        // Schedule mail accounts deletion
        execQuery("UPDATE mail_users SET status = 'todelete' WHERE domain_id = ?", [$data['domain_id']]);

        // Schedule subdomain aliases deletion
        execQuery(
            "
                UPDATE subdomain_alias AS t1
                JOIN domain_aliases AS t2 ON(t2.domain_id = ?)
                SET t1.subdomain_alias_status = 'todelete'
                WHERE t1.alias_id = t2.alias_id
            ",
            [$data['domain_id']]
        );

        // Schedule domain aliases deletion
        execQuery("UPDATE domain_aliases SET alias_status = 'todelete' WHERE domain_id = ?", [$data['domain_id']]);

        // Schedule subdomains deletion
        execQuery("UPDATE subdomain SET subdomain_status = 'todelete' WHERE domain_id = ?", [$data['domain_id']]);

        // Schedule domain deletion
        execQuery("UPDATE domain SET domain_status = 'todelete' WHERE domain_id = ?", [$data['domain_id']]);

        // Schedule customer deletion
        execQuery("UPDATE admin SET admin_status = 'todelete' WHERE admin_id = ?", [$customerId]);

        // Schedule SSL certificates deletion
        execQuery(
            "UPDATE ssl_certs SET status = 'todelete' WHERE domain_type = 'dmn' AND domain_id = ?", [$data['domain_id']]
        );
        execQuery(
            "
                UPDATE ssl_certs
                SET status = 'todelete'
                WHERE domain_id IN (SELECT alias_id FROM domain_aliases WHERE domain_id = ?)
                AND domain_type = 'als'

            ",
            [$data['domain_id']]
        );
        execQuery(
            "
                UPDATE ssl_certs
                SET status = 'todelete'
                WHERE domain_id IN (SELECT subdomain_id FROM subdomain WHERE domain_id = ?)
                AND domain_type = 'sub'
            ",
            [$data['domain_id']]
        );
        execQuery(
            "
                UPDATE ssl_certs
                SET status = 'todelete'
                WHERE domain_id IN (
                    SELECT subdomain_alias_id FROM subdomain_alias WHERE alias_id IN (SELECT alias_id FROM domain_aliases WHERE domain_id = ?)
                )
                AND domain_type = 'alssub'
            ",
            [$data['domain_id']]
        );

        // Delete autoreplies log entries
        \iMSCP\Functions\Mail::deleteAutorepliesLogs();

        // Update reseller properties
        recalculateResellerAssignments($data['created_by']);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteCustomer, NULL, [
            'customerId' => $customerId
        ]);

        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    // We are now ready to send a request to the daemon for delegated tasks.
    // Note: We are safe here. If the daemon doesn't answer, some entities will not be removed. In such case the
    // sysadmin will have to fix the problem causing deletion break and send a request to the daemon manually via the
    // panel, or run the imscp-rqst-mngr script manually.
    \iMSCP\Functions\Daemon::sendRequest();
    return true;
}

/**
 * Delete the given domain alias, including any entity that belong to it
 *
 * @param int $customerId Customer unique identifier
 * @param int $domainId Customer primary domain identifier
 * @param int $aliasId Domain alias unique identifier
 * @param string $aliasName Domain alias name
 * @param string $aliasMount Domain alias mount point
 * @return void
 */
function deleteDomainAlias($customerId, $domainId, $aliasId, $aliasName, $aliasMount)
{
    ignore_user_abort(true);
    set_time_limit(0);


    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteDomainAlias, NULL, [
            'domainAliasId'   => $aliasId,
            'domainAliasName' => $aliasName
        ]);

        // Delete FTP groups and FTP accounting/limit data
        $stmt = execQuery(
            'SELECT t1.groupname, t1.members FROM ftp_group AS t1 JOIN admin AS t2 ON(t2.admin_name = t1.groupname) WHERE admin_id = ?', [$customerId]
        );
        if ($stmt->rowCount()) {
            $ftpGroupData = $stmt->fetch();
            $members = array_filter(
                preg_split('/,/', $ftpGroupData['members'], -1, PREG_SPLIT_NO_EMPTY),
                function ($member) use ($aliasName) {
                    return !preg_match("/@(?:.+\\.)*$aliasName$/", $member);
                }
            );

            if (empty($members)) {
                execQuery('DELETE FROM ftp_group WHERE groupname = ?', [$ftpGroupData['groupname']]);
                execQuery('DELETE FROM quotalimits WHERE name = ?', [$ftpGroupData['groupname']]);
                execQuery('DELETE FROM quotatallies WHERE name = ?', [$ftpGroupData['groupname']]);
            } else {
                execQuery('UPDATE ftp_group SET members = ? WHERE groupname = ?', [implode(',', $members), $ftpGroupData['groupname']]);
            }

            unset($ftpGroupData, $members);
        }

        // Delete custom DNS
        execQuery('DELETE FROM domain_dns WHERE alias_id = ?', [$aliasId]);

        // Delete PHP ini
        execQuery("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'als'", [$aliasId]);
        execQuery(
            "
                DELETE t1 FROM php_ini AS t1
                JOIN subdomain_alias AS t2 ON(t2.subdomain_alias_id = t1.domain_id  AND t1.domain_type = 'subals')
                WHERE alias_id = ?
            ",
            [$aliasId]
        );

        // Schedule FTP accounts deletion
        execQuery(
            "
                UPDATE ftp_users AS t1
                LEFT JOIN domain_aliases AS t2 ON(alias_id = ?)
                LEFT JOIN subdomain_alias AS t3 USING(alias_id)
                SET status = 'todelete'
                WHERE (userid LIKE CONCAT('%@', t3.subdomain_alias_name, '.', t2.alias_name) OR userid LIKE CONCAT('%@', t2.alias_name))
            ",
            [$aliasId]
        );

        // Schedule mail accounts deletion
        execQuery(
            "
                UPDATE mail_users
                SET status = 'todelete'
                WHERE (sub_id = ? AND mail_type LIKE '%alias_%')
                OR (sub_id IN (SELECT subdomain_alias_id FROM subdomain_alias WHERE alias_id = ?) AND mail_type LIKE '%alssub_%')
            ",
            [$aliasId, $aliasId]
        );

        // Schedule SSL certificates deletion
        execQuery(
            "
                UPDATE ssl_certs
                SET status = 'todelete'
                WHERE domain_id IN (SELECT subdomain_alias_id FROM subdomain_alias WHERE alias_id = ?)
                AND domain_type = 'alssub'
            ",
            [$aliasId]
        );
        execQuery("UPDATE ssl_certs SET status = 'todelete' WHERE domain_id = ? and domain_type = 'als'", [$aliasId]);

        // Schedule protected areas deletion
        execQuery(
            "UPDATE htaccess SET status = 'todelete' WHERE dmn_id = ? AND path LIKE ?",
            [$domainId, normalizePath($aliasMount) . '%']
        );

        // Schedule subdomain aliases deletion
        execQuery("UPDATE subdomain_alias SET subdomain_alias_status = 'todelete' WHERE alias_id = ?", [$aliasId]);

        // Schedule domain alias deletion
        execQuery("UPDATE domain_aliases SET alias_status = 'todelete' WHERE alias_id = ?", [$aliasId]);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteDomainAlias, NULL, [
            'domainAliasId'   => $aliasId,
            'domainAliasName' => $aliasName
        ]);

        $db->getDriver()->getConnection()->commit();

        \iMSCP\Functions\Daemon::sendRequest();
        writeLog(sprintf('%s scheduled deletion of the %s domain alias', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $aliasName), E_USER_NOTICE);
        View::setPageMessage(tr('Domain alias successfully scheduled for deletion.'), 'success');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to remove a domain alias: %s', $e->getMessage()), E_ERROR);
        View::setPageMessage(tr("Couldn't delete domain alias. An unexpected error occurred."), 'error');
    }
}

//
// Reseller related functions
//

/**
 * Returns properties for the given reseller
 *
 * @param int $resellerId Reseller unique identifier
 * @param bool $forceReload Whether or not force properties reload from database
 * @return array
 */
function getResellerProperties($resellerId, $forceReload = false)
{
    static $properties = NULL;

    if (NULL === $properties || $forceReload) {
        $stmt = execQuery('SELECT * FROM reseller_props WHERE reseller_id = ?', [$resellerId]);

        if (!$stmt->rowCount()) {
            throw new \Exception(tr('Properties for reseller with ID %d were not found in database.', $resellerId));
        }

        $properties = $stmt->fetch();
    }

    return $properties;
}

/**
 * Update reseller properties
 *
 * @param  int $resellerId Reseller unique identifier.
 * @param  array $props Array that contain new properties values
 * @return \PDOStatement|null
 */
function updateResellerProperties($resellerId, $props)
{
    ignore_user_abort(true);
    set_time_limit(0);

    if (empty($props)) {
        return NULL;
    }

    list($dmnCur, $dmnMax, $subCur, $subMax, $alsCur, $alsMax, $mailCur, $mailMax, $ftpCur, $ftpMax, $sqlDbCur, $sqlDbMax, $sqlUserCur, $sqlUserMax,
        $traffCur, $traffMax, $diskCur, $diskMax) = explode(';', $props);

    $stmt = execQuery(
        '
            UPDATE reseller_props SET current_dmn_cnt = ?, max_dmn_cnt = ?, current_sub_cnt = ?, max_sub_cnt = ?, current_als_cnt = ?,
                max_als_cnt = ?, current_mail_cnt = ?, max_mail_cnt = ?, current_ftp_cnt = ?, max_ftp_cnt = ?, current_sql_db_cnt = ?,
                max_sql_db_cnt = ?, current_sql_user_cnt = ?, max_sql_user_cnt = ?, current_traff_amnt = ?, max_traff_amnt = ?, current_disk_amnt = ?,
                max_disk_amnt = ?
            WHERE reseller_id = ?
        ',
        [
            $dmnCur, $dmnMax, $subCur, $subMax, $alsCur, $alsMax, $mailCur, $mailMax, $ftpCur, $ftpMax, $sqlDbCur, $sqlDbMax, $sqlUserCur,
            $sqlUserMax, $traffCur, $traffMax, $diskCur, $diskMax, $resellerId
        ]
    );

    return $stmt;
}

//
// Utils functions
//

/**
 * Redirect to the given location
 *
 * @param string $location URL to redirect to
 * @return void
 */
function redirectTo($location)
{
    header('Location: ' . $location);
    exit;
}

/**
 * Encode the given UTF-8 string to ACE form
 *
 * @param  string $string UTF-8 string to encode
 * @return string Encoded UTF-8 string (ACE string), or original string on failure
 */
function encodeIdna($string)
{
    static $converter;

    if (!$converter) {
        $converter = new IdnaConvert([
            'encoding'    => 'utf8',
            'idn_version' => 2008,
            'strict_mode' => false // Accept any string, not only individual domain name parts
        ]);
    }

    try {
        return $converter->encode($string);
    } catch (\Exception $e) {
        return $string;
    }
}

/**
 * Decode the given ACE string to UTF-8
 *
 * @param  string $string ACE string to decode
 * @return string Decoded ACE string (UTF-8 string), or original string on failure
 */
function decodeIdna($string)
{
    static $converter;
    if (!$converter) {
        $converter = new IdnaConvert([
            'encoding'    => 'utf8',
            'idn_version' => 2008,
            'strict_mode' => false // Accept any string, not only individual domain name parts   
        ]);
    }

    try {
        return $converter->decode($string);
    } catch (\Exception $e) {
        return $string;
    }
}

/**
 * Utils function to upload file
 *
 * @param string $inputFieldName upload input field name
 * @param string|array $destPath Destination path string or an array where the first item is an anonymous function to run before moving file and any
 *                               other items the arguments passed to the anonymous function. The anonymous function must return a string that is the
 *                               destination path or FALSE on failure.
 *
 * @return string|bool File destination path on success, FALSE otherwise
 */
function uploadFile($inputFieldName, $destPath)
{
    if (isset($_FILES[$inputFieldName]) && $_FILES[$inputFieldName]['error'] == UPLOAD_ERR_OK) {
        $tmpFilePath = $_FILES[$inputFieldName]['tmp_name'];

        if (!is_readable($tmpFilePath)) {
            View::setPageMessage(tr('File is not readable.'), 'error');
            return false;
        }

        if (!is_string($destPath) && is_array($destPath)) {
            if (!($destPath = call_user_func_array(array_shift($destPath), $destPath))) {
                return false;
            }
        }

        if (!@move_uploaded_file($tmpFilePath, $destPath)) {
            View::setPageMessage(tr('Unable to move file.'), 'error');
            return false;
        }
    } else {
        switch ($_FILES[$inputFieldName]['error']) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                View::setPageMessage(tr('File exceeds the size limit.'), 'error');
                break;
            case UPLOAD_ERR_PARTIAL:
                View::setPageMessage(tr('The uploaded file was only partially uploaded.'), 'error');
                break;
            case UPLOAD_ERR_NO_FILE:
                View::setPageMessage(tr('No file was uploaded.'), 'error');
                break;
            case UPLOAD_ERR_NO_TMP_DIR:
                View::setPageMessage(tr('Temporary folder not found.'), 'error');
                break;
            case UPLOAD_ERR_CANT_WRITE:
                View::setPageMessage(tr('Failed to write file to disk.'), 'error');
                break;
            case UPLOAD_ERR_EXTENSION:
                View::setPageMessage(tr('A PHP extension stopped the file upload.'), 'error');
                break;
            default:
                View::setPageMessage(tr('An unknown error occurred during file upload: %s', $_FILES[$inputFieldName]['error']), 'error');
        }

        return false;
    }

    return $destPath;
}

/**
 * Returns Upload max file size in bytes
 *
 * @return int Upload max file size in bytes
 */
function getMaxFileUpload()
{
    $uploadMaxFilesize = getPhpValueInBytes(ini_get('upload_max_filesize'));
    $postMaxSize = getPhpValueInBytes(ini_get('post_max_size'));
    $memoryLimit = getPhpValueInBytes(ini_get('memory_limit'));
    return min($uploadMaxFilesize, $postMaxSize, $memoryLimit);
}

/**
 * Returns PHP directive value in bytes
 *
 * Note: If $value do not come with shorthand byte value, the value is retured as this.
 *
 * See http://fr2.php.net/manual/en/faq.using.php#faq.using.shorthandbytes for further explaination
 *
 * @param int|string PHP directive value
 * @return int Value in bytes
 */
function getPhpValueInBytes($value)
{
    $value = trim($value);

    if (ctype_digit($value)) {
        return $value;
    }

    $unit = strtolower($value[strlen($value) - 1]);
    $value = substr($value, 0, -1);

    if ($unit == 'g') {
        return ($value * 1024);
    }

    if ($unit == 'm') {
        return ($value * 1024 * 1024);
    }

    if ($unit == 'k') {
        return ($value * 1024 * 1024 * 1024);
    }

    return $value;
}

/**
 * Normalize the given path (e.g. A//B, A/./B and A/foo/../B all become A/B)
 *
 * It should be understood that this may change the meaning of the path if it contains symbolic links.
 *
 * @param string $path Path
 * @param bool $posixCompliant Be POSIX compliant regarding initial slashes?
 * @return string Normalized path
 */
function normalizePath($path, $posixCompliant = false)
{
    if (strlen($path) == 0)
        return '.';

    // Attempt to avoid path encoding problems.
    $path = iconv('UTF-8', 'UTF-8//IGNORE//TRANSLIT', $path);

    $initialSlashes = strpos($path, '/') === 0;
    // POSIX allows one or two initial slashes, but treats three or more as
    // single slash.
    if ($posixCompliant && $initialSlashes && strpos($path, '//') === 0 && strpos($path, '///') !== 0) {
        $initialSlashes = 2;
    }

    $segments = explode('/', $path);
    $newSegments = [];

    foreach ($segments as $segment) {
        if ($segment === '' || $segment === '.') {
            continue;
        }

        if ($segment !== '..' || (!$initialSlashes && !$newSegments) || ($newSegments && end($newSegments) === '..')) {
            array_push($newSegments, $segment);
        } elseif ($newSegments) {
            array_pop($newSegments);
        }
    }

    $path = implode('/', $newSegments);

    if ($initialSlashes) {
        $path = str_repeat('/', $initialSlashes) . $path;
    }

    return isset($path) ? $path : '.';
}

/**
 * Remove the given directory recursively
 *
 * @param string $directory Path of directory to remove
 * @return boolean TRUE on success, FALSE otherwise
 */
function removeDirectory($directory)
{
    $directory = rtrim($directory, '/');

    if (!is_dir($directory)) {
        return false;
    }

    if (!is_readable($directory)) {
        return true;
    }

    $handle = opendir($directory);

    while (false !== ($item = readdir($handle))) {
        if ($item == '.' || $item == '..') {
            continue;
        }

        $path = $directory . '/' . $item;

        if (is_dir($path)) {
            removeDirectory($path);
        } else {
            @unlink($path);
        }

    }

    closedir($handle);

    if (!@rmdir($directory)) {
        return false;
    }

    return true;
}

/**
 * Merge two arrays
 *
 * For duplicate keys, the following is done:
 *  - Nested arrays are recursively merged
 *  - Items in $array2 with INTEGER keys are appended
 *  - Items in $array2 with STRING keys overwrite current values
 *
 * @param array $array1
 * @param array $array2
 * @return array
 */
function arrayMergeRecursive(array $array1, array $array2)
{
    foreach ($array2 as $key => $value) {
        if (!array_key_exists($key, $array1)) {
            $array1[$key] = $value;
            continue;
        }

        if (is_int($key)) {
            $array1[] = $value;
        } elseif (is_array($value) && is_array($array1[$key])) {
            $array1[$key] = arrayMergeRecursive($array1[$key], $value);
        } else {
            $array1[$key] = $value;
        }
    }

    return $array1;
}

/**
 * Compares array1 against array2 (recursively) and returns the difference
 *
 * @param array $array1 The array to compare from
 * @param array $array2 An array to compare against
 * @return array An array containing all the entries from array1 that are not
 *               present in $array2.
 */
function arrayDiffRecursive(array $array1, array $array2)
{
    $diff = [];
    foreach ($array1 as $key => $value) {
        if (!array_key_exists($key, $array2)) {
            $diff[$key] = $value;
            continue;
        }

        if (is_array($value)) {
            $arrDiff = arrayDiffRecursive($value, $array2[$key]);

            if (count($arrDiff)) {
                $diff[$key] = $arrDiff;
            }
        } elseif ($value != $array2[$key]) {
            $diff[$key] = $value;
        }
    }

    return $diff;
}

//
// Checks functions
//

/**
 * Checks if all of the characters in the provided string are numerical
 *
 * @param string $number string to be checked
 * @return bool TRUE if all characters are numerical, FALSE otherwise
 */
function isNumber($number)
{
    return (bool)preg_match('/^[0-9]+$/D', $number);
}

/**
 * Is the request a Javascript XMLHttpRequest?
 *
 * Returns true if the request‘s "X-Requested-With" header contains "XMLHttpRequest".
 *
 * Note: jQuery and Prototype Javascript libraries both set this header with every Ajax request.
 *
 * @return boolean TRUE if the request‘s "X-Requested-With" header contains "XMLHttpRequest", FALSE otherwise
 */
function isXhr()
{
    static $isXhr = NULL;

    if (NULL === $isXhr) {
        $isXhr = isset($_SERVER['HTTP_X_REQUESTED_WITH']) && $_SERVER['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest';
    }

    return $isXhr;
}

/**
 * Check if a data is serialized.
 *
 * @param string $data Data to be checked
 * @return boolean TRUE if serialized data, FALSE otherwise
 */
function isSerialized($data)
{
    if (!is_string($data)) {
        return false;
    }

    $data = trim($data);

    if ('N;' == $data) {
        return true;
    }

    if (preg_match("/^[aOs]:[0-9]+:.*[;}]\$/s", $data) || preg_match("/^[bid]:[0-9.E-]+;\$/", $data)) {
        return true;
    }

    return false;
}

/**
 * Check if the given string look like json data
 *
 * @param $string $string $string to be checked
 * @return boolean TRUE if the given string look like json data, FALSE
 *                 otherwise
 */
function isJson($string)
{
    json_decode($string);
    return json_last_error() == JSON_ERROR_NONE;
}

/**
 * Is the current request a secure request?
 *
 * @return boolean TRUE if is https secure request, FALSE otherwise
 */
function isSecureRequest()
{
    if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO'])) {
        return strtolower($_SERVER['HTTP_X_FORWARDED_PROTO']) == 'https';
    }

    return !empty($_SERVER['HTTPS']) && strtolower($_SERVER['HTTPS']) !== 'off';
}

/**
 * Get request scheme
 *
 * @return string
 */
function getRequestScheme()
{
    return isSecureRequest() ? 'https' : 'http';
}

/**
 * Get request host
 *
 * Code borrowed to Symfony project
 *
 * @return string
 */
function getRequestHost()
{
    $possibleHostSources = ['HTTP_X_FORWARDED_HOST', 'HTTP_HOST', 'SERVER_NAME', 'SERVER_ADDR'];
    $sourceTransformations = [
        "HTTP_X_FORWARDED_HOST" => function ($value) {
            $elements = explode(',', $value);
            return trim(end($elements));
        }
    ];

    $host = '';
    foreach ($possibleHostSources as $source) {
        if (!empty($host)) {
            break;
        }

        if (empty($_SERVER[$source])) {
            continue;
        }

        $host = $_SERVER[$source];

        if (array_key_exists($source, $sourceTransformations)) {
            $host = $sourceTransformations[$source]($host);
        }
    }

    // trim and remove port number from host
    // host is lowercase as per RFC 952/2181
    $host = strtolower(preg_replace('/:\d+$/', '', trim($host)));

    // as the host can come from the user (HTTP_HOST and depending on the
    // configuration, SERVER_NAME too can come from the user) check that it
    // does not contain forbidden characters (see RFC 952 and RFC 2181)
    // use preg_replace() instead of preg_match() to prevent DoS attacks with
    // long host names
    if ($host && '' !== preg_replace('/(?:^\[)?[a-zA-Z0-9-:\]_]+\.?/', '', $host)) {
        throw new \UnexpectedValueException(sprintf('Invalid Host "%s"', $host));
    }

    return $host;
}

/**
 * Get request port
 *
 * @return string
 */
function getRequestPort()
{
    if (!empty($_SERVER['HTTP_X_FORWARDED_PORT'])) {
        return $_SERVER['HTTP_X_FORWARDED_PORT'];
    }

    if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
        return 443;
    }

    if ($host = $_SERVER['HTTP_HOST']) {
        if ($host[0] == '[') {
            $pos = strpos($host, ':', strrpos($host, ']'));
        } else {
            $pos = strrpos($host, ':');
        }

        if (false !== $pos) {
            return (int)substr($host, $pos + 1);
        }

        return 'https' == getRequestScheme() ? 443 : 80;
    }

    return $_SERVER['SERVER_PORT'];
}

/**
 * Get HTTP host
 *
 * The port name will be appended to the host if it's non-standard.
 *
 * @return string
 */
function getHttpHost()
{
    $scheme = getRequestScheme();
    $port = getRequestPort();

    if (('http' == $scheme && $port == 80) || ('https' == $scheme && $port == 443)) {
        return getRequestHost();
    }

    return getRequestHost() . ':' . $port;
}

/**
 * Get request base URL
 *
 * @return string
 */
function getRequestBaseUrl()
{
    $scheme = getRequestScheme();
    $port = getRequestPort();

    if (('http' == $scheme && $port == 80) || ('https' == $scheme && $port == 443)) {
        return $scheme . '://' . getRequestHost();
    }

    return $scheme . '://' . getRequestHost() . ':' . $port;
}

//
// Logging related functions
//

/**
 * Writes a log message in database and notify administrator by email
 *
 * @param string $msg Message
 * @param int $logLevel Log level
 * @return void
 */
function writeLog($msg, $logLevel = E_USER_WARNING)
{
    if (getenv('IMSCP_INSTALLER')) {
        return;
    }

    $msg = '[' . getIpAddr() . '] ' . replaceHtml($msg);
    execQuery('INSERT INTO `log` (`log_time`,`log_message`) VALUES(NOW(), ?)', [$msg]);

    $cfg = Application::getInstance()->getConfig();
    if ($logLevel > $cfg['LOG_LEVEL']) {
        return;
    }

    $msg = strip_tags(preg_replace('/<br\s*\/?>/', "\n", $msg));

    if ($logLevel == E_USER_NOTICE) {
        $severity = 'Notice';
    } elseif ($logLevel == E_USER_WARNING) {
        $severity = 'Warning';
    } elseif ($logLevel == E_USER_ERROR) {
        $severity = 'Error';
    } else {
        $severity = 'Unknown error';
    }

    \iMSCP\Functions\Mail::sendMail([
        'mail_id'      => 'imscp-log',
        'username'     => tr('administrator'),
        'email'        => $cfg['DEFAULT_ADMIN_ADDRESS'],
        'subject'      => "i-MSCP Notification ($severity)",
        'message'      => tr('Dear {NAME},

This is an automatic email sent by your i-MSCP control panel:

Server name: {HOSTNAME}
Server IP:   {SERVER_IP}
Client IP:   {CLIENT_IP}
Version:     {VERSION}
Build:       {BUILDDATE}
Severity:    {MESSAGE_SEVERITY}

==========================================================================
{MESSAGE}
==========================================================================

Please do not reply to this email.

________________
i-MSCP Mailer'),
        'placeholders' => [
            '{USERNAME}'         => tr('administrator'),
            '{HOSTNAME}'         => $cfg['SERVER_HOSTNAME'],
            '{SERVER_IP}'        => $cfg['BASE_SERVER_PUBLIC_IP'],
            '{CLIENT_IP}'        => getIpAddr() ? getIpAddr() : 'unknown',
            '{VERSION}'          => $cfg['Version'],
            '{BUILDDATE}'        => $cfg['BuildDate'] ?: tr('Unavailable'),
            '{MESSAGE_SEVERITY}' => $severity,
            '{MESSAGE}'          => $msg
        ],
    ]);
}

//
// Database related functions
//

/**
 * Convenience function to prepare and execute a SQL statement with optional parameters
 *
 * For backward compatibility reasons, we return the underlying \PDOStatement object.
 *
 * @param string $sql SQL statement
 * @param array $parameters Parameter
 * @return \PDOStatement
 */
function execQuery(string $sql, array $parameters = NULL): \PDOStatement
{
    return Application::getInstance()->getDb()->createStatement($sql)->execute($parameters)->getResource();
}

/**
 * Quote SQL identifier
 *
 * Note: An Identifier is essentially a name of a database, table, or table column.
 *
 * @param  string $identifier Identifier to quote
 * @return string quoted identifier
 */
function quoteIdentifier($identifier)
{
    return $db = Application::getInstance()->getDb()->getPlatform()->quoteIdentifier($identifier);
}

/**
 * Quote value
 *
 * @param mixed $value Value to quote
 * @return mixed quoted value
 */
function quoteValue($value)
{
    return $db = Application::getInstance()->getDb()->getPlatform()->quoteValue($value);
}

//
// Unclassified functions
//

/**
 * Unset global variables
 *
 * @return void
 */
function unsetMessages()
{
    $GLOBALS = array_diff_key(
        $GLOBALS, array_fill_keys(['dmn_name', 'dmn_tpl', 'chtpl', 'step_one', 'step_two_data', 'ch_hpprops', 'local_data'], NULL)
    );

    $session = Application::getInstance()->getSession();
    $session->exchangeArray(array_diff_key($session->getArrayCopy(), array_fill_keys(
        [
            'dmn_name', 'dmn_tpl', 'chtpl', 'step_one', 'step_two_data', 'ch_hpprops', 'local_data', 'dmn_expire', 'dmn_url_forward',
            'dmn_type_forward', 'dmn_host_forward'
        ],
        NULL
    )));
}

/**
 * Turns byte counts to human readable format
 *
 * If you feel like a hard-drive manufacturer, you can start counting bytes by power of 1000 (instead of the generous 1024). Just set power to 1000.
 *
 * But if you are a floppy disk manufacturer and want to start counting in units of 1024 (for your "1.44 MB" disks ?) let the default value for power.
 *
 * The units for power 1000 are: ('B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')
 * Those for power 1024 are: ('B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB')
 *
 * @see http://physics.nist.gov/cuu/Units/binary.html
 * @param int|float $bytes Bytes value to convert
 * @param string $unit OPTIONAL Unit to calculate to
 * @param int $decimals OPTIONAL Number of decimal to be show
 * @param int $power OPTIONAL Power to use for conversion (1024 or 1000)
 * @return string
 */
function bytesHuman($bytes, $unit = NULL, $decimals = 2, $power = 1024)
{
    if ($power == 1000) {
        $units = ['B' => 0, 'kB' => 1, 'MB' => 2, 'GB' => 3, 'TB' => 4, 'PB' => 5, 'EB' => 6, 'ZB' => 7, 'YB' => 8];
    } elseif ($power == 1024) {
        $units = ['B' => 0, 'kiB' => 1, 'MiB' => 2, 'GiB' => 3, 'TiB' => 4, 'PiB' => 5, 'EiB' => 6, 'ZiB' => 7, 'YiB' => 8];
    } else {
        throw new \Exception('Unknown power value');
    }

    $value = 0;

    if ($bytes > 0) {
        if (!array_key_exists($unit, $units)) {
            if (NULL === $unit) {
                $pow = floor(log($bytes) / log($power));
                $unit = array_search($pow, $units);
            } else {
                throw new \Exception('Unknown unit value');
            }
        }

        $value = ($bytes / pow($power, floor($units[$unit])));
    } else {
        $unit = 'B';
    }

    // If decimals is not numeric or decimals is less than 0
    // then set default value
    if (!is_numeric($decimals) || $decimals < 0) {
        $decimals = 2;
    }

    // units Translation
    switch ($unit) {
        case 'B':
            $unit = tr('B');
            break;
        case 'kB':
            $unit = tr('kB');
            break;
        case 'kiB':
            $unit = tr('kiB');
            break;
        case 'MB':
            $unit = tr('MB');
            break;
        case 'MiB':
            $unit = tr('MiB');
            break;
        case 'GB':
            $unit = tr('GB');
            break;
        case 'GiB':
            $unit = tr('GiB');
            break;
        case 'TB':
            $unit = tr('TB');
            break;
        case 'TiB':
            $unit = tr('TiB');
            break;
        case 'PB':
            $unit = tr('PB');
            break;
        case 'PiB':
            $unit = tr('PiB');
            break;
        case 'EB':
            $unit = tr('EB');
            break;
        case 'EiB':
            $unit = tr('EiB');
            break;
        case 'ZB':
            $unit = tr('ZB');
            break;
        case 'ZiB':
            $unit = tr('ZiB');
            break;
        case 'YB':
            $unit = tr('YB');
            break;
        case 'YiB':
            $unit = tr('YiB');
            break;
    }

    return sprintf('%.' . $decimals . 'f ' . $unit, $value);
}

/**
 * Turns mebibyte counts to human readable format
 *
 * @see bytesHuman()
 * @param int|float $mebibyte Mebibyte value to convert
 * @param string $unit OPTIONAL Unit to calculate to
 * @param int $decimals OPTIONAL Number of decimal to be show
 * @param int $power OPTIONAL Power to use for conversion (1024 or 1000)
 * @return string
 */
function mebibytesHuman($mebibyte, $unit = NULL, $decimals = 2, $power = 1024)
{
    return bytesHuman($mebibyte * 1048576, $unit, $decimals, $power);
}

/**
 * Humanize database value
 *
 * @param int $value variable to be translated
 * @param bool $autosize calculate value in different unit (default false)
 * @param string $to OPTIONAL Unit to calclulate to ('B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')
 * @return String
 */
function humanizeDbValue($value, $autosize = false, $to = NULL)
{
    switch (strtolower($value)) {
        case '-1':
            return '-';
        case  '0':
            return '∞';
        case '_yes_':
        case 'yes':
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('Enabled')) . '</span>';
        case '_no_':
        case 'no':
        case '':
            return '<span style="color:#a3a3a3;font-weight:bold;">' . toHtml(tr('Disabled')) . '</span>';
        case('dmn|sql|mail'):
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('Web data, SQL data and mail data')) . '</span>';
        case 'sql|mail':
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('Mail data and SQL data only')) . '</span>';
        case 'dmn':
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('Web data only')) . '</span>';
        case 'sql':
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('SQL data only')) . '</span>';
        case 'mail':
            return '<span style="color:green;font-weight:bold;">' . toHtml(tr('Mail data only')) . '</span>';
        default:
            return toHtml($autosize ? mebibytesHuman($value, $to) : $value);
    }
}

/**
 * Return UNIX timestamp representing the first day of current month
 *
 * @param int|null $month OPTIONAL month, as returned by Date('m')
 * @param int|null $year OPTIONAL year as returned by Date('y')
 * @return int
 */
function getFirstDayOfMonth($month = NULL, $year = NULL): int
{
    $date = new \DateTime('first day of this month 00:00:00', new \DateTimeZone('UTC'));

    if ($month || $year) {
        $date->setDate($month ?: Date('m'), $year ?: Date('y'), $date->format('%d'));
    }

    return $date->getTimestamp();
}

/**
 * Return UNIX timestamp representing last day of current month
 *
 * @param int $month
 * @param int $year
 * @return int
 */
function getLastDayOfMonth(int $month = NULL, int $year = NULL): int
{
    $date = new \DateTime('last day of this month 23:59:59', new \DateTimeZone('UTC'));

    if ($month || $year) {
        $date->setDate($month ?: Date('m'), $year ?: Date('y'));
    }

    return $date->getTimestamp();
}

/**
 * Get list of available FTP filemanagers
 *
 * @return array
 */
function getFilemanagerList(): array
{
    $config = $db = Application::getInstance()->getConfig();
    if (isset($config['FILEMANAGERS']) && strtolower($config['FILEMANAGERS']) != 'no') {
        return explode(',', $config['FILEMANAGERS']);
    }

    return [];
}

/**
 * Returns client IP address
 *
 * @return string User's Ip address
 */
function getIpAddr(): string
{
    static $remoteIp = NULL;

    if (NULL === $remoteIp) {
        $remoteIp = new Zend\Http\PhpEnvironment\RemoteAddress;
        $remoteIp->setUseProxy();
        $remoteIp = $remoteIp->getIpAddress();
    }
    /*
    $ipAddr = !empty($_SERVER['HTTP_CLIENT_IP']) ? $_SERVER['HTTP_CLIENT_IP'] : false;

    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ipAddrs = explode(', ', $_SERVER['HTTP_X_FORWARDED_FOR']);
        if ($ipAddr) {
            array_unshift($ipAddrs, $ipAddr);
            $ipAddr = false;
        }

        $countIpAddrs = count($ipAddrs);
        // Loop over ip stack as long an ip out of private range is not found
        for ($i = 0; $i < $countIpAddrs; $i++) {
            if (filter_var($ipAddrs[$i], FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE)) {
                $ipAddr = $ipAddrs[$i];
                break;
            }
        }
    }

    return $ipAddr ? $ipAddr : (isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : tr('Unknown'));
    */
    return $remoteIp;
}

/**
 * Check that limits for the given hosting plan are not exceeding limits of the given reseller
 *
 * @param int|string $hp Hosting plan unique identifier or string representing hosting plan properties to check against
 * @param int $resellerId Reseller unique identifier
 * @return bool TRUE if none of the given hosting plan limits is exceeding limits of the given reseller, FALSE otherwise
 */
function validateHostingPlanLimits($hp, int $resellerId): bool
{
    $ret = true;

    if (isNumber($hp)) {
        $session = Application::getInstance()->getSession();

        if (isset($session['ch_hpprops'])) {
            $hostingPlanProperties = $session['ch_hpprops'];
        } else {
            $stmt = execQuery('SELECT props FROM hosting_plans WHERE id = ?', [$hp]);
            if (($hostingPlanProperties = $stmt->fetchColumn()) === false) {
                throw new \Exception('Hosting plan not found');
            }
        }
    } else {
        $hostingPlanProperties = $hp;
    }

    list(, , $newSubLimit, $newAlsLimit, $newMailLimit, $newFtpLimit, $newSqlDbLimit, $newSqlUserLimit, $newTrafficLimit,
        $newDiskspaceLimit) = explode(';', $hostingPlanProperties);

    $stmt = execQuery('SELECT * FROM reseller_props WHERE reseller_id = ?', [$resellerId]);
    $data = $stmt->fetch();
    $currentDmnLimit = $data['current_dmn_cnt'];
    $maxDmnLimit = $data['max_dmn_cnt'];
    $currentSubLimit = $data['current_sub_cnt'];
    $maxSubLimit = $data['max_sub_cnt'];
    $currentAlsLimit = $data['current_als_cnt'];
    $maxAlsLimit = $data['max_als_cnt'];
    $currentMailLimit = $data['current_mail_cnt'];
    $maxMailLimit = $data['max_mail_cnt'];
    $currentFtpLimit = $data['current_ftp_cnt'];
    $ftpMaxLimit = $data['max_ftp_cnt'];
    $currentSqlDbLimit = $data['current_sql_db_cnt'];
    $maxSqlDbLimit = $data['max_sql_db_cnt'];
    $currentSqlUserLimit = $data['current_sql_user_cnt'];
    $maxSqlUserLimit = $data['max_sql_user_cnt'];
    $currentTrafficLimit = $data['current_traff_amnt'];
    $maxTrafficLimit = $data['max_traff_amnt'];
    $currentDiskspaceLimit = $data['current_disk_amnt'];
    $maxDiskspaceLimit = $data['max_disk_amnt'];

    if ($maxDmnLimit != 0 && $currentDmnLimit + 1 > $maxDmnLimit) {
        View::setPageMessage(tr('You have reached your domains limit. You cannot add more domains.'), 'error');
        $ret = false;
    }

    if ($maxSubLimit != 0 && $newSubLimit != -1) {
        if ($newSubLimit == 0) {
            View::setPageMessage(tr('You have a subdomains limit. You cannot add a user with unlimited subdomains.'), 'error');
            $ret = false;
        } else if ($currentSubLimit + $newSubLimit > $maxSubLimit) {
            View::setPageMessage(tr('You are exceeding your subdomains limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxAlsLimit != 0 && $newAlsLimit != -1) {
        if ($newAlsLimit == 0) {
            View::setPageMessage(tr('You have a domain aliases limit. You cannot add a user with unlimited domain aliases.'), 'error');
            $ret = false;
        } else if ($currentAlsLimit + $newAlsLimit > $maxAlsLimit) {
            View::setPageMessage(tr('You are exceeding you domain aliases limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxMailLimit != 0) {
        if ($newMailLimit == 0) {
            View::setPageMessage(tr('You have a mail accounts limit. You cannot add a user with unlimited mail accounts.'), 'error');
            $ret = false;
        } else if ($currentMailLimit + $newMailLimit > $maxMailLimit) {
            View::setPageMessage(tr('You are exceeding your mail accounts limit.'), 'error');
            $ret = false;
        }
    }

    if ($ftpMaxLimit != 0) {
        if ($newFtpLimit == 0) {
            View::setPageMessage(tr('You have a FTP accounts limit. You cannot add a user with unlimited FTP accounts.'), 'error');
            $ret = false;
        } else if ($currentFtpLimit + $newFtpLimit > $ftpMaxLimit) {
            View::setPageMessage(tr('You are exceeding your FTP accounts limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxSqlDbLimit != 0 && $newSqlDbLimit != -1) {
        if ($newSqlDbLimit == 0) {
            View::setPageMessage(tr('You have a SQL databases limit. You cannot add a user with unlimited SQL databases.'), 'error');
            $ret = false;
        } else if ($currentSqlDbLimit + $newSqlDbLimit > $maxSqlDbLimit) {
            View::setPageMessage(tr('You are exceeding your SQL databases limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxSqlUserLimit != 0 && $newSqlUserLimit != -1) {
        if ($newSqlUserLimit == 0) {
            View::setPageMessage(tr('You have a SQL users limit. You cannot add a user with unlimited SQL users.'), 'error');
            $ret = false;
        } elseif ($newSqlDbLimit == -1) {
            View::setPageMessage(tr('You have disabled SQL databases for this user. You cannot have SQL users here.'), 'error');
            $ret = false;
        } elseif ($currentSqlUserLimit + $newSqlUserLimit > $maxSqlUserLimit) {
            View::setPageMessage(tr('You are exceeding your SQL users limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxTrafficLimit != 0) {
        if ($newTrafficLimit == 0) {
            View::setPageMessage(tr('You have a monthly traffic limit. You cannot add a user with unlimited monthly traffic.'), 'error');
            $ret = false;
        } elseif ($currentTrafficLimit + $newTrafficLimit > $maxTrafficLimit) {
            View::setPageMessage(tr('You are exceeding your monthly traffic limit.'), 'error');
            $ret = false;
        }
    }

    if ($maxDiskspaceLimit != 0) {
        if ($newDiskspaceLimit == 0) {
            View::setPageMessage(tr('You have a disk space limit. You cannot add a user with unlimited disk space.'), 'error');
            $ret = false;
        } elseif ($currentDiskspaceLimit + $newDiskspaceLimit > $maxDiskspaceLimit) {
            View::setPageMessage(tr('You are exceeding your disk space limit.'), 'error');
            $ret = false;
        }
    }

    return $ret;
}


/**
 * Get mount points
 *
 * @param int $domainId Customer primary domain unique identifier
 * @return array List of mount points
 */
function getMountpoints(int $domainId): array
{
    static $mountpoints = [];

    if (empty($mountpoints)) {
        $stmt = execQuery(
            '
                SELECT subdomain_mount AS mount_point FROM subdomain WHERE domain_id = ?
                UNION ALL
                SELECT alias_mount AS mount_point FROM domain_aliases WHERE domain_id = ?
                UNION ALL
                SELECT subdomain_alias_mount AS mount_point FROM subdomain_alias
                JOIN domain_aliases USING(alias_id) WHERE domain_id = ?
            ',
            [$domainId, $domainId, $domainId]
        );

        if ($stmt->rowCount()) {
            $mountpoints = $stmt->fetchAll(\PDO::FETCH_COLUMN);
        }

        array_unshift($mountpoints, '/'); // primary domain mount point
    }

    return $mountpoints;
}

/**
 * Get mount point and document root for the given domain
 *
 * @param int $domainId Domain unique identifier
 * @param string $domainType Domain type (dmn,als,sub,alssub)
 * @param int $ownerId Domain owner unique identifier
 * @return array Array containing domain mount point and document root
 */
function getDomainMountpoint(int $domainId, string $domainType, int $ownerId): array
{
    switch ($domainType) {
        case 'dmn':
            $query = "SELECT '/' AS mount_point, document_root FROM domain WHERE domain_id = ? AND domain_admin_id = ?";
            break;
        case 'sub':
            $query = '
              SELECT subdomain_mount AS mount_point, subdomain_document_root AS document_root
              FROM subdomain
              JOIN domain USING(domain_id)
              WHERE subdomain_id = ?
              AND domain_admin_id = ?
            ';
            break;
        case 'als':
            $query = '
              SELECT alias_mount AS mount_point, alias_document_root AS document_root
              FROM domain_aliases
              JOIN domain USING(domain_id)
              WHERE alias_id = ?
              AND domain_admin_id = ?
            ';
            break;
        case 'alssub':
            $query = '
              SELECT subdomain_alias_mount AS mount_point, subdomain_alias_document_root AS document_root
              FROM subdomain_alias
              JOIN domain_aliases USING(alias_id)
              JOIN domain USING(domain_id)
              WHERE subdomain_alias_id = ?
              AND domain_admin_id = ?
            ';
            break;
        default:
            throw new \Exception('Unknown domain type');
    }

    $stmt = execQuery($query, [$domainId, $ownerId]);
    if (!$stmt->rowCount()) {
        throw new \Exception("Couldn't find domain data");
    }

    return $stmt->fetch(\PDO::FETCH_NUM);
}


/**
 * Delete the given subdomain, including any entity that belong to it
 *
 * @param int $id Subdomain unique identifier
 * @return void
 */
function deleteSubdomain(int $id): void
{
    ignore_user_abort(true);
    set_time_limit(0);

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    $stmt = execQuery(
        "
            SELECT t1.domain_id, CONCAT(t1.subdomain_name, '.', t2.domain_name) AS subdomain_name, t1.subdomain_mount
            FROM subdomain AS t1
            JOIN domain AS t2 USING(domain_id)
            WHERE t1.subdomain_id = ?
            AND t2.domain_admin_id = ?
        ",
        [$id, $identity->getUserId()]
    );
    $stmt->rowCount() or \iMSCP\Functions\View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteSubdomain, NULL, [
            'subdomainId'   => $id,
            'subdomainName' => $row['subdomain_name'],
            'subdomainType' => 'sub'
        ]);

        // Delete FTP groups and FTP accounting/limit data
        $stmt = execQuery(
            "SELECT groupname, members FROM ftp_group JOIN ftp_users USING(gid) WHERE userid LIKE CONCAT('%@', ?) LIMIT 1", [$row['subdomain_name']]
        );
        if ($stmt->rowCount()) {
            $ftpGroupData = $stmt->fetch();
            $members = array_filter(
                preg_split('/,/', $ftpGroupData['members'], -1, PREG_SPLIT_NO_EMPTY),
                function ($member) use ($row) {
                    return !preg_match("/@{$row['subdomain_name']}$/", $member);
                }
            );

            if (empty($members)) {
                execQuery('DELETE FROM ftp_group WHERE groupname = ?', [$ftpGroupData['groupname']]);
                execQuery('DELETE FROM quotalimits WHERE name = ?', [$ftpGroupData['groupname']]);
                execQuery('DELETE FROM quotatallies WHERE name = ?', [$ftpGroupData['groupname']]);
            } else {
                execQuery('UPDATE ftp_group SET members = ? WHERE groupname = ?', [implode(',', $members), $ftpGroupData['groupname']]);
            }

            unset($ftpGroupData, $members);
        }

        // Delete PHP ini entries
        execQuery("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'sub'", [$id]);
        // Schedule FTP accounts deletion
        execQuery("UPDATE ftp_users SET status = 'todelete' WHERE userid LIKE ?", ['%@' . $row['subdomain_name']]);
        // Schedule mail accounts deletion
        execQuery("UPDATE mail_users SET status = 'todelete' WHERE sub_id = ? AND mail_type LIKE '%subdom_%'", [$id]);
        // Schedule SSL certificates deletion
        execQuery("UPDATE ssl_certs SET status = 'todelete' WHERE domain_id = ? AND domain_type = 'sub'", [$id]);
        // Schedule protected area deletion        
        execQuery("UPDATE htaccess SET status = 'todelete' WHERE dmn_id = ? AND path LIKE ?", [
            $row['domain_id'], normalizePath($row['subdomain_mount']) . '%'
        ]);

        // Schedule subdomain deletion
        execQuery("UPDATE subdomain SET subdomain_status = 'todelete' WHERE subdomain_id = ?", [$id]);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteSubdomain, NULL, [
            'subdomainId'   => $id,
            'subdomainName' => $row['subdomain_name'],
            'subdomainType' => 'sub'
        ]);

        $db->getDriver()->getConnection()->commit();
        \iMSCP\Functions\Daemon::sendRequest();
        writeLog(
            sprintf(
                'Deletion of the %s subdomain has been scheduled by %s', decodeIdna($row['subdomain_alias_name']), decodeIdna($identity->getUsername())
            ),
            E_USER_NOTICE
        );
        View::setPageMessage(tr('Subdomain scheduled for deletion.'), 'success');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to remove a subdomain: %s', $e->getMessage()), E_ERROR);
        View::setPageMessage(tr("Couldn't delete subdomain. An unexpected error occurred."), 'error');
    }
}

/**
 * Delete the given subdomain alias, including any entity that belong to it
 *
 * @param int $id Subdomain alias unique identifier
 * @return void
 */
function deleteSubdomainAlias(int $id): void
{
    ignore_user_abort(true);
    set_time_limit(0);

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $domainId = getCustomerMainDomainId($identity->getUserId());
    $stmt = execQuery(
        "
            SELECT CONCAT(t1.subdomain_alias_name, '.', t2.alias_name) AS subdomain_alias_name, t1.subdomain_alias_mount
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            WHERE t2.domain_id = ?
            AND t1.subdomain_alias_id = ?
        ",
        [$domainId, $id]
    );
    $stmt->rowCount() or \iMSCP\Functions\View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteSubdomain, NULL, [
            'subdomainId'   => $id,
            'subdomainName' => $row['subdomain_alias_name'],
            'subdomainType' => 'alssub'
        ]);

        // Delete FTP groups and FTP accounting/limit data
        $stmt = execQuery("SELECT groupname, members FROM ftp_group JOIN ftp_users USING(gid) WHERE userid LIKE CONCAT('%@', ?) LIMIT 1", [
            $row['subdomain_alias_name']
        ]);
        if ($stmt->rowCount()) {
            $ftpGroupData = $stmt->fetch();
            $members = array_filter(
                preg_split('/,/', $ftpGroupData['members'], -1, PREG_SPLIT_NO_EMPTY),
                function ($member) use ($row) {
                    return !preg_match("/@{$row['subdomain_alias_name']}$/", $member);
                }
            );

            if (empty($members)) {
                execQuery('DELETE FROM ftp_group WHERE groupname = ?', $ftpGroupData['groupname']);
                execQuery('DELETE FROM quotalimits WHERE name = ?', $ftpGroupData['groupname']);
                execQuery('DELETE FROM quotatallies WHERE name = ?', $ftpGroupData['groupname']);
            } else {
                execQuery('UPDATE ftp_group SET members = ? WHERE groupname = ?', [implode(',', $members), $ftpGroupData['groupname']]);
            }

            unset($ftpGroupData, $members);
        }

        // Delete PHP ini entries
        execQuery("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'subals'", $id);

        // Schedule FTP accounts deletion
        execQuery("UPDATE ftp_users SET status = 'todelete' WHERE userid LIKE ?", '%@' . $row['subdomain_alias_name']);

        // Schedule mail accounts deletion
        execQuery("UPDATE mail_users SET status = 'todelete' WHERE sub_id = ? AND mail_type LIKE '%alssub_%'", $id);

        // Schedule SSL certificates deletion
        execQuery("UPDATE ssl_certs SET status = 'todelete' WHERE domain_id = ? AND domain_type = 'alssub'", $id);

        // Schedule protected areas deletion
        execQuery("UPDATE htaccess SET status = 'todelete' WHERE dmn_id = ? AND path LIKE ?", [
            $domainId, normalizePath($row['subdomain_alias_mount']) . '%'
        ]);

        // Schedule subdomain aliases deletion
        execQuery("UPDATE subdomain_alias SET subdomain_alias_status = 'todelete' WHERE subdomain_alias_id = ?", $id);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteSubdomain, NULL, [
            'subdomainId'   => $id,
            'subdomainName' => $row['subdomain_alias_name'],
            'subdomainType' => 'alssub'
        ]);

        $db->getDriver()->getConnection()->commit();

        \iMSCP\Functions\Daemon::sendRequest();
        writeLog(
            sprintf(
                'Deletion of the %s subdomain has been scheduled by %s', decodeIdna($row['subdomain_alias_name']), decodeIdna($identity->getUsername())
            ),
            E_USER_NOTICE
        );
        View::setPageMessage(tr('Subdomain scheduled for deletion.'), 'success');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to remove a subdomain: %s', $e->getMessage()), E_ERROR);
        View::setPageMessage(tr("Couldn't delete subdomain. An unexpected error occurred."), 'error');
        redirectTo('domains_manage.php');
    }
}

/**
 * Is the SQL databases limit of the logged-in customer has been reached?
 *
 * @return bool TRUE if SQL database limit is reached, FALSE otherwise
 */
function customerSqlDbLimitIsReached(): bool
{
    $domainProps = getCustomerProperties($identity = Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    if ($domainProps['domain_sqld_limit'] == 0
        || \iMSCP\Functions\Counting::getCustomerSqlDatabasesCount($domainProps['domain_id']) < $domainProps['domain_sqld_limit']
    ) {
        return false;
    }

    return true;
}

/**
 * Load the given i-MSCP service configuration file (<service>.data file)
 *
 * @param string $configFilePath Configuration file path
 * @return array
 */
function loadServiceConfigFile(string $configFilePath): array
{
    $configFilePath = normalizePath($configFilePath);
    $id = md5($configFilePath);

    if (Application::getInstance()->getCache()->hasItem($id)) {
        return Application::getInstance()->getCache()->getItem($id);
    }

    // Setup reader for Java .properties configuration file
    \Zend\Config\Factory::registerReader('data', \Zend\Config\Reader\JavaProperties::class);
    $reader = new \Zend\Config\Reader\JavaProperties('=', \Zend\Config\Reader\JavaProperties::WHITESPACE_TRIM);
    $config = $reader->fromFile($configFilePath);

    Application::getInstance()->getCache()->setItem($id, $config);
    return $config;
}

/**
 * Retrieve username of current processor
 *
 * An identity can be "usurped" either by administrators or resellers.
 * This method make it possible to retrieve the real processor of current request.
 *
 * @param UserIdentityInterface $identity
 * @return string
 */
function getProcessorUsername(UserIdentityInterface $identity): string
{
    static $username = NULL;

    if (NULL == $username) {
        if ($identity instanceof SuIdentityInterface) {
            if ($identity->getSuIdentity() instanceof SuIdentityInterface) {
                $username = $identity->getSuIdentity()->getSuUsername();
            } else {
                $username = $identity->getSuUsername();
            }
        } else {
            $username = decodeIdna($identity->getUsername());
        }
    }

    return $username;
}
