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
 * Class PhpEditorLimit
 * @package iMSCP\Model
 */
class UserPhpEditorLimit extends BaseModel
{
    /**
     * @var int
     */
    private $userPhpEditorlimitID;
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
    private $value;

    /**
     * @return int
     */
    public function getUserPhpEditorlimitID(): int
    {
        return $this->userPhpEditorlimitID;
    }

    /**
     * @param int $userPhpEditorlimitID
     * @return UserPhpEditorLimit
     */
    public function setUserPhpEditorlimitID(int $userPhpEditorlimitID): UserPhpEditorLimit
    {
        $this->userPhpEditorlimitID = $userPhpEditorlimitID;
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
     * @return UserPhpEditorLimit
     */
    public function setUserID(int $userID): UserPhpEditorLimit
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
     * @return UserPhpEditorLimit
     */
    public function setName(string $name): UserPhpEditorLimit
    {
        $this->name = $name;
        return $this;
    }

    /**
     * @return string
     */
    public function getValue(): string
    {
        return $this->value;
    }

    /**
     * @param string $value
     * @return UserPhpEditorLimit
     */
    public function setValue(string $value): UserPhpEditorLimit
    {
        $this->value = $value;
        return $this;
    }
    
    
}
