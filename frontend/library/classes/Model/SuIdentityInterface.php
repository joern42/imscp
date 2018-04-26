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
 * @package iMSCP\Model
 */
interface SuIdentityInterface extends IdentityInterface
{
    /**
     * SuIdentity constructor.
     *
     * @param UserIdentity $suIdentity
     * @param UserIdentity $userIdentity
     */
    public function __construct(UserIdentity $suIdentity, UserIdentity $userIdentity);

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
