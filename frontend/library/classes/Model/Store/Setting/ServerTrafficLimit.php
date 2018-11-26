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
 * Class ServerTrafficLimit
 * @package iMSCP\Model\Store\Setting
 */
class ServerTrafficLimit implements SettingInterface
{
    const NAME = 'ServerTrafficLimit';

    /**
     * @var string
     */
    private $hostname;

    /**
     * @var int
     */
    private $trafficLimit = 0;

    /**
     * @var int
     */
    private $trafficWarn = 0;

    /**
     * ServerTrafficLimit constructor.
     * @param string $hostname
     * @param int $trafficLimit
     * @param int $trafficWarn
     */
    public function __construct(string $hostname, int $trafficLimit = 0, int $trafficWarn = 0)
    {
        // TODO validation
        $this->hostname = $hostname;
        $this->trafficLimit = $trafficLimit;
        $this->trafficWarn = $trafficWarn;
    }

    /**
     * @return string
     */
    public function getName()
    {
        return self::NAME . '::' . $this->getHostname();
    }

    /**
     * @return string
     */
    public function getHostname(): string
    {
        return $this->hostname;
    }

    /**
     * @param string $hostname
     * @return ServerTrafficLimit
     */
    public function setHostname(string $hostname): ServerTrafficLimit
    {
        $this->hostname = $hostname;
        return $this;
    }

    /**
     * @return int
     */
    public function getTrafficLimit(): int
    {
        return $this->trafficLimit;
    }

    /**
     * @param int $trafficLimit
     * @return ServerTrafficLimit
     */
    public function setTrafficLimit(int $trafficLimit): ServerTrafficLimit
    {
        $this->trafficLimit = $trafficLimit;
        return $this;
    }

    /**
     * @return int
     */
    public function getTrafficWarn(): int
    {
        return $this->trafficWarn;
    }

    /**
     * @param int $trafficWarn
     * @return ServerTrafficLimit
     */
    public function setTrafficWarn(int $trafficWarn): ServerTrafficLimit
    {
        $this->trafficWarn = $trafficWarn;
        return $this;
    }
}
