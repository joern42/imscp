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

namespace iMSCP\Model\Store;

use Doctrine\KeyValueStore\Mapping\Annotations as KeyValue;

/**
 * Class Services
 * @package iMSCP\Model\Store
 * @KeyValue\Entity(storageName="imscp_storage")
 */
class DatabaseRevision extends StoreAbstract
{
    /**
     * @var int
     */
    private $revision;

    /**
     * DatabaseRevision constructor.
     * @param int $revision
     */
    public function __construct(int $revision = 0)
    {
        $this->revision = $revision;
    }

    /**
     * Get database revision
     *
     * @return int
     */
    public function getRevision(): int
    {
        return $this->revision;
    }

    /**
     * Set database revision
     *
     * @param int $revision
     * @return DatabaseRevision
     */
    public function setRevision(int $revision): DatabaseRevision
    {
        $this->revision = $revision;
        return $this;
    }
}
