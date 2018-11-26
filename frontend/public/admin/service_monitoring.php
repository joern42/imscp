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
 *
 * @noinspection PhpUndefinedFieldInspection
 */

namespace iMSCP;

use iMSCP\Authentication\AuthenticationService;
use iMSCP\Functions\View;
use iMSCP\Model\CpMonitoredService;

require_once 'application.php';

$app = Application::getInstance();
$app->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
$em = $app->getEventManager();
$em->trigger(Events::onAdminScriptStart);
$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/ui.tpl',
    'page'           => 'admin/service_monitoring.phtml',
    'page_message'   => 'layout',
    'service_status' => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Admin / General / Service Monitoring')));
$tpl->services = $app->getEntityManager()->getRepository(CpMonitoredService::class)->findAll();
$tpl->newRefresh = (bool)$app->getRequest()->getQuery('refresh', false);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
$em->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
