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

use iMSCP\Crypt as Crypt;
use iMSCP\TemplateEngine;
use iMSCP\VirtualFileSystem as VirtualFileSystem;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/**
 * Update Ftp account
 *
 * @param string $userid Ftp userid
 * @return bool TRUE on success, FALSE on failure
 */
function updateFtpAccount($userid)
{
    isset($_POST['password']) && isset($_POST['password_repeat']) && isset($_POST['home_dir']) or showBadRequestErrorPage();

    $error = false;
    $passwd = cleanInput($_POST['password']);
    $passwdRepeat = cleanInput($_POST['password_repeat']);
    $homeDir = normalizePath('/' . cleanInput($_POST['home_dir']));

    if ($passwd !== '') {
        if ($passwd !== $passwdRepeat) {
            setPageMessage(tr('Passwords do not match.'), 'error');
            $error = true;
        }

        if (!checkPasswordSyntax($_POST['password'])) {
            $error = true;
        }
    }

    if ($homeDir === '') {
        setPageMessage(tr('FTP home directory cannot be empty.'), 'error');
        $error = true;
    }

    if ($error) {
        return false;
    }

    $mainDmnProps = getCustomerProperties($_SESSION['user_id']);

    $vfs = new VirtualFileSystem($_SESSION['user_logged']);
    if ($homeDir !== '/' && !$vfs->exists($homeDir, VirtualFileSystem::VFS_TYPE_DIR)) {
        setPageMessage(tr("Directory '%s' doesn't exist.", $homeDir), 'error');
        return false;
    }

    $homeDir = normalizePath(Registry::get('config')['USER_WEB_DIR'] . '/' . $mainDmnProps['domain_name'] . '/' . $homeDir);

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeEditFtp, [
        'ftpUserId'   => $userid,
        'ftpPassword' => $passwd,
        'ftpUserHome' => $homeDir
    ]);

    if ($passwd !== '') {
        execQuery("UPDATE ftp_users SET passwd = ?, homedir = ?, status = 'tochange' WHERE userid = ? AND admin_id = ?", [
            Crypt::sha512($passwd), $homeDir, $userid, $_SESSION['user_id']
        ]);
    } else {
        execQuery("UPDATE ftp_users SET homedir = ?, status = 'tochange' WHERE userid = ? AND admin_id = ?", [
            $homeDir, $userid, $_SESSION['user_id']
        ]);
    }

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterEditFtp, [
        'ftpUserId'   => $userid,
        'ftpPassword' => $passwd,
        'ftpUserHome' => $homeDir
    ]);

    sendDaemonRequest();
    writeLog(sprintf('An FTP account (%s) has been updated by', $userid, $_SESSION['user_logged']), E_USER_NOTICE);
    setPageMessage(tr('FTP account successfully updated.'), 'success');
    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param string $ftpUserId Ftp userid
 * @return void
 */
function generatePage($tpl, $ftpUserId)
{
    $mainDmnProps = getCustomerProperties($_SESSION['user_id']);

    # Set parameters for the FTP chooser
    $_SESSION['ftp_chooser_domain_id'] = $mainDmnProps['domain_id'];
    $_SESSION['ftp_chooser_user'] = $_SESSION['user_logged'];
    $_SESSION['ftp_chooser_root_dir'] = '/';
    $_SESSION['ftp_chooser_hidden_dirs'] = [];
    $_SESSION['ftp_chooser_unselectable_dirs'] = [];

    $cfg = Registry::get('config');
    $stmt = execQuery('SELECT homedir FROM ftp_users WHERE userid = ?', [$ftpUserId]);
    $row = $stmt->fetch();

    $ftpHomeDir = normalizePath('/' . $row['homedir']);
    $customerHomeDir = normalizePath('/' . $cfg['USER_WEB_DIR'] . '/' . $mainDmnProps['domain_name']);

    if ($ftpHomeDir == $customerHomeDir) {
        $customFtpHomeDir = '/';
    } else {
        $customFtpHomeDir = substr($ftpHomeDir, strlen($customerHomeDir));
    }

    $tpl->assign([
        'USERNAME' => toHtml(decodeIdna($ftpUserId), 'htmlAttr'),
        'HOME_DIR' => isset($_POST['home_dir']) ? toHtml($_POST['home_dir']) : toHtml($customFtpHomeDir),
        'ID'       => toHtml($ftpUserId, 'htmlAttr'),
    ]);
}

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptStart);

customerHasFeature('ftp') && isset($_GET['id']) or showBadRequestErrorPage();

$userid = cleanInput($_GET['id']);
$stmt = execQuery('SELECT COUNT(admin_id) FROM ftp_users WHERE userid = ? AND admin_id = ?', [$userid, $_SESSION['user_id']]);
$stmt->fetchColumn() or showBadRequestErrorPage();

if (!empty($_POST)) {
    if (updateFtpAccount($userid)) {
        redirectTo('ftp_accounts.php');
    }
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/ftp_edit.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / FTP / Overview / Edit FTP Account'),
    'TR_FTP_USER_DATA'   => tr('Ftp account data'),
    'TR_USERNAME'        => tr('Username'),
    'TR_PASSWORD'        => tr('Password'),
    'TR_PASSWORD_REPEAT' => tr('Repeat password'),
    'TR_HOME_DIR'        => tr('Home directory'),
    'TR_CHOOSE_DIR'      => tr('Choose dir'),
    'TR_CHANGE'          => tr('Update'),
    'TR_CANCEL'          => tr('Cancel')
]);
Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['close'] = tr('Close');
    $translations['core']['ftp_directories'] = tr('FTP home directory');
});

generateNavigation($tpl);
generatePage($tpl, $userid);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
