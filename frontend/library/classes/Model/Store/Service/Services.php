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

namespace iMSCP\Model\Store\Service;

use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\KeyValueStore\Mapping\Annotations as KeyValue;
use iMSCP\Model\Store\StoreAbstract;

/**
 * Class Services
 * @package iMSCP\Model\Store
 * @KeyValue\Entity(storageName="imscp_storage")
 */
class Services extends StoreAbstract implements \IteratorAggregate
{
    /**
     * @var Service[]
     */
    private $services = [];

    /**
     * Services constructor.
     */
    public function __construct()
    {
        parent::__construct();
        $this->services = new ArrayCollection();
    }

    /**
     * Add a service
     *
     * @param Service $service
     * @return Services
     */
    public function addService(Service $service): Services
    {
        $this->services->add($service);
        return $this;
    }

    /**
     * Remove a service
     *
     * @param Service $service
     * @return Services
     */
    public function removeService(Service $service): Services
    {
        $this->services->removeElement($service);
        return $this;
    }

    /**
     * @return \ArrayIterator
     */
    public function getIterator(): \ArrayIterator
    {
        return $this->services->getIterator();
    }
}
