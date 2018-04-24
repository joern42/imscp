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
 * Class Statistics
 * @package iMSCP\Functions
 */
class Statistics
{
    /**
     * Return usage in percent
     *
     * @param  int $usage Current value
     * @param  int $usageMax (0 = unlimited)
     * @return float Usage in percent
     */
    public static function getPercentUsage(int $usage, int $usageMax): float
    {
        return sprintf('%.2f', min([100, $usageMax > 0 ? round($usage / $usageMax * 100, PHP_ROUND_HALF_ODD) : 0]));
    }

    /**
     * Get monthly traffic data for the given customer
     *
     * @param int $domainId Customer primary domain unique identifier
     * @return array An array container Web, FTP, SMTP, POP and total traffic (for the current month)
     */
    public static function getClientMonthlyTrafficStats(int $domainId): array
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                '
                    SELECT IFNULL(SUM(dtraff_web), 0) AS dtraff_web, IFNULL(SUM(dtraff_ftp), 0) AS dtraff_ftp,
                    IFNULL(SUM(dtraff_mail), 0) AS dtraff_smtp, IFNULL(SUM(dtraff_pop), 0) AS dtraff_pop
                    FROM domain_traffic
                    WHERE domain_id = ? 
                    AND dtraff_time BETWEEN ? AND ?
                '
            );
            $stmt->prepare();
        }

        $result = $stmt->execute([$domainId, getFirstDayOfMonth(), getLastDayOfMonth()])->getResource();
        if (($row = $result->fetch()) === false) {
            return array_fill(0, 5, 0);
        }

        return [
            $row['dtraff_web'],
            $row['dtraff_ftp'],
            $row['dtraff_smtp'],
            $row['dtraff_pop'],
            $row['dtraff_web'] + $row['dtraff_ftp'] + $row['dtraff_smtp'] + $row['dtraff_pop']
        ];
    }

    /**
     * Get statistics for the given client
     *
     * @param int $clientId User unique identifier
     * @return array
     */
    public static function getClientTrafficAndDiskStats(int $clientId): array
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT domain_id, IFNULL(domain_disk_usage, 0) AS disk_usage FROM domain WHERE domain_admin_id = ?'
            );
            $stmt->prepare();
        }

        $result = $stmt->execute([$clientId])->getResource();
        $row = $result->fetch() !== false or View::showBadRequestErrorPage();
        list($webTraffic, $ftpTraffic, $smtpTraffic, $popTraffic, $totalTraffic) = static::getClientMonthlyTrafficStats($row['domain_id']);

        return [$webTraffic, $ftpTraffic, $smtpTraffic, $popTraffic, $totalTraffic, $row['disk_usage']];
    }

    /**
     * Get count of consumed and max items for the given customer
     *
     * Note: For disk and traffic, only limit are returned.
     *
     * @param  int $clientId Client unique identifier
     * @return array
     */
    public static function getClientItemsCountAndLimits(int $clientId): array
    {
        $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                '
                    SELECT domain_id, domain_subd_limit, domain_alias_limit, domain_mailacc_limit, domain_ftpacc_limit, domain_sqld_limit,
                        domain_sqlu_limit, domain_traffic_limit, domain_disk_limit
                    FROM domain
                    WHERE domain_admin_id = ?
                '
            );
            $stmt->prepare();
        }

        $result = $stmt->execute([$clientId])->getResource();

        if (($row = $result->fetch()) === false) {
            return array_fill(0, 14, 0);
        }

        return [
            $row['domain_subd_limit'] == -1 ? 0 : Counting::getCustomerSubdomainsCount($row['domain_id']), $row['domain_subd_limit'],
            $row['domain_alias_limit'] == -1 ? 0 : Counting::getCustomerDomainAliasesCount($row['domain_id']), $row['domain_alias_limit'],
            $row['domain_mailacc_limit'] == -1 ? 0 : Counting::getCustomerMailAccountsCount($row['domain_id']), $row['domain_mailacc_limit'],
            $row['domain_ftpacc_limit'] == -1 ? 0 : Counting::getCustomerFtpUsersCount($clientId), $row['domain_ftpacc_limit'],
            $row['domain_sqld_limit'] == -1 ? 0 : Counting::getCustomerSqlDatabasesCount($row['domain_id']), $row['domain_sqld_limit'],
            $row['domain_sqlu_limit'] == -1 ? 0 : Counting::getCustomerSqlUsersCount($row['domain_id']), $row['domain_sqlu_limit'],
            $row['domain_traffic_limit'] * 1048576,
            $row['domain_disk_limit'] * 1048576
        ];
    }

    /**
     * Returns statistics about consumed items for the given reseller
     *
     * @param  int $resellerId Reseller unique indentifier
     * @return array An array containing total consumed for each items
     */
    public static function getResellerStats(int $resellerId): array
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                'SELECT t1.domain_admin_id FROM domain AS t1 JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id) WHERE t2.created_by = ?'
            );
            $stmt->prepare();
        }

        $result = $stmt->execute([$resellerId])->getResource();

        if ($result->rowCount() < 1) {
            return array_fill(0, 9, 0);
        }

        $rtraffConsumed = $rdiskConsumed = 0;

        while ($domainAdminId = $result->fetchColumn()) {
            $customerStats = static::getClientTrafficAndDiskStats($domainAdminId);
            $rtraffConsumed += $customerStats[4];
            $rdiskConsumed += $customerStats[5];
        }

        return [
            Counting::getResellerDomainsCount($resellerId),
            Counting::getResellerSubdomainsCount($resellerId),
            Counting::getResellerDomainAliasesCount($resellerId),
            Counting::getResellerMailAccountsCount($resellerId),
            Counting::getResellerFtpUsersCount($resellerId),
            Counting::getResellerSqlDatabasesCount($resellerId),
            Counting::getResellerSqlUsersCount($resellerId),
            $rtraffConsumed,
            $rdiskConsumed
        ];
    }
}
