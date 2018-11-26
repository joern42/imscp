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

use iMSCP\Authentication\AuthenticationService;
use iMSCP\Functions\Counting;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    $stmt = execQuery('SELECT * FROM htaccess WHERE dmn_id = ?', [
        getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId())
    ]);

    if (!$stmt->rowCount()) {
        $tpl->assign('PROTECTED_AREAS', '');
        View::setPageMessage(tr('You do not have protected areas.'), 'static_info');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'AREA_NAME' => toHtml($row['auth_name']),
            'AREA_PATH' => toHtml($row['path']),
            'STATUS'    => humanizeItemStatus($row['status'])
        ]);

        if (!in_array($row['status'], ['toadd', 'tochange', 'todelete'])) {
            $tpl->assign([
                'ID'             => toHtml($row['id'], 'htmlAttr'),
                'DATA_AREA_NAME' => toHtml($row['auth_name'], 'htmlAttr'),
            ]);
            $tpl->parse('ACTION_LINKS', 'action_links');
        } else {
            $tpl->assign('ACTION_LINKS', tr('N/A'));
        }

        $tpl->parse('DIR_ITEM', '.dir_item');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('webProtectedAreas') or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'          => 'shared/layouts/ui.tpl',
    'page'            => 'client/protected_areas.tpl',
    'page_message'    => 'layout',
    'protected_areas' => 'page',
    'dir_item'        => 'protected_areas',
    'action_links'    => 'dir_item'
]);
$tpl->assign([
    'TR_PAGE_TITLE'              => tr('Client / Webtools / Protected Areas'),
    'TR_NAME'                    => tr('Name'),
    'TR_PATH'                    => tr('Path'),
    'TR_STATUS'                  => tr('Status'),
    'TR_ACTIONS'                 => tr('Actions'),
    'TR_EDIT'                    => tr('Edit'),
    'TR_DELETE'                  => tr('Delete'),
    'TR_ADD_PROTECTED_AREA'      => tr('Add new protected area'),
    'TR_MANAGE_USERS_AND_GROUPS' => tr('Manage users and groups')
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['dataTable'] = View::getDataTablesPluginTranslations();
    $translations['core']['deletion_confirm_msg'] = tr('Are you sure you want to delete the `%%s` protected area?');
});
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
