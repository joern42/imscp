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
 * Class CpSupportTicket
 * @ORM\Entity
 * @ORM\Table(name="imscp_cp_support_ticket", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class CpSupportTicket
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $cpSupportTicketID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $fromUser;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $toUser;

    /**
     * @ORM\Column(type="string")
     * @var int
     */
    private $replyTo;

    /**
     * @ORM\Column(type="datetime_immutable")
     * @var \DateTimeImmutable
     */
    private $date;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $level;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $urgency;

    /**
     * @ORM\Column(type="integer")
     * @var int
     */
    private $state;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $subject;

    /**
     * @ORM\Column(type="text")
     * @var string
     */
    private $body;

    /**
     * @return int
     */
    public function getCpSupportTicketID(): int
    {
        return $this->cpSupportTicketID;
    }

    /**
     * @return User
     */
    public function getFromUser(): User
    {
        return $this->fromUser;
    }

    /**
     * @param User $fromUser
     * @return CpSupportTicket
     */
    public function setFromUser(User $fromUser): CpSupportTicket
    {
        $this->fromUser = $fromUser;
        return $this;
    }

    /**
     * @return User
     */
    public function getToUser(): User
    {
        return $this->toUser;
    }

    /**
     * @param User $toUser
     * @return CpSupportTicket
     */
    public function setToUser(User $toUser): CpSupportTicket
    {
        $this->toUser = $toUser;
        return $this;
    }

    /**
     * @return int|null
     */
    public function getReplyTo(): ?int
    {
        return $this->replyTo;
    }

    /**
     * @param int|null $replyTo
     * @return CpSupportTicket
     */
    public function setReplyTo(int $replyTo = NULL): CpSupportTicket
    {
        $this->replyTo = $replyTo;
        return $this;
    }

    /**
     * @return \DateTimeImmutable
     */
    public function getDate(): \DateTimeImmutable
    {
        return $this->date;
    }

    /**
     * @param \DateTimeImmutable $date
     * @return CpSupportTicket
     */
    public function setDate(\DateTimeImmutable $date): CpSupportTicket
    {
        $this->date = $date;
        return $this;
    }

    /**
     * @return int
     */
    public function getLevel(): int
    {
        return $this->level;
    }

    /**
     * @param int $level
     * @return CpSupportTicket
     */
    public function setLevel(int $level): CpSupportTicket
    {
        $this->level = $level;
        return $this;
    }

    /**
     * @return int
     */
    public function getUrgency(): int
    {
        return $this->urgency;
    }

    /**
     * @param int $urgency
     * @return CpSupportTicket
     */
    public function setUrgency(int $urgency): CpSupportTicket
    {
        $this->urgency = $urgency;
        return $this;
    }

    /**
     * @return int
     */
    public function getState(): int
    {
        return $this->state;
    }

    /**
     * @param int $state
     * @return CpSupportTicket
     */
    public function setState(int $state): CpSupportTicket
    {
        $this->state = $state;
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
     * @return CpSupportTicket
     */
    public function setSubject(string $subject): CpSupportTicket
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
     * @return CpSupportTicket
     */
    public function setBody(string $body): CpSupportTicket
    {
        $this->body = $body;
        return $this;
    }
}
