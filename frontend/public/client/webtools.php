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
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;

/**
 * Hide disabled feature.
 *
 * @param TemplateEngine $tpl Template engine instance
 */
function client_hideDisabledFeatures($tpl)
{
    if (!Counting::customerHasFeature('backup')) {
        $tpl->assign('BACKUP_FEATURE', '');
    }

    $webmails = Mail::getWebmailList();
    if (!Counting::customerHasFeature('mail') || empty($webmails)) {
        $tpl->assign('MAIL_FEATURE', '');
    } else {
        if (in_array('Roundcube', $webmails)) {
            $tpl->assign('WEBMAIL_RPATH', '/webmail/');
        } else {
            $tpl->assign('WEBMAIL_RPATH', '/' . strtolower($webmails[0]) . '/');
        }
    }

    if (!Counting::customerHasFeature('ftp') || Application::getInstance()->getConfig()['FILEMANAGERS'] == 'no') {
        $tpl->assign('FTP_FEATURE', '');
    }

    if (!Counting::customerHasFeature('webstats')) {
        $tpl->assign('WEBSTATS_FEATURE', '');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);

$tpl = new TemplateEngine();
$tpl->define(
    [
        'layout'           => 'shared/layouts/ui.tpl',
        'page'             => 'client/webtools.tpl',
        'page_message'     => 'layout',
        'backup_feature'   => 'page',
        'mail_feature'     => 'page',
        'ftp_feature'      => 'page',
        'webstats_feature' => 'page'
    ]
);
$tpl->assign(
    [
        'TR_PAGE_TITLE'        => tr('Client / Webtools / Overview'),
        'TR_FEATURE'           => tr('Feature'),
        'TR_DESCRIPTION'       => tr('Description'),
        'TR_HTACCESS'          => tr('Protected areas'),
        'TR_HTACCESS_TXT'      => tr('Manage your protected areas, users and groups.'),
        'TR_ERROR_PAGES'       => tr('Error pages'),
        'TR_ERROR_PAGES_TXT'   => tr('Customize error pages for your domain.'),
        'TR_BACKUP'            => tr('Backup'),
        'TR_BACKUP_TXT'        => tr('Backup and restore settings.'),
        'TR_WEBMAIL'           => tr('Webmail'),
        'TR_WEBMAIL_TXT'       => tr('Access your mail through the web interface.'),
        'TR_FILEMANAGER'       => tr('FileManager'),
        'TR_FILEMANAGER_TXT'   => tr('Access your files through the web interface.'),
        'TR_WEBSTATS'          => tr('Web Statistics'),
        'TR_WEBSTATS_TXT'      => tr('Access your domain statistics through the Web interface.'),
        'TR_APP_INSTALLER'     => tr('Application installer'),
        'TR_APP_INSTALLER_TXT' => tr('Install various Web applications with a few clicks.')
    ]
);
View::generateNavigation($tpl);
client_hideDisabledFeatures($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
