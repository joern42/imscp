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

use iMSCP\TemplateEngine;
use iMSCP_Registry as Registry;

require 'imscp-lib.php';

checkLogin('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);

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
        setPageMessage(tr('Please specify a message subject.'), 'error');
        $error = true;
    }

    if ($data['message'] == '') {
        setPageMessage(tr('Please specify a message content.'), 'error');
        $error = true;
    }

    if (!$error) {
        setWelcomeEmail(0, $data);
        setPageMessage(tr('Welcome email template has been updated.'), 'success');
        redirectTo('settings_welcome_mail.php');
    }
}

$data = getWelcomeEmail($_SESSION['user_id']);

$tpl->assign([
    'TR_PAGE_TITLE'               => tr('Admin / Settings / Welcome Email'),
    'TR_EMAIL_SETUP'              => tr('Email setup'),
    'TR_MESSAGE_TEMPLATE_INFO'    => tr('Message template info'),
    'TR_USER_LOGIN_NAME'          => tr('User login (system) name'),
    'TR_USER_PASSWORD'            => tr('User password'),
    'TR_USER_REAL_NAME'           => tr('User real (first and last) name'),
    'TR_MESSAGE_TEMPLATE'         => tr('Message template'),
    'TR_SUBJECT'                  => tr('Subject'),
    'TR_MESSAGE'                  => tr('Message'),
    'TR_SENDER_EMAIL'             => tr('Reply-To email'),
    'TR_SENDER_NAME'              => tr('Reply-To name'),
    'TR_UPDATE'                   => tr('Update'),
    'TR_USERTYPE'                 => tr('User type (admin, reseller, user)'),
    'TR_BASE_SERVER_VHOST_PREFIX' => tr('URL protocol'),
    'TR_BASE_SERVER_VHOST'        => tr('URL to this admin panel'),
    'TR_BASE_SERVER_VHOST_PORT'   => tr('URL port'),
    'SUBJECT_VALUE'               => toHtml($data['subject']),
    'MESSAGE_VALUE'               => toHtml($data['message']),
    'SENDER_EMAIL_VALUE'          => toHtml($data['sender_email']),
    'SENDER_NAME_VALUE'           => toHtml($data['sender_name'])
]);

generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
