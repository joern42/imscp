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

use Doctrine\ORM\Mapping as ORM;

/**
 * Class CpCustomMenu
 * @ORM\Entity
 * @ORM\Table(name="imscp_cp_custom_menu", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class CpCustomMenu
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $cpCustomMenuID;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $menuLevel;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $menuOrder = 0;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $menuName;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $menuLink;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $menuTarget = '_blank';

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isActive = true;

    /**
     * @return int
     */
    public function getCpCustomMenuID(): int
    {
        return $this->cpCustomMenuID;
    }

    /**
     * @return string
     */
    public function getMenuLevel(): string
    {
        return $this->menuLevel;
    }

    /**
     * @param string $menuLevel
     * @return CpCustomMenu
     */
    public function setMenuLevel(string $menuLevel): CpCustomMenu
    {
        $this->menuLevel = $menuLevel;
        return $this;
    }

    /**
     * @return int
     */
    public function getMenuOrder(): int
    {
        return $this->menuOrder;
    }

    /**
     * @param int $menuOrder
     * @return CpCustomMenu
     */
    public function setMenuOrder(int $menuOrder): CpCustomMenu
    {
        $this->menuOrder = $menuOrder;
        return $this;
    }

    /**
     * @return string
     */
    public function getMenuName(): string
    {
        return $this->menuName;
    }

    /**
     * @param string $menuName
     * @return CpCustomMenu
     */
    public function setMenuName(string $menuName): CpCustomMenu
    {
        $this->menuName = $menuName;
        return $this;
    }

    /**
     * @return string
     */
    public function getMenuLink(): string
    {
        return $this->menuLink;
    }

    /**
     * @param string $menuLink
     * @return CpCustomMenu
     */
    public function setMenuLink(string $menuLink): CpCustomMenu
    {
        $this->menuLink = $menuLink;
        return $this;
    }

    /**
     * @return string
     */
    public function getMenuTarget(): string
    {
        return $this->menuTarget;
    }

    /**
     * @param string $menuTarget
     * @return CpCustomMenu
     */
    public function setMenuTarget(string $menuTarget): CpCustomMenu
    {
        $this->menuTarget = $menuTarget;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsActive(): bool
    {
        return $this->isActive;
    }

    /**
     * @param bool $isActive
     * @return CpCustomMenu
     */
    public function setIsActive(bool $isActive): CpCustomMenu
    {
        $this->isActive = $isActive;
        return $this;
    }
}
