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

namespace iMSCP\Config\Reader;

use Zend\Config\Reader;

/**
 * Class JavaProperties
 *
 * Java-style properties config reader.
 *
 * This is deviating from ZF implementation only for the separator (= vs :).
 * We also remove leading and trailing whitespaces from key/value pairs.
 *
 * @package iMSCP\Config\Reader
 */
class JavaProperties extends Reader\JavaProperties
{
    /**
     * @inheritdoc
     */
    protected function parse($string)
    {
        $result = [];
        $lines = explode("\n", $string);
        $key = '';
        $value = '';
        $isWaitingOtherLine = false;
        foreach ($lines as $i => $line) {
            // Ignore empty lines and commented lines
            if (empty($line)
                || (!$isWaitingOtherLine && strpos($line, '#') === 0)
                || (!$isWaitingOtherLine && strpos($line, '!') === 0)) {
                continue;
            }

            // Add a new key-value pair or append value to a previous pair
            if (!$isWaitingOtherLine) {
                $key = substr($line, 0, strpos($line, '='));
                $value = substr($line, strpos($line, '=') + 1, strlen($line));
            } else {
                $value .= $line;
            }

            // Check if ends with single '\' (indicating another line is expected)
            if (strrpos($value, "\\") === strlen($value) - strlen("\\")) {
                $value = substr($value, 0, strlen($value) - 1);
                $isWaitingOtherLine = true;
            } else {
                $isWaitingOtherLine = false;
            }

            $result[trim($key)] = stripslashes(trim($value));
            unset($lines[$i]);
        }

        return $result;
    }
}
