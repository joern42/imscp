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
 * Class UserIdentity
 * @package iMSCP\Model
 */
class UserIdentity implements UserIdentityInterface
{
    /**
     * @var int User unique identifier
     */
    protected $admin_id;

    /**
     * @var string Username
     */
    protected $admin_name;

    /**
     * @var string User password (hashed)
     */
    protected $admin_pass;

    /**
     * @var string User type (admin, reseller or client)
     */
    protected $admin_type;

    /**
     * @var string User email address
     */
    protected $email;

    /**
     * @var int User creator unique identifier
     */
    protected $created_by;

    /**
     * @inheritdoc
     */
    public function getUserId(): int
    {
        return $this->admin_id;
    }

    /**
     * @inheritdoc
     */
    public function getUsername(): string
    {
        return $this->admin_name;
    }

    /**
     * @inheritdoc
     */
    public function getUserPassword(): string
    {
        return $this->admin_pass;
    }

    /**
     * @inheritdoc
     */
    public function clearUserPassword(): void
    {
        $this->admin_pass = NULL;
    }

    /**
     * @inheritdoc
     */
    public function getUserType(): string
    {
        return $this->admin_type;
    }

    /**
     * @inheritdoc
     */
    public function getUserEmail(): string
    {
        return $this->email;
    }

    /**
     * @inheritdoc
     */
    public function getUserCreatedBy(): int
    {
        return $this->created_by;
    }
}
