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

use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $imscpDaemonType = json_decode(Application::getInstance()->getConfig()['iMSCP_INFO'])->daemon_type;
    $services = new Services();

    foreach ($services as $service) {
        $isRunning = $services->isRunning(isset($_GET['refresh']));

        if ($isRunning && $service[0] == 23) {
            setPageMessage(tr('The Telnet-Server is currently running on your server. This legacy service is not secure.'), 'static_warning');
        } elseif ($service[0] == 9876 && $imscpDaemonType != 'imscp') {
            continue;
        }

        if (!$service[3]) {
            continue;
        }

        $tpl->assign([
            'SERVICE'        => toHtml($service[2]),
            'IP'             => $service[4] == '0.0.0.0' ? toHtml(tr('Any')) : toHtml($service[4]),
            'PORT'           => toHtml($service[0]),
            'STATUS'         => $isRunning ? toHtml(tr('UP')) : toHtml(tr('DOWN')),
            'CLASS'          => $isRunning ? 'up' : ($service[0] != 23 ? 'down' : 'up'),
            'STATUS_TOOLTIP' => toHtml($isRunning ? tr('Service is running') : tr('Service is not running'), 'htmlAttr')
        ]);
        $tpl->parse('SERVICE_STATUS', '.service_status');
    }

    if (isset($_GET['refresh'])) {
        setPageMessage(toHtml(tr('Service statuses were refreshed.')), 'success');
        redirectTo('service_statuses.php');
    }
}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/ui.tpl',
    'page'           => 'admin/service_statuses.tpl',
    'page_message'   => 'layout',
    'service_status' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'    => toHtml(tr('Admin / General / Services Status')),
    'TR_SERVICE'       => toHtml(tr('Service name')),
    'TR_IP'            => toHtml(tr('IP address')),
    'TR_PORT'          => toHtml(tr('Port')),
    'TR_STATUS'        => toHtml(tr('Status')),
    'TR_SERVER_STATUS' => toHtml(tr('Server status')),
    'TR_FORCE_REFRESH' => toHtml(tr('Force refresh', 'htmlAttr'))
]);

Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations(false);
});
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
