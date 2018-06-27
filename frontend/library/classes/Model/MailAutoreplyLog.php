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
 * Class MailAutoreplyLog
 * @package iMSCP\Model\Service
 * @ORM\Entity
 * @ORM\Table(
 *     name="imscp_mail_autoreply_log", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"},
 *     indexes={@ORM\Index(columns={"autoreplyTime"}), @ORM\Index(columns={"autoreplyFrom"}), @ORM\Index(columns={"autoreplTo"})}
 * )
 */
class MailAutoreplyLog
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $autoreplyID;

    /**
     * @ORM\Column(type="datetime_immutable")
     * @var \DateTimeImmutable
     */
    private $autoreplyTime;

    /**
     * @ORM\Column(type="string")
     * @var
     */
    private $autoreplyFrom;

    /**
     * @ORM\Column(type="string")
     * @var
     */
    private $autoreplyTo;

    /**
     * @return string
     */
    public function getAutoreplyID(): string
    {
        return $this->autoreplyID;
    }

    /**
     * @return \DateTimeImmutable
     */
    public function getAutoreplyTime(): \DateTimeImmutable
    {
        return $this->autoreplyTime;
    }

    /**
     * @return mixed
     */
    public function getAutoreplyFrom()
    {
        return $this->autoreplyFrom;
    }

    /**
     * @return mixed
     */
    public function getAutoreplyTo()
    {
        return $this->autoreplyTo;
    }
}
