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
 * Interface IdentityInterface
 * @package iMSCP\Model
 */
interface IdentityInterface
{
    /**
     * Get user unique identifier
     *
     * @return int
     */
    public function getUserId(): int;

    /**
     * Get user name
     *
     * @return string
     */
    public function getUsername(): string;

    /**
     * Get user password (hashed)
     * @return string
     */
    public function getUserPassword(): string;

    /**
     * Get user email address
     *
     * @return string
     */
    public function getUserEmail(): string;

    /**
     * Get user type
     *
     * @return string
     */
    public function getUserType(): string;

    /**
     * Get user creator unique identifier
     *
     * @return int
     */
    public function getUserCreatedBy(): int;
}
