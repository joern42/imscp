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
 * Class WebDomainPhpDirective
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_domain_php_directive", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebDomainPhpDirective
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webDomainPhpDirectiveID;

    /**
     * @ORM\ManyToOne(targetEntity="WebDomain")
     * @ORM\JoinColumn(name="webDomainID", referencedColumnName="webDomainID", onDelete="CASCADE")
     * @var WebDomain
     */
    private $webDomain;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $name;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $value;

    /**
     * @return int
     */
    public function getWebDomainPhpDirectiveID(): int
    {
        return $this->webDomainPhpDirectiveID;
    }

    /**
     * @param int $webDomainPhpDirectiveID
     * @return WebDomainPhpDirective
     */
    public function setWebDomainPhpDirectiveID(int $webDomainPhpDirectiveID): WebDomainPhpDirective
    {
        $this->webDomainPhpDirectiveID = $webDomainPhpDirectiveID;
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
     * @return WebDomainPhpDirective
     */
    public function setWebDomain(WebDomain $webDomain): WebDomainPhpDirective
    {
        $this->webDomain = $webDomain;
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
     * @return WebDomainPhpDirective
     */
    public function setName(string $name): WebDomainPhpDirective
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
     * @return WebDomainPhpDirective
     */
    public function setValue(string $value): WebDomainPhpDirective
    {
        $this->value = $value;
        return $this;
    }
}
