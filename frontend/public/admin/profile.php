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
use iMSCP_Registry as Registry;

/**
 * Generates page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    $stmt = execQuery('SELECT domain_created FROM admin WHERE admin_id = ?', [$_SESSION['user_id']]);
    $row = $stmt->fetch();
    $tpl->assign([
        'TR_ACCOUNT_SUMMARY'   => toHtml(tr('Account summary')),
        'TR_USERNAME'          => toHtml(tr('Username')),
        'USERNAME'             => toHtml($_SESSION['user_logged']),
        'TR_ACCOUNT_TYPE'      => toHtml(tr('Account type')),
        'ACCOUNT_TYPE'         => toHtml(tr('Administrator')),
        'TR_REGISTRATION_DATE' => toHtml(tr('Registration date')),
        'REGISTRATION_DATE'    => $row['domain_created'] != 0
            ? toHtml(date(Registry::get('config')['DATE_FORMAT'], $row['domain_created'])) : toHtml(tr('N/A'))
    ]);
}

require 'imscp-lib.php';

checkLogin('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/profile.tpl',
    'page_message' => 'layout'
]);
$tpl->assign('TR_PAGE_TITLE', tr('Admin / Profile / Account Summary'));
generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
