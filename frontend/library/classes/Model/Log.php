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
 * Class Log
 * @package iMSCP\Model
 */
class Log extends BaseModel
{
    /**
     * @var int
     */
    private $logID;

    /**
     * @var \DateTimeImmutable
     */
    private $logTime;

    /**
     * @var string
     */
    private $log;

    /**
     * @return int
     */
    public function getLogID(): int
    {
        return $this->logID;
    }

    /**
     * @param int $logID
     * @return Log
     */
    public function setLogID(int $logID): Log
    {
        $this->logID = $logID;
        return $this;
    }

    /**
     * @return \DateTimeImmutable
     */
    public function getLogTime(): \DateTimeImmutable
    {
        return $this->logTime;
    }

    /**
     * @param \DateTimeImmutable $logTime
     * @return Log
     */
    public function setLogTime(\DateTimeImmutable $logTime): Log
    {
        $this->logTime = $logTime;
        return $this;
    }

    /**
     * @return string
     */
    public function getLog(): string
    {
        return $this->log;
    }

    /**
     * @param string $log
     * @return Log
     */
    public function setLog(string $log): Log
    {
        $this->log = $log;
        return $this;
    }
}
