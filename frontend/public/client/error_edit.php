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
 * Write error page
 *
 * @param int $eid Error page unique identifier
 * @return bool TRUE on success, FALSE otherwise
 */
function writeErrorPage($eid)
{
    $vfs = new VirtualFileSystem(Application::getInstance()->getAuthService()->getIdentity()->getUsername(), '/errors');
    return $vfs->put($eid . '.html', $_POST['error']);
}

/**
 * Edit an error page
 *
 * @param int $eid Error page unique identifier
 * @return TRUE on success, FALSE on failure
 */
function editErrorPage($eid)
{
    isset($_POST['error']) or View::showBadRequestErrorPage();

    if (in_array($eid, [401, 403, 404, 500, 503]) && writeErrorPage($eid)) {
        setPageMessage(tr('Custom error page updated.'), 'success');
        return true;
    }

    setPageMessage(tr('System error - custom error page was not updated.'), 'error');
    return false;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param int $eid Error page unique identifier
 * @return void
 */
function generatePage($tpl, $eid)
{
    $vfs = new VirtualFileSystem(Application::getInstance()->getAuthService()->getIdentity()->getUsername(), '/errors');
    $errorPageContent = $vfs->get($eid . '.html');
    $tpl->assign('ERROR', ($errorPageContent !== false) ? toHtml($errorPageContent) : '');
}

require 'application.php';

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('custom_error_pages') && isset($_REQUEST['eid']) or View::showBadRequestErrorPage();

$eid = intval($_REQUEST['eid']);

in_array($eid, ['401', '403', '404', '500', '503']) or View::showBadRequestErrorPage();

if (!empty($_POST) && editErrorPage($eid)) {
    redirectTo('error_pages.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/error_edit.phtml',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / Webtools / Custom Error Pages / Edit Custom Error Page'),
    'TR_ERROR_EDIT_PAGE' => tr('Edit error page'),
    'TR_SAVE'            => tr('Save'),
    'TR_CANCEL'          => tr('Cancel'),
    'EID'                => $eid
]);
View::generateNavigation($tpl);
generatePage($tpl, $eid);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
