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
    $form->setData(Application::getInstance()->getRequest()->getPost());

    if (!$form->isValid()) {
        View::setPageMessage(View::formatPageMessages($form->getMessages()), 'error');
        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $ldata = $form->getData()['loginData'];
    $pdata = $form->getData()['personalData'];
    $dbConnect = Application::getInstance()->getDb()->getDriver()->getConnection();

    try {
        $dbConnect->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddUser, NULL, [
            'loginData'    => $ldata,
            'personalData' => $pdata
        ]);
        execQuery(
            "
                INSERT INTO admin (
                    admin_name, admin_pass, admin_type, domain_created, created_by, fname, lname, firm, zip, city, state, country, email, phone, fax,
                    street1, street2, gender
                ) VALUES (
                    ?, ?, 'admin', UNIX_TIMESTAMP(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ",
            [
                $ldata['admin_name'], Crypt::bcrypt($ldata['admin_pass']), $identity->getUserId(), $pdata['fname'], $pdata['lname'], $pdata['firm'],
                $pdata['zip'], $pdata['city'], $pdata['state'], $pdata['country'], encodeIdna($pdata['email']), $pdata['phone'], $pdata['fax'],
                $pdata['street1'], $pdata['street2'], $pdata['gender']
            ]
        );

        $config = Application::getInstance()->getConfig();

        execQuery('INSERT INTO user_gui_props (user_id, lang, layout) VALUES (LAST_INSERT_ID(), ?, ?)', [
            $config['USER_INITIAL_LANG'], $config['USER_INITIAL_THEME']
        ]);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddUser, NULL, [
            'userId'       => $dbConnect->getLastGeneratedValue(),
            'loginData'    => $ldata,
            'personalData' => $pdata
        ]);

        $dbConnect->commit();

        Mail::sendWelcomeMail($identity->getUserId(), $ldata['admin_name'], $ldata['admin_pass'], $pdata['email'], $pdata['fname'], $pdata['lname'],
            tr('Administrator')
        );
        writeLog(sprintf('The %s administrator has been added by %s', $ldata['admin_name'], $identity->getUsername()), E_USER_NOTICE);
        View::setPageMessage('Administrator has been added.', 'success');
        redirectTo('users.php');
    } catch (\Exception $e) {
        $dbConnect->rollBack();
        throw $e;
    }
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
        'options' => ['label' => tr('Add')]
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
