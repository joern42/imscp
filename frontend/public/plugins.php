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

require_once 'application.php';

if (($urlComponents = parse_url($_SERVER['REQUEST_URI'])) === false || !isset($urlComponents['path'])) {
    View::showBadRequestErrorPage();
}

$urlComponents['path'] = rtrim($urlComponents['path'], '/');
$pluginManager = Application::getInstance()->getPluginManager();
$plugins = $pluginManager->pluginGetLoaded();
!empty($plugins) or View::showNotFoundErrorPage();
$eventsManager = Application::getInstance()->getEventManager();
$responses = $eventsManager->trigger(Events::onBeforePluginsRoute, null, ['pluginManager' => $pluginManager]);
!$responses->stopped() or View::showNotFoundErrorPage();

$pluginActionScriptPath = NULL;
foreach ($plugins as $plugin) {
    if ($pluginActionScriptPath = $plugin->route($urlComponents)) {
        break;
    }

    foreach ($plugin->getRoutes() as $pluginRoute => $scriptPath) {
        if ($pluginRoute == $urlComponents['path']) {
            $pluginActionScriptPath = $scriptPath;
            $_SERVER['SCRIPT_NAME'] = $pluginRoute;
            break;
        }
    }

    if ($pluginActionScriptPath) {
        break;
    }
}

NULL !== $pluginActionScriptPath or View::showNotFoundErrorPage();

$eventsManager->trigger(Events::onAfterPluginsRoute, null, [
    'pluginManager' => $pluginManager,
    'scriptPath'    => $pluginActionScriptPath
]);

is_file($pluginActionScriptPath) or View::showNotFoundErrorPage();
include $pluginActionScriptPath;
