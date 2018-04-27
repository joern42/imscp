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
use iMSCP\Functions\Login;
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
    $identity = Application::getInstance()->getAuthService()->getIdentity();

    $data = execQuery('SELECT admin_name FROM admin WHERE admin_id = ? AND created_by = ?', [$userId, $identity->getUserId()])->fetch();
    $data or View::showBadRequestErrorPage();

    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    $passwordUpdated = $form->getValue('admin_pass') !== '';

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
                phone = ?, fax = ?, street1 = ?, street2 = ?, gender = ?, admin_status = IF(?, 'tochangepwd', admin_status)
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
            $form->getValue('fname'), $form->getValue('lname'), tr('Customer')
        );
    }

    Daemon::sendRequest();
    writeLog(sprintf('The %s user has been updated by %s', $data['admin_name'], $identity->getUsername()), E_USER_NOTICE);
    setPageMessage('User has been updated.', 'success');

    if ($ret) {
        setPageMessage(tr('New login data were sent to the %s user.', decodeIdna($data['admin_name'])), 'success');
    }

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
    $tpl->form = $form;
    $tpl->editId = $userId;

    if (!empty($_POST)) {
        $form->setDefault('admin_name', getUsername($userId));
        return;
    }

    $stmt = execQuery(
        "
            SELECT admin_name, fname, lname, IFNULL(gender, 'U') as gender, firm, zip, city, state, country, street1, street2, email, phone, fax
            FROM admin
            WHERE admin_id = ?
            AND created_by = ?
        ",
        [$userId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
    );

    $data = $stmt->fetch() or View::showBadRequestErrorPage();
    $form->setDefaults($data);
}

require 'application.php';

Login::checkLogin('reseller');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
isset($_GET['client_id']) or View::showBadRequestErrorPage();

$userId = intval($_GET['client_id']);

if ($userId == Application::getInstance()->getAuthService()->getIdentity()->getUserId()) {
    redirectTo('personal_change.php');
}

$form = getUserLoginDataForm(false, false)->addElements(getUserPersonalDataForm()->getElements());

empty($_POST) or updateUserData($form, $userId);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/user_edit.phtml',
    'page_message' => 'layout'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Reseller / Customers / Overview / Edit Customer')));

View::generateNavigation($tpl);
generatePage($tpl, $form, $userId);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
