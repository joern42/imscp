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
 * Class CpUserLogin
 * @ORM\Entity
 * @ORM\Table(
 *     name="imscp_cp_user_login",
 *     options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"},
 *     indexes={@ORM\Index(columns={"lastAccessTime"})}
 * )
 * @ORM\HasLifecycleCallbacks()
 * @package iMSCP\Model
 */
class CpUserLogin
{
    /**
     * @ORM\Id
     * @ORM\Column(type="string", unique=true)
     * @ORM\GeneratedValue(strategy="NONE")
     * @var string
     */
    private $cpUserLoginID;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $username;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $ipAddress;

    /**
     * @ORM\Column(type="datetime_immutable", columnDefinition="")
     * @var \DateTimeImmutable
     */
    private $lastAccessTime;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $loginCount;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $captchaCount;

    /**
     * CpLoging constructor
     *
     * @param string $cpUserLoginID
     * @param string|NULL $username
     * @param string $ipAddress
     */
    public function __construct(string $cpUserLoginID, string $username = null, string $ipAddress)
    {
        $this->setCpUserLoginID($cpUserLoginID);
        $this->setUsername($username);
        $this->setIpAddress($ipAddress);
    }

    /**
     * @return string
     */
    public function getCpUserLoginID(): string
    {
        return $this->cpUserLoginID;
    }

    /**
     * @param string $cpUserLoginID
     * @return CpUserLogin
     */
    public function setCpUserLoginID(string $cpUserLoginID): CpUserLogin
    {
        $this->cpUserLoginID = $cpUserLoginID;
        return $this;
    }

    /**
     * @return string
     */
    public function getUsername(): string
    {
        return $this->username;
    }

    /**
     * @param string $username
     * @return CpUserLogin
     */
    public function setUsername(string $username): CpUserLogin
    {
        $this->username = $username;
        return $this;
    }

    /**
     * @return string
     */
    public function getIpAddress(): string
    {
        return $this->ipAddress;
    }

    /**
     * @param string $ipAddress
     * @return CpUserLogin
     */
    public function setIpAddress(string $ipAddress): CpUserLogin
    {
        $this->ipAddress = $ipAddress;
        return $this;
    }

    /**
     * @return \DateTimeImmutable
     */
    public function getLastAccessTime(): \DateTimeImmutable
    {
        return $this->lastAccessTime;
    }

    /**
     * @ORM\PrePersist()
     * @ORM\PreUpdate()
     * @return CpUserLogin
     */
    public function setLastAccessTime(): CpUserLogin
    {
        $this->lastAccessTime = new \DateTimeImmutable;
        return $this;
    }

    /**
     * @return int
     */
    public function getLoginCount(): int
    {
        return $this->loginCount;
    }

    /**
     * @param int $loginCount
     * @return CpUserLogin
     */
    public function setLoginCount(int $loginCount): CpUserLogin
    {
        $this->loginCount = $loginCount;
        return $this;
    }

    /**
     * @return int
     */
    public function getCaptchaCount(): int
    {
        return $this->captchaCount;
    }

    /**
     * @param int $captchaCount
     * @return CpUserLogin
     */
    public function setCaptchaCount(int $captchaCount): CpUserLogin
    {
        $this->captchaCount = $captchaCount;
        return $this;
    }
}
