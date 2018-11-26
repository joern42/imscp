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
use iMSCP\Functions\Counting;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;

/**
 * Send circular mail
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender email
 * @param string $subject Subject
 * @param string $body Body
 * @param array $rcptToData Recipient data
 * @return bool TRUE on success, FALSE on failure
 */
function sendCircularMail($senderName, $senderEmail, $subject, $body, $rcptToData)
{
    if ($rcptToData['email'] == '') {
        return true;
    }

    $ret = Mail::sendMail([
        'mail_id'      => 'admin-circular',
        'fname'        => $rcptToData['fname'],
        'lname'        => $rcptToData['lname'],
        'username'     => $rcptToData['admin_name'],
        'email'        => $rcptToData['email'],
        'sender_name'  => $senderName,
        'sender_email' => encodeIdna($senderEmail),
        'subject'      => $subject,
        'message'      => $body
    ]);

    if (!$ret) {
        writeLog(sprintf('Could not send reseller circular to %s', $rcptToData['admin_name']), E_USER_ERROR);
        return false;
    }

    return true;
}

/**
 * Send circular to customers
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender email
 * @param string $subject Subject
 * @param string $body Body
 * @return void
 */
function sendCircularToCustomers($senderName, $senderEmail, $subject, $body)
{
    if (!Counting::resellerHasClients()) {
        return;
    }

    $stmt = execQuery("SELECT MIN(admin_name), MIN(fname), MIN(lname), email FROM admin WHERE created_by = ? GROUP BY email", [
        Application::getInstance()->getAuthService()->getIdentity()->getUserId()
    ]);
    while ($rcptToData = $stmt->fetch()) {
        sendCircularMail($senderName, $senderEmail, $subject, $body, $rcptToData);
    }
}

/**
 * Validate circular
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender Email
 * @param string $subject Subject
 * @param string $body Body
 * @return bool TRUE if circular is valid, FALSE otherwise
 */
function isValidCircular($senderName, $senderEmail, $subject, $body)
{
    $ret = true;
    if ($senderName == '') {
        View::setPageMessage(tr('Sender name is missing.'), 'error');
        $ret = false;
    }

    if ($senderEmail == '') {
        View::setPageMessage(tr('Reply-To email is missing.'), 'error');
        $ret = false;
    } elseif (!ValidateEmail($senderEmail)) {
        View::setPageMessage(tr("Incorrect email length or syntax."), 'error');
        $ret = false;
    }

    if ($subject == '') {
        View::setPageMessage(tr('Subject is missing.'), 'error');
        $ret = false;
    }

    if ($body == '') {
        View::setPageMessage(tr('Body is missing.'), 'error');
        $ret = false;
    }

    return $ret;
}

/**
 * Send circular
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function sendCircular()
{
    isset($_POST['sender_name']) && isset($_POST['sender_email']) && isset($_POST['subject']) && isset($_POST['body']) or View::showBadRequestErrorPage();

    $senderName = cleanInput($_POST['sender_name']);
    $senderEmail = cleanInput($_POST['sender_email']);
    $subject = cleanInput($_POST['subject']);
    $body = cleanInput($_POST['body']);

    if (!isValidCircular($senderName, $senderEmail, $subject, $body)) {
        return false;
    }

    $responses = Application::getInstance()->getEventManager()->trigger(Events::onBeforeSendCircular, NULL, [
        'sender_name'  => $senderName,
        'sender_email' => $senderEmail,
        'rcpt_to'      => 'customers',
        'subject'      => $subject,
        'body'         => $body
    ]);

    if ($responses->stopped()) {
        return true;
    }

    set_time_limit(0);
    ignore_user_abort(true);
    sendCircularToCustomers($senderName, $senderEmail, $subject, $body);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterSendCircular, NULL, [
        'sender_name'  => $senderName,
        'sender_email' => $senderEmail,
        'rcpt_to'      => 'customers',
        'subject'      => $subject,
        'body'         => $body
    ]);
    View::setPageMessage(tr('Circular successfully sent.'), 'success');
    writeLog(sprintf('A circular has been sent by a reseller: %s', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity())), E_USER_NOTICE);
    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    $senderName = isset($_POST['sender_name']) ? $_POST['sender_name'] : '';
    $senderEmail = isset($_POST['sender_email']) ? $_POST['sender_email'] : '';
    $subject = isset($_POST['subject']) ? $_POST['subject'] : '';
    $body = isset($_POST['body']) ? $_POST['body'] : '';

    if ($senderName == '' && $senderEmail == '') {
        $stmt = execQuery('SELECT admin_name, fname, lname, email FROM admin WHERE admin_id = ?', [
            Application::getInstance()->getAuthService()->getIdentity()->getUserId()
        ]);
        $row = $stmt->fetch();

        if (!empty($row['fname']) && !empty($row['lname'])) {
            $senderName = $row['fname'] . ' ' . $row['lname'];
        } elseif (!empty($row['fname'])) {
            $senderName = $row['fname'];
        } elseif (!empty($row['lname'])) {
            $senderName = $row['lname'];
        } else {
            $senderName = $row['admin_name'];
        }

        if ($row['email'] != '') {
            $senderEmail = $row['email'];
        } else {
            $config = Application::getInstance()->getConfig();
            if (isset($config['DEFAULT_ADMIN_ADDRESS']) && $config['DEFAULT_ADMIN_ADDRESS'] != '') {
                $senderEmail = $config['DEFAULT_ADMIN_ADDRESS'];
            } else {
                $senderEmail = 'webmaster@' . $config['BASE_SERVER_VHOST'];
            }
        }
    }

    $tpl->assign([
        'SENDER_NAME'  => toHtml($senderName),
        'SENDER_EMAIL' => toHtml($senderEmail),
        'SUBJECT'      => toHtml($subject),
        'BODY'         => toHtml($body)
    ]);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
Counting::resellerHasClients() or View::showBadRequestErrorPage();

if (Application::getInstance()->getRequest()->isPost() && sendCircular()) {
    redirectTo('users.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'reseller/circular.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'    => tr('Reseller / Customers / Circular'),
    'TR_CIRCULAR'      => tr('Circular'),
    'TR_SEND_TO'       => tr('Send to'),
    'TR_SUBJECT'       => tr('Subject'),
    'TR_BODY'          => tr('Body'),
    'TR_SENDER_EMAIL'  => tr('Reply-To email'),
    'TR_SENDER_NAME'   => tr('Reply-To name'),
    'TR_SEND_CIRCULAR' => tr('Send circular'),
    'TR_CANCEL'        => tr('Cancel')
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
