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

namespace iMSCP\Update;

/**
 * Class UpdatePatch
 * @package iMSCP\Update
 */
class Patch extends UpdateAbstract
{

    protected $api_url = 'https://api.github.com/repos/i-MSCP/imscp-patch/%version%';

    /**
     * @var array|null Update info
     */
    protected $updateInfo;

    /**
     * Apply all available update
     *
     * @return bool TRUE on success, FALSE othewise
     */
    public function applyUpdates()
    {
        // Fixme: make it possible to trigger execution of imscp-patcher through frontend
        $this->setError('i-MSCP patch can be applied throug the imscp-patcher script only.');
        return false;
    }

    /**
     * Get update info from GitHub (using the GitHub API)
     *
     * @param bool $forceReload Whether data must be reloaded from Github
     * @return array|bool An array containing update info on success, false on failure
     */
    public function getUpdateInfo($forceReload = false)
    {
        if (NULL !== $this->updateInfo) {
            return $this->updateInfo;
        }

        $file = CACHE_PATH . '/imscp_info.json';
        if ($forceReload || !file_exists($file) || strtotime('+1 day', filemtime($file)) < time()) {
            clearstatcache();
            $context = stream_context_create([
                'http' => [
                    'method'           => 'GET',
                    'protocol_version' => '1.1',
                    'header'           => [
                        'Host: api.github.com',
                        'Accept: application/vnd.github.v3+json',
                        'User-Agent: i-MSCP',
                        'Connection: close',
                        'timeout' => 30
                    ]
                ]
            ]);

            if (!stream_context_set_option($context, 'ssl', 'verify_peer', false)) {
                $this->setError(tr('Unable to set sslverifypeer option'));
                return false;
            }

            if (!stream_context_set_option($context, 'ssl', 'allow_self_signed', true)) {
                $this->setError(tr('Unable to set sslallowselfsigned option'));
                return false;
            }

            // Retrieving latest release info from GitHub
            $info = @file_get_contents('https://api.github.com/repos/i-MSCP/trees/releases/latest', false, $context);
            if ($info === false) {
                $this->setError(tr('Unable to get update info from Github'));
            } elseif (!isJson($info)) {
                $this->setError(tr('Invalid payload received from GitHub'));
                return false;
            }

            if (file_exists($file)) {
                if (!@unlink($file)) {
                    $this->setError(tr('Unable to delete i-MSCP info file.'));
                    writeLog(sprintf('Unable to deelte i-MSCP info file.'), E_USER_ERROR);
                    return false;
                }
            }

            if (@file_put_contents($file, $info, LOCK_EX) === false) {
                writeLog(sprintf('Unable to create i-MSCP info file.'), E_USER_ERROR);
            } else {
                writeLog(sprintf('New i-MSCP info file has been created.'), E_USER_NOTICE);
            }
        } elseif (($info = file_get_contents($file)) === false) {
            $this->setError(tr('Unable to load i-MSCP info file.'));
            writeLog(sprintf('Unable to load i-MSCP info file.'), E_USER_ERROR);
            return false;
        }

        $this->updateInfo = json_decode($info, true);
        return $this->updateInfo;
    }

    /**
     * Checks for available update
     *
     * @return bool TRUE if an update available, FALSE otherwise
     */
    public function isAvailableUpdate()
    {
        if (version_compare($this->getNextUpdate(), $this->getLastAppliedUpdate(), '>')) {
            return true;
        }

        return false;
    }

    /**
     * Return next update
     *
     * @return mixed next update info
     */
    public function getNextUpdate()
    {
        // TODO: Implement getNextUpdate() method.
    }

    /**
     * Returns last applied update
     *
     * @return mixed
     */
    public function getLastAppliedUpdate()
    {
        // TODO: Implement getLastAppliedUpdate() method.
    }

    /**
     * Singleton - Make clone unavailable
     *
     * @return void
     */
    protected function __clone()
    {

    }
}
