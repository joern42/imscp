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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Config;

/**
 * Schedule deletion of the given mail account
 *
 * @param int $mailId Mail account unique identifier
 * @param int $domainId Customer primary domain unique identifier
 * @param Config\Config $config
 * @param array &$postfixConfig
 * @param int &$nbDeletedMails Counter for deleted mail accounts
 * @return void
 */
function deleteMailAccount($mailId, $domainId, $config, &$postfixConfig, &$nbDeletedMails)
{
    $stmt = execQuery('SELECT mail_acc, mail_addr, mail_type FROM mail_users WHERE mail_id = ? AND domain_id = ?', [$mailId, $domainId]);

    if (!$stmt->rowCount()) {
        return;
    }

    $row = $stmt->fetch();

    if ($config['PROTECT_DEFAULT_EMAIL_ADDRESSES']
        && (
            (in_array($row['mail_type'], [Mail::MT_NORMAL_FORWARD, Mail::MT_ALIAS_FORWARD])
                && in_array($row['mail_acc'], ['abuse', 'hostmaster', 'postmaster', 'webmaster'])
            )
            || ($row['mail_acc'] == 'webmaster' && in_array($row['mail_type'], [Mail::MT_SUBDOM_FORWARD, Mail::MT_ALSSUB_FORWARD]))
        )
    ) {
        return;
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeDeleteMail, NULL, ['mailId' => $mailId]);
    execQuery("UPDATE mail_users SET status = 'todelete' WHERE mail_id = ?", [$mailId]);

    if (strpos($row['mail_type'], '_mail') !== false) {
        # Remove cached quota info if any
        list($user, $domain) = explode('@', $row['mail_addr']);
        unset(Application::getInstance()->getSession()['maildirsize'][normalizePath($postfixConfig['MTA_VIRTUAL_MAIL_DIR'] . "/$domain/$user/maildirsize")]);
    }

    # Update or delete forward and/or catch-all accounts that list mail_addr of
    # the account that is being deleted.
    #
    # Forward accounts:
    #  A forward account that is only forwarded to the mail_addr of the account
    #  that is being deleted will be also deleted, else the mail_addr will be
    #  simply removed from its forward list
    #
    # Catch-all accounts:
    #   A catch-all account that catch only on mail_addr of the account that is
    #   being deleted will be also deleted, else the mail_addr will be simply
    #   deleted from the catch-all addresses list.
    $stmt = execQuery('SELECT mail_id, mail_acc, mail_forward FROM mail_users WHERE mail_id <> ? AND (mail_acc RLIKE ? OR mail_forward RLIKE ?)', [
        $mailId, '(,|^)' . $row['mail_addr'] . '(,|$)', '(,|^)' . $row['mail_addr'] . '(,|$)'
    ]);

    if ($stmt->rowCount()) {
        while ($row = $stmt->fetch()) {
            if ($row['mail_forward'] == '_no_') {
                # catch-all account
                $row['mail_acc'] = implode(
                    ',', preg_grep('/^' . quotemeta($row['mail_addr']) . '$/', explode(',', $row['mail_acc']), PREG_GREP_INVERT)
                );
            } else {
                # Forward account
                $row['mail_forward'] = implode(
                    ',', preg_grep('/^' . quotemeta($row['mail_addr']) . '$/', explode(',', $row['mail_forward']), PREG_GREP_INVERT)
                );
            }

            if ($row['mail_acc'] === '' || $row['mail_forward'] === '') {
                execQuery("UPDATE mail_users SET status = 'todelete' WHERE mail_id = ?", [$row['mail_id']]);
            } else {
                execQuery("UPDATE mail_users SET status = 'tochange', mail_acc = ?, mail_forward = ? WHERE mail_id = ?", [
                    $row['mail_acc'], $row['mail_forward'], $row['mail_id']
                ]);
            }
        }
    }

    Mail::deleteAutorepliesLogs();
    Application::getInstance()->getEventManager()->trigger(Events::onAfterDeleteMail, NULL, ['mailId' => $mailId]);
    $nbDeletedMails++;
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::USER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('mail') && isset($_REQUEST['id']) or View::showBadRequestErrorPage();

$identity = Application::getInstance()->getAuthService()->getIdentity();
$domainId = getCustomerMainDomainId($identity->getUserId());
$nbDeletedMails = 0;
$mailIds = (array)$_REQUEST['id'];

if (empty($mailIds)) {
    View::setPageMessage(tr('You must select at least one mail account to delete.'), 'error');
    redirectTo('mail_accounts.php');
}

$db = Application::getInstance()->getDb();

try {
    $db->getDriver()->getConnection()->beginTransaction();
    $config = Application::getInstance()->getConfig();
    $postfixConfig = loadServiceConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/postfix/postfix.data');

    foreach ($mailIds as $mailId) {
        deleteMailAccount(intval($mailId), $domainId, $config, $postfixConfig, $nbDeletedMails);
    }

    $db->getDriver()->getConnection()->commit();
    Daemon::sendRequest();

    if ($nbDeletedMails) {
        writeLog(sprintf('%d mail account(s) were deleted by %s', $nbDeletedMails, getProcessorUsername($identity)), E_USER_NOTICE);
        View::setPageMessage(ntr('Mail account has been scheduled for deletion.', '%d mail accounts were scheduled for deletion.', $nbDeletedMails, $nbDeletedMails), 'success');
    } else {
        View::setPageMessage(tr('No mail account has been deleted.'), 'warning');
    }
} catch (\Exception $e) {
    $db->getDriver()->getConnection()->rollBack();
    $errorMessage = $e->getMessage();
    $code = $e->getCode();
    writeLog(sprintf('An unexpected error occurred while attempting to delete a mail account: %s', $errorMessage), E_USER_ERROR);

    if ($code == 403) {
        View::setPageMessage(tr('Operation cancelled: %s', $errorMessage), 'warning');
    } elseif ($e->getCode() == 400) {
        View::showBadRequestErrorPage();
    } else {
        View::setPageMessage(tr('An unexpected error occurred. Please contact your reseller.'), 'error');
    }
}

redirectTo('mail_accounts.php');
