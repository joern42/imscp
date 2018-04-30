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
 * Get catch-all domain
 *
 * @param int $catchallDomainId Domain unique identifier
 * @param int $catchalType Catch-all type
 * @return string Catch-all domain name if owner is verified, FALSE otherwise
 */
function getCatchallDomain($catchallDomainId, $catchalType)
{
    switch ($catchalType) {
        case Mail::MT_NORMAL_CATCHALL:
            $stmt = execQuery('SELECT domain_name FROM domain WHERE domain_id = ? AND domain_admin_id = ?', [
                $catchallDomainId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()
            ]);
            break;
        case Mail::MT_SUBDOM_CATCHALL:
            $stmt = execQuery(
                "
                    SELECT CONCAT(subdomain_name, '.', domain_name) FROM subdomain
                    JOIN domain USING(domain_id)
                    WHERE subdomain_id = ?
                    AND domain_admin_id = ?
                ",
                [$catchallDomainId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
            );
            break;
        case Mail::MT_ALIAS_CATCHALL:
            $stmt = execQuery(
                "
                    SELECT alias_name FROM domain_aliases
                    JOIN domain USING(domain_id)
                    WHERE alias_id = ?
                    AND domain_admin_id = ?
                ",
                [$catchallDomainId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
            );
            break;
        case Mail::MT_ALSSUB_CATCHALL:
            $stmt = execQuery(
                "
                    SELECT CONCAT(subdomain_alias_name, '.', alias_name) FROM subdomain_alias
                    JOIN domain_aliases USING(alias_id)
                    JOIN domain USING(domain_id)
                    WHERE subdomain_alias_id = ?
                    AND domain_admin_id = ?
                ",
                [$catchallDomainId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
            );
            break;
        default:
            return false;
    }

    return $stmt->fetchColumn();
}

/**
 * Add catch-all account
 *
 * @param int $catchallDomainId Catch-all domain unique identifier
 * @param string $catchallDomain Catch all domain name
 * @param string $catchallType Catch-all type
 * @return void
 */
function addCatchallAccount($catchallDomainId, $catchallDomain, $catchallType)
{
    if (!isset($_POST['catchall_addresses_type']) || !in_array($_POST['catchall_addresses_type'], ['auto', 'manual'])
        || ($_POST['catchall_addresses_type'] == 'manual' && !isset($_POST['manual_catchall_addresses']))
    ) {
        View::showBadRequestErrorPage();
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $userId = $identity->getUserId();

    if ($_POST['catchall_addresses_type'] == 'auto') {
        if (!isset($_POST['automatic_catchall_addresses']) || !is_array($_POST['automatic_catchall_addresses'])) {
            View::showBadRequestErrorPage();
        }

        if (empty($_POST['automatic_catchall_addresses'])) {
            View::setPageMessage(tr('You must select at least one catch-all address.'), 'error');
            View::showBadRequestErrorPage();
        }

        $catchallAddresses = [];

        foreach ($_POST['automatic_catchall_addresses'] as $catchallAddressId) {
            $stmt = execQuery('SELECT mail_addr FROM mail_users WHERE mail_id = ? AND domain_id = ?', [intval($catchallAddressId), $userId]);
            $stmt->rowCount() or View::showBadRequestErrorPage();
            $catchallAddresses[] = $stmt->fetchColumn();
        }
    } else {
        $catchallAddresses = cleanInput($_POST['manual_catchall_addresses']);
        if ($catchallAddresses === '') {
            View::setPageMessage(tr('Catch-all addresses field cannot be empty.'), 'error');
            return;
        }

        $catchallAddresses = array_unique(preg_split('/\s|,/', $catchallAddresses, -1, PREG_SPLIT_NO_EMPTY));
        foreach ($catchallAddresses as $key => &$catchallAddress) {
            $catchallAddress = encodeIdna(mb_strtolower(trim($catchallAddress)));
            if (!ValidateEmail($catchallAddress)) {
                View::setPageMessage(tr('Bad email address in catch-all addresses field.'), 'error');
                return;
            }
        }

        if (empty($catchallAddresses)) {
            View::setPageMessage(tr('Catch-all addresses field cannot be empty.'), 'error');
            return;
        }
    }

    $domainId = getCustomerMainDomainId($userId);

    switch ($catchallType) {
        case Mail::MT_NORMAL_CATCHALL:
            $subId = '0';
            break;
        case Mail::MT_ALIAS_CATCHALL:
        case Mail::MT_SUBDOM_CATCHALL:
        case Mail::MT_ALSSUB_CATCHALL:
            $subId = $catchallDomainId;
            break;
        default:
            View::showBadRequestErrorPage();
            exit;
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddMailCatchall, NULL, [
        'mailCatchallDomain'    => $catchallDomain,
        'mailCatchallAddresses' => $catchallAddresses
    ]);
    execQuery(
        "
            INSERT INTO mail_users (
                mail_acc, mail_forward, domain_id, mail_type, sub_id, status, po_active, mail_addr
            ) VALUES (
                ?, '_no_', ?, ?, ?, 'toadd', 'no', ?
            )
        ",
        [implode(',', $catchallAddresses), $domainId, $catchallType, $subId, '@' . $catchallDomain]
    );
    Application::getInstance()->getEventManager()->trigger(Events::onAfterAddMailCatchall, NULL, [
        'mailCatchallId'        => Application::getInstance()->getDb()->getDriver()->getLastGeneratedValue(),
        'mailCatchallDomain'    => $catchallDomain,
        'mailCatchallAddresses' => $catchallAddresses
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('A catch-all account has been created by %s', getProcessorUsername($identity)), E_USER_NOTICE);
    View::setPageMessage(tr('Catch-all successfully scheduled for addition.'), 'success');
    redirectTo('mail_catchall.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param int $catchallDomainId Catch-all domain unique identifier
 * @param string $catchallType Catch-all type
 * @return void
 */
function generatePage($tpl, $catchallDomainId, $catchallType)
{
    switch ($catchallType) {
        case Mail::MT_NORMAL_CATCHALL:
            $stmt = execQuery("SELECT mail_id, mail_addr FROM mail_users WHERE domain_id = ? AND mail_type RLIKE ? AND status = 'ok'", [
                $catchallDomainId, Mail::MT_NORMAL_MAIL . '|' . Mail::MT_NORMAL_FORWARD
            ]);

            if (!$stmt->rowCount()) {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_BLK'  => '',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED' => ' checked',
                    'MANUAL_CATCHALL_ADDRESSES'         => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);
            } else {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_CHECKED' => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? '' : ' checked',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED'    => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? ' checked' : '',
                    'MANUAL_CATCHALL_ADDRESSES'            => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);

                while ($row = $stmt->fetch()) {
                    $tpl->assign([
                        'AUTOMATIC_CATCHALL_ADDRESS_ID' => $row['mail_id'],
                        'AUTOMATIC_CATCHALL_ADDRESS'    => toHtml(decodeIdna($row['mail_addr']))
                    ]);
                    $tpl->parse('AUTOMATIC_CATCHALL_ADDRESS_OPTION', '.automatic_catchall_address_option');
                }
            }
            break;
        case Mail::MT_SUBDOM_CATCHALL:
            $stmt = execQuery("SELECT mail_id, mail_addr FROM mail_users WHERE domain_id AND sub_id = ? AND mail_type RLIKE ? AND status = 'ok'", [
                getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId()),
                $catchallDomainId,
                Mail::MT_SUBDOM_MAIL . '|' . Mail::MT_SUBDOM_FORWARD
            ]);

            if (!$stmt->rowCount()) {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_BLK'  => '',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED' => ' checked',
                    'MANUAL_CATCHALL_ADDRESSES'         => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);
            } else {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_CHECKED' => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? '' : ' checked',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED'    => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? ' checked' : '',
                    'MANUAL_CATCHALL_ADDRESSES'            => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);

                while ($row = $stmt->fetch()) {
                    $tpl->assign([
                        'AUTOMATIC_CATCHALL_ADDRESS_ID' => $row['mail_id'],
                        'AUTOMATIC_CATCHALL_ADDRESS'    => toHtml(decodeIdna($row['mail_addr']))
                    ]);
                    $tpl->parse('AUTOMATIC_CATCHALL_ADDRESS_OPTION', '.automatic_catchall_address_option');
                }
            }
            break;
        case Mail::MT_ALIAS_CATCHALL:
            $stmt = execQuery(
                "SELECT mail_id, mail_addr FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type RLIKE ? AND status = 'ok'",
                [
                    getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId()),
                    $catchallDomainId,
                    Mail::MT_ALIAS_MAIL . '|' . Mail::MT_ALIAS_FORWARD
                ]
            );

            if (!$stmt->rowCount()) {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_BLK'  => '',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED' => ' checked',
                    'MANUAL_CATCHALL_ADDRESSES'         => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);
            } else {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_CHECKED' => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? '' : ' checked',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED'    => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? ' checked' : '',
                    'MANUAL_CATCHALL_ADDRESSES'            => isset($_POST['manual_catchall_addresses'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);

                while ($row = $stmt->fetch()) {
                    $tpl->assign([
                        'AUTOMATIC_CATCHALL_ADDRESS_ID' => $row['mail_id'],
                        'AUTOMATIC_CATCHALL_ADDRESS'    => toHtml(decodeIdna($row['mail_addr']))
                    ]);
                    $tpl->parse('AUTOMATIC_CATCHALL_ADDRESS_OPTION', '.automatic_catchall_address_option');
                }
            }
            break;
        case Mail::MT_ALSSUB_CATCHALL:
            $stmt = execQuery(
                "SELECT mail_id, mail_addr FROM mail_users WHERE domain_id = ? AND sub_id = ? AND mail_type RLIKE ? AND status = 'ok'",
                [
                    getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId()),
                    $catchallDomainId,
                    Mail::MT_ALSSUB_MAIL . '|' . Mail::MT_ALSSUB_FORWARD
                ]
            );

            if (!$stmt->rowCount()) {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_BLK'  => '',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED' => ' checked',
                    'MANUAL_CATCHALL_ADDRESSES'         => isset($_POST['forward_list']) ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);
            } else {
                $tpl->assign([
                    'AUTOMATIC_CATCHALL_ADDRESSES_CHECKED' => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? '' : ' checked',
                    'MANUAL_CATCHALL_ADDRESSES_CHECKED'    => isset($_POST['catchall_addresses_type'])
                    && $_POST['catchall_addresses_type'] == 'manual' ? ' checked' : '',
                    'MANUAL_CATCHALL_ADDRESSES'            => isset($_POST['forward_list'])
                        ? toHtml($_POST['manual_catchall_addresses']) : ''
                ]);

                while ($row = $stmt->fetch()) {
                    $tpl->assign([
                        'AUTOMATIC_CATCHALL_ADDRESS_ID' => $row['mail_id'],
                        'AUTOMATIC_CATCHALL_ADDRESS'    => toHtml(decodeIdna($row['mail_addr']))
                    ]);
                    $tpl->parse('AUTOMATIC_CATCHALL_ADDRESS_OPTION', '.automatic_catchall_address_option');
                }
            }
            break;
        default:
            View::showBadRequestErrorPage();
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('mail') && isset($_GET['id']) or View::showBadRequestErrorPage();

$catchallId = cleanInput($_GET['id']);

if (!preg_match(
        '/^(?P<catchallDomainId>\d+);(?P<catchallType>(?:'
        . Mail::MT_NORMAL_CATCHALL . '|' . Mail::MT_SUBDOM_CATCHALL . '|' . Mail::MT_ALIAS_CATCHALL . '|' . Mail::MT_ALSSUB_CATCHALL
        . '))$/',
        $catchallId,
        $matches
    )
    || ($catchallDomain = getCatchallDomain($matches['catchallDomainId'], $matches['catchallType'])) === false
) {
    View::showBadRequestErrorPage();
    exit;
}

if (Application::getInstance()->getRequest()->isPost()) {
    addCatchallAccount($matches['catchallDomainId'], $catchallDomain, $matches['catchallType']);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                            => 'shared/layouts/ui.tpl',
    'page'                              => 'client/mail_catchall_add.phtml',
    'page_message'                      => 'layout',
    'automatic_catchall_addresses_blk'  => 'page',
    'automatic_catchall_address_option' => 'automatic_catchall_addresses_blk'
]);
$tpl->assign([
    'TR_PAGE_TITLE'   => toHtml(tr('Client / Mail / Catch-all Accounts / Add Catch-all account')),
    'CATCHALL_DOMAIN' => toHtml(decodeIdna($catchallDomain)),
    'CATCHALL_ID'     => toHtml($catchallId, 'htmlAttr')
]);
View::generateNavigation($tpl);
generatePage($tpl, $matches['catchallDomainId'], $matches['catchallType']);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
