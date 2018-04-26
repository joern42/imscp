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

use iMSCP\Model\IdentityInterface;
use Zend\Authentication\Result;

/**
 * Class AuthResult
 * @package iMSCP\Authentication
 */
class AuthResult extends Result
{
    /**
     * The identity used in the authentication attempt
     *
     * @var IdentityInterface
     */
    protected $identity;

    /**
     * Sets the result code, identity, and failure messages
     *
     * @param  int $code
     * @param  mixed $identity
     * @param  array $messages
     */
    public function __construct(int $code, IdentityInterface $identity = NULL, array $messages = [])
    {
        $this->code = $code;
        $this->identity = $identity;
        $this->messages = $messages;
    }

    /**
     * Returns the identity used in the authentication attempt
     *
     * @return IdentityInterface
     */
    public function getIdentity(): IdentityInterface
    {
        return $this->identity;
    }
}
