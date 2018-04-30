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

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/settings_welcome_mail.tpl',
    'page_message' => 'layout'
]);

if (isset($_POST['uaction']) && $_POST['uaction'] == 'email_setup') {
    $data['subject'] = isset($_POST['auto_subject']) ? cleanInput($_POST['auto_subject']) : '';
    $data['message'] = isset($_POST['auto_message']) ? cleanInput($_POST['auto_message']) : '';
    $error = false;

    if ($data['subject'] == '') {
        View::setPageMessage(tr('Please specify a message subject.'), 'error');
        $error = true;
    }

    if ($data['message'] == '') {
        View::setPageMessage(tr('Please specify a message content.'), 'error');
        $error = true;
    }

    if (!$error) {
        Mail::setWelcomeEmail(0, $data);
        View::setPageMessage(tr('Welcome email template has been updated.'), 'success');
        redirectTo('settings_welcome_mail.php');
    }
}

$data = Mail::getWelcomeEmail(Application::getInstance()->getAuthService()->getIdentity()->getUserId());

$tpl->assign([
    'TR_PAGE_TITLE'               => toHtml(tr('Admin / Settings / Welcome Email')),
    'TR_EMAIL_SETUP'              => toHtml(tr('Email setup')),
    'TR_MESSAGE_TEMPLATE_INFO'    => toHtml(tr('Message template info')),
    'TR_USER_LOGIN_NAME'          => toHtml(tr('User login (system) name')),
    'TR_USER_PASSWORD'            => toHtml(tr('User password')),
    'TR_USER_REAL_NAME'           => toHtml(tr('User real (first and last) name')),
    'TR_MESSAGE_TEMPLATE'         => toHtml(tr('Message template')),
    'TR_SUBJECT'                  => toHtml(tr('Subject')),
    'TR_MESSAGE'                  => toHtml(tr('Message')),
    'TR_SENDER_EMAIL'             => toHtml(tr('Reply-To email')),
    'TR_SENDER_NAME'              => toHtml(tr('Reply-To name')),
    'TR_UPDATE'                   => toHtml(tr('Update')),
    'TR_USERTYPE'                 => toHtml(tr('User type (admin, reseller, user)')),
    'TR_BASE_SERVER_VHOST_PREFIX' => toHtml(tr('URL protocol')),
    'TR_BASE_SERVER_VHOST'        => toHtml(tr('URL to this admin panel')),
    'TR_BASE_SERVER_VHOST_PORT'   => toHtml(tr('URL port')),
    'SUBJECT_VALUE'               => toHtml($data['subject']),
    'MESSAGE_VALUE'               => toHtml($data['message']),
    'SENDER_EMAIL_VALUE'          => toHtml($data['sender_email']),
    'SENDER_NAME_VALUE'           => toHtml($data['sender_name'])
]);
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
