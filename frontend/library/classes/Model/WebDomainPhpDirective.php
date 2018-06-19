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

/**
 * Class WebDomainPhpDirective
 * @package iMSCP\Model
 */
class WebDomainPhpDirective
{
    /**
     * @var int
     */
    private $webDomainPhpDirectiveID;

    /**
     * @var int
     */
    private $webDomainID;

    /**
     * @var string
     */
    private $name;

    /**
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
     * @return int
     */
    public function getWebDomainID(): int
    {
        return $this->webDomainID;
    }

    /**
     * @param int $webDomainID
     * @return WebDomainPhpDirective
     */
    public function setWebDomainID(int $webDomainID): WebDomainPhpDirective
    {
        $this->webDomainID = $webDomainID;
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
