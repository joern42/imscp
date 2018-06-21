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

/**
 * Class CpPreventExternalLogin
 * @package iMSCP\Model\Store\Setting
 */
class CpPreventExternalLogin implements SettingInterface
{
    const NAME = 'CpPreventExternalLogin';

    /**
     * @var bool
     */
    private $adminExternalLogin = false;

    /**
     * @var bool
     */
    private $resellerExternalLogin = false;

    /**
     * @var bool
     */
    private $clientExternalLogin = false;

    /**
     * @return string
     */
    public function getName()
    {
        return self::NAME;
    }

    /**
     * @return bool
     */
    public function isAdminExternalLogin(): bool
    {
        return $this->adminExternalLogin;
    }

    /**
     * @param bool $adminExternalLogin
     * @return CpPreventExternalLogin
     */
    public function setAdminExternalLogin(bool $adminExternalLogin): CpPreventExternalLogin
    {
        $this->adminExternalLogin = $adminExternalLogin;
        return $this;
    }

    /**
     * @return bool
     */
    public function isResellerExternalLogin(): bool
    {
        return $this->resellerExternalLogin;
    }

    /**
     * @param bool $resellerExternalLogin
     * @return CpPreventExternalLogin
     */
    public function setResellerExternalLogin(bool $resellerExternalLogin): CpPreventExternalLogin
    {
        $this->resellerExternalLogin = $resellerExternalLogin;
        return $this;
    }

    /**
     * @return bool
     */
    public function isClientExternalLogin(): bool
    {
        return $this->clientExternalLogin;
    }

    /**
     * @param bool $clientExternalLogin
     * @return CpPreventExternalLogin
     */
    public function setClientExternalLogin(bool $clientExternalLogin): CpPreventExternalLogin
    {
        $this->clientExternalLogin = $clientExternalLogin;
        return $this;
    }
}
