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
 * Class CpCustomMenu
 * @package iMSCP\Model
 */
class CpCustomMenu extends BaseModel
{
    /**
     * @var int
     */
    private $cpCustomMenuID;

    /**
     * @var string
     */
    private $menuLevel;

    /**
     * @var int
     */
    private $menuOrder = 0;

    /**
     * @var string
     */
    private $menuName;

    /**
     * @var string
     */
    private $menuLink;

    /**
     * @var string
     */
    private $menuTarget = '_blank';

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getCpCustomMenuID(): int
    {
        return $this->cpCustomMenuID;
    }

    /**
     * @param int $cpCustomMenuID
     * @return CpCustomMenu
     */
    public function setCpCustomMenuID(int $cpCustomMenuID): CpCustomMenu
    {
        $this->cpCustomMenuID = $cpCustomMenuID;
        return $this;
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
     * @return int
     */
    public function getIsActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return CpCustomMenu
     */
    public function setIsActive(int $isActive): CpCustomMenu
    {
        $this->isActive = $isActive;
        return $this;
    }
}
