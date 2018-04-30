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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Form\Form;

/**
 * Update user data
 *
 * @param Form $form
 * @param int $userId User unique identifier
 * @return void
 */
function updateUserData(Form $form, $userId)
{
    global $userType;

    $data = execQuery('SELECT admin_name, admin_type FROM admin WHERE admin_id = ?', [$userId])->fetch();
    $data !== false or View::showBadRequestErrorPage();
    $userType = $data['admin_type'];

    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                View::setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    $passwordUpdated = $form->getValue('admin_pass') != '';

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
            'userId'   => $userId,
            'userData' => $form->getValues()
        ]);
        execQuery(
            "
                UPDATE admin
                SET admin_pass = IFNULL(?, admin_pass), fname = ?, lname = ?, firm = ?, zip = ?, city = ?, state = ?, country = ?, email = ?,
                    phone = ?, fax = ?, street1 = ?, street2 = ?, gender = ?,
                    admin_status = IF(admin_type = 'user', IF(?, 'tochangepwd', admin_status), admin_status)
                WHERE admin_id = ?
            ",
            [
                $passwordUpdated ? Crypt::bcrypt($form->getValue('admin_pass')) : NULL, $form->getValue('fname'), $form->getValue('lname'),
                $form->getValue('firm'), $form->getValue('zip'), $form->getValue('city'), $form->getValue('state'), $form->getValue('country'),
                encodeIdna($form->getValue('email')), $form->getValue('phone'), $form->getValue('fax'), $form->getValue('street1'),
                $form->getValue('street2'), $form->getValue('gender'), $passwordUpdated ? 1 : 0, $userId
            ]
        );
        // Force user to login again (needed due to possible password or email change)
        execQuery('DELETE FROM login WHERE user_name = ?', [$data['admin_name']]);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
            'userId'   => $userId,
            'userData' => $form->getValues()
        ]);
        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    $ret = false;
    if ($passwordUpdated) {
        $ret = Mail::sendWelcomeMail(
            $userId, $data['admin_name'], $form->getValue('admin_pass'), $form->getValue('email'),
            $form->getValue('fname'), $form->getValue('lname'), $data['admin_type'] == 'admin' ? tr('Administrator') : tr('Customer')
        );
    }

    $userType != 'user' or Daemon::sendRequest();

    writeLog(sprintf('The %s user has been updated by %s', $data['admin_name'], Application::getInstance()->getAuthService()->getIdentity()->getUsername()), E_USER_NOTICE);
    View::setPageMessage('User has been updated.', 'success');
    !$ret or View::setPageMessage(tr('New login data were sent to the %s user.', decodeIdna($data['admin_name'])), 'success');
    redirectTo("user_edit.php?edit_id=$userId");
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param Form $form
 * @param int $userId User unique identifier
 *
 * @return void
 */
function generatePage(TemplateEngine $tpl, Form $form, $userId)
{
    global $userType;

    $tpl->form = $form;
    $tpl->editId = $userId;

    if (Application::getInstance()->getRequest()->isPost()) {
        $form->setDefault('admin_name', getUsername($userId));
        return;
    }

    $stmt = execQuery(
        "
            SELECT admin_name, admin_type, fname, lname, IFNULL(gender, 'U') as gender, firm, zip, city, state, country, street1, street2, email,
                phone, fax
            FROM admin
            WHERE admin_id = ?
        ",
        [$userId]
    );

    $data = $stmt->fetch() !== false or View::showBadRequestErrorPage();
    $userType = $data['admin_type'];
    $form->setDefaults($data);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
isset($_GET['edit_id']) or View::showBadRequestErrorPage();

$userId = intval($_GET['edit_id']);
$userId != Application::getInstance()->getAuthService()->getIdentity()->getUserId() or redirectTo('personal_change.php');

global $userType;

$form = getUserLoginDataForm(false, false)->addElements(getUserPersonalDataForm()->getElements());

if(Application::getInstance()->getRequest()->isPost()) {
    updateUserData($form, $userId);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/user_edit.phtml',
    'page_message' => 'layout'
]);

View::generateNavigation($tpl);
generatePage($tpl, $form, $userId);
View::generatePageMessages($tpl);

if ($userType == 'admin') {
    $tpl->assign([
        'TR_PAGE_TITLE'       => toHtml(tr('Admin / Users / Overview / Edit Admin')),
        'TR_DYNAMIC_TITLE'    => toHtml(tr('Edit admin')),
        'DYNAMIC_TITLE_CLASS' => 'user_yellow'
    ]);
} else {
    $tpl->assign([
        'TR_PAGE_TITLE'       => toHtml(tr('Admin / Users / Overview / Edit Customer')),
        'TR_DYNAMIC_TITLE'    => toHtml(tr('Edit customer')),
        'DYNAMIC_TITLE_CLASS' => 'user_blue'
    ]);
}

$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
