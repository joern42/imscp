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

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                         => 'shared/layouts/ui.tpl',
    'page'                           => 'admin/users.phtml',
    'page_message'                   => 'layout',
    'administrator_message'          => 'page',
    'administrator_list'             => 'page',
    'administrator_item'             => 'administrator_list',
    'administrator_delete_link'      => 'administrator_item',
    'reseller_message'               => 'page',
    'reseller_list'                  => 'page',
    'reseller_item'                  => 'reseller_list',
    'client_search_form'             => 'page',
    'client_show_domain_aliases_blk' => 'client_search_form',
    'client_domain_aliases_switch'   => 'client_search_form',
    'client_domain_aliases_show'     => 'client_domain_aliases_switch',
    'client_domain_aliases_hide'     => 'client_domain_aliases_switch',
    'client_message'                 => 'page',
    'client_list'                    => 'page',
    'client_item'                    => 'client_list',
    'client_domain_status_ok'        => 'client_item',
    'client_domain_status_not_ok'    => 'client_item',
    'client_restricted_links'        => 'client_item',
    'client_domain_alias_blk'        => 'client_item',
    'client_scroll_prev'             => 'client_list',
    'client_scroll_prev_gray'        => 'client_list',
    'client_scroll_next_gray'        => 'client_list',
    'client_scroll_next'             => 'client_list'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Admin / Users / Overview')));

if (isset($_POST['details']) && !empty($_POST['details'])) {
    Application::getInstance()->getSession()['details'] = $_POST['details'];
} elseif (!isset(Application::getInstance()->getSession()['details'])) {
    Application::getInstance()->getSession()['details'] = 'hide';
}

View::generateNavigation($tpl);
View::generateUsersLists($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
