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

namespace iMSCP\Model\Store\Setting;

use iMSCP\Model\Store\Service\SettingInterface;

/**
 * Class CpPasswordStrength
 * @package iMSCP\Model\Store\Setting
 */
class CpPasswordStrength implements SettingInterface
{
    const NAME = 'CpPasswordStrength';
    
    /**
     * @var int 
     */
    private $minPasswordChars = 6;

    /**
     * @var bool 
     */
    private $strongPassword = true;

    /**
     * @return string
     */
    public function getName()
    {
        return self::NAME;
    }

    /**
     * @return int
     */
    public function getMinPasswordChars(): int
    {
        return $this->minPasswordChars;
    }

    /**
     * @param int $minPasswordChars
     * @return CpPasswordStrength
     */
    public function setMinPasswordChars(int $minPasswordChars): CpPasswordStrength
    {
        $this->minPasswordChars = $minPasswordChars;
        return $this;
    }

    /**
     * @return bool
     */
    public function isStrongPassword(): bool
    {
        return $this->strongPassword;
    }

    /**
     * @param bool $strongPassword
     * @return CpPasswordStrength
     */
    public function setStrongPassword(bool $strongPassword): CpPasswordStrength
    {
        $this->strongPassword = $strongPassword;
        return $this;
    }
}
