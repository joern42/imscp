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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Get domains list
 *
 * @return array Domains list
 */
function getDomainsList()
{
    static $domainsList = NULL;

    if (NULL === $domainsList) {
        $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
        $domainsList = [[
            'name' => $mainDmnProps['domain_name'],
            'id'   => $mainDmnProps['domain_id'],
            'type' => 'dmn'
        ]];
        $stmt = execQuery(
            "
              SELECT CONCAT(t1.subdomain_name, '.', t2.domain_name) AS name, t1.subdomain_id AS id, 'sub' AS type
              FROM subdomain AS t1
              JOIN domain AS t2 USING(domain_id)
              WHERE t1.domain_id = :domain_id AND t1.subdomain_status = :status_ok
              UNION ALL
              SELECT alias_name AS name, alias_id AS id, 'als' AS type
              FROM domain_aliases
              WHERE domain_id = :domain_id AND alias_status = :status_ok
              UNION ALL
              SELECT CONCAT(t1.subdomain_alias_name, '.', t2.alias_name) AS name, t1.subdomain_alias_id AS id,
                'alssub' AS type
              FROM subdomain_alias AS t1
              JOIN domain_aliases AS t2 USING(alias_id)
              WHERE t2.domain_id = :domain_id AND subdomain_alias_status = :status_ok
          ",
            ['domain_id' => $mainDmnProps['domain_id'], 'status_ok' => 'ok']
        );
        if ($stmt->rowCount()) {
            $domainsList = array_merge($domainsList, $stmt->fetchAll());
            usort($domainsList, function ($a, $b) {
                return strnatcmp(decodeIdna($a['name']), decodeIdna($b['name']));
            });
        }
    }

    return $domainsList;
}

