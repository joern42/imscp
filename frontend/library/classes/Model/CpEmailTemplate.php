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
 * Class EmailTemplate
 * @ORM\Entity
 * @ORM\Table(name="imscp_cp_email_template", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class CpEmailTemplate
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $cpEmailTemplateID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $name;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $subject;

    /**
     * @ORM\Column(type="text", length=16777215)
     * @var string
     */
    private $body;

    /**
     * @return int
     */
    public function getCpEmailTemplateID(): int
    {
        return $this->cpEmailTemplateID;
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
     * @return CpEmailTemplate
     */
    public function setUser(User $user): CpEmailTemplate
    {
        $this->user = $user;
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
     * @return CpEmailTemplate
     */
    public function setName(string $name): CpEmailTemplate
    {
        $this->name = $name;
        return $this;
    }

    /**
     * @return string
     */
    public function getSubject(): string
    {
        return $this->subject;
    }

    /**
     * @param string $subject
     * @return CpEmailTemplate
     */
    public function setSubject(string $subject): CpEmailTemplate
    {
        $this->subject = $subject;
        return $this;
    }

    /**
     * @return string
     */
    public function getBody(): string
    {
        return $this->body;
    }

    /**
     * @param string $body
     * @return CpEmailTemplate
     */
    public function setBody(string $body): CpEmailTemplate
    {
        $this->body = $body;
        return $this;
    }
}
