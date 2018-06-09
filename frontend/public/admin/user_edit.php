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
use iMSCP\Form\UserLoginDataFieldset;
use iMSCP\Form\UserPersonalDataFieldset;
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Form\Element;
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

    $form->setData($_POST);
    // We do not want validate username in edit mode
    $form->getInputFilter()->get('loginData')->remove('admin_name');

    // Password is optional in edit mode
    $form->getInputFilter()->get('loginData')->get('admin_pass')->setRequired(false);
    if ($form->get('loginData')->get('admin_pass')->getValue() == ''
        && $form->get('loginData')->get('admin_pass_confirmation')->getValue() == ''
    ) {
        $form->getInputFilter()->get('loginData')->get('admin_pass_confirmation')->setRequired(false);
    }

    if (!$form->isValid()) {
        foreach ($form->getMessages() as $messages) {
            foreach ($messages as $fieldsetMessages) {
                View::setPageMessage(View::formatPageMessages($fieldsetMessages), 'error');
            }
        }

        return;
    }

    /** @var \Zend\Form\Fieldset $loginData */
    $loginData = $form->get('loginData');
    /** @var \Zend\Form\Fieldset $personalData */
    $personalData = $form->get('personalData');
    $newPassword = $loginData->get('admin_pass')->getValue();

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
            'userId'   => $userId,
            'userData' => $form->getData()
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
                $newPassword != '' ? Crypt::bcrypt($newPassword) : NULL,
                $personalData->get('fname')->getValue(),
                $personalData->get('lname')->getValue(),
                $personalData->get('firm')->getValue(),
                $personalData->get('zip')->getValue(),
                $personalData->get('city')->getValue(),
                $personalData->get('state')->getValue(),
                $personalData->get('country')->getValue(),
                encodeIdna($personalData->get('email')->getValue()),
                $personalData->get('phone')->getValue(),
                $personalData->get('fax')->getValue(),
                $personalData->get('street1')->getValue(),
                $personalData->get('street2')->getValue(),
                $personalData->get('gender')->getValue(),
                $newPassword != '' ? 1 : 0,
                $userId
            ]
        );
        // Force user to login again (needed due to possible password or email change)
        execQuery('DELETE FROM login WHERE user_name = ?', [$data['admin_name']]);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
            'userId'   => $userId,
            'userData' => $form->getData()
        ]);
        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    $ret = false;
    if ($newPassword != '') {
        $ret = Mail::sendWelcomeMail(
            $userId,
            $data['admin_name'],
            $newPassword,
            $personalData->get('email')->getValue(),
            $personalData->get('fname')->getValue(),
            $personalData->get('lname')->getValue(),
            $data['admin_type'] == 'admin' ? tr('Administrator') : tr('Customer')
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
 * @return void
 */
function generatePage(TemplateEngine $tpl, Form $form, $userId)
{
    global $userType;

    /** @noinspection PhpUndefinedFieldInspection */
    $tpl->form = $form;
    /** @noinspection PhpUndefinedFieldInspection */
    $tpl->editId = $userId;

    if (Application::getInstance()->getRequest()->isPost()) {
        $form->get('loginData')->get('admin_name')->setValue(getUsername($userId));
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

    ($data = $stmt->fetch()) !== false or View::showBadRequestErrorPage();
    $userType = $data['admin_type'];
    $form->get('loginData')->populateValues($data);
    $form->get('personalData')->populateValues($data);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
isset($_GET['edit_id']) or View::showBadRequestErrorPage();

$userId = intval($_GET['edit_id']);
$userId != Application::getInstance()->getAuthService()->getIdentity()->getUserId() or redirectTo('personal_change.php');

global $userType;

($form = new Form('UserEditForm'))
    ->add([
        'type' => UserLoginDataFieldset::class,
        'name' => 'loginData'
    ])
    ->add([
        'type' => UserPersonalDataFieldset::class,
        'name' => 'personalData'
    ])
    ->add([
        'type'    => Element\Csrf::class,
        'name'    => 'csrf',
        'options' => [
            'csrf_options' => [
                'timeout' => 300,
                'message' => tr('Validation token (CSRF) was expired. Please try again.')
            ]
        ]
    ])
    ->add([
        'type'    => Element\Submit::class,
        'name'    => 'submit',
        'options' => [
            'label' => tr('Update')
        ]
    ])
    ->get('personalData')->get('gender')->setValue('U');

if (Application::getInstance()->getRequest()->isPost()) {
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
