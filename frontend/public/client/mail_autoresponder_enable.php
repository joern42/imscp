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

/**
 * Checks the given mail account
 *
 * - Mail account must exists
 * - Mail account must be owned by customer
 * - Mail account must be of type normal, forward or normal & forward
 * - Mail account must must be in consistent state
 * - Mail account autoresponder must not be active
 *
 * @param int $mailAccountId Mail account unique identifier
 * @return string|false string if all conditions are met, FALSE otherwise
 */
function checkMailAccount($mailAccountId)
{
    return execQuery(
        "
            SELECT IFNULL(mail_auto_respond_text, '')
            FROM mail_users AS t1
            JOIN domain AS t2 USING(domain_id)
            WHERE t1.mail_id = ? AND t2.domain_admin_id = ? AND t1.mail_type NOT RLIKE ? AND t1.status = 'ok'
            AND t1.mail_auto_respond = 0
        ",
        [
            $mailAccountId,
            Application::getInstance()->getAuthService()->getIdentity()->getUserId(),
            Mail::MT_NORMAL_CATCHALL . '|' . Mail::MT_SUBDOM_CATCHALL . '|' . Mail::MT_ALIAS_CATCHALL . '|' . Mail::MT_ALSSUB_CATCHALL
        ]
    )->fetchColumn();
}

/**
 * Activate autoresponder of the given mail account with the given autoreponder message
 *
 * @param int $mailAccountId Mail account id
 * @param string $autoresponderMessage Auto-responder message
 * @return void
 */
function activateAutoresponder($mailAccountId, $autoresponderMessage)
{
    if ($autoresponderMessage === '') {
        View::setPageMessage(tr('Autoresponder message cannot be empty.'), 'error');
        redirectTo("mail_autoresponder_enable.php?mail_account_id=$mailAccountId");
    }

    execQuery("UPDATE mail_users SET status = 'tochange', mail_auto_respond = 1, mail_auto_respond_text = ? WHERE mail_id = ?", [
        $autoresponderMessage, $mailAccountId
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('A mail autoresponder has been activated by %s', getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity())), E_USER_NOTICE);
    View::setPageMessage(tr('Autoresponder has been activated.'), 'success');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param int $mailAccountId Mail account id
 * @return void
 */
function generatePage($tpl, $mailAccountId)
{
    $stmt = execQuery('SELECT mail_auto_respond_text FROM mail_users WHERE mail_id = ?', [$mailAccountId]);
    $row = $stmt->fetch();
    $tpl->assign('AUTORESPONDER_MESSAGE', toHtml($row['mail_auto_respond_text']));
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('mail') && isset($_REQUEST['id']) or View::showBadRequestErrorPage();

$mailAccountId = intval($_REQUEST['id']);

if (($autoresponderMsg = checkMailAccount($mailAccountId)) === FALSE) {
    View::showBadRequestErrorPage();
}

if ($autoresponderMsg !== '') {
    activateAutoresponder($mailAccountId, $autoresponderMsg);
    redirectTo('mail_accounts.php');
}

if (!isset($_POST['id'])) {
    $tpl = new TemplateEngine();
    $tpl->define([
        'layout'       => 'shared/layouts/ui.tpl',
        'page'         => 'client/mail_autoresponder.tpl',
        'page_message' => 'layout'
    ]);
    $tpl->assign([
        'TR_PAGE_TITLE'            => toHtml(tr('Client / Mail / Overview / Activate Autoresponder')),
        'TR_AUTORESPONDER_MESSAGE' => toHtml(tr('Please enter your autoresponder message below')),
        'TR_ACTION'                => toHtml(tr('Activate')),
        'TR_CANCEL'                => toHtml(tr('Cancel')),
        'MAIL_ACCOUNT_ID'          => toHtml($mailAccountId)
    ]);
    View::generateNavigation($tpl);
    generatePage($tpl, $mailAccountId);
    View::generatePageMessages($tpl);
    $tpl->parse('LAYOUT_CONTENT', 'page');
    Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
    $tpl->prnt();
    unsetMessages();
} elseif (isset($_POST['autoresponder_message'])) {
    activateAutoresponder($mailAccountId, cleanInput($_POST['autoresponder_message']));
    redirectTo('mail_accounts.php');
} else {
    View::showBadRequestErrorPage();
}
