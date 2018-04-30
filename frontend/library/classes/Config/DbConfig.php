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

namespace iMSCP\Config;

use iMSCP\Application;
use Zend\Db\Adapter\Adapter as DbAdapter;
use Zend\Db\Adapter\Driver\StatementInterface;

/**
 * Class DbConfig
 * @package iMSCP\Config
 */
class DbConfig extends \ArrayObject
{
    const INSERT_QUERY_COUNTER = 'insert';
    const UPDATE_QUERY_COUNTER = 'update';
    const DELETE_QUERY_COUNTER = 'delete';

    /**
     * @var string Database table name for configuration parameters
     */
    public static $tableName = 'config';

    /**
     * @var string Database column name for parameter keys
     */
    public static $keyColumn = 'name';

    /**
     * @var string Database column name for parameter values
     */
    public static $valueColumn = 'value';

    /**
     * @var DbAdapter
     */
    protected $db;

    /**
     * @var StatementInterface for insert queries
     */
    protected $insertStmt;

    /**
     * @var StatementInterface for update queries
     */
    protected $updateStmt;

    /**
     * @var StatementInterface for delete queries
     */
    protected $deleteStmt;

    /**
     * @var int Counter for update queries
     */
    protected $insertQueriesCounter = 0;

    /**
     * @var int Counter for insert queries
     */
    protected $updateQueriesCounter = 0;

    /**
     * @var int Counter for delete queries
     */
    protected $deleteQueriesCounter = 0;

    /**
     * DbConfig constructor
     * @param DbAdapter $db
     */
    public function __construct(DbAdapter $db)
    {
        $this->db = $db;

        $stmt = $this->db->createStatement(sprintf(
            'SELECT %s, %s FROM %s',
            $this->db->getPlatform()->quoteIdentifier(static::$keyColumn),
            $this->db->getPlatform()->quoteIdentifier(static::$valueColumn),
            $this->db->getPlatform()->quoteIdentifier(static::$tableName)
        ))->execute();

        parent::__construct($stmt->getResource()->fetchAll(\PDO::FETCH_KEY_PAIR), \ArrayObject::ARRAY_AS_PROPS);
    }

    /**
     * @inheritdoc
     */
    public function offsetSet($key, $value)
    {
        if (!$this->offsetExists($key)) {
            if (!$this->insertStmt instanceof StatementInterface) {
                $this->insertStmt = $this->db->createStatement(sprintf(
                    'INSERT INTO %s (%s, %s) VALUES (?,?)',
                    $this->db->getPlatform()->quoteIdentifier(static::$tableName),
                    $this->db->getPlatform()->quoteIdentifier(static::$keyColumn),
                    $this->db->getPlatform()->quoteIdentifier(static::$valueColumn)
                ));
                $this->insertStmt->prepare();
            }

            $this->insertStmt->execute([$key, $value]);
            $this->insertQueriesCounter++;
        } else {
            if (!$this->updateStmt instanceof StatementInterface) {
                $this->updateStmt = $this->db->createStatement(sprintf(
                    'UPDATE %s SET %s = ? WHERE %s = ?',
                    $this->db->getPlatform()->quoteIdentifier(static::$tableName),
                    $this->db->getPlatform()->quoteIdentifier(static::$valueColumn),
                    $this->db->getPlatform()->quoteIdentifier(static::$keyColumn)
                ));
                $this->updateStmt->prepare();
            }

            $result = $this->updateStmt->execute([$value, $key]);

            if (count($result)) {
                $this->updateQueriesCounter++;
            }
        }

        parent::offsetSet($key, $value);
    }

    /**
     * @inheritdoc
     */
    public function offsetUnset($key)
    {
        if (!$this->deleteStmt instanceof StatementInterface) {
            $this->deleteStmt = $this->db->createStatement(sprintf(
                'DELETE FROM %s WHERE %s = ?',
                $this->db->getPlatform()->quoteIdentifier(static::$tableName),
                $this->db->getPlatform()->quoteIdentifier(static::$keyColumn)
            ));
            $this->deleteStmt->prepare();
        }

        $result = $this->deleteStmt->execute([$key]);

        if (count($result)) {
            $this->deleteQueriesCounter++;
        }

        if ($this->offsetExists($key)) { // Avoid notice for undefined index...
            parent::offsetUnset($key);
        }
    }

    /**
     * Returns the count of SQL queries that were executed
     *
     * This method returns the count of queries that were executed since the
     * last call of {@link resetQueriesCounter()} method.
     *
     * @param string $queriesCounterType Query counter type
     * @return int
     */
    public function countQueries(string $queriesCounterType): int
    {
        switch ($queriesCounterType) {
            case self::INSERT_QUERY_COUNTER:
                return $this->insertQueriesCounter;
                break;
            case self::UPDATE_QUERY_COUNTER:
                return $this->updateQueriesCounter;
                break;
            case self::DELETE_QUERY_COUNTER:
                return $this->deleteQueriesCounter;
                break;
            default:
                throw new \InvalidArgumentException('Unknown queries counter.');
        }
    }

    /**
     * Reset a counter of queries
     *
     * @param string $queriesCounterType Query counter
     * @return void
     */
    public function resetQueriesCounter(string $queriesCounterType): void
    {
        switch ($queriesCounterType) {
            case self::INSERT_QUERY_COUNTER:
                $this->insertQueriesCounter = 0;
                break;
            case self::UPDATE_QUERY_COUNTER:
                $this->updateQueriesCounter = 0;
                break;
            case self::DELETE_QUERY_COUNTER:
                $this->deleteQueriesCounter = 0;
                break;
            default:
                throw new \InvalidArgumentException('Unknown queries counter.');
        }
    }

    /**
     * @inheritdoc
     */
    public function serialize()
    {
        $this->resetQueriesCounter(self::INSERT_QUERY_COUNTER);
        $this->resetQueriesCounter(self::UPDATE_QUERY_COUNTER);
        $this->resetQueriesCounter(self::DELETE_QUERY_COUNTER);
        unset($this->db, $this->insertStmt, $this->updateStmt, $this->deleteStmt);
        return parent::serialize();
    }

    /**
     * @inheritdoc
     */
    public function unserialize($serialized)
    {
        $this->db = Application::getInstance()->getDb();
        parent::unserialize($serialized);
    }
}
