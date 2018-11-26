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
 * Class WebHtpasswd
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_htpasswd", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebHtpasswd 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webHtpasswdID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var int
     */
    private $user;
    
    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $username;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $passwordHash;

    /**
     * WebHtpasswd constructor
     *
     * @param User $user
     * @param string $username
     * @param $passwordHash
     */
    public function __construct(User $user, string $username, $passwordHash)
    {
        $this->setUser($user);
        $this->setUsername($username);
        $this->setPasswordHash($passwordHash);
    }

    /**
     * @return int
     */
    public function getWebHtpasswdID(): int
    {
        return $this->webHtpasswdID;
    }

    /**
     * @return int
     */
    public function getUser(): int
    {
        return $this->user;
    }

    /**
     * @param int $user
     * @return WebHtpasswd
     */
    public function setUser(int $user): WebHtpasswd
    {
        $this->user = $user;
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
     * @return WebHtpasswd
     */
    public function setUsername(string $username): WebHtpasswd
    {
        $this->username = $username;
        return $this;
    }

    /**
     * @return string
     */
    public function getPasswordHash(): string
    {
        return $this->passwordHash;
    }

    /**
     * @param string $passwordHash
     * @return WebHtpasswd
     */
    public function setPasswordHash(string $passwordHash): WebHtpasswd
    {
        $this->passwordHash = $passwordHash;
        return $this;
    }
}
