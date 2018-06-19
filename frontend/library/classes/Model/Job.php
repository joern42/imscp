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
 * Class Job
 * @package iMSCP\Model
 */
class Job extends BaseModel
{
    /**
     * @var int
     */
    private $jobID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var int
     */
    private $objectID;

    /**
     * @var string
     */
    private $moduleName;

    /**
     * @var string
     */
    private $moduleGroup;

    /**
     * @var string
     */
    private $moduleAction;

    /**
     * @var string
     */
    private $moduleData;

    /**
     * @var string
     */
    private $state = 'scheduled';

    /**
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
     * @param int $jobID
     * @return Job
     */
    public function setJobID(int $jobID): Job
    {
        $this->jobID = $jobID;
        return $this;
    }

    /**
     * @return int
     */
    public function getUserID(): int
    {
        return $this->userID;
    }

    /**
     * @param int $userID
     * @return Job
     */
    public function setUserID(int $userID): Job
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return int
     */
    public function getServerID(): int
    {
        return $this->serverID;
    }

    /**
     * @param int $serverID
     * @return Job
     */
    public function setServerID(int $serverID): Job
    {
        $this->serverID = $serverID;
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
     * @return Job
     */
    public function setObjectID(int $objectID): Job
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
     * @return Job
     */
    public function setModuleName(string $moduleName): Job
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
     * @return Job
     */
    public function setModuleGroup(string $moduleGroup): Job
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
     * @return Job
     */
    public function setModuleAction(string $moduleAction): Job
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
     * @return Job
     */
    public function setModuleData(string $moduleData): Job
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
     * @return Job
     */
    public function setState(string $state): Job
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
     * @return Job
     */
    public function setError(string $error = NULL): Job
    {
        $this->error = $error;
        return $this;
    }
}
