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
 * Class Ticket
 * @package iMSCP\Model
 */
class Ticket extends BaseModel
{
    /**
     * @var int
     */
    private $ticketID;

    /**
     * @var int
     */
    private $fromUserID;

    /**
     * @var int
     */
    private $toUserID;

    /**
     * @var int
     */
    private $replyTo;

    /**
     * @var \DateTimeImmutable
     */
    private $date;

    /**
     * @var int
     */
    private $level;

    /**
     * @var int
     */
    private $urgency;

    /**
     * @var int
     */
    private $state;

    /**
     * @var string
     */
    private $subject;

    /**
     * @var string
     */
    private $body;

    /**
     * @return int
     */
    public function getTicketID(): int
    {
        return $this->ticketID;
    }

    /**
     * @param int $ticketID
     * @return Ticket
     */
    public function setTicketID(int $ticketID): Ticket
    {
        $this->ticketID = $ticketID;
        return $this;
    }

    /**
     * @return int
     */
    public function getFromUserID(): int
    {
        return $this->fromUserID;
    }

    /**
     * @param int $fromUserID
     * @return Ticket
     */
    public function setFromUserID(int $fromUserID): Ticket
    {
        $this->fromUserID = $fromUserID;
        return $this;
    }

    /**
     * @return int
     */
    public function getToUserID(): int
    {
        return $this->toUserID;
    }

    /**
     * @param int $toUserID
     * @return Ticket
     */
    public function setToUserID(int $toUserID): Ticket
    {
        $this->toUserID = $toUserID;
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
     * @return Ticket
     */
    public function setReplyTo(int $replyTo = NULL): Ticket
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
     * @return Ticket
     */
    public function setDate(\DateTimeImmutable $date): Ticket
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
     * @return Ticket
     */
    public function setLevel(int $level): Ticket
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
     * @return Ticket
     */
    public function setUrgency(int $urgency): Ticket
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
     * @return Ticket
     */
    public function setState(int $state): Ticket
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
     * @return Ticket
     */
    public function setSubject(string $subject): Ticket
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
     * @return Ticket
     */
    public function setBody(string $body): Ticket
    {
        $this->body = $body;
        return $this;
    }
}
