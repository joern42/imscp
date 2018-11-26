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
 * Class WebHtgroup
 * @ORM\Entity
 * @ORM\Table(name="imscp_web_htgroup", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class WebHtgroup 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $webHtgroupID;

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
    private $groupName;

    /**
     * @ORM\Column(type="simple_array")
     * @var string|null
     */
    private $members;

    /**
     * WebHtpasswd constructor
     *
     * @param User $user
     * @param string $groupName
     */
    public function __construct(User $user, string $groupName)
    {
        $this->setUser($user);
        $this->setGroupName($groupName);
    }
    
    /**
     * @return int
     */
    public function getWebHtgroupID(): int
    {
        return $this->webHtgroupID;
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
     * @return WebHtgroup
     */
    public function setUser(User $user): WebHtgroup
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return string
     */
    public function getGroupName(): string
    {
        return $this->groupName;
    }

    /**
     * @param string $groupName
     * @return WebHtgroup
     */
    public function setGroupName(string $groupName): WebHtgroup
    {
        $this->groupName = $groupName;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getMembers(): ?string
    {
        return $this->members;
    }

    /**
     * @param string|null $members
     * @return WebHtgroup
     */
    public function setMembers(string $members = NULL): WebHtgroup
    {
        $this->members = $members;
        return $this;
    }
}
