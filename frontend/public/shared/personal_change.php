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

use iMSCP\Functions\View;
use Zend\Form\Form;

/**
 * Update personal data
 *
 * @param Form $form
 * @return void
 */
function updatePersonalData(Form $form)
{
    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                View::setPageMessage(toHtml($msg), 'error');
            }
        }

        return;
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    $idnaEmail = $form->getValue('email');

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
        'userId'   => $identity->getUserId(),
        'userData' => $form->getValues()
    ]);
    execQuery(
        "
            UPDATE admin
            SET fname = ?, lname = ?, firm = ?, zip = ?, city = ?, state = ?, country = ?, email = ?, phone = ?, fax = ?, street1 = ?, street2 = ?,
                gender = ?
            WHERE admin_id = ?
        ",
        [
            $form->getValue('fname'), $form->getValue('lname'), $form->getValue('firm'), $form->getValue('zip'),
            $form->getValue('city'), $form->getValue('state'), $form->getValue('country'),
            $idnaEmail, $form->getValue('phone'), $form->getValue('fax'), $form->getValue('street1'),
            $form->getValue('street2'), $form->getValue('gender'), $identity->getUserId()
        ]
    );

    # We need also update user email in session
    //AuthenticationService::getInstance()->getIdentity()->email = $idnaEmail;
    //Application::getInstance()->getSession()['user_email'] = $idnaEmail; // Only for backward compatibility

    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
        'userId'   => $identity->getUserId(),
        'userData' => $form->getValues()
    ]);
    writeLog(sprintf('The %s user data were updated', $identity->getUsername()), E_USER_NOTICE);
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
    $tpl->form = $form;

    if (Application::getInstance()->getRequest()->isPost()) {
        return;
    }

    $stmt = execQuery(
        "
            SELECT admin_name, admin_type, fname, lname, IFNULL(gender, 'U') as gender, firm, zip, city, state, country, street1, street2, email,
            phone, fax
            FROM admin
            WHERE admin_id = ?
        ",
        [Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
    );

    $data = $stmt->fetch() or View::showBadRequestErrorPage();
    $form->setDefaults($data);
}

require_once 'application.php';

defined('SHARED_SCRIPT_NEEDED') or View::showNotFoundErrorPage();

$form = getUserPersonalDataForm();

if(Application::getInstance()->getRequest()->isPost()) {
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
