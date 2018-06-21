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
 * Class StoreAbstract
 * @package iMSCP\Model\Store
 * @KeyValue\Entity(storageName="imscp_storage")
 */
abstract class StoreAbstract
{
    /**
     * @KeyValue\Id
     */
    protected $storageID;

    /**
     * StoreAbstract constructor.
     */
    public function __construct()
    {
        $this->storageID = static::class;
    }
}
