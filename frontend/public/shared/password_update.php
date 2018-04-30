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
                View::setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
        'userId'   => $identity->getUserId(),
        'userData' => [
            'admin_name' => $identity->getUsername(),
            'admin_pass' => $form->getValue('admin_pass')
        ]
    ]);
    execQuery("UPDATE admin SET admin_pass = ?, admin_status = IF(admin_type = 'user', 'tochangepwd', admin_status) WHERE admin_id = ?", [
        Crypt::bcrypt($form->getValue('admin_pass')), $identity->getUserId()
    ]);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
        'userId'   => $identity->getUserId(),
        'userData' => [
            'admin_name' => $identity->getUsername(),
            'admin_pass' => $form->getValue('admin_pass')
        ]
    ]);

    if ($identity->getUserType() == 'user') {
        Daemon::sendRequest();
    }

    writeLog(sprintf('Password has been updated for the %s user.', $identity->getUsername(), E_USER_NOTICE));
    View::setPageMessage(tr('Password successfully updated.'), 'success');
    redirectTo('password_update.php');
}

require_once 'application.php';

defined('SHARED_SCRIPT_NEEDED') or View::showNotFoundErrorPage();

if(Application::getInstance()->getRequest()->isPost()) {
    updatePassword();
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/password_update.phtml',
    'page_message' => 'layout'
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
