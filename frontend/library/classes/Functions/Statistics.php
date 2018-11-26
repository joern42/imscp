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
     * Get monthly traffic data for the given client
     *
     * @param int $clientID Client unique identifier
     * @return array An array container Web, FTP, SMTP, POP and total traffic (for the current month)
     */
    public static function getClientMonthlyTrafficStats(int $clientID): array
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement(
                '
                  SELECT IFNULL(SUM(web), 0) AS web, IFNULL(SUM(ftp), 0) AS ftp, IFNULL(SUM(smtp), 0) AS smtp, IFNULL(SUM(po), 0) AS po
                  FROM imscp_traffic
                  WHERE userID = ? 
                  AND trafficTime BETWEEN ? AND ?
                '
            );
            $stmt->prepare();
        }

        $result = $stmt->execute([$clientID, getFirstDayOfMonth(), getLastDayOfMonth()])->getResource();
        if (FALSE === ($row = $result->fetch())) {
            return array_fill(0, 5, 0);
        }

        return [$row['web'], $row['ftp'], $row['smtp'], $row['po'], $row['web'] + $row['ftp'] + $row['smtp'] + $row['po']];
    }

    /**
     * Get statistics for the given client
     *
     * @param int $clientID Client unique identifier
     * @return array
     */
    public static function getClientTrafficAndDiskStats(int $clientID): array
    {
        return array_merge(static::getClientMonthlyTrafficStats($clientID), getClientProperties($clientID)['diskUsage']);
    }

    /**
     * Get objects count and limits for the given client
     *
     * Diskspace and monthly traffic, only limit are returned.
     *
     * @param  int $clientID Client unique identifier
     * @return array
     */
    public static function getClientObjectsCountAndLimits(int $clientID): array
    {
        $clientProps = getClientProperties($clientID);

        return [
            $clientProps['domainsLimit'] == -1 ? 0 : Counting::getClientDomainsCount($clientID), $clientProps['domainsLimit'],
            $clientProps['subdomainsLimit'] == -1 ? 0 : Counting::getClientSubdomainsCount($clientID), $clientProps['subdomainsLimit'],
            $clientProps['mailboxesLimit'] == -1 ? 0 : Counting::getClientMailboxesCount($clientID), $clientProps['mailboxesLimit'],
            $clientProps['ftpUsersLimit'] == -1 ? 0 : Counting::getClientFtpUsersCount($clientID), $clientProps['ftpUsersLimit'],
            $clientProps['sqlDatabasesLimit'] == -1 ? 0 : Counting::getClientSqlDatabasesCount($clientID), $clientProps['sqlDatabasesLimit'],
            $clientProps['sqlUsersLimit'] == -1 ? 0 : Counting::getClientSqlDatabasesCount($clientID), $clientProps['sqlUsersLimit'],
            $clientProps['monthlyTrafficLimit'] * 1048576,
            $clientProps['diskspaceLimit'] * 1048576
        ];
    }

    /**
     * Returns statistics about consumed items for the given reseller
     *
     * @param  int $resellerID Reseller unique indentifier
     * @return array An array containing total consumed for each items
     */
    public static function getResellerStats(int $resellerID): array
    {
        static $stmt = NULL;

        if (NULL === $stmt) {
            $stmt = Application::getInstance()->getDb()->createStatement('SELECT userID FROM imscp_user WHERE created_by = ?');
            $stmt->prepare();
        }

        $result = $stmt->execute([$resellerID])->getResource();
        if ($result->rowCount() < 1) {
            return array_fill(0, 9, 0);
        }

        $trafficConsumption = 0;
        $diskspaceConsumption = 0;

        while ($row = $result->fetch()) {
            $customerStats = static::getClientTrafficAndDiskStats($row['userID']);
            $trafficConsumption += $customerStats[4];
            $diskspaceConsumption += $customerStats[5];
        }

        return [
            Counting::getResellerDomainsCount($resellerID),
            Counting::getResellerSubdomainsCount($resellerID),
            Counting::getResellerMailboxesCount($resellerID),
            Counting::getResellerFtpUsersCount($resellerID),
            Counting::getResellerSqlDatabasesCount($resellerID),
            Counting::getResellerSqlUsersCount($resellerID),
            $trafficConsumption,
            $diskspaceConsumption
        ];
    }
}
