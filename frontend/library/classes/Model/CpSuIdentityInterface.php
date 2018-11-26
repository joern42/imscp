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
 * Interface SuIdentityInterface
 *
 * The SU identity is used to "usurp" an identity during a login session.
 * The original identity is referred as the 'SU' identity while the new
 * identity is referred  as the 'User' identity. This identity compose
 * the original identity and the "usurped" identity.
 *
 * @package iMSCP\Model
 */
interface CpSuIdentityInterface extends UserIdentityInterface
{
    /**
     * SuIdentity constructor.
     *
     * @param UserIdentityInterface $suIdentity
     * @param UserIdentityInterface $userIdentity
     */
    public function __construct(UserIdentityInterface $suIdentity, UserIdentityInterface $userIdentity);

    /**
     * Get SU identity
     *
     * @return UserIdentityInterface|CpSuIdentityInterface
     */
    public function getSuIdentity(): UserIdentityInterface;

    /**
     * Get User identity
     *
     * @return UserIdentityInterface
     */
    public function getUserIdentity(): UserIdentityInterface;

    /**
     * get SU user unique identitfier
     *
     * @return int
     */
    public function getSuUserId(): int;

    /**
     * Get SU user name
     *
     * @return string
     */
    public function getSuUsername(): string;

    /**
     * Get SU user email
     *
     * @return string
     */
    public function getSuUserEmail(): string;

    /**
     * get SU user type
     *
     * @return string
     */
    public function getSuUserType(): string;

    /**
     * Get SU user creator unique identifier
     *
     * @return int
     */
    public function getSuUserCreatedBy(): int;
}
