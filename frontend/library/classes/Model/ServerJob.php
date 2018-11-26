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
 * Class Job
 * @ORM\Entity
 * @ORM\Table(name="imscp_cp_job", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class ServerJob 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $jobID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\ManyToOne(targetEntity="Server")
     * @ORM\JoinColumn(name="serverID", referencedColumnName="serverID", onDelete="CASCADE")
     * @var Server
     */
    private $server;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $objectID;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $moduleName;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $moduleGroup;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $moduleAction;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $moduleData;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $state = 'scheduled';

    /**
     * @ORM\Column(type="string", length=16777215, nullable=true)
     * @var string|null
     */
    private $error;

    /**
     * @return int
     */
    public function getJobID(): int
    {
        return $this->jobID;
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
     * @return ServerJob
     */
    public function setUser(User $user): ServerJob
    {
        $this->user = $user;
        return $this;
    }

    /**
     * @return Server
     */
    public function getServer(): Server
    {
        return $this->server;
    }

    /**
     * @param Server $server
     * @return ServerJob
     */
    public function setServer(Server $server): ServerJob
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return int
     */
    public function getObjectID(): int
    {
        return $this->objectID;
    }

    /**
     * @param int $objectID
     * @return ServerJob
     */
    public function setObjectID(int $objectID): ServerJob
    {
        $this->objectID = $objectID;
        return $this;
    }

    /**
     * @return string
     */
    public function getModuleName(): string
    {
        return $this->moduleName;
    }

    /**
     * @param string $moduleName
     * @return ServerJob
     */
    public function setModuleName(string $moduleName): ServerJob
    {
        $this->moduleName = $moduleName;
        return $this;
    }

    /**
     * @return string
     */
    public function getModuleGroup(): string
    {
        return $this->moduleGroup;
    }

    /**
     * @param string $moduleGroup
     * @return ServerJob
     */
    public function setModuleGroup(string $moduleGroup): ServerJob
    {
        $this->moduleGroup = $moduleGroup;
        return $this;
    }

    /**
     * @return string
     */
    public function getModuleAction(): string
    {
        return $this->moduleAction;
    }

    /**
     * @param string $moduleAction
     * @return ServerJob
     */
    public function setModuleAction(string $moduleAction): ServerJob
    {
        $this->moduleAction = $moduleAction;
        return $this;
    }

    /**
     * @return string
     */
    public function getModuleData(): string
    {
        return $this->moduleData;
    }

    /**
     * @param string $moduleData
     * @return ServerJob
     */
    public function setModuleData(string $moduleData): ServerJob
    {
        $this->moduleData = $moduleData;
        return $this;
    }

    /**
     * @return string
     */
    public function getState(): string
    {
        return $this->state;
    }

    /**
     * @param string $state
     * @return ServerJob
     */
    public function setState(string $state): ServerJob
    {
        $this->state = $state;
        return $this;
    }

    /**
     * @return string
     */
    public function getError(): ?string
    {
        return $this->error;
    }

    /**
     * @param string|null $error
     * @return ServerJob
     */
    public function setError(string $error = NULL): ServerJob
    {
        $this->error = $error;
        return $this;
    }
}
