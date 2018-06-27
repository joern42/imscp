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
 * Class imscp_mail_catchall
 * @ORM\Entity
 * @ORM\Table(name="imscp_mail_catchall", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class MailCatchall
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $mailCatchallID;

    /**
     * @ORM\ManyToOne(targetEntity="MailDomain")
     * @ORM\JoinColumn(name="mailDomainID", referencedColumnName="mailDomainID", onDelete="CASCADE")
     * @var MailDomain
     */
    private $mailDomain;

    /**
     * @ORM\Column(type="simple_array", length=16777215)
     * @var array
     */
    private $catchallAddresses;

    /**
     * @param MailDomain $mailDomain
     * @param array $catchallAddresses
     */
    public function construct(MailDomain $mailDomain, array $catchallAddresses)
    {
        $this->setMailDomain($mailDomain);
        $this->setCatchallAddresses($catchallAddresses);
    }

    /**
     * @return string
     */
    public function getMailCatchallID(): string
    {
        return $this->mailCatchallID;
    }

    /**
     * @param string $mailCatchallID
     * @return MailCatchall
     */
    public function setMailCatchallID(string $mailCatchallID): MailCatchall
    {
        $this->mailCatchallID = $mailCatchallID;
        return $this;
    }

    /**
     * @return MailDomain
     */
    public function getMailDomain(): MailDomain
    {
        return $this->mailDomain;
    }

    /**
     * @param MailDomain $mailDomain
     * @return MailCatchall
     */
    public function setMailDomain(MailDomain $mailDomain): MailCatchall
    {
        $this->mailDomain = $mailDomain;
        return $this;
    }

    /**
     * @return array
     */
    public function getCatchallAddresses(): array
    {
        return $this->catchallAddresses;
    }

    /**
     * @param array $catchallAddresses
     * @return MailCatchall
     */
    public function setCatchallAddresses(array $catchallAddresses): MailCatchall
    {
        $this->catchallAddresses = $catchallAddresses;
        return $this;
    }
}
