<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "VHCS - Virtual Hosting Control System".
 *
 * The Initial Developer of the Original Code is moleSoftware GmbH.
 * Portions created by Initial Developer are Copyright (C) 2001-2006
 * by moleSoftware GmbH. All Rights Reserved.
 *
 * Portions created by the ispCP Team are Copyright (C) 2006-2010 by
 * isp Control Panel. All Rights Reserved.
 *
 * Portions created by the i-MSCP Team are Copyright (C) 2010-2018 by
 * i-MSCP - internet Multi Server Control Panel. All Rights Reserved.
 */

use iMSCP_Registry as Registry;
use iMSCP\TemplateEngine;

/***********************************************************************************************************************
 * Functions
 */

/**
 * Schedule backup restoration.
 *
 * @param int $userId Customer unique identifier
 * @return void
 */
function scheduleBackupRestoration($userId)
{
    exec_query("UPDATE domain SET domain_status = ? WHERE domain_admin_id = ?", ['torestore', $userId]);
    send_request();
    write_log(sprintf('A backup restore has been scheduled by %s.', $_SESSION['user_logged']), E_USER_NOTICE);
    set_page_message(tr('Backup has been successfully scheduled for restoration.'), 'success');
}

/***********************************************************************************************************************
 * Main
 */

require_once 'imscp-lib.php';

check_login('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('backup') or showBadRequestErrorPage();

if (!empty($_POST)) {
    scheduleBackupRestoration($_SESSION['user_id']);
    redirectTo('backup.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/backup.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'         => tr('Client / Webtools / Daily Backup'),
    'TR_BACKUP'             => tr('Backup'),
    'TR_DAILY_BACKUP'       => tr('Daily backup'),
    'TR_DOWNLOAD_DIRECTION' => tr("Download last daily backup"),
    'TR_FTP_LOG_ON'         => tr('Login with your FTP account'),
    'TR_SWITCH_TO_BACKUP'   => tr('Go in the backups directory'),
    'TR_DOWNLOAD_FILE'      => tr('Download the files stored in the directory'),
    'TR_RESTORE_BACKUP'     => tr('Restore last daily backup'),
    'TR_RESTORE_DIRECTIONS' => tr("Click the 'Restore' button to restore the last daily backup. This include Web data and SQL databases. Bear in mind that only known databases are restored."),
    'TR_RESTORE'            => tr('Restore'),
    'TR_CONFIRM_MESSAGE'    => tr('Are you sure you want to restore the last daily backup?')
]);

generateNavigation($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();

unsetMessages();
