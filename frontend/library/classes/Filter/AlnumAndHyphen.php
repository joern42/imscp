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

namespace iMSCP\Filter;

use Locale;
use Zend\I18n\Filter\Alnum;
use Zend\Stdlib\StringUtils;

/**
 * Class AlnumAndHyphen
 * @package iMSCP\Filter
 */
class AlnumAndHyphen extends Alnum
{
    /**
     * Defined by Zend_Filter_Interface
     *
     * Returns $value as string with all non-alphabetic, digit and hyphen characters removed
     *
     * @param  string|array $value
     * @return string
     */
    public function filter($value)
    {
        if (!is_scalar($value) && !is_array($value)) {
            return $value;
        }

        $whiteSpace = $this->options['allow_white_space'] ? '\s' : '';
        $language = Locale::getPrimaryLanguage($this->getLocale());

        if (!StringUtils::hasPcreUnicodeSupport()) {
            // POSIX named classes are not supported, use alternative a-zA-Z0-9 match
            $pattern = '/[^a-zA-Z0-9' . $whiteSpace . '-]/';
        } elseif ($language == 'ja' || $language == 'ko' || $language == 'zh') {
            // Use english alphabet
            $pattern = '/[^a-zA-Z0-9' . $whiteSpace . '-]/u';
        } else {
            // Use native language alphabet
            $pattern = '/[^\p{L}\p{N}' . $whiteSpace . '-]/u';
        }

        return preg_replace($pattern, '', $value);
    }
}
