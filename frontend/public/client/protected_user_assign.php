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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

/**
 * Return htaccess username
 *
 * @param int $htuserId Htaccess user unique identifier
 * @param int $domainId Domain unique identifier
 * @return string
 */
function client_getHtaccessUsername($htuserId, $domainId)
{
    $stmt = execQuery('SELECT uname, status FROM htaccess_users WHERE id = ? AND dmn_id = ?', [$htuserId, $domainId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    if ($row['status'] != 'ok') {
        setPageMessage(tr('A task is in progress for this htuser.'));
        redirectTo('protected_user_manage.php');
    }

    return $row['uname'];
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function client_generatePage($tpl)
{
    $domainId = getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']);

    if (isset($_GET['uname']) && isNumber($_GET['uname'])) {
        $htuserId = intval($_GET['uname']);
        $tpl->assign('UNAME', toHtml(client_getHtaccessUsername($htuserId, $domainId)));
        $tpl->assign('UID', $htuserId);
    } elseif (isset($_POST['nadmin_name']) && isNumber($_POST['nadmin_name'])) {
        $htuserId = intval($_POST['nadmin_name']);
        $tpl->assign('UNAME', toHtml(client_getHtaccessUsername($htuserId, $domainId)));
        $tpl->assign('UID', $htuserId);
    } else {
        redirectTo('protected_user_manage.php');
        return; // Useless but avoid stupid IDE warning about possible undefined variable
    }

    // Get groups
    $stmt = execQuery('SELECT * FROM htaccess_groups WHERE dmn_id = ?', [$domainId]);
    if (!$stmt->rowCount()) {
        setPageMessage(tr('You have no groups.'), 'error');
        redirectTo('protected_user_manage.php');
    }

    $addedIn = 0;
    $notAddedIn = 0;

    while ($row = $stmt->fetch()) {
        $groupId = $row['id'];
        $groupName = $row['ugroup'];
        $members = $row['members'];

        $members = explode(',', $members);
        $grp_in = 0;
        // let's generate all groups where the user is assigned
        for ($i = 0, $cnt_members = count($members); $i < $cnt_members; $i++) {
            if ($htuserId == $members[$i]) {
                $tpl->assign([
                    'GRP_IN'    => toHtml($groupName),
                    'GRP_IN_ID' => $groupId,
                ]);

                $tpl->parse('ALREADY_IN', '.already_in');
                $grp_in = $groupId;
                $addedIn++;
            }
        }

        if ($grp_in !== $groupId) {
            $tpl->assign([
                'GRP_NAME' => toHtml($groupName),
                'GRP_ID'   => $groupId
            ]);
            $tpl->parse('GRP_AVLB', '.grp_avlb');
            $notAddedIn++;
        }
    }

    // generate add/remove buttons
    if ($addedIn < 1) {
        $tpl->assign('IN_GROUP', '');
    }

    if ($notAddedIn < 1) {
        $tpl->assign('NOT_IN_GROUP', '');
    }
}

/**
 * Assign a specific htaccess user to a specific htaccess group
 *
 * @return void
 */
function client_addHtaccessUserToHtaccessGroup()
{
    if (empty($_POST)) {
        return;
    }

    isset($_POST['uaction']) or View::showBadRequestErrorPage();

    if ($_POST['uaction'] != 'add') {
        return;
    }

    if (!isset($_GET['uname']) || !isset($_POST['groups']) || empty($_POST['groups']) || !isset($_POST['nadmin_name']) || !isNumber($_POST['groups'])
        || !isNumber($_POST['nadmin_name'])
    ) {
        View::showBadRequestErrorPage();
    }

    $domainId = getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']);
    $htuserId = cleanInput($_POST['nadmin_name']);
    $htgroupId = $_POST['groups'];
    $stmt = execQuery('SELECT id, ugroup, members FROM htaccess_groups WHERE dmn_id = ? AND id = ?', [$domainId, $htgroupId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();
    $members = $row['members'];
    if ($members == '') {
        $members = $htuserId;
    } else {
        $members = $members . ',' . $htuserId;
    }

    execQuery("UPDATE htaccess_groups SET members = ?, status = 'tochange' WHERE id = ? AND dmn_id = ?", [$members, $htgroupId, $domainId]);
    Daemon::sendRequest();
    setPageMessage(tr('Htaccess user successfully assigned to the %s htaccess group', $row['ugroup']), 'success');
    redirectTo('protected_user_manage.php');
}

/**
 * Remove user from a specific group
 *
 * @return void
 */
function client_removeHtaccessUserFromHtaccessGroup()
{
    if (empty($_POST)) {
        return;
    }

    isset($_POST['uaction']) or View::showBadRequestErrorPage();

    if ($_POST['uaction'] != 'remove') {
        return;
    }

    if (!isset($_POST['groups_in']) || empty($_POST['groups_in']) || !isset($_POST['nadmin_name']) || !isNumber($_POST['groups_in'])
        || !isNumber($_POST['nadmin_name'])
    ) {
        View::showBadRequestErrorPage();
    }

    $domainId = getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']);
    $htgroupId = intval($_POST['groups_in']);
    $htuserId = cleanInput($_POST['nadmin_name']);
    $stmt = execQuery('SELECT ugroup, members FROM htaccess_groups WHERE id = ? AND dmn_id = ?', [$htgroupId, $domainId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();
    $members = explode(',', $row['members']);
    $key = array_search($htuserId, $members);

    if ($key === false) {
        return;
    }

    unset($members[$key]);
    $members = implode(',', $members);

    execQuery("UPDATE htaccess_groups SET members = ?, status = 'tochange' WHERE id = ? AND dmn_id = ?", [$members, $htgroupId, $domainId]);
    Daemon::sendRequest();
    setPageMessage(tr('Htaccess user successfully deleted from the %s htaccess group ', $row['ugroup']), 'success');
    redirectTo('protected_user_manage.php');
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('protected_areas') or View::showBadRequestErrorPage();

client_addHtaccessUserToHtaccessGroup();
client_removeHtaccessUserFromHtaccessGroup();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'        => 'shared/layouts/ui.tpl',
    'page'          => 'client/puser_assign.tpl',
    'page_message'  => 'layout',
    'in_group'      => 'page',
    'already_in'    => 'in_group',
    'remove_button' => 'in_group',
    'not_in_group'  => 'page',
    'grp_avlb'      => 'not_in_group',
    'add_button'    => 'not_in_group'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => 'Client / Webtools / Protected Areas / Manage Users and Groups / Assign Group',
    'TR_SELECT_GROUP'    => tr('Select group'),
    'TR_MEMBER_OF_GROUP' => tr('Member of group'),
    'TR_ADD'             => tr('Add'),
    'TR_REMOVE'          => tr('Remove'),
    'TR_CANCEL'          => tr('Cancel')
]);
View::generateNavigation($tpl);
client_generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
