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
use Zend\EventManager\Event;

/**
 * Is allowed directory?
 *
 * @param string $directory Directory path
 * @return bool
 */
function isAllowedDir($directory)
{
    global $mountpoints;

    $disallowedDirs = implode('|', array_map(function ($dir) {
        return quotemeta(normalizePath('/' . $dir));
    }, ['/', '00_private', 'backups', 'errors', 'logs', 'phptmp']));

    $mountpointsReg = implode('|', array_map(function ($dir) {
        $path = normalizePath('/' . $dir);
        if ($path == '/') return '';
        return quotemeta($path);
    }, $mountpoints));

    if (preg_match("%^(?:$mountpointsReg)(?:$disallowedDirs)?$%", $directory))
        return false;

    return true;
}

/**
 * Add/update protected area
 *
 * @return void
 */
function handleProtectedArea()
{
    isset($_POST['protected_area_name']) && isset($_POST['protected_area_path']) or View::showBadRequestErrorPage();

    $protectionType = (isset($_POST['protection_type']) && in_array($_POST['protection_type'], ['user', 'group'], true))
        ? $_POST['protection_type'] : 'user';

    $error = false;

    if ($_POST['protected_area_name'] === '') {
        setPageMessage(tr('Please enter a name for the protected area.'), 'error');
        $error = true;
    }

    if ($_POST['protected_area_path'] === '') {
        setPageMessage(tr('Please enter protected area path.'), 'error');
        $error = true;
    }

    if ($protectionType == 'user' && empty($_POST['users'])) {
        setPageMessage(tr('Please choose at least one htaccess user.'), 'error');
        $error = true;
    } elseif ($protectionType == 'group' && empty($_POST['groups'])) {
        setPageMessage(tr('Please choose at least one htaccess user/group.'), 'error');
        $error = true;
    }

    if ($error) {
        return;
    }

    $protectedAreaName = cleanInput($_POST['protected_area_name']);
    $protectedAreaPath = normalizePath('/' . cleanInput($_POST['protected_area_path']));

    if (!isAllowedDir($protectedAreaPath)) {
        setPageMessage(tr("Directory '%s' is not allowed or invalid.", $protectedAreaPath), 'error');
        return;
    }

    $vfs = new VirtualFileSystem(Application::getInstance()->getSession()['user_logged']);
    if ($protectedAreaPath !== '/' && !$vfs->exists($protectedAreaPath, VirtualFileSystem::VFS_TYPE_DIR)) {
        setPageMessage(tr("Directory '%s' doesn't exist.", $protectedAreaPath), 'error');
        return;
    }

    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);

    if ($protectionType === 'user') {
        $stmt = execQuery(
            'SELECT id FROM htaccess_users WHERE id IN(' . implode(',', array_map('quoteValue', (array)$_POST['users'])) . ') AND dmn_id = ?',
            [$mainDmnProps['domain_id']]
        );
        $stmt->rowCount() or View::showBadRequestErrorPage();

        $userIdList = implode(',', $stmt->fetchAll(\PDO::FETCH_COLUMN));
        $groupIdList = 0;
    } else {
        $stmt = execQuery(
            '
              SELECT id
              FROM htaccess_groups
              WHERE id IN(' . implode(',', array_map('quoteValue', (array)$_POST['groups'])) . ')
              AND dmn_id = ?
            ',
            [$mainDmnProps['domain_id']]
        );
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $groupIdList = implode(',', $stmt->fetchAll(\PDO::FETCH_COLUMN));
        $userIdList = 0;
    }

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        if (isset($_REQUEST['id']) && $_REQUEST['id'] > 0) {
            $stmt = execQuery("UPDATE htaccess SET status = 'todelete' WHERE id = ? AND dmn_id = ?", [$_REQUEST['id'], $mainDmnProps['domain_id']]);
            $stmt->rowCount() or View::showBadRequestErrorPage();
        }

        execQuery(
            "
                INSERT INTO htaccess (dmn_id, user_id, group_id, auth_type, auth_name, path, status)
                VALUES (?, ?, ?, 'Basic', ?, ?, 'toadd')
            ",
            [$mainDmnProps['domain_id'], $userIdList, $groupIdList, $protectedAreaName, $protectedAreaPath]
        );

        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    Daemon::sendRequest();

    if (isset($_REQUEST['id']) && $_REQUEST['id'] > 0) {
        setPageMessage(tr('Protected area successfully scheduled for update.'), 'success');
    } else {
        setPageMessage(tr('Protected area successfully scheduled for addition.'), 'success');
    }

    redirectTo('protected_areas.php');
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generatePage($tpl)
{
    global $mountpoints;

    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);

    # Set parameters for the FTP chooser
    Application::getInstance()->getSession()['ftp_chooser_domain_id'] = $mainDmnProps['domain_id'];
    Application::getInstance()->getSession()['ftp_chooser_user'] = Application::getInstance()->getSession()['user_logged'];
    Application::getInstance()->getSession()['ftp_chooser_root_dir'] = '/';
    Application::getInstance()->getSession()['ftp_chooser_hidden_dirs'] = ['00_private', 'backups', 'errors', 'logs', 'phptmp'];
    Application::getInstance()->getSession()['ftp_chooser_unselectable_dirs'] = $mountpoints;

    if (isset($_REQUEST['id']) && $_REQUEST['id'] > 0) {
        $stmt = execQuery('SELECT * FROM htaccess WHERE dmn_id = ? AND id = ?', [$mainDmnProps['domain_id'], intval($_REQUEST['id'])]);
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();
        $tpl->assign('ID', $row['id']);
        $userIds = $row['user_id'];
        $groupIds = $row['group_id'];
        $authType = ((isset($_POST['protection_type']) && $_POST['protection_type'] === 'group') || $userIds == 0) ? 'group' : 'user';
        $tpl->assign([
            'AREA_NAME' => isset($_POST['protected_area_name'])
                ? toHtml($_POST['protected_area_name'], 'htmlAttr') : toHtml($row['auth_name'], 'htmlAttr'),
            'PATH'      => isset($_POST['protected_area_path'])
                ? toHtml($_POST['protected_area_path'], 'htmlAttr') : toHtml($row['path'], 'htmlAttr')
        ]);
    } else {
        $userIds = 0;
        $groupIds = 0;
        $authType = ((isset($_POST['protection_type']) && $_POST['protection_type'] === 'group')) ? 'group' : 'user';
        $tpl->assign([
            'ID'        => 0,
            'AREA_NAME' => isset($_POST['protected_area_name']) ? toHtml($_POST['protected_area_name'], 'htmlAttr') : '',
            'PATH'      => isset($_POST['protected_area_path'])
                ? toHtml($_POST['protected_area_path'], 'htmlAttr')
                : toHtml(normalizePath('/' . $mainDmnProps['document_root']), 'htmlAttr')
        ]);
    }

    if ($authType == 'user') {
        $tpl->assign([
            'USER_CHECKED'  => ' checked',
            'GROUP_CHECKED' => ''
        ]);
    }

    if ($authType == 'group') {
        $tpl->assign([
            'USER_CHECKED'  => '',
            'GROUP_CHECKED' => ' checked'
        ]);
    }

    $stmt = execQuery('SELECT * FROM htaccess_users WHERE dmn_id = ?', [$mainDmnProps['domain_id']]);
    if (!$stmt->rowCount()) {
        setPageMessage(tr('You must first create a user.'), 'error');
        redirectTo('protected_areas.php');
    }

    # Create htuser list
    $userIds = isset($_POST['users']) ? (array)$_POST['users'] : explode(',', $userIds);
    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'USER_VALUE'    => toHtml($row['id']),
            'USER_LABEL'    => toHtml($row['uname']),
            'USER_SELECTED' => ($authType === 'user' && in_array($row['id'], $userIds)) ? ' selected' : ''
        ]);
        $tpl->parse('USER_ITEM', '.user_item');
    }

    # Create htgroup list
    $stmt = execQuery('SELECT * FROM htaccess_groups WHERE dmn_id = ?', [$mainDmnProps['domain_id']]);
    if (!$stmt->rowCount()) {
        $tpl->assign([
            'AUTH_SELECTORS_JS'      => '',
            'AUTH_SELECTORS'         => '',
            'AUTH_GROUP_LIST'        => '',
            'TR_AUTHENTICATION_DATA' => tr('Authentication users'),
        ]);
    } else {
        $tpl->assign('TR_AUTHENTICATION_DATA', tr('Authentication users/groups'));
        $groupIds = isset($_POST['groups']) ? (array)$_POST['groups'] : explode(',', $groupIds);
        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'GROUP_VALUE'    => toHtml($row['id']),
                'GROUP_LABEL'    => toHtml($row['ugroup']),
                'GROUP_SELECTED' => ($authType == 'group' && in_array($row['id'], $groupIds)) ? ' selected' : ''
            ]);
            $tpl->parse('GROUP_ITEM', '.group_item');
        }
    }
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('protected_areas') or View::showBadRequestErrorPage();

$mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);

global $mountpoints;
$mountpoints = getMountpoints($mainDmnProps['domain_id']);

empty($_POST) or handleProtectedArea();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'              => 'shared/layouts/ui.tpl',
    'page'                => 'client/protect_it.tpl',
    'page_message'        => 'layout',
    'auth_selectors_js'   => 'page',
    'auth_selectors'      => 'page',
    'auth_group_selector' => 'auth_selectors',
    'auth_group_list'     => 'page',
    'group_item'          => 'auth_group_list',
    'user_item'           => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'          => tr('Client / Webtools / Protected Areas / {TR_DYNAMIC_TITLE}'),
    'TR_DYNAMIC_TITLE'       => isset($_REQUEST['id']) && $_REQUEST['id'] > 0 ? tr('Edit protected area') : tr('Add protected area'),
    'TR_PROTECTED_AREA_DATA' => tr('Protected area data'),
    'TR_AREA_NAME'           => tr('Protected area name'),
    'TR_PATH'                => tr('Protected area path'),
    'TR_CHOOSE_DIR'          => tr('Choose dir'),
    'TR_USER_AUTH'           => tr('Authentication by user'),
    'TR_GROUP_AUTH'          => tr('Authentication by group'),
    'TR_PROTECT_IT'          => (isset($_REQUEST['id']) && $_REQUEST['id'] > 0) ? tr('Edit protected area') : tr('Add protected area'),
    'TR_CANCEL'              => tr('Cancel')
]);

Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['close'] = tr('Close');
    $translations['core']['ftp_directories'] = tr('Protected area path');
});
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
