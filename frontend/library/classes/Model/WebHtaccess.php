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
 * Class WebHtaccess
 * @ORM\Entity
 * @ORM\Table(
 *     name="imscp_web_htaccess",
 *     options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci"}
 * )
 * @package iMSCP\Model
 */
class WebHtaccess
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webHtaccessID;

    /**
     * @ORM\ManyToOne(targetEntity="WebDomain")
     * @ORM\JoinColumn(name="webDomainID", referencedColumnName="webDomainID", onDelete="CASCADE")
     * @var WebDomain
     */
    private $webDomain;

    /**
     * @ORM\ManyToOne(targetEntity="WebHtgroup")
     * @ORM\JoinColumn(name="webHtgroupID", referencedColumnName="webHtgroupID")
     * @var WebHtgroup|null
     */
    private $webHtgroup;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $authName;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $path;

    public function __construct(WebDomain $webDomain, string $authName, WebHtgroup $htgroup = null)
    {
        $this->setWebDomain($webDomain);
        $this->setAuthName($authName);
        $this->setWebHtgroup($htgroup);
    }

    /**
     * @return int
     */
    public function getWebHtaccessID(): int
    {
        return $this->webHtaccessID;
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
     * @return WebHtaccess
     */
    public function setWebDomain(WebDomain $webDomain): WebHtaccess
    {
        $this->webDomain = $webDomain;
        return $this;
    }

    /**
     * @return WebHtpasswd|null
     */
    public function getWebHtpasswd(): ?WebHtpasswd
    {
        return $this->webHtpasswd;
    }

    /**
     * @param WebHtpasswd|null $webHtpasswd
     * @return WebHtaccess
     */
    public function setWebHtpasswd(WebHtpasswd $webHtpasswd = NULL): WebHtaccess
    {
        $this->webHtpasswd = $webHtpasswd;
        return $this;
    }

    /**
     * @return WebHtgroup|null
     */
    public function getWebHtgroup(): ?WebHtgroup
    {
        return $this->webHtgroup;
    }

    /**
     * @param WebHtgroup|null $webHtgroup
     * @return WebHtaccess
     */
    public function setWebHtgroup(WebHtgroup $webHtgroup = NULL): WebHtaccess
    {
        $this->webHtgroup = $webHtgroup;
        return $this;
    }

    /**
     * @return string
     */
    public function getAuthName(): string
    {
        return $this->authName;
    }

    /**
     * @param string $authName
     * @return WebHtaccess
     */
    public function setAuthName(string $authName): WebHtaccess
    {
        $this->authName = $authName;
        return $this;
    }

    /**
     * @return string
     */
    public function getPath(): string
    {
        return $this->path;
    }

    /**
     * @param string $path
     * @return WebHtaccess
     */
    public function setPath(string $path): WebHtaccess
    {
        $this->path = $path;
        return $this;
    }
}
