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
 * Class WebDomainAlias
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_domain_alias", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebDomainAlias 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webDomainAliasId;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $domainAliasName;

    /**
     * @ORM\Column(type="boolean")
     * @var int
     */
    private $automaticDNS = 1;

    /**
     * @return int
     */
    public function getWebDomainAliasId(): int
    {
        return $this->webDomainAliasId;
    }

    /**
     * @param int $webDomainAliasId
     * @return WebDomainAlias
     */
    public function setWebDomainAliasId(int $webDomainAliasId): WebDomainAlias
    {
        $this->webDomainAliasId = $webDomainAliasId;
        return $this;
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
     * @return WebDomainAlias
     */
    public function setUser(User $user): WebDomainAlias
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return string
     */
    public function getDomainAliasName(): string
    {
        return $this->domainAliasName;
    }

    /**
     * @param string $domainAliasName
     * @return WebDomainAlias
     */
    public function setDomainAliasName(string $domainAliasName): WebDomainAlias
    {
        $this->domainAliasName = $domainAliasName;
        return $this;
    }

    /**
     * @return int
     */
    public function getAutomaticDNS(): int
    {
        return $this->automaticDNS;
    }

    /**
     * @param int $automaticDNS
     * @return WebDomainAlias
     */
    public function setAutomaticDNS(int $automaticDNS): WebDomainAlias
    {
        $this->automaticDNS = $automaticDNS;
        return $this;
    }
}
