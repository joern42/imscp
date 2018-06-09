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
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Form\Element;
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
                $loginData->get('admin_name')->getValue(),
                Crypt::bcrypt($loginData->get('admin_pass')->getValue()),
                $identity->getUserId(),
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
                $personalData->get('gender')->getValue()
            ]
        );

        $adminId = $db->getDriver()->getLastGeneratedValue();
        $config = Application::getInstance()->getConfig();

        execQuery('INSERT INTO user_gui_props (user_id, lang, layout) VALUES (?, ?, ?)', [
            $adminId, $config['USER_INITIAL_LANG'], $config['USER_INITIAL_THEME']
        ]);

        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddUser, NULL, [
            'userId'   => $adminId,
            'userData' => $form->getData()
        ]);

        $db->getDriver()->getConnection()->commit();
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }

    Mail::sendWelcomeMail(
        $identity->getUserId(),
        $loginData->get('admin_name')->getValue(),
        $loginData->get('admin_pass')->getValue(),
        $personalData->get('email')->getValue(),
        $personalData->get('fname')->getValue(),
        $personalData->get('lname')->getValue(),
        tr('Administrator')
    );
    writeLog(sprintf('The %s administrator has been added by %s', $loginData->get('admin_name')->getValue(), $identity->getUsername()), E_USER_NOTICE);
    View::setPageMessage('Administrator has been added.', 'success');
    redirectTo('users.php');
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

($form = new Form('AdminAddForm'))
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
            'label' => tr('Add')
        ]
    ])
    ->get('personalData')->get('gender')->setValue('U');

if (Application::getInstance()->getRequest()->isPost()) {
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
/** @noinspection PhpUndefinedFieldInspection */
$tpl->form = $form;
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
