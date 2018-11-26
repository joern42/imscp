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
 * Class CpClientDiskUsage
 * @ORM\Entity
 * @ORM\Table(name="imscp_user_disk_usage", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class UserDiskUsage
{
    private $userDiskUsageID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="string")
     * @var 
     */
    private $dataType;

    /**
     * @ORM\Column(type="bigint")
     * @var int
     */
    private $usageInBytes;

    /**
     * @return mixed
     */
    public function getUserDiskUsageID()
    {
        return $this->userDiskUsageID;
    }

    /**
     * @param mixed $userDiskUsageID
     * @return UserDiskUsage
     */
    public function setUserDiskUsageID($userDiskUsageID)
    {
        $this->userDiskUsageID = $userDiskUsageID;
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
     * @return mixed
     */
    public function getDataType()
    {
        return $this->dataType;
    }

    /**
     * @return int
     */
    public function getUsageInBytes(): int
    {
        return $this->usageInBytes;
    }
}
