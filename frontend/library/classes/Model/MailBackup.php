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
 * Class MailBackup
 * @ORM\Entity
 * @ORM\Table(name="imscp_mail_backup", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class MailBackup
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $mailBackupID;

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
     * @ORM\ManyToOne(targetEntity="MailDomain")
     * @ORM\JoinColumn(name="mailDomainID", referencedColumnName="mailDomainID", onDelete="CASCADE")
     * @var MailDomain
     */
    private $mailDomain;

    /**
     * MailBackup constructor.
     * @param User $user
     * @param Server $server
     * @param MailDomain $mailDomain
     */
    public function __construct(User $user, Server $server, MailDomain $mailDomain)
    {
        $this->setUser($user);
        $this->setServer($server);
        $this->setMailDomain($mailDomain);
    }

    /**
     * @return string
     */
    public function getMailBackupID(): string
    {
        return $this->mailBackupID;
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
     * @return MailBackup
     */
    public function setUser(User $user): MailBackup
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
     * @return MailBackup
     */
    public function setServer(Server $server): MailBackup
    {
        $this->server = $server;
        return $this;
    }

    /**
     * @return MailDomain
     */
    public function getMailDomain(): MailDomain
    {
        return $this->mailDomain;
    }

    /**
     * @param MailDomain $mailDomain
     * @return MailBackup
     */
    public function setMailDomain(MailDomain $mailDomain): MailBackup
    {
        $this->mailDomain = $mailDomain;
        return $this;
    }
}
