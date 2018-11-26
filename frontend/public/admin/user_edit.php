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
use iMSCP\Form\LoginDataFieldset;
use iMSCP\Form\PersonalDataFieldset;
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

    $udata = execQuery('SELECT admin_name, admin_type FROM admin WHERE admin_id = ?', [$userId])->fetch();
    $udata !== false or View::showBadRequestErrorPage();
    $userType = $udata['admin_type'];

    $form->setData(Application::getInstance()->getRequest()->getPost());

    // We do not want validate username in edit mode
    $form->getInputFilter()->get('logindatafieldset')->remove('admin_name');

    // Password is optional in edit mode
    $form->getInputFilter()->get('logindatafieldset')->get('admin_pass')->setRequired(false);
    if ($form->get('logindatafieldset')->get('admin_pass')->getValue() == ''
        && $form->get('logindatafieldset')->get('admin_pass_confirmation')->getValue() == ''
    ) {
        $form->getInputFilter()->get('logindatafieldset')->get('admin_pass_confirmation')->setRequired(false);
    }

    if (!$form->isValid()) {
        View::setPageMessage(View::formatPageMessages($form->getMessages()), 'error');
        return;
    }

    $ldata = $form->getData()['logindatafieldset'];
    $pdata = $form->getData()['personaldatafieldset'];

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
            'loginData'    => $ldata,
            'personalData' => $pdata
        ]);
        execQuery(
            "
                UPDATE admin
                SET admin_pass = IFNULL(?, admin_pass), fname = ?, lname = ?, firm = ?, zip = ?, city = ?, state = ?, country = ?, email = ?,
                    phone = ?, fax = ?, street1 = ?, street2 = ?, gender = ?, admin_status = IF(
                    admin_type = 'user', IF(?, 'tochangepwd', admin_status), admin_status
                )
                WHERE admin_id = ?
            ",
            [
                $ldata['admin_pass'] != '' ? Crypt::bcrypt($ldata['admin_pass']) : NULL, $pdata['fname'], $pdata['lname'], $pdata['firm'],
                $pdata['zip'], $pdata['city'], $pdata['state'], $pdata['country'], encodeIdna($pdata['email']), $pdata['phone'], $pdata['fax'],
                $pdata['street1'], $pdata['street2'], $pdata['gender'], $ldata['admin_pass'] != '' ? 1 : 0, $userId
            ]
        );
        // Force user to login again (needed due to possible password or email change)
        //execQuery('DELETE FROM login WHERE user_name = ?', [$udata['admin_name']]);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
            'userId'       => $userId,
            'loginData'    => $ldata,
            'personalData' => $pdata

        ]);
        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    $ret = false;
    if ($ldata['admin_pass'] != '') {
        $ret = Mail::sendAcountUpdateMail($userId, $udata['admin_name'], $ldata['admin_pass'], $pdata['email'], $pdata['fname'], $pdata['lname'],
            $udata['admin_type'] == 'admin' ? tr('Administrator') : tr('Customer')
        );
    }

    $userType != 'user' or Daemon::sendRequest();

    writeLog(sprintf('The %s user has been updated by %s', $udata['admin_name'], Application::getInstance()->getAuthService()->getIdentity()->getUsername()), E_USER_NOTICE);
    View::setPageMessage('User has been updated.', 'success');
    !$ret or View::setPageMessage(tr('New login data were sent to the %s user.', decodeIdna($udata['admin_name'])), 'success');
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
        $form->get('logindatafieldset')->get('admin_name')->setValue(getUsername($userId));
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
    $form->get('logindatafieldset')->populateValues($data);
    $form->get('personaldatafieldset')->populateValues($data);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
($userId = Application::getInstance()->getRequest()->getQuery('edit_id')) !== NULL or View::showBadRequestErrorPage();
$userId != Application::getInstance()->getAuthService()->getIdentity()->getUserId() or redirectTo('personal_change.php');

global $userType;

($form = new Form('user-edit-form'))
    ->add(['type' => LoginDataFieldset::class])
    ->add(['type' => PersonalDataFieldset::class])
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
        'options' => ['label' => tr('Update')]
    ]);

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
