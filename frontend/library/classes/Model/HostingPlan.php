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
 * Class HostingPlan
 * @package iMSCP\Model
 */
class HostingPlan extends BaseModel
{
    /**
     * @var int
     */
    private $hostingPlanID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var string
     */
    private $name;

    /**
     * @var string
     */
    private $description;

    /**
     * @var array
     */
    private $properties;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getHostingPlanID(): int
    {
        return $this->hostingPlanID;
    }

    /**
     * @param int $hostingPlanID
     * @return HostingPlan
     */
    public function setHostingPlanID(int $hostingPlanID): HostingPlan
    {
        $this->hostingPlanID = $hostingPlanID;
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
     * @return HostingPlan
     */
    public function setUserID(int $userID): HostingPlan
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return string
     */
    public function getName(): string
    {
        return $this->name;
    }

    /**
     * @param string $name
     * @return HostingPlan
     */
    public function setName(string $name): HostingPlan
    {
        $this->name = $name;
        return $this;
    }

    /**
     * @return string
     */
    public function getDescription(): string
    {
        return $this->description;
    }

    /**
     * @param string $description
     * @return HostingPlan
     */
    public function setDescription(string $description): HostingPlan
    {
        $this->description = $description;
        return $this;
    }

    /**
     * @return array
     */
    public function getProperties(): array
    {
        return $this->properties;
    }

    /**
     * @param array $properties
     * @return HostingPlan
     */
    public function setProperties(array $properties): HostingPlan
    {
        $this->properties = $properties;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return HostingPlan
     */
    public function setIsActive(int $isActive): HostingPlan
    {
        $this->isActive = $isActive;
        return $this;
    }
}
