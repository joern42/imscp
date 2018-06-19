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
 * Class SqlDatabase
 * @package iMSCP\Model
 */
class SqlDatabase extends BaseModel
{
    /**
     * @var int
     */
    private $sqlDatabaseID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $databaseName;

    /**
     * @return int
     */
    public function getSqlDatabaseID(): int
    {
        return $this->sqlDatabaseID;
    }

    /**
     * @param int $sqlDatabaseID
     * @return SqlDatabase
     */
    public function setSqlDatabaseID(int $sqlDatabaseID): SqlDatabase
    {
        $this->sqlDatabaseID = $sqlDatabaseID;
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
     * @return SqlDatabase
     */
    public function setUserID(int $userID): SqlDatabase
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return int
     */
    public function getServerID(): int
    {
        return $this->serverID;
    }

    /**
     * @param int $serverID
     * @return SqlDatabase
     */
    public function setServerID(int $serverID): SqlDatabase
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getDatabaseName(): string
    {
        return $this->databaseName;
    }

    /**
     * @param string $databaseName
     * @return SqlDatabase
     */
    public function setDatabaseName(string $databaseName): SqlDatabase
    {
        $this->databaseName = $databaseName;
        return $this;
    }
}
