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
use iMSCP\Functions\View;

/**
 * Update password
 *
 * @return void
 */
function updatePassword()
{
    $form = getUserLoginDataForm(false, true);

    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, null, [
        'userId'   => Application::getInstance()->getSession()['user_id'],
        'userData' => [
            'admin_name' => getUsername(Application::getInstance()->getSession()['user_id']),
            'admin_pass' => $form->getValue('admin_pass')
        ]
    ]);
    execQuery("UPDATE admin SET admin_pass = ?, admin_status = IF(admin_type = 'user', 'tochangepwd', admin_status) WHERE admin_id = ?", [
        Crypt::apr1MD5($form->getValue('admin_pass')), Application::getInstance()->getSession()['user_id']
    ]);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, null, [
        'userId'   => Application::getInstance()->getSession()['user_id'],
        'userData' => [
            'admin_name' => getUsername(Application::getInstance()->getSession()['user_id']),
            'admin_pass' => $form->getValue('admin_pass')
        ]
    ]);

    if (Application::getInstance()->getSession()['user_type'] == 'user') {
        Daemon::sendRequest();
    }

    writeLog(sprintf('Password has been updated for the %s user.', Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
    setPageMessage(tr('Password successfully updated.'), 'success');
    redirectTo('password_update.php');
}



defined('SHARED_SCRIPT_NEEDED') or View::showNotFoundErrorPage();

empty($_POST) or updatePassword();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/password_update.phtml',
    'page_message' => 'layout'
]);
View::generateNavigation($tpl);
generatePageMessage($tpl);
