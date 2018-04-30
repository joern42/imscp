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

/**
 * Move the given reseller from the given administrator to the given administrator
 *
 * @param int $resellerId Reseller unique identifier
 * @param int $fromAdministratorId Administrator unique identifier
 * @param int $toAdministratorId Administrator unique identifier
 * @return void
 */
function moveReseller($resellerId, $fromAdministratorId, $toAdministratorId)
{
    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        // Move reseller to (TO) administrator
        execQuery('UPDATE admin SET created_by = ? WHERE admin_id = ?', [$toAdministratorId, $resellerId]);
        Application::getInstance()->getEventManager()->trigger(Events::onMoveReseller, NULL, [
            'resellerId'          => $resellerId,
            'fromAdministratorId' => $fromAdministratorId,
            'toAdministratorId'   => $toAdministratorId
        ]);

        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf("Couldn't move reseller with ID %d: %s", $resellerId, $e->getMessage()));
        throw new \Exception(tr("Couldn't move reseller with ID %d: %s", $resellerId, $e->getMessage()), $e->getCode(), $e);
    }
}

/**
 * Move selected resellers
 *
 * @return bool TRUE on success, other on failure
 */
function moveResellers()
{
    if (!isset($_POST['from_administrator']) || !isset($_POST['to_administrator']) || !isset($_POST['administrator_resellers'])
        || !is_array($_POST['administrator_resellers'])
    ) {
        View::showBadRequestErrorPage();
    }

    set_time_limit(0);
    ignore_user_abort(true);

    try {
        $fromAdministratorId = intval($_POST['from_administrator']);
        $toAdministratorId = intval($_POST['to_administrator']);
        $fromAdministratorId != $toAdministratorId or View::showBadRequestErrorPage();

        foreach ($_POST['administrator_resellers'] as $resellerId) {
            moveReseller(intval($resellerId), $fromAdministratorId, $toAdministratorId);
        }
    } catch (\Exception $e) {
        View::setPageMessage(toHtml($e->getMessage()), 'error');
        return false;
    }

    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $administrators = $stmt = execQuery("SELECT admin_id, admin_name FROM admin WHERE admin_type = 'admin'")->fetchAll();
    $fromAdministratorId = isset($_POST['from_administrator']) ? intval($_POST['from_administrator']) : $administrators[0]['admin_id'];
    $toAdministratorId = isset($_POST['to_administrator']) ? intval($_POST['to_administrator']) : $administrators[1]['admin_id'];

    // Generate From/To reseller lists
    foreach ($administrators as $administrator) {
        $tpl->assign([
            'FROM_ADMINISTRATOR_ID'       => toHtml($administrator['admin_id'], 'htmlAttr'),
            'FROM_ADMINISTRATOR_NAME'     => toHtml($administrator['admin_name']),
            'FROM_ADMINISTRATOR_SELECTED' => $fromAdministratorId == $administrator['admin_id'] ? ' selected' : ''
        ]);
        $tpl->parse('FROM_ADMINISTRATOR_ITEM', '.from_administrator_item');
        $tpl->assign([
            'TO_ADMINISTRATOR_ID'       => toHtml($administrator['admin_id'], 'htmlAttr'),
            'TO_ADMINISTRATOR_NAME'     => toHtml($administrator['admin_name']),
            'TO_ADMINISTRATOR_SELECTED' => ($toAdministratorId == $administrator['admin_id']) ? ' selected' : ''
        ]);
        $tpl->parse('TO_ADMINISTRATOR_ITEM', '.to_administrator_item');
    }

    // Generate resellers list for the selected (FROM) administrator
    $resellers = execQuery("SELECT admin_id, admin_name FROM admin WHERE created_by = ? AND admin_type = 'reseller'", [
        $fromAdministratorId
    ])->fetchAll();

    if (empty($resellers)) {
        $tpl->assign('FROM_ADMINISTRATOR_RESELLERS_LIST', '');
        return;
    }

    $selectedResellers = isset($_POST['administrator_resellers']) ? $_POST['administrator_resellers'] : [];
    foreach ($resellers as $reseller) {
        $tpl->assign([
            'RESELLER_ID'                    => toHtml($reseller['admin_id'], 'htmlAttr'),
            'RESELLER_NAME'                  => toHtml(decodeIdna($reseller['admin_name'])),
            'ADMINISTRATOR_RESELLER_CHECKED' => in_array($reseller['admin_id'], $selectedResellers) ? ' checked' : ''
        ]);
        $tpl->parse('FROM_ADMINISTRATOR_RESELLER_ITEM', '.from_administrator_reseller_item');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
Counting::systemHasManyAdmins() && Counting::systemHasResellers() or View::showBadRequestErrorPage();

if (isset($_POST['uaction']) && $_POST['uaction'] == 'move_resellers' && moveResellers()) {
    View::setPageMessage(tr('Reseller(s) successfully moved.'), 'success');
    redirectTo('users.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                            => 'shared/layouts/ui.tpl',
    'page'                              => 'admin/manage_reseller_owners.phtml',
    'page_message'                      => 'layout',
    'from_administrator_resellers_list' => 'page',
    'from_administrator_reseller_item'  => 'from_administrator_resellers_list',
    'from_administrator_item'           => 'page',
    'to_administrator_item'             => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Admin / Users / Reseller Assignments')));
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
