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
 * Class CpLog
 * @ORM\Entity
 * @ORM\Table(
 *     name="imscp_cp_log", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"},
 *     indexes={@ORM\Index(columns={"logTime"})}
 * )
 * @ORM\HasLifecycleCallbacks()
 * @package iMSCP\Model
 */
class CpLog
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $cpLogID;

    /**
     * @ORM\Column(type="datetime_immutable")
     * @var \DateTimeImmutable
     */
    private $logTime;

    /**
     * @ORM\Column(type="text")
     * @var string
     */
    private $log;

    /**
     * CpLog constructor.
     * @param string $log
     */
    public function __construct(string $log)
    {
        $this->setLog($log);
    }

    /**
     * @return int
     */
    public function getCpLogID(): int
    {
        return $this->cpLogID;
    }

    /**
     * @return \DateTimeImmutable
     */
    public function getLogTime(): \DateTimeImmutable
    {
        return $this->logTime;
    }

    /**
     * @ORM\PrePersist()
     * @return CpLog
     */
    public function setLogTime(): CpLog
    {
        $this->logTime = new \DateTimeImmutable();
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
     * @return CpLog
     */
    private function setLog(string $log): CpLog
    {
        $this->log = $log;
        return $this;
    }
}
