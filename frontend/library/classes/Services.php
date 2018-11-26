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

namespace iMSCP;

use Doctrine\Common\Persistence\ObjectManager;
use iMSCP\Model\Store\Service\MonitoredService;
use iMSCP\Model\Store\Service\ServiceCollection;

/**
 * Class Services
 * @package iMSCP
 */
class Services implements \IteratorAggregate
{
    /**
     * @var
     */
    private $objectManager;

    /**
     * @var ServiceCollection
     */
    private $services;

    /**
     * Settings constructor
     * @param ObjectManager $objectManager
     */
    public function __construct(ObjectManager $objectManager)
    {
        $this->objectManager = $objectManager;
    }

    /**
     * Get service from service collection
     *
     * @param string $name Setting name
     * @return MonitoredService
     */
    public function getService(string $name): MonitoredService
    {
        return $this->getServices()->getService($name);
    }

    /**
     * Add service
     *
     * @param MonitoredService $service
     * @return Services
     */
    public function addService(MonitoredService $service): Services
    {
        $this->getServices()->addService($service);
        return $this;
    }

    /**
     * Delete service
     *
     * @param string $name
     * @return Services
     */
    public function deleteService(string $name): Services
    {
        $this->getServices()->deleteService($name);
        return $this;
    }

    /**
     * Save setting collection
     *
     * @return Services
     */
    public function saveServices(): Services
    {
        $this->getServices();

        foreach ($this as $service) {
            $this->services->addService(clone $service);
        }

        $this->objectManager->persist($this->services);
        $this->objectManager->flush();

        return $this;
    }

    /**
     * Is the given service known?
     *
     * @param string $name
     * @return bool
     */
    public function hasService(string $name): bool
    {
        try {
            $this->getServices()->getService($name);
            return true;
        } catch (\Throwable $e) {
            return false;
        }
    }

    /**
     * @inheritdoc
     * @çeturn Service[]
     */
    public function getIterator(): ServiceCollection
    {
        return $this->getServices();
    }

    /**
     * Get service collection
     *
     * @return ServiceCollection
     */
    protected function getServices(): ServiceCollection
    {
        if (NULL === $this->services) {
            $this->services = $this->objectManager->find(ServiceCollection::class, ServiceCollection::class);
        }

        return $this->services;
    }
}

