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

namespace iMSCP\Functions;

use iMSCP\Application;

/**
 * Class Daemon
 * @package iMSCP\Functions
 */
class Daemon
{
    /**
     * @var bool Whether or not a request has been already sent
     */
    private static $isSent = false;

    /**
     * Send a request to the i-MSCP daemon
     *
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function sendRequest(): bool
    {
        // Make sure that a backend request will not be sent twice
        if (static::$isSent) {
            return true;
        }

        if (Application::getInstance()->getConfig()['DAEMON_TYPE'] != 'imscp') {
            return static::$isSent = true;
        }

        if (false === ($socket = @socket_create(AF_INET, SOCK_STREAM, SOL_TCP)) || false === @socket_connect($socket, '127.0.0.1', 9876)) {
            writeLog(sprintf("Couldn't connect to the i-MSCP daemon: %s", socket_strerror(socket_last_error())), E_USER_ERROR);
            return false;
        }

        $version = Application::getInstance()->getConfig()['Version'];
        if (static::readAnswer($socket) // Read Welcome message from i-MSCP daemon
            && static::sendCommand($socket, "helo $version") // Send helo command to i-MSCP daemon
            && static::readAnswer($socket) // Read answer from i-MSCP daemon
            && static::sendCommand($socket, 'execute backend command') // Send execute request command to i-MSCP daemon
            && static::readAnswer($socket) // Read answer from i-MSCP daemon
            && static::sendCommand($socket, 'bye') // Send bye command to i-MSCP daemon
            && static::readAnswer($socket) // Read answer from i-MSCP daemon
        ) {
            static::$isSent = $ret = true;
        } else {
            $ret = false;
        }

        socket_close($socket);
        return $ret;
    }

    /**
     * Read an answer from the i-MSCP daemon
     *
     * @param resource &$socket
     * @return bool TRUE on success, FALSE otherwise
     */
    private static function readAnswer(&$socket): bool
    {
        if (($answer = @socket_read($socket, 1024, PHP_NORMAL_READ)) === false) {
            writeLog(sprintf('Unable to read answer from i-MSCP daemon: %s' . socket_strerror(socket_last_error())), E_USER_ERROR);
            return false;
        }

        list($code) = explode(' ', $answer);
        $code = intval($code);
        if ($code != 250) {
            writeLog(sprintf('i-MSCP daemon returned an unexpected answer: %s', $answer), E_USER_ERROR);
            return false;
        }


        return true;
    }

    /**
     * Send a command to the i-MSCP daemon
     *
     * @param resource &$socket
     * @param string $command Command
     * @return bool TRUE on success, FALSE otherwise
     */
    private static function sendCommand(&$socket, string $command): bool
    {
        $command .= "\n";
        $commandLength = strlen($command);

        while (true) {
            if (($bytesSent = @socket_write($socket, $command, $commandLength)) == false) {
                writeLog(sprintf("Couldn't send command to i-MSCP daemon: %s", socket_strerror(socket_last_error())), E_USER_ERROR);
                return false;
            }

            if ($bytesSent < $commandLength) {
                $command = substr($command, $bytesSent);
                $commandLength -= $bytesSent;
            } else {
                return true;
            }
        }

        return false;
    }
}
