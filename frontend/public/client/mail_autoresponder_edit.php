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

/**
 * Checks the given mail account
 *
 * - Mail account must exists
 * - Mail account must be owned by customer
 * - Mail account must be of type normal, forward or normal & forward
 * - Mail account must be in consistent state
 *
 * @param int $mailAccountId Mail account unique identifier
 * @return bool TRUE if all conditions are met, FALSE otherwise
 */
function checkMailAccount($mailAccountId)
{
    return execQuery(
        "
            SELECT COUNT(t1.mail_id) FROM mail_users AS t1
            JOIN domain AS t2 USING(domain_id)
            WHERE t1.mail_id = ? AND t2.domain_admin_id = ? AND t1.mail_type NOT RLIKE ? AND t1.status = 'ok'
        ",
        [$mailAccountId, Application::getInstance()->getSession()['user_id'], Mail::MT_NORMAL_CATCHALL . '|' . Mail::MT_SUBDOM_CATCHALL . '|' . Mail::MT_ALIAS_CATCHALL . '|' . Mail::MT_ALSSUB_CATCHALL]
    )->fetchColumn() > 0;
}

/**
 * Update autoresponder of the given mail account
 *
 * @param int $mailAccountId Mail account id
 * @param string $autoresponderMessage Auto-responder message
 * @return void
 */
function updateAutoresponderMessage($mailAccountId, $autoresponderMessage)
{
    if ($autoresponderMessage === '') {
        setPageMessage(tr('Autoresponder message cannot be empty.'), 'error');
        redirectTo("mail_autoresponder_enable.php?mail_account_id=$mailAccountId");
    }

    execQuery("UPDATE mail_users SET status = IF(mail_auto_respond, 'tochange', status), mail_auto_respond_text = ?WHERE mail_id = ?", [
        $autoresponderMessage, $mailAccountId
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('A mail autoresponder has been edited by %s', Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE);
    setPageMessage(tr('Autoresponder has been edited.'), 'success');
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
    $stmt = execQuery('SELECT mail_auto_respond_text, mail_acc FROM mail_users WHERE mail_id = ?', [$mailAccountId]);
    $row = $stmt->fetch();
    $tpl->assign('AUTORESPONDER_MESSAGE', toHtml($row['mail_auto_respond_text']));
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('mail') && isset($_REQUEST['id']) or View::showBadRequestErrorPage();
$mailAccountId = intval($_REQUEST['id']);
checkMailAccount($mailAccountId) or View::showBadRequestErrorPage();

if (!isset($_POST['id'])) {
    $tpl = new TemplateEngine();
    $tpl->define([
        'layout'       => 'shared/layouts/ui.tpl',
        'page'         => 'client/mail_autoresponder.tpl',
        'page_message' => 'layout'
    ]);
    $tpl->assign([
        'TR_PAGE_TITLE'            => toHtml(tr('Client / Mail / Overview / Edit Autoresponder')),
        'TR_AUTORESPONDER_MESSAGE' => toHtml(tr('Please edit your autoresponder message below')),
        'TR_ACTION'                => toHtml(tr('Update')),
        'TR_CANCEL'                => toHtml(tr('Cancel')),
        'MAIL_ACCOUNT_ID'          => toHtml($mailAccountId)
    ]);
    View::generateNavigation($tpl);
    generatePage($tpl, $mailAccountId);
    generatePageMessage($tpl);
    $tpl->parse('LAYOUT_CONTENT', 'page');
    Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
    $tpl->prnt();
    unsetMessages();
} elseif (isset($_POST['autoresponder_message'])) {
    updateAutoresponderMessage($mailAccountId, cleanInput($_POST['autoresponder_message']));
    redirectTo('mail_accounts.php');
} else {
    View::showBadRequestErrorPage();
}
