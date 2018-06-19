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
 * Class Mailbox
 * @package iMSCP\Model
 */
class Mailbox extends BaseModel
{
    /**
     * @var int
     */
    private $mailboxID;

    /**
     * @var int
     */
    private $mailDomainID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $serverID;

    /**
     * @var string
     */
    private $mailbox;

    /**
     * @var string|null
     */
    private $passwordHash;

    /**
     * @var int|null
     */
    private $quota;

    /**
     * @var string|null
     */
    private $aliases;

    /**
     * @var string|null
     */
    private $autoreply;

    /**
     * @var int
     */
    private $keepLocalCopy = 0;

    /**
     * @var int
     */
    private $isDefault = 0;

    /**
     * @var int
     */
    private $isCatchall = 0;

    /**
     * @var int
     */
    private $isPoActive = 1;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getMailboxID(): int
    {
        return $this->mailboxID;
    }

    /**
     * @param int $mailboxID
     * @return Mailbox
     */
    public function setMailboxID(int $mailboxID): Mailbox
    {
        $this->mailboxID = $mailboxID;
        return $this;
    }

    /**
     * @return int
     */
    public function getMailDomainID(): int
    {
        return $this->mailDomainID;
    }

    /**
     * @param int $mailDomainID
     * @return Mailbox
     */
    public function setMailDomainID(int $mailDomainID): Mailbox
    {
        $this->mailDomainID = $mailDomainID;
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
     * @return Mailbox
     */
    public function setUserID(int $userID): Mailbox
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
     * @return Mailbox
     */
    public function setServerID(int $serverID): Mailbox
    {
        $this->serverID = $serverID;
        return $this;
    }

    /**
     * @return string
     */
    public function getMailbox(): string
    {
        return $this->mailbox;
    }

    /**
     * @param string $mailbox
     * @return Mailbox
     */
    public function setMailbox(string $mailbox): Mailbox
    {
        $this->mailbox = $mailbox;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getPasswordHash(): ?string
    {
        return $this->passwordHash;
    }

    /**
     * @param string|null $passwordHash
     * @return Mailbox
     */
    public function setPasswordHash(string $passwordHash = NULL): Mailbox
    {
        $this->passwordHash = $passwordHash;
        return $this;
    }

    /**
     * @return int|null
     */
    public function getQuota(): ?int
    {
        return $this->quota;
    }

    /**
     * @param int $quota |null
     * @return Mailbox
     */
    public function setQuota(int $quota = NULL): Mailbox
    {
        $this->quota = $quota;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getAliases(): ?string
    {
        return $this->aliases;
    }

    /**
     * @param string|null $aliases
     * @return Mailbox
     */
    public function setAliases(string $aliases = NULL): Mailbox
    {
        $this->aliases = $aliases;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getAutoreply(): ?string
    {
        return $this->autoreply;
    }

    /**
     * @param string|null $autoreply
     * @return Mailbox
     */
    public function setAutoreply(string $autoreply = NULL): Mailbox
    {
        $this->autoreply = $autoreply;
        return $this;
    }

    /**
     * @return int
     */
    public function getKeepLocalCopy(): int
    {
        return $this->keepLocalCopy;
    }

    /**
     * @param int $keepLocalCopy
     * @return Mailbox
     */
    public function setKeepLocalCopy(int $keepLocalCopy): Mailbox
    {
        $this->keepLocalCopy = $keepLocalCopy;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsDefault(): int
    {
        return $this->isDefault;
    }

    /**
     * @param int $isDefault
     * @return Mailbox
     */
    public function setIsDefault(int $isDefault): Mailbox
    {
        $this->isDefault = $isDefault;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsCatchall(): int
    {
        return $this->isCatchall;
    }

    /**
     * @param int $isCatchall
     * @return Mailbox
     */
    public function setIsCatchall(int $isCatchall): Mailbox
    {
        $this->isCatchall = $isCatchall;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsPoActive(): int
    {
        return $this->isPoActive;
    }

    /**
     * @param int $isPoActive
     * @return Mailbox
     */
    public function setIsPoActive(int $isPoActive): Mailbox
    {
        $this->isPoActive = $isPoActive;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return Mailbox
     */
    public function setIsActive(int $isActive): Mailbox
    {
        $this->isActive = $isActive;
        return $this;
    }
}
