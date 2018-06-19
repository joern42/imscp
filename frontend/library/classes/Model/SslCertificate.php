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
 * Class SslCertificate
 * @package iMSCP\Model
 */
class SslCertificate extends BaseModel
{
    /**
     * @var int
     */
    private $sslCertificateID;

    /**
     * @var int
     */
    private $webDomainID;

    /**
     * @var string
     */
    private $privateKey;

    /**
     * @var string
     */
    private $certificate;

    /**
     * @var string
     */
    private $caBundle;

    /**
     * @var int
     */
    private $hsts = 0;

    /**
     * @var int
     */
    private $hstsMaxAge = 31536000;

    /**
     * @var int
     */
    private $hstsIncludeSubdomains = 0;

    /**
     * @return int
     */
    public function getSslCertificateID(): int
    {
        return $this->sslCertificateID;
    }

    /**
     * @param int $sslCertificateID
     * @return SslCertificate
     */
    public function setSslCertificateID(int $sslCertificateID): SslCertificate
    {
        $this->sslCertificateID = $sslCertificateID;
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
     * @return SslCertificate
     */
    public function setWebDomainID(int $webDomainID): SslCertificate
    {
        $this->webDomainID = $webDomainID;
        return $this;
    }

    /**
     * @return string
     */
    public function getPrivateKey(): string
    {
        return $this->privateKey;
    }

    /**
     * @param string $privateKey
     * @return SslCertificate
     */
    public function setPrivateKey(string $privateKey): SslCertificate
    {
        $this->privateKey = $privateKey;
        return $this;
    }

    /**
     * @return string
     */
    public function getCertificate(): string
    {
        return $this->certificate;
    }

    /**
     * @param string $certificate
     * @return SslCertificate
     */
    public function setCertificate(string $certificate): SslCertificate
    {
        $this->certificate = $certificate;
        return $this;
    }

    /**
     * @return string
     */
    public function getCaBundle(): string
    {
        return $this->caBundle;
    }

    /**
     * @param string $caBundle
     * @return SslCertificate
     */
    public function setCaBundle(string $caBundle): SslCertificate
    {
        $this->caBundle = $caBundle;
        return $this;
    }

    /**
     * @return int
     */
    public function getHsts(): int
    {
        return $this->hsts;
    }

    /**
     * @param int $hsts
     * @return SslCertificate
     */
    public function setHsts(int $hsts): SslCertificate
    {
        $this->hsts = $hsts;
        return $this;
    }

    /**
     * @return int
     */
    public function getHstsMaxAge(): int
    {
        return $this->hstsMaxAge;
    }

    /**
     * @param int $hstsMaxAge
     * @return SslCertificate
     */
    public function setHstsMaxAge(int $hstsMaxAge): SslCertificate
    {
        $this->hstsMaxAge = $hstsMaxAge;
        return $this;
    }

    /**
     * @return int
     */
    public function getHstsIncludeSubdomains(): int
    {
        return $this->hstsIncludeSubdomains;
    }

    /**
     * @param int $hstsIncludeSubdomains
     * @return SslCertificate
     */
    public function setHstsIncludeSubdomains(int $hstsIncludeSubdomains): SslCertificate
    {
        $this->hstsIncludeSubdomains = $hstsIncludeSubdomains;
        return $this;
    }
}
