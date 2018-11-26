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
 * Class WebErrorPage
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_error_page", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebErrorPage 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webErrorPageID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $code;

    /**
     * @ORM\Column(type="text")
     * @var string
     */
    private $content;

    /**
     * @return int
     */
    public function getWebErrorPageID(): int
    {
        return $this->webErrorPageID;
    }

    /**
     * @param int $webErrorPageID
     * @return WebErrorPage
     */
    public function setWebErrorPageID(int $webErrorPageID): WebErrorPage
    {
        $this->webErrorPageID = $webErrorPageID;
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
     * @return WebErrorPage
     */
    public function setUser(User $user): WebErrorPage
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return int
     */
    public function getCode(): int
    {
        return $this->code;
    }

    /**
     * @param int $code
     * @return WebErrorPage
     */
    public function setCode(int $code): WebErrorPage
    {
        $this->code = $code;
        return $this;
    }

    /**
     * @return string
     */
    public function getContent(): string
    {
        return $this->content;
    }

    /**
     * @param string $content
     * @return WebErrorPage
     */
    public function setContent(string $content): WebErrorPage
    {
        $this->content = $content;
        return $this;
    }
}
