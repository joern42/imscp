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

// Define application paths
defined('FRONTEND_ROOT_DIR') || define('FRONTEND_ROOT_DIR', dirname(__DIR__));
defined('LIBRARY_PATH') || define('LIBRARY_PATH', __DIR__);
defined('CACHE_PATH') || define('CACHE_PATH', FRONTEND_ROOT_DIR . '/data/cache');
defined('PERSISTENT_PATH') || define('PERSISTENT_PATH', FRONTEND_ROOT_DIR . '/data/persistent');
defined('CONFIG_FILE_PATH') || define('CONFIG_FILE_PATH', getenv('IMSCP_CONF') ?: '/etc/imscp/imscp.conf');
// Define application environment
defined('APPLICATION_ENV') || define('APPLICATION_ENV', getenv('APPLICATION_ENV') ? getenv('APPLICATION_ENV') : 'production');

// Composer autoloading
$autoloader = include FRONTEND_ROOT_DIR . '/vendor/autoload.php';

// Create application
$application = new Application($autoloader, APPLICATION_ENV);
unset($autoloader);

// Bootstrap application
$application->bootstrap(CONFIG_FILE_PATH);
