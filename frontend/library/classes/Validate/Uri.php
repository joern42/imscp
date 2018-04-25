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

namespace iMSCP\Validate;

use Zend\Uri\UriFactory;
use Zend\Validator\AbstractValidator;

/**
 * Class iMSCP_Validate_Uri
 */
class Uri extends AbstractValidator
{
    const INVALID_URI = 'invalidURI';

    protected $_messageTemplates = [
        self::INVALID_URI => "'%value%' is not a valid URI.",
    ];

    /**
     * Returns true if the $uri is valid
     *
     * If $uri is not a valid URI, then this method returns false, and getMessages() will return an array of messages that explain why the
     * validation failed.
     *
     * @param  string $uri URI to be validated
     * @return boolean
     */
    public function isValid($uri)
    {
        $uri = (string)$uri;
        $this->setValue($uri);

        try {
            UriFactory::factory($uri, 'iMSCP_Uri_Redirect');
        } catch (\Exception $e) {
            $this->error(self::INVALID_URI);
            return false;
        }

        return true;
    }
}
