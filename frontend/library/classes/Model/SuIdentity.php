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
 * Class SuIdentity
 * @package iMSCP\Model
 */
class SuIdentity implements SuIdentityInterface
{
    /**
     * @var UserIdentityInterface
     */
    protected $suIdentity;

    /**
     * @var UserIdentityInterface
     */
    protected $userIdentity;

    /**
     * @inheritdoc
     */
    public function __construct(UserIdentityInterface $suIdentity, UserIdentityInterface $userIdentity)
    {
        $this->suIdentity = $suIdentity;
        $this->userIdentity = $userIdentity;
    }

    /**
     * @inheritdoc
     */
    public function getSuIdentity(): UserIdentityInterface
    {
        return $this->suIdentity;
    }

    /**
     * @inheritdoc
     */
    public function getUserIdentity(): UserIdentityInterface
    {
        return $this->userIdentity;
    }

    /**
     * @inheritdoc
     */
    public function getUserId(): int
    {
        return $this->userIdentity->getUserId();
    }

    /**
     * @inheritdoc
     */
    public function getUsername(): string
    {
        return $this->userIdentity->getUsername();
    }

    /**
     * @inheritdoc
     */
    public function getUserPassword(): string
    {
        return $this->userIdentity->getUserPassword();
    }

    /**
     * @inheritdoc
     */
    public function clearUserPassword(): void
    {
        $this->userIdentity->clearUserPassword();
    }

    /**
     * @inheritdoc
     */
    public function getUserEmail(): string
    {
        return $this->userIdentity->getUserEmail();
    }

    /**
     * @inheritdoc
     */
    public function getUserType(): string
    {
        return $this->userIdentity->getUserType();
    }

    /**
     * @inheritdoc
     */
    public function getUserCreatedBy(): int
    {
        return $this->userIdentity->getUserCreatedBy();
    }

    /**
     * @inheritdoc
     */
    public function getSuUserId(): int
    {
        return $this->suIdentity->getUserId();
    }

    /**
     * @inheritdoc
     */
    public function getSuUsername(): string
    {
        return $this->suIdentity->getUsername();
    }

    /**
     * @inheritdoc
     */
    public function getSuUserEmail(): string
    {
        return $this->suIdentity->getUserEmail();
    }

    /**
     * @inheritdoc
     */
    public function getSuUserType(): string
    {
        return $this->suIdentity->getUserType();
    }

    /**
     * @inheritdoc
     */
    public function getSuUserCreatedBy(): int
    {
        return $this->suIdentity->getUserCreatedBy();
    }
}
