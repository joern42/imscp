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

namespace iMSCP;

use iMSCP\Functions\View;
use iMSCP\Utility\OpcodeCache;

strtolower($_SERVER['REQUEST_METHOD']) == 'get' or View::showBadRequestErrorPage();
$cacheIds = explode(';', isset($_GET['ids']) ? cleanInput((string)$_GET['ids']) : []);
!empty($cacheIds) or View::showBadRequestErrorPage();

foreach ($cacheIds as $cacheId) {
    if ($cacheId === 'opcache') {
        OpcodeCache::clearAllActive();
        writeLog('OPcache has been flushed.', E_USER_NOTICE);
    } elseif ($cacheId === 'userland') {
        Application::getInstance()->getCache()->flush() or View::showInternalServerError();
        writeLog('APCu userland cache has been flushed.', E_USER_NOTICE);
    } elseif (Application::getInstance()->getCache()->hasItem($cacheId)) {
        Application::getInstance()->getCache()->removeItem($cacheId) or View::showInternalServerError();
        writeLog(sprintf('APCu userland cache with ID `%s` has been flushed.', $cacheId), E_USER_NOTICE);
    }
}

exit('success');
