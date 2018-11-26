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

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/ui.tpl',
    'page'           => 'reseller/settings_lostpassword.tpl',
    'page_message'   => 'layout',
    'custom_buttons' => 'page'
]);

$userID = Application::getInstance()->getAuthService()->getIdentity()->getUserId();
$data1 = Mail::getLostpasswordActivationEmail($userID);
$data2 = Mail::getLostpasswordEmail($userID);

if (isset($_POST['uaction']) && $_POST['uaction'] == 'apply') {
    $error = false;
    $data1['emailSubject'] = cleanInput($_POST['subject1']);
    $data1['emailBody'] = cleanInput($_POST['message1']);
    $data2['emailSubject'] = cleanInput($_POST['subject2']);
    $data2['emailBody'] = cleanInput($_POST['message2']);

    if (empty($data1['emailSubject']) || empty($data2['emailSubject'])) {
        View::setPageMessage(tr('You must specify a subject.'), 'error');
        $error = true;
    }

    if (empty($data1['emailBody']) || empty($data2['emailBody'])) {
        View::setPageMessage(tr('You must specify a message.'), 'error');
        $error = true;
    }

    if ($error) {
        return false;
    }

    Mail::setLostpasswordActivationEmail($userID, $data1);
    Mail::setLostpasswordEmail($userID, $data2);
    View::setPageMessage(tr('Lost password email templates were updated.'), 'success');
}

View::generateNavigation($tpl);
$tpl->assign([
    'TR_PAGE_TITLE'               => tr('Reseller / Customers / Lost Password Email'),
    'TR_MESSAGE_TEMPLATE_INFO'    => tr('Message template info'),
    'TR_MESSAGE_TEMPLATE'         => tr('Message template'),
    'SUBJECT_VALUE1'              => toHtml($data1['emailSubject']),
    'MESSAGE_VALUE1'              => toHtml($data1['emailBody']),
    'SUBJECT_VALUE2'              => toHtml($data2['emailSubject']),
    'MESSAGE_VALUE2'              => toHtml($data2['emailBody']),
    'SENDER_EMAIL_VALUE'          => toHtml($data1['senderEmail']),
    'SENDER_NAME_VALUE'           => toHtml($data1['senderName']),
    'TR_ACTIVATION_EMAIL'         => tr('Activation email'),
    'TR_PASSWORD_EMAIL'           => tr('Password email'),
    'TR_USER_LOGIN_NAME'          => tr('User login (system) name'),
    'TR_USER_PASSWORD'            => tr('User password'),
    'TR_USER_REAL_NAME'           => tr('User (first and last) name'),
    'TR_LOSTPW_LINK'              => tr('Lost password link'),
    'TR_SUBJECT'                  => tr('Subject'),
    'TR_MESSAGE'                  => tr('Message'),
    'TR_SENDER_EMAIL'             => tr('Reply-To email'),
    'TR_SENDER_NAME'              => tr('Reply-To name'),
    'TR_UPDATE'                   => tr('Update'),
    'TR_BASE_SERVER_VHOST_PREFIX' => tr('URL protocol'),
    'TR_BASE_SERVER_VHOST'        => tr('URL to this admin panel'),
    'TR_BASE_SERVER_VHOST_PORT'   => tr('URL port'),
    'TR_CANCEL'                   => tr('Cancel')
]);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
