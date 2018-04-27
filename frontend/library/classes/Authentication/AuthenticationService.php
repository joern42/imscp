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

namespace iMSCP\Authentication;

use iMSCP\Model\SuIdentityInterface;
use iMSCP\Model\UserIdentityInterface;

/**
 * Class AuthenticationService
 *
 * Extend ZF implementation to enforce identity type and make
 * it possible to set the identity outside of the authentication process.
 *
 * @package iMSCP\Authentication
 */
class AuthenticationService extends \Zend\Authentication\AuthenticationService
{
    /**
     * Returns the identity from storage or null if no identity is available
     *
     * @return UserIdentityInterface|SuIdentityInterface|null
     */
    public function getIdentity()
    {
        $storage = $this->getStorage();

        if ($storage->isEmpty()) {
            return NULL;
        }

        return $storage->read();
    }

    /**
     * Set the identity
     *
     * @param UserIdentityInterface $identity
     */
    public function setIdentity(UserIdentityInterface $identity)
    {
        /**
         * Prevent multiple successive calls from storing inconsistent results
         * Ensure storage has clean state
         */
        if ($this->hasIdentity()) {
            $this->clearIdentity();
        }

        $this->getStorage()->write($identity);
    }
}