/**
 * Add mail account
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function addMailAccount()
{
    if (!isset($_POST['username']) || !isset($_POST['domain_name']) || !isset($_POST['password']) || !isset($_POST['password_rep'])
        || !isset($_POST['quota']) || !isset($_POST['forward_list']) || !isset($_POST['account_type'])
        || !in_array($_POST['account_type'], ['1', '2', '3'], true)
    ) {
        View::showBadRequestErrorPage();
    }

    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
    $password = $forwardList = '_no_';
    $mailType = $subId = '';
    $mailTypeNormal = in_array($_POST['account_type'], ['1', '3']);
    $mailTypeForward = in_array($_POST['account_type'], ['2', '3']);
    $mailQuotaLimitBytes = NULL;

    // Check for username
    $username = mb_strtolower(cleanInput($_POST['username']));

    if ($_POST['username'] == '' || !ValidateEmail($username, true)) {
        setPageMessage(tr('Invalid email username.'), 'error');
        return false;
    }

    // Check for domain existence and owner
    $domainName = mb_strtolower(cleanInput($_POST['domain_name']));
    $domainType = NULL;
    $domainId = NULL;

    foreach (getDomainsList() as $domain) {
        if ($domain['name'] == $domainName) {
            $domainType = $domain['type'];
            $domainId = $domain['id'];
            $subId = ($domainType != 'dmn') ? $domainId : '0';
        }
    }

    if (NULL === $domainType) {
        View::showBadRequestErrorPage();
    }

    if (Application::getInstance()->getConfig()['SERVER_HOSTNAME'] == $domainName && $mailTypeNormal) {
        # SERVER_HOSTNAME is a canonical domain (local domain) which cannot be
        # listed in both `mydestination' and `virtual_mailbox_domains' Postfix
        # parameters. See http://www.postfix.org/VIRTUAL_README.html#canonical
        # This necessarily means that Postfix canonical domains cannot have
        # virtual mailboxes, hence their prohibition.
        setPageMessage(tr('You cannot create new mailboxes for that domain. Only forwarded mail accounts are allowed.'), 'warning');
        return false;
    }

    $mailAddr = $username . '@' . $domainName;

    if ($mailTypeNormal) {
        // Check for password
        $password = cleanInput($_POST['password']);
        $passwordRep = cleanInput($_POST['password_rep']);

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

        // Check for quota

        $customerEmailQuotaLimitBytes = filterDigits($mainDmnProps['mail_quota'], 0);
        $mailQuotaLimitBytes = filterDigits($_POST['quota']) * 1048576; // MiB to Bytes

        if ($customerEmailQuotaLimitBytes > 0) {
            if ($mailQuotaLimitBytes < 1) {
                setPageMessage(tr('Incorrect email quota.'), 'error');
                return false;
            }

            $customerMailboxesQuotaSumBytes = execQuery(
                'SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE domain_id = ?', [$mainDmnProps['domain_id']]
            )->fetchColumn();

            if ($customerMailboxesQuotaSumBytes >= $customerEmailQuotaLimitBytes) {
                View::showBadRequestErrorPage(); # Customer should never goes here excepted if it try to bypass js code
            }

            if ($mailQuotaLimitBytes > $customerEmailQuotaLimitBytes - $customerMailboxesQuotaSumBytes) {
                setPageMessage(tr('Email quota cannot be bigger than %s', bytesHuman($mailQuotaLimitBytes)), 'error');
                return false;
            }
        }

        switch ($domainType) {
            case 'dmn':
                $mailType = Mail::MT_NORMAL_MAIL;
                break;
            case 'sub':
                $mailType = Mail::MT_SUBDOM_MAIL;
                break;
            case 'als':
                $mailType = Mail::MT_ALIAS_MAIL;
                break;
            case 'alssub':
                $mailType = Mail::MT_ALSSUB_MAIL;
        }

        $password = Crypt::sha512($password);
    }

    if ($mailTypeForward) {
        // Check forward list
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
            case 'dmn':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_NORMAL_FORWARD;
                break;
            case 'sub':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_SUBDOM_FORWARD;
                break;
            case 'als':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_ALIAS_FORWARD;
                break;
            case 'alssub':
                $mailType .= ($mailType != '' ? ',' : '') . Mail::MT_ALSSUB_FORWARD;
        }
    }

    try {
        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddMail, NULL, [
            'mailType'     => $mailTypeNormal ? ($mailTypeForward ? 'normal+forward' : 'normal') : 'forward',
            'mailUsername' => $username,
            'forwardList'  => $mailTypeForward ? $forwardList : '',
            'MailAddress'  => $mailAddr
        ]);
        execQuery(
            '
                INSERT INTO mail_users (
                    mail_acc, mail_pass, mail_forward, domain_id, mail_type, sub_id, status, po_active, mail_auto_respond, mail_auto_respond_text,
                    quota, mail_addr
                ) VALUES(
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [
                $username, $password, $forwardList, $mainDmnProps['domain_id'], $mailType, $subId, 'toadd',
                $mailTypeNormal ? 'yes' : 'no', '0', NULL, $mailQuotaLimitBytes, $mailAddr
            ]
        );
        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddMail, NULL, [
            'mailId'       => Application::getInstance()->getDb()->getDriver()->getLastGeneratedValue(),
            'mailType'     => $mailTypeNormal ? ($mailTypeForward ? 'normal+forward' : 'normal') : 'forward',
            'mailUsername' => $username,
            'forwardList'  => $mailTypeForward ? $forwardList : '',
            'mailAddress'  => $mailAddr
        ]);
        Daemon::sendRequest();
        writeLog(sprintf('A mail account has been added by %s', Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
        setPageMessage(tr('Mail account successfully scheduled for addition.'), 'success');
    } catch (\Exception $e) {
        if ($e->getCode() == 23000) {
            setPageMessage(tr('Mail account already exists.'), 'error');
            return false;
        }
    }

    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 */
