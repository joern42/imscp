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

use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use Zend\Config;
use Zend\EventManager\Event;

/**
 * Get mail account data
 *
 * @param int $mailId Mail account unique identifier
 * @return array mail account data
 */
function client_getEmailAccountData($mailId)
{
    static $mailData = NULL;

    if (NULL !== $mailData) {
        return $mailData;
    }

    $stmt = execQuery('SELECT * FROM mail_users WHERE mail_id = ? AND domain_id = ?', [$mailId, getCustomerMainDomainId(Application::getInstance()->getSession()['user_id'])]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    return $stmt->fetch();
}

/**
 * Edit mail account
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function client_editMailAccount()
{
    if (!isset($_POST['password']) || !isset($_POST['password_rep']) || !isset($_POST['quota']) || !isset($_POST['forward_list'])
        || !isset($_POST['account_type']) || !in_array($_POST['account_type'], ['1', '2', '3'], true)
    ) {
        View::showBadRequestErrorPage();
    }

    $mailData = client_getEmailAccountData(cleanInput($_GET['id']));
    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
    $password = $forwardList = '_no_';
    $mailType = '';
    $mailQuotaLimitBytes = NULL;

    if (!preg_match('/^(.*?)_(?:mail|forward)/', $mailData['mail_type'], $match)) {
        throw new \Exception('Could not determine mail type');
    }

    $domainType = $match[1];
    $mailTypeNormal = in_array($_POST['account_type'], ['1', '3']);
    $mailTypeForward = in_array($_POST['account_type'], ['2', '3']);

    if (!$mailTypeNormal && !$mailTypeForward) {
        View::showBadRequestErrorPage();
    }

    if (Application::getInstance()->getConfig()['SERVER_HOSTNAME'] == explode('@', $mailData['mail_addr'])[1] && $mailTypeNormal) {
        # SERVER_HOSTNAME is a canonical domain (local domain) which cannot be
        # listed in both `mydestination' and `virtual_mailbox_domains' Postfix
        # parameters. See http://www.postfix.org/VIRTUAL_README.html#canonical
        # This necessarily means that Postfix canonical domains cannot have
        # virtual mailboxes, hence their prohibition.
        setPageMessage(tr('You cannot create new mailboxes for that domain. Only forwarded mail accounts are allowed.'), 'warning');
        return false;
    }

    $mailAddr = $mailData['mail_addr'];

    if ($mailTypeNormal) {
        $password = cleanInput($_POST['password']);
        $passwordRep = cleanInput($_POST['password_rep']);

        if ($mailData['mail_pass'] == '_no_' || $password != '' || $passwordRep != '') {
            if ($password == '') {
                setPageMessage(tr('Password is missing.'), 'error');
                return false;
            }

            if ($passwordRep == '') {
                setPageMessage(tr('You must confirm your password.'), 'error');
                return false;
            }

            if ($password !== $passwordRep) {
                setPageMessage(tr('Passwords do not match.'), 'error');
                return false;
            }

            if (!checkPasswordSyntax($password)) {
                return false;
            }

            $password = Crypt::sha512($password);
        } else {
            $password = $mailData['mail_pass'];
        }

        // Check for quota

        $customerEmailQuotaLimitBytes = filterDigits($mainDmnProps['mail_quota'], 0);
        $mailQuotaLimitBytes = filterDigits($_POST['quota']) * 1048576; // MiB to Bytes

        if ($customerEmailQuotaLimitBytes > 0) {
            if ($mailQuotaLimitBytes < 1) {
                setPageMessage(tr('Incorrect mail quota.'), 'error');
                return false;
            }

            $customerMailboxesQuotaSumBytes = execQuery('SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE mail_id <> ? AND domain_id = ?', [
                $mailData['mail_id'], $mainDmnProps['domain_id']
            ])->fetchColumn();

            if ($customerMailboxesQuotaSumBytes >= $customerEmailQuotaLimitBytes) {
                View::showBadRequestErrorPage(); # Customer should never goes here excepted if it try to bypass js code
            }

            if ($mailQuotaLimitBytes > $customerEmailQuotaLimitBytes - $customerMailboxesQuotaSumBytes) {
                setPageMessage(tr('Mail quota cannot be bigger than %s', bytesHuman($mailQuotaLimitBytes)), 'error');
                return false;
            }
        }

        switch ($domainType) {
            case 'normal':
                $mailType = Mail::MT_NORMAL_MAIL;
                break;
            case 'subdom':
                $mailType = Mail::MT_SUBDOM_MAIL;
                break;
            case 'alias':
                $mailType = Mail::MT_ALIAS_MAIL;
                break;
            case 'alssub':
                $mailType = Mail::MT_ALSSUB_MAIL;
        }
    }

    if ($mailTypeForward) {
        $forwardList = cleanInput($_POST['forward_list']);
        if ($forwardList == '') {
            setPageMessage(tr('Forward list is empty.'), 'error');
            return false;
        }

        $forwardList = array_unique(preg_split('/\s|,/', $forwardList, -1, PREG_SPLIT_NO_EMPTY));
        foreach ($forwardList as $key => &$forwardEmailAddr) {
            $forwardEmailAddr = encodeIdna(mb_strtolower($forwardEmailAddr));

            if (!ValidateEmail($forwardEmailAddr)) {
                setPageMessage(tr('Bad email address in forward list field.'), 'error');
                return false;
            }

            if ($forwardEmailAddr == $mailAddr) {
                setPageMessage(tr('You cannot forward %s on itself.', $mailAddr), 'error');
                return false;
            }
        }

        if (empty($forwardList)) {
            setPageMessage(tr('Forward list is empty.'), 'error');
            return false;
        }

        $forwardList = implode(',', $forwardList);
        switch ($domainType) {
            case 'normal':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_NORMAL_FORWARD;
                break;
            case 'subdom':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_SUBDOM_FORWARD;
                break;
            case 'alias':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_ALIAS_FORWARD;
                break;
            case 'alssub':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_ALSSUB_FORWARD;
        }
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditMail, NULL, ['mailId' => $mailData['mail_id']]);
    execQuery(
        'UPDATE mail_users SET mail_pass = ?, mail_forward = ?, mail_type = ?, status = ?, po_active = ?, quota = ? WHERE mail_id = ?',
        [$password, $forwardList, $mailType, 'tochange', $mailTypeNormal ? 'yes' : 'no', $mailQuotaLimitBytes, $mailData['mail_id']]
    );

    # Force synching of quota info on next load (or remove cached data in case of normal account changed to forward account)
    $postfixConfig = loadConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/postfix/postfix.data');
    list($user, $domain) = explode('@', $mailAddr);
    unset(Application::getInstance()->getSession()['maildirsize'][normalizePath($postfixConfig['MTA_VIRTUAL_MAIL_DIR'] . "/$domain/$user/maildirsize")]);

    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditMail, NULL, ['mailId' => $mailData['mail_id']]);
    Daemon::sendRequest();
    writeLog(sprintf('A mail account (%s) has been edited by %s', decodeIdna($mailAddr), Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
    setPageMessage(tr('Mail account successfully scheduled for update.'), 'success');
    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 */
function client_generatePage($tpl)
{
    $mailId = cleanInput($_GET['id']);
    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
    $mailData = client_getEmailAccountData($mailId);
    list($username, $domainName) = explode('@', $mailData['mail_addr']);

    $customerMailboxesQuotaSumBytes = execQuery('SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE mail_id <> ? AND domain_id = ?', [
        $mailId, $mainDmnProps['domain_id']
    ])->fetchColumn();

    $customerEmailQuotaLimitBytes = filterDigits($mainDmnProps['mail_quota'], 0);

    if ($customerEmailQuotaLimitBytes < 1) {
        $tpl->assign([
            'TR_QUOTA'  => toHtml(tr('Quota in MiB (0 ∞)')),
            'MIN_QUOTA' => 0,
            'MAX_QUOTA' => toHtml(17592186044416, 'htmlAttr'), // Max quota = MySQL UNSIGNED BIGINT in MiB
            'QUOTA'     => isset($_POST['quota'])
                ? toHtml(filterDigits($_POST['quota']), 'htmlAttr') : toHtml($mailData['quota'] / 1048576, 'htmlAttr') // Bytes to MiB conversion
        ]);
        $mailTypeForwardOnly = false;
    } else {
        if ($customerEmailQuotaLimitBytes > $customerMailboxesQuotaSumBytes) {
            $mailQuotaLimitBytes = $customerEmailQuotaLimitBytes - $customerMailboxesQuotaSumBytes;
            $mailMaxQuotaLimitMib = $mailQuotaLimitBytes / 1048576;
            $mailQuotaLimitMiB = ($mailData['quota'] > 0 && $mailData['quota'] < $mailQuotaLimitBytes)
                ? $mailData['quota'] / 1048576 : min(10, $mailMaxQuotaLimitMib);
            $mailTypeForwardOnly = false;
        } else {
            setPageMessage(tr('You cannot make this account a normal mail account because you have already assigned all your mail quota. If you want make this account a normal mail account, you must first lower the quota assigned to one of your other mail account.'), 'static_info');
            setPageMessage(tr('For the time being, you can only edit your forwarded mail account.'), 'static_info');
            $mailQuotaLimitBytes = 1048576; // Only for sanity. Customer won't be able to switch to normal mail account
            $mailMaxQuotaLimitMib = 1;
            $mailQuotaLimitMiB = 1;
            $mailTypeForwardOnly = true;
        }

        $tpl->assign([
            'TR_QUOTA'  => toHtml(tr('Quota in MiB (Max: %s)', bytesHuman($mailQuotaLimitBytes))),
            'MIN_QUOTA' => 1,
            'MAX_QUOTA' => toHtml($mailMaxQuotaLimitMib, 'htmlAttr'),
            'QUOTA'     => isset($_POST['quota']) ? toHtml(filterDigits($_POST['quota']), 'htmlAttr') : toHtml($mailQuotaLimitMiB, 'htmlAttr')
        ]);
    }

    $mailType = '';

    if (!isset($_POST['account_type']) || !in_array($_POST['account_type'], ['1', '2', '3'])) {
        if (preg_match('/_mail/', $mailData['mail_type'])) {
            $mailType = '1';
        }

        if (preg_match('/_forward/', $mailData['mail_type'])) {
            $mailType = ($mailType == '1') ? '3' : '2';
        }
    } else {
        $mailType = $_POST['account_type'];
    }

    $tpl->assign([
        'MAIL_ID'                => toHtml($mailId),
        'USERNAME'               => toHtml($username),
        'NORMAL_CHECKED'         => $mailType == '1' ? ' checked' : '',
        'FORWARD_CHECKED'        => $mailType == '2' ? ' checked' : '',
        'NORMAL_FORWARD_CHECKED' => $mailType == '3' ? ' checked' : '',
        'PASSWORD'               => isset($_POST['password']) ? toHtml($_POST['password']) : '',
        'PASSWORD_REP'           => isset($_POST['password_rep']) ? toHtml($_POST['password_rep']) : '',
        'FORWARD_LIST'           => isset($_POST['forward_list'])
            ? toHtml($_POST['forward_list']) : ($mailData['mail_forward'] != '_no_' ? toHtml($mailData['mail_forward']) : ''),
        'DOMAIN_NAME'            => toHtml($domainName),
        'DOMAIN_NAME_UNICODE'    => toHtml(decodeIdna($domainName)),
        'DOMAIN_NAME_SELECTED'   => ' selected'
    ]);

    Application::getInstance()->getEventManager()->attach(
        Events::onGetJsTranslations,
        function (Event $e) use ($mailTypeForwardOnly) {
            $e->getParam('translations')->core['mail_add_forward_only'] = $mailTypeForwardOnly;
        }
    );
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('mail') && isset($_GET['id']) or View::showBadRequestErrorPage();

if (!empty($_POST) && client_editMailAccount()) {
    redirectTo('mail_accounts.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/mail_edit.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'          => tr('Client / Mail / Edit Mail Account'),
    'TR_MAIl_ACCOUNT_DATA'   => tr('Mail account data'),
    'TR_USERNAME'            => tr('Username'),
    'TR_DOMAIN_NAME'         => tr('Domain name'),
    'TR_MAIL_ACCOUNT_TYPE'   => tr('Mail account type'),
    'TR_NORMAL_MAIL'         => tr('Normal'),
    'TR_FORWARD_MAIL'        => tr('Forward'),
    'TR_FORWARD_NORMAL_MAIL' => tr('Normal + Forward'),
    'TR_PASSWORD'            => tr('Password'),
    'TR_PASSWORD_REPEAT'     => tr('Password confirmation'),
    'TR_FORWARD_TO'          => tr('Forward to'),
    'TR_FWD_HELP'            => tr('Separate addresses by a comma, line-break or space.'),
    'TR_UPDATE'              => tr('Update'),
    'TR_CANCEL'              => tr('Cancel')
]);
client_generatePage($tpl);
View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
