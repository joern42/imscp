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
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Form\Form;

/**
 * Add admin user
 *
 * @param Form $form
 * @return void
 */
function addAdminUser(Form $form)
{
    $form->setData($_POST);

    if (!$form->isValid()) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                View::setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddUser, NULL, [
            'userData' => $form->getData()
        ]);

        execQuery(
            "
                INSERT INTO admin (
                    admin_name, admin_pass, admin_type, domain_created, created_by, fname, lname, firm, zip, city, state, country, email, phone, fax,
                    street1, street2, gender
                ) VALUES (
                    ?, ?, 'admin', unix_timestamp(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ",
            [
                $form->getValue('admin_name'), Crypt::bcrypt($form->getValue('admin_pass')), $identity->getUserId(),
                $form->getValue('fname'), $form->getValue('lname'), $form->getValue('firm'), $form->getValue('zip'),
                $form->getValue('city'), $form->getValue('state'), $form->getValue('country'),
                encodeIdna($form->getValue('email')), $form->getValue('phone'), $form->getValue('fax'),
                $form->getValue('street1'), $form->getValue('street2'), $form->getValue('gender')
            ]
        );

        $adminId = $db->getDriver()->getLastGeneratedValue();
        $cfg = Application::getInstance()->getConfig();

        execQuery('INSERT INTO user_gui_props (user_id, lang, layout) VALUES (?, ?, ?)', [
            $adminId, $cfg['USER_INITIAL_LANG'], $cfg['USER_INITIAL_THEME']
        ]);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddUser, NULL, [
            'userId'   => $adminId,
            'userData' => $form->getValues()
        ]);

        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    Mail::sendWelcomeMail(
        $identity->getUserId(), $form->getValue('admin_name'), $form->getValue('admin_pass'), $form->getValue('email'), $form->getValue('fname'),
        $form->getValue('lname'), tr('Administrator')
    );
    writeLog(sprintf('The %s administrator has been added by %s', $form->getValue('admin_name'), $identity->getUsername()), E_USER_NOTICE);
    View::setPageMessage('Administrator has been added.', 'success');
    redirectTo('users.php');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$form = getUserLoginDataForm(true, true)->add(getUserPersonalDataForm()->getElements());
$form->setDefault('gender', 'U');

if(Application::getInstance()->getRequest()->isPost()) {
 addAdminUser($form);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/admin_add.phtml',
    'page_message' => 'layout'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Admin / Users / Add Admin')));
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->form = $form;
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
