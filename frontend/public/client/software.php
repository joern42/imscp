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

use iMSCP\TemplateEngine;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/**
 * client_generatePageLists.
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function client_generatePageLists($tpl)
{
    $domainProperties = getCustomerProperties($_SESSION['user_id']);
    $stmt = execQuery('SELECT created_by FROM admin WHERE admin_id = ?', [$_SESSION['user_id']]);
    $software_poss = gen_software_list($tpl, $domainProperties['domain_id'], $stmt->fetchColumn());
    $tpl->assign('TOTAL_SOFTWARE_AVAILABLE', $software_poss);
}

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('aps') or showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                  => 'shared/layouts/ui.tpl',
    'page'                    => 'client/software.tpl',
    'page_message'            => 'layout',
    'software_message'        => 'page',
    'software_item'           => 'page',
    'software_action_delete'  => 'page',
    'software_action_install' => 'page',
    'software_total'          => 'page',
    'no_software'             => 'page',
    'no_software_support'     => 'page',
    'software_list'           => 'page',
    'del_software_support'    => 'software_list',
    'del_software_item'       => 'software_list',
    't_software_support'      => 'software_list'
]);
$tpl->assign([
    'TR_PAGE_TITLE'         => tr('Client / Webtools / Software'),
    'TR_SOFTWARE'           => tr('Software'),
    'TR_VERSION'            => tr('Version'),
    'TR_LANGUAGE'           => tr('Language'),
    'TR_TYPE'               => tr('Type'),
    'TR_NEED_DATABASE'      => tr('Database'),
    'TR_STATUS'             => tr('Status'),
    'TR_ACTION'             => tr('Action'),
    'TR_SOFTWARE_AVAILABLE' => tr('Available software')
]);
Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = getDataTablesPluginTranslations(false);
});
generateNavigation($tpl);
client_generatePageLists($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
