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
 * Class MailDomain
 * @ORM\Entity
 * @ORM\Table(name="imscp_mail_domain", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class MailDomain 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $mailDomainID;

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
     * @ORM\Column(type="string")
     * @var string
     */
    private $domainName;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $hasAutomaticDNS = true;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $isActive = true;

    /**
     * @return int
     */
    public function getMailDomainID(): int
    {
        return $this->mailDomainID;
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
     * @return MailDomain
     */
    public function setUser(User $user): MailDomain
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
     * @return MailDomain
     */
    public function setServer(Server $server): MailDomain
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return string
     */
    public function getDomainName(): string
    {
        return $this->domainName;
    }

    /**
     * @param string $domainName
     * @return MailDomain
     */
    public function setDomainName(string $domainName): MailDomain
    {
        $this->domainName = $domainName;
        return $this;
    }

    /**
     * @return int
     */
    public function getHasAutomaticDNS(): int
    {
        return $this->hasAutomaticDNS;
    }

    /**
     * @param string $hasAutomaticDNS
     * @return MailDomain
     */
    public function setHasAutomaticDNS(string $hasAutomaticDNS): MailDomain
    {
        $this->hasAutomaticDNS = $hasAutomaticDNS;
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
     * @return MailDomain
     */
    public function setIsActive(bool $isActive): MailDomain
    {
        $this->isActive = $isActive;
        return $this;
    }
}
