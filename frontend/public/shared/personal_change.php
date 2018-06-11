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

use iMSCP\Form\UserPersonalDataFieldset;
use iMSCP\Functions\View;
use Zend\Form\Element;
use Zend\Form\Form;

/**
 * Update personal data
 *
 * @param Form $form
 * @return void
 */
function updatePersonalData(Form $form)
{
    $form->setData(Application::getInstance()->getRequest()->getPost());

    if (!$form->isValid()) {
        View::setPageMessage(View::formatPageMessages($form->getMessages()), 'error');
        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $pdata = $form->getData()['personalData'];

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUserPersonalData, NULL, [
        'userId'       => $identity->getUserId(),
        'personalData' => $pdata
    ]);
    execQuery(
        "
            UPDATE admin
            SET fname = ?, lname = ?, firm = ?, zip = ?, city = ?, state = ?, country = ?, email = ?, phone = ?, fax = ?, street1 = ?, street2 = ?,
                gender = ?
            WHERE admin_id = ?
        ",
        [
            $pdata['fname'], $pdata['lname'], $pdata['firm'], $pdata['zip'], $pdata['city'], $pdata['state'], $pdata['country'],
            encodeIdna($pdata['email']), $pdata['phone'], $pdata['fax'], $pdata['street1'], $pdata['street2'], $pdata['gender'],
            $identity->getUserId()
        ]
    );
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUserPersonalData, NULL, [
        'userId'   => $identity->getUserId(),
        'userData' => $pdata
    ]);
    writeLog(sprintf('The %s user personal data were updated', $identity->getUsername()), E_USER_NOTICE);
    View::setPageMessage(tr('Personal data were updated.'), 'success');
    redirectTo('personal_change.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param Form $form
 * @return void
 */
function generatePage(TemplateEngine $tpl, Form $form)
{
    /** @noinspection PhpUndefinedFieldInspection */
    $tpl->form = $form;
    $stmt = execQuery(
        "
            SELECT admin_name, admin_type, fname, lname, IFNULL(gender, 'U') as gender, firm, zip, city, state, country, street1, street2, email,
            phone, fax
            FROM admin
            WHERE admin_id = ?
        ",
        [Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
    );
    $pdata = $stmt->fetch() or View::showBadRequestErrorPage();
    $form->get('personalData')->populateValues($pdata);
}

require_once 'application.php';

defined('SHARED_SCRIPT_NEEDED') or View::showNotFoundErrorPage();

($form = new Form('PersonalDataEditForm'))
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
        'options' => ['label' => tr('Update')]
    ]);

if (Application::getInstance()->getRequest()->isPost()) {
    updatePersonalData($form);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'shared/partials/personal_change.phtml',
    'page_message' => 'layout'
]);
View::generateNavigation($tpl);
generatePage($tpl, $form);
View::generatePageMessages($tpl);
