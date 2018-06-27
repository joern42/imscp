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
 * Class WebBackup
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_backup", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebBackup
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webBackupID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\ManyToOne(targetEntity="Server")
     * @ORM\JoinColumn(name="serverID", referencedColumnName="serverID", onDelete="CASCADE")
     * @var Server
     */
    private $server;

    /**
     * @ORM\ManyToOne(targetEntity="WebDomain")
     * @ORM\JoinColumn(name="webDomainID", referencedColumnName="webDomainID", onDelete="CASCADE")
     * @var WebDomain
     */
    private $webDomain;

    /**
     * WebBackup constructor.
     * @param User $user
     * @param Server $server
     * @param WebDomain $webDomain
     */
    public function __construct(User $user, Server $server, WebDomain $webDomain)
    {
        $this->setUser($user);
        $this->setServer($server);
        $this->setWebDomain($webDomain);
    }
    
    /**
     * @return string
     */
    public function getWebBackupID(): string
    {
        return $this->webBackupID;
    }

    /**
     * @return User
     */
    public function getUser(): User
    {
        return $this->user;
    }

    /**
     * @param User $user
     * @return WebBackup
     */
    public function setUser(User $user): WebBackup
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return Server
     */
    public function getServer(): Server
    {
        return $this->server;
    }

    /**
     * @param Server $server
     * @return WebBackup
     */
    public function setServer(Server $server): WebBackup
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return WebDomain
     */
    public function getWebDomain(): WebDomain
    {
        return $this->webDomain;
    }

    /**
     * @param WebDomain $webDomain
     * @return WebBackup
     */
    public function setWebDomain(WebDomain $webDomain): WebBackup
    {
        $this->webDomain = $webDomain;
        return $this;
    }
}
