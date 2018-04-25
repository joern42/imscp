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
use iMSCP\Functions\Mail;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

/**
 * Generate catch-all item
 *
 *
 * @param TemplateEngine $tpl
 * @param string $domainName
 * @param int $mailId
 * @param string $mailAcc
 * @param int $domainId
 * @param string $mailStatus
 * @param string $mailType
 */
function generateCatchallItem($tpl, $domainName, $mailId, $mailAcc, $domainId, $mailStatus, $mailType)
{
    if ($mailId > 0) {
        $mailAcc = implode(', ', array_map('decodeIdna', explode(',', $mailAcc)));

        $tpl->assign([
            'CATCHALL_DOMAIN'            => toHtml(decodeIdna($domainName)),
            'CATCHALL_LONG_FOWARD_LIST'  => toHtml(wordwrap($mailAcc, 75)),
            'CATCHALL_SHORT_FOWARD_LIST' => toHtml(strlen($mailAcc) > 50 ? substr($mailAcc, 0, 50) . '...' : $mailAcc, 'htmlAttr'),
            'CATCHALL_STATUS'            => toHtml(humanizeDomainStatus($mailStatus)),
        ]);

        if ($mailStatus != 'ok') {
            $tpl->assign([
                'CATCHALL_ADD_LINK'    => tr('N/A'),
                'CATCHALL_DELETE_LINK' => ''
            ]);
            return;
        }

        $tpl->assign([
            'CATCHALL_ID'       => $mailId,
            'CATCHALL_ADD_LINK' => ''
        ]);
        $tpl->parse('CATCHALL_DELETE_LINK', 'catchall_delete_link');
        return;
    }

    $tpl->assign([
        'CATCHALL_DOMAIN'            => toHtml(decodeIdna($domainName)),
        'CATCHALL_LONG_FOWARD_LIST'  => toHtml($mailAcc),
        'CATCHALL_SHORT_FOWARD_LIST' => toHtml($mailAcc, 'htmlAttr'),
        'CATCHALL_STATUS'            => toHtml($mailStatus),
        'CATCHALL_ID'                => "$domainId;$mailType",
        'CATCHALL_DELETE_LINK'       => ''
    ]);
    $tpl->parse('CATCHALL_ADD_LINK', 'catchall_add_link');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @çeturn void
 */
function generatePage($tpl)
{
    $dmnProps = getCustomerProperties(Application::getInstance()->getSession()['user_id']);

    // Normal catch-all account

    $stmt = execQuery('SELECT mail_id, mail_acc, status FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type = ?', [
        $dmnProps['domain_id'], 0, Mail::MT_NORMAL_CATCHALL
    ]);

    if (!$stmt->rowCount()) {
        generateCatchallItem($tpl, $dmnProps['domain_name'], 0, tr('N/A'), $dmnProps['domain_id'], tr('N/A'), Mail::MT_NORMAL_CATCHALL);
    } else {
        $row = $stmt->fetch();
        generateCatchallItem(
            $tpl, $dmnProps['domain_name'], $row['mail_id'], $row['mail_acc'], $dmnProps['domain_id'], $row['status'], Mail::MT_NORMAL_CATCHALL
        );
    }

    $tpl->parse('CATCHALL_ITEM', 'catchall_item');

    // Subdomain aliases catch-all accounts

    $stmt = execQuery(
        "
            SELECT t1.subdomain_id, CONCAT(t1.subdomain_name, '.', t2.domain_name) AS subdomain_name
            FROM subdomain AS t1
            JOIN domain AS t2 USING(domain_id)
            WHERE t1.domain_id = ?
            AND t1.subdomain_status = 'ok'
        ",
        [$dmnProps['domain_id']]
    );

    while ($data = $stmt->fetch()) {
        $stmt2 = execQuery('SELECT mail_id, mail_acc, status FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type = ?', [
            $dmnProps['domain_id'], $data['subdomain_id'], Mail::MT_SUBDOM_CATCHALL
        ]);

        if (!$stmt2->rowCount()) {
            generateCatchallItem($tpl, $data['subdomain_name'], 0, tr('N/A'), $data['subdomain_id'], tr('N/A'), Mail::MT_SUBDOM_CATCHALL);
        } else {
            $row = $stmt2->fetch();
            generateCatchallItem(
                $tpl, $data['subdomain_name'], $row['mail_id'], $row['mail_acc'], $data['subdomain_id'], $row['status'], Mail::MT_SUBDOM_CATCHALL
            );
        }

        $tpl->parse('CATCHALL_ITEM', '.catchall_item');
    }

    // Domain alias catch-all accounts

    $stmt = execQuery("SELECT alias_id, alias_name FROM domain_aliases WHERE domain_id = ? AND alias_status = 'ok'", [$dmnProps['domain_id']]);

    while ($data = $stmt->fetch()) {
        $stmt2 = execQuery('SELECT mail_id, mail_acc, status FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type = ?', [
            $dmnProps['domain_id'], $data['alias_id'], Mail::MT_ALIAS_CATCHALL
        ]);

        if (!$stmt2->rowCount()) {
            generateCatchallItem($tpl, $data['alias_name'], 0, tr('N/A'), $data['alias_id'], tr('N/A'), Mail::MT_ALIAS_CATCHALL);
        } else {
            $row = $stmt2->fetch();
            generateCatchallItem(
                $tpl, $data['alias_name'], $row['mail_id'], $row['mail_acc'], $data['alias_id'], $row['status'], Mail::MT_ALIAS_CATCHALL
            );
        }

        $tpl->parse('CATCHALL_ITEM', '.catchall_item');
    }

    $stmt = execQuery(
        "
            SELECT t1.subdomain_alias_id, CONCAT(t1.subdomain_alias_name, '.', t2.alias_name) AS subdomain_name
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            JOIN domain as t3 USING(domain_id)
            WHERE t2.domain_id = ?
            AND t1.subdomain_alias_status = 'ok'
        ",
        [$dmnProps['domain_id']]
    );

    // Subdomain alias catch-all accounts

    while ($data = $stmt->fetch()) {
        $stmt2 = execQuery('SELECT mail_id, mail_acc, status FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type = ?', [
            $dmnProps['domain_id'], $data['subdomain_alias_id'], Mail::MT_ALSSUB_CATCHALL
        ]);

        if (!$stmt2->rowCount()) {
            generateCatchallItem($tpl, $data['subdomain_name'], 0, tr('N/A'), $data['subdomain_alias_id'], tr('N/A'), Mail::MT_ALSSUB_CATCHALL);
        } else {
            $row = $stmt2->fetch();
            generateCatchallItem(
                $tpl, $data['subdomain_name'], $row['mail_id'], $row['mail_acc'], $data['subdomain_alias_id'], $row['status'], Mail::MT_ALSSUB_CATCHALL
            );
        }

        $tpl->parse('CATCHALL_ITEM', '.catchall_item');
    }
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('mail') or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'               => 'shared/layouts/ui.tpl',
    'page'                 => 'client/mail_catchall.phtml',
    'page_message'         => 'layout',
    'catchall_item'        => 'page',
    'catchall_add_link'    => 'catchall_item',
    'catchall_delete_link' => 'catchall_item'

]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Client / Mail / Catch-all Accounts')));
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
