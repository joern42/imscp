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

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('custom_error_pages') or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/error_pages.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'  => tr('Client / Webtools / Custom Error Pages'),
    'DOMAIN'         => toHtml('http://www.' . Application::getInstance()->getSession()['user_logged'], 'htmlAttr'),
    'TR_ERROR_401'   => tr('Unauthorized'),
    'TR_ERROR_403'   => tr('Forbidden'),
    'TR_ERROR_404'   => tr('Not Found'),
    'TR_ERROR_500'   => tr('Internal Server Error'),
    'TR_ERROR_503'   => tr('Service Unavailable'),
    'TR_ERROR_PAGES' => tr('Custom error pages'),
    'TR_EDIT'        => tr('Edit'),
    'TR_VIEW'        => tr('View')
]);
View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
