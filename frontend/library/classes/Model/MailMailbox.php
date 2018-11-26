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
 * Class Mailbox
 * @ORM\Entity
 * @ORM\Table(name="imscp_mail_mailbox", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class MailMailbox
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $mailboxID;

    /**
     * @var int
     */
    private $mailDomainID;

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
     * @ORM\Column(type="string")
     * @var string
     */
    private $mailbox;

    /**
     * @ORM\Column(type="string")
     * @var string|null
     */
    private $passwordHash;

    /**
     * @ORM\Column(type="integer", nullable=true)
     * @var int|null
     */
    private $quota;

    /**
     * @ORM\Column(type="text", nullable=true)
     * @var string|null
     */
    private $aliases;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $keepLocalCopy = false;

    /**
     * @ORM\Column(type="text", nullable=true)
     * @var string|null
     */
    private $autoreply;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isAutoreplyActive = false;


    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isDefault = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isCatchall = false;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isPoActive = true;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isActive = true;

    /**
     * @return int
     */
    public function getMailboxID(): int
    {
        return $this->mailboxID;
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
     * @return MailMailbox
     */
    public function setMailDomainID(int $mailDomainID): MailMailbox
    {
        $this->mailDomainID = $mailDomainID;
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
     * @param User $user
     * @return MailMailbox
     */
    public function setUser(User $user): MailMailbox
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
     * @return MailMailbox
     */
    public function setServer(Server $server): MailMailbox
    {
        $this->server = $server;
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
     * @return MailMailbox
     */
    public function setMailbox(string $mailbox): MailMailbox
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
     * @return MailMailbox
     */
    public function setPasswordHash(string $passwordHash = NULL): MailMailbox
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
     * @return MailMailbox
     */
    public function setQuota(int $quota = NULL): MailMailbox
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
     * @return MailMailbox
     */
    public function setAliases(string $aliases = NULL): MailMailbox
    {
        $this->aliases = $aliases;
        return $this;
    }

    /**
     * @return bool
     */
    public function getKeepLocalCopy(): bool
    {
        return $this->keepLocalCopy;
    }

    /**
     * @param bool $keepLocalCopy
     * @return MailMailbox
     */
    public function setKeepLocalCopy(bool $keepLocalCopy): MailMailbox
    {
        $this->keepLocalCopy = $keepLocalCopy;
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
     * @return MailMailbox
     */
    public function setAutoreply(string $autoreply = NULL): MailMailbox
    {
        $this->autoreply = $autoreply;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsAutoreplyActive(): bool
    {
        return $this->isAutoreplyActive;
    }

    /**
     * @param bool $isAutoreplyActive
     * @return MailMailbox
     */
    public function setIsAutoreplyActive(bool $isAutoreplyActive): MailMailbox
    {
        $this->isAutoreplyActive = $isAutoreplyActive;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsDefault(): bool
    {
        return $this->isDefault;
    }

    /**
     * @param bool $isDefault
     * @return MailMailbox
     */
    public function setIsDefault(bool $isDefault): MailMailbox
    {
        $this->isDefault = $isDefault;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsCatchall(): bool
    {
        return $this->isCatchall;
    }

    /**
     * @param bool $isCatchall
     * @return MailMailbox
     */
    public function setIsCatchall(bool $isCatchall): MailMailbox
    {
        $this->isCatchall = $isCatchall;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsPoActive(): bool
    {
        return $this->isPoActive;
    }

    /**
     * @param bool $isPoActive
     * @return MailMailbox
     */
    public function setIsPoActive(bool $isPoActive): MailMailbox
    {
        $this->isPoActive = $isPoActive;
        return $this;
    }

    /**
     * @return bool
     */
    public function getIsActive(): bool
    {
        return $this->isActive;
    }

    /**
     * @param bool $isActive
     * @return MailMailbox
     */
    public function setIsActive(bool $isActive): MailMailbox
    {
        $this->isActive = $isActive;
        return $this;
    }
}
