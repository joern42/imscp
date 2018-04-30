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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\View;

/**
 * Schedule backup restoration.
 *
 * @param int $userId Customer unique identifier
 * @return void
 */
function scheduleBackupRestoration($userId)
{
    execQuery("UPDATE domain SET domain_status = ? WHERE domain_admin_id = ?", ['torestore', $userId]);
    Daemon::sendRequest();
    writeLog(sprintf('A backup restore has been scheduled by %s.', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity())), E_USER_NOTICE);
    View::setPageMessage(tr('Backup has been successfully scheduled for restoration.'), 'success');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('backup') or View::showBadRequestErrorPage();

if (Application::getInstance()->getRequest()->isPost()) {
    scheduleBackupRestoration(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
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
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