function generatePage($tpl)
{
    $mainDmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
    $customerMailboxesQuotaSumBytes = execQuery('SELECT IFNULL(SUM(quota), 0) FROM mail_users WHERE domain_id = ?', [
        $mainDmnProps['domain_id']
    ])->fetchColumn();
    $customerEmailQuotaLimitBytes = filterDigits($mainDmnProps['mail_quota'], 0);

    if ($customerEmailQuotaLimitBytes < 1) {
        $tpl->assign([
            'TR_QUOTA'  => toHtml(tr('Quota in MiB (0 ∞)')),
            'MIN_QUOTA' => 0,
            'MAX_QUOTA' => toHtml(17592186044416, 'htmlAttr'), // Max quota = MySQL UNSIGNED BIGINT in MiB
            'QUOTA'     => isset($_POST['quota']) ? toHtml(filterDigits($_POST['quota']), 'htmlAttr') : 10
        ]);
        $mailTypeForwardOnly = false;
    } else {
        if ($customerEmailQuotaLimitBytes > $customerMailboxesQuotaSumBytes) {
            $mailQuotaLimitBytes = $customerEmailQuotaLimitBytes - $customerMailboxesQuotaSumBytes;
            $mailMaxQuotaLimitMib = $mailQuotaLimitBytes / 1048576;
            $mailQuotaLimitMiB = $mailMaxQuotaLimitMib;
            $mailTypeForwardOnly = false;
        } else {
            setPageMessage(tr('You cannot add normal mail accounts because you have already assigned all your mail quota. If you want to add a normal mail account, you must first lower the quota assigned to one of your other mail account.'), 'static_info');
            setPageMessage(tr('For the time being, you can only add forwarded mail account.'), 'static_info');
            # Only for sanity; Attempting to create account involving quota
            # will fail because quota is already full assigned (expected)
            $mailQuotaLimitBytes = 1048576; # 1 Mio
            $mailMaxQuotaLimitMib = 1;
            $mailQuotaLimitMiB = 1;
            $mailTypeForwardOnly = true;
        }

        $tpl->assign([
            'TR_QUOTA'  => toHtml(tr('Quota in MiB (Max: %s)', bytesHuman($mailQuotaLimitBytes))),
            'MIN_QUOTA' => 1,
            'MAX_QUOTA' => toHtml($mailMaxQuotaLimitMib, 'htmlAttr'),
            'QUOTA'     => isset($_POST['quota'])
                ? toHtml(filterDigits($_POST['quota']), 'htmlAttr') : toHtml(min(10, $mailQuotaLimitMiB), 'htmlAttr')
        ]);
    }

    $mailType = (isset($_POST['account_type']) && in_array($_POST['account_type'], ['1', '2', '3']))
        ? $_POST['account_type'] : '1';

    $tpl->assign([
        'USERNAME'               => isset($_POST['username']) ? toHtml($_POST['username']) : '',
        'NORMAL_CHECKED'         => ($mailType == '1') ? ' checked' : '',
        'FORWARD_CHECKED'        => ($mailType == '2') ? ' checked' : '',
        'NORMAL_FORWARD_CHECKED' => ($mailType == '3') ? ' checked' : '',
        'FORWARD_LIST'           => isset($_POST['forward_list']) ? toHtml($_POST['forward_list']) : '',
    ]);

    foreach (getDomainsList() as $domain) {
        $tpl->assign([
            'DOMAIN_NAME'          => toHtml($domain['name']),
            'DOMAIN_NAME_UNICODE'  => toHtml(decodeIdna($domain['name'])),
            'DOMAIN_NAME_SELECTED' => (isset($_POST['domain_name']) && $_POST['domain_name'] == $domain['name']) ? ' selected' : '',
        ]);
        $tpl->parse('DOMAIN_NAME_ITEM', '.domain_name_item');
    }

    Application::getInstance()->getEventManager()->attach(
        Events::onGetJsTranslations,
        function (Event $e) use ($mailTypeForwardOnly) {
            $e->getParam('translations')->core['mail_add_forward_only'] = $mailTypeForwardOnly;
        }
    );
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('mail') or View::showBadRequestErrorPage();

$dmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);
$emailAccountsLimit = $dmnProps['domain_mailacc_limit'];

if ($emailAccountsLimit != '0') {
    $nbEmailAccounts = Counting::getCustomerMailAccountsCount($dmnProps['domain_id']);
    if ($nbEmailAccounts >= $emailAccountsLimit) {
        setPageMessage(tr('You have reached the maximum number of mail accounts allowed by your subscription.'), 'warning');
        redirectTo('mail_accounts.php');
    }
}

if (!empty($_POST) && addMailAccount()) {
    redirectTo('mail_accounts.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'           => 'shared/layouts/ui.tpl',
    'page'             => 'client/mail_add.tpl',
    'page_message'     => 'layout',
    'domain_name_item' => 'page',
]);
$tpl->assign([
    'TR_PAGE_TITLE'          => tr('Client / Mail / Add Mail Account'),
    'TR_MAIl_ACCOUNT_DATA'   => tr('Mail account data'),
    'TR_USERNAME'            => tr('Username'),
    'TR_DOMAIN_NAME'         => tr('Domain name'),
    'TR_MAIL_ACCOUNT_TYPE'   => tr('Mail account type'),
    'TR_NORMAL_MAIL'         => tr('Normal'),
    'TR_FORWARD_MAIL'        => tr('Forward'),
    'TR_FORWARD_NORMAL_MAIL' => tr('Normal & Forward'),
    'TR_PASSWORD'            => tr('Password'),
    'TR_PASSWORD_REPEAT'     => tr('Password confirmation'),
    'TR_FORWARD_TO'          => tr('Forward to'),
    'TR_FWD_HELP'            => tr('Separate addresses by a comma, line-break or space.'),
    'TR_ADD'                 => tr('Add'),
    'TR_CANCEL'              => tr('Cancel')
]);
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
