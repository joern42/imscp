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

namespace iMSCP\Model\Store\Database;

use Doctrine\ORM\Mapping as ORM;
use iMSCP\Model\Store\StoreAbstract;

/**
 * Class DatabaseRevision
 * @package iMSCP\Model\Store\Database
 * @ORM\Entity
 * @ORM\Table(name="imscp_storages", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @ORM\ChangeTrackingPolicy("DEFERRED_EXPLICIT")
 */
class Revision extends StoreAbstract
{
    /**
     * Get database revision
     *
     * @return int
     */
    public function getRevision(): int
    {
        return $this->storageData;
    }

    /**
     * Set database revision
     *
     * @param int $revision
     * @return Revision
     */
    public function setRevision(int $revision): Revision
    {
        $this->storageData = $revision;
        return $this;
    }
}
