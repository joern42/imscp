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
use iMSCP\Functions\Counting;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

/**
 * Send email
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender email
 * @param string $subject Subject
 * @param string $body Body
 * @param array $rcptToData Recipient data
 * @return bool TRUE on success, FALSE on failure
 */
function admin_sendEmail($senderName, $senderEmail, $subject, $body, $rcptToData)
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
        writeLog(sprintf('Could not send admin circular to %s', $rcptToData['admin_name']), E_USER_ERROR);
        return false;
    }

    return true;
}

/**
 * Send circular to administrators
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender email
 * @param string $subject Subject
 * @param string $body Body
 * @return void
 */
function admin_sendToAdministrators($senderName, $senderEmail, $subject, $body)
{
    if (!Counting::systemHasManyAdmins()) {
        return;
    }

    $stmt = execQuery("SELECT MIN(admin_name), MIN(fname), MIN(lname), email FROM admin WHERE admin_type = 'admin' GROUP BY email");

    while ($rcptToData = $stmt->fetch()) {
        admin_sendEmail($senderName, $senderEmail, $subject, $body, $rcptToData);
    }
}

/**
 * Send circular to resellers
 *
 * @param string $senderName Sender name
 * @param string $senderEmail Sender email
 * @param string $subject Subject
 * @param string $body Body
 * @return void
 */
function admin_sendToResellers($senderName, $senderEmail, $subject, $body)
{
    if (!Counting::systemHasResellers()) {
        return;
    }

    $stmt = execQuery("SELECT MIN(admin_name), MIN(fname), MIN(lname), email FROM admin WHERE admin_type = 'reseller' GROUP BY email");
    while ($rcptToData = $stmt->fetch()) {
        admin_sendEmail($senderName, $senderEmail, $subject, $body, $rcptToData);
    }
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
function admin_sendToCustomers($senderName, $senderEmail, $subject, $body)
{
    if (!Counting::systemHasCustomers()) {
        return;
    }

    $stmt = execQuery("SELECT MIN(admin_name), MIN(fname), MIN(lname), email FROM admin WHERE admin_type = 'user' GROUP BY email");
    while ($rcptToData = $stmt->fetch()) {
        admin_sendEmail($senderName, $senderEmail, $subject, $body, $rcptToData);
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
function admin_isValidCircular($senderName, $senderEmail, $subject, $body)
{
    $ret = true;
    if ($senderName == '') {
        setPageMessage(tr('Sender name is missing.'), 'error');
        $ret = false;
    }

    if ($senderEmail == '') {
        setPageMessage(tr('Reply-To email is missing.'), 'error');
        $ret = false;
    } elseif (!ValidateEmail($senderEmail)) {
        setPageMessage(tr("Incorrect email length or syntax."), 'error');
        $ret = false;
    }

    if ($subject == '') {
        setPageMessage(tr('Subject is missing.'), 'error');
        $ret = false;
    }

    if ($body == '') {
        setPageMessage(tr('Body is missing.'), 'error');
        $ret = false;
    }

    return $ret;
}

/**
 * Send circular
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function admin_sendCircular()
{
    if (!isset($_POST['sender_name']) || !isset($_POST['sender_email']) || !isset($_POST['rcpt_to']) || !isset($_POST['subject'])
        || !isset($_POST['body'])
    ) {
        View::showBadRequestErrorPage();
    }

    $senderName = cleanInput($_POST['sender_name']);
    $senderEmail = cleanInput($_POST['sender_email']);
    $rcptTo = cleanInput($_POST['rcpt_to']);
    $subject = cleanInput($_POST['subject']);
    $body = cleanInput($_POST['body']);

    if (!admin_isValidCircular($senderName, $senderEmail, $subject, $body)) {
        return false;
    }

    $responses = Application::getInstance()->getEventManager()->trigger(Events::onBeforeSendCircular, NULL, [
        'sender_name'  => $senderName,
        'sender_email' => $senderEmail,
        'rcpt_to'      => $rcptTo,
        'subject'      => $subject,
        'body'         => $body
    ]);

    if ($responses->stopped()) {
        return true;
    }

    set_time_limit(0);
    ignore_user_abort(true);

    if ($rcptTo == 'all_users' || $rcptTo == 'administrators_resellers' || $rcptTo == 'administrators_customers' || $rcptTo == 'administrators') {
        admin_sendToAdministrators($senderName, $senderEmail, $subject, $body);
    }

    if ($rcptTo == 'all_users' || $rcptTo == 'administrators_resellers' || $rcptTo == 'resellers_customers' || $rcptTo == 'resellers') {
        admin_sendToResellers($senderName, $senderEmail, $subject, $body);
    }

    if ($rcptTo == 'all_users' || $rcptTo == 'administrators_customers' || $rcptTo == 'resellers_customers' || $rcptTo == 'customers') {
        admin_sendToCustomers($senderName, $senderEmail, $subject, $body);
    }

    Application::getInstance()->getEventManager()->trigger(Events::onAfterSendCircular, NULL, [
        'sender_name'  => $senderName,
        'sender_email' => $senderEmail,
        'rcpt_to'      => $rcptTo,
        'subject'      => $subject,
        'body'         => $body
    ]);
    setPageMessage(tr('Circular successfully sent.'), 'success');
    writeLog(sprintf('A circular has been sent by %s', Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
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
    $rcptTo = isset($_POST['rcpt_to']) ? $_POST['rcpt_to'] : '';
    $subject = isset($_POST['subject']) ? $_POST['subject'] : '';
    $body = isset($_POST['body']) ? $_POST['body'] : '';

    if ($senderName == '' && $senderEmail == '') {
        $stmt = execQuery('SELECT admin_name, fname, lname, email FROM admin WHERE admin_id = ?', [Application::getInstance()->getSession()['user_id']]);
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

    $rcptToOptions = [['all_users', tr('All users')]];

    if (Counting::systemHasManyAdmins() && Counting::systemHasResellers()) {
        $rcptToOptions[] = ['administrators_resellers', tr('Administrators and resellers')];
    }

    if (Counting::systemHasManyAdmins() && Counting::systemHasCustomers()) {
        $rcptToOptions[] = ['administrators_customers', tr('Administrators and customers')];
    }

    if (Counting::systemHasResellers() && Counting::systemHasCustomers()) {
        $rcptToOptions[] = ['resellers_customers', tr('Resellers and customers')];
    }

    if (Counting::systemHasManyAdmins()) {
        $rcptToOptions[] = ['administrators', tr('Administrators')];
    }

    if (Counting::systemHasResellers()) {
        $rcptToOptions[] = ['resellers', tr('Resellers')];
    }

    if (Counting::systemHasCustomers()) {
        $rcptToOptions[] = ['customers', tr('Customers')];
    }

    foreach ($rcptToOptions as $option) {
        $tpl->assign([
            'RCPT_TO'    => $option[0],
            'TR_RCPT_TO' => $option[1],
            'SELECTED'   => $rcptTo == $option[0] ? ' selected="selected"' : ''
        ]);
        $tpl->parse('RCPT_TO_OPTION', '.rcpt_to_option');
    }
}

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
Counting::systemHasAdminsOrResellersOrCustomers() or View::showBadRequestErrorPage();

if (!empty($_POST) && admin_sendCircular()) {
    redirectTo('users.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'         => 'shared/layouts/ui.tpl',
    'page'           => 'admin/circular.tpl',
    'page_message'   => 'layout',
    'rcpt_to_option' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'    => tr('Admin / Users / Circular'),
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
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
