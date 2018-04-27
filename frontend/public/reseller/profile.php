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

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generatePage($tpl)
{
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $stmt = execQuery('SELECT domain_created FROM admin WHERE admin_id = ?', [$identity->getUserId()]);
    $row = $stmt->fetch();
    $tpl->assign([
        'TR_ACCOUNT_SUMMARY'   => tr('Account summary'),
        'TR_USERNAME'          => tr('Username'),
        'USERNAME'             => toHtml($identity->getUsername()),
        'TR_ACCOUNT_TYPE'      => tr('Account type'),
        'ACCOUNT_TYPE'         => tr('Reseller'),
        'TR_REGISTRATION_DATE' => tr('Registration date'),
        'REGISTRATION_DATE'    => ($row['domain_created'] != 0)
            ? toHtml(date(Application::getInstance()->getConfig()['DATE_FORMAT'], $row['domain_created'])) : tr('Unknown')
    ]);
}

require 'application.php';

Login::checkLogin('reseller');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/profile.tpl',
    'page_message' => 'layout'
]);
$tpl->assign('TR_PAGE_TITLE', tr('Reseller / Profile / Account Summary'));
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
