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
use iMSCP\Update\UpdateException;
use iMSCP\Update\UpdateVersion;
use iMSCP_Registry as Registry;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function admin_generatePage($tpl)
{
    try {
        $cfg = Registry::get('config');

        if (!$cfg['CHECK_FOR_UPDATES']) {
            setPageMessage(tr('i-MSCP version update checking is disabled.'), 'static_info');
            $tpl->assign('UPDATE_INFO', '');
            return;
        }

        $updateVersion = new UpdateVersion();

        if (!$updateVersion->isAvailableUpdate()) {
            setPageMessage(tr('No update available'), 'static_info');
            $tpl->assign('UPDATE_INFO', '');
            return;
        }

        $updateInfo = $updateVersion->getUpdateInfo();
        $date = new DateTime($updateInfo['published_at']);
        $tpl->assign([
            'TR_UPDATE_INFO'         => tr('Update info'),
            'TR_RELEASE_VERSION'     => tr('Release version'),
            'RELEASE_VERSION'        => toHtml($updateInfo['tag_name']),
            'TR_RELEASE_DATE'        => tr('Release date'),
            'RELEASE_DATE'           => toHtml($date->format($cfg['DATE_FORMAT'])),
            'TR_RELEASE_DESCRIPTION' => tr('Release description'),
            'RELEASE_DESCRIPTION'    => toHtml($updateInfo['body']),
            'TR_DOWNLOAD_LINKS'      => tr('Download links'),
            'TR_DOWNLOAD_ZIP'        => tr('Download ZIP'),
            'TR_DOWNLOAD_TAR'        => tr('Download TAR'),
            'TARBALL_URL'            => toHtml($updateInfo['tarball_url']),
            'ZIPBALL_URL'            => toHtml($updateInfo['zipball_url'])
        ]);
    } catch (UpdateException $e) {
        writeLog($e->getMessage(), E_USER_ERROR);
        setPageMessage(tr("Couldn't get update information from Github. Consult the admin logs for more details."), 'static_error');
        $tpl->assign('UPDATE_INFO', '');
    }
}

require 'imscp-lib.php';

checkLogin('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);
stripos(Registry::get('config')['Version'], 'git') === false or showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/imscp_updates.tpl',
    'page_message' => 'layout',
    'update_info'  => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Admin / System Tools / i-MSCP Updates')));
generateNavigation($tpl);
admin_generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
