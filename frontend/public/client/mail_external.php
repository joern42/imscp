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
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Exception_Database as DatabaseException;
use iMSCP_Registry as Registry;

/**
 * Activate or deactivate external mail feature for the given domain
 *
 * @throws DatabaseException
 * @param string $action Action to be done (activate|deactivate)
 * @param int $domainId Domain unique identifier
 * @param string $domainType Domain type
 * @return void
 */
function updateExternalMailFeature($action, $domainId, $domainType)
{
    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();
    try {
        $db->beginTransaction();

        if ($domainType == 'dmn') {
            $stmt = execQuery(
                "UPDATE domain SET domain_status = 'tochange', external_mail = ?WHERE domain_id = ? AND domain_admin_id = ? AND domain_status = 'ok'",
                [$action == 'activate' ? 'on' : 'off', $domainId, $_SESSION['user_id']]
            );
            $stmt->rowCount() or showBadRequestErrorPage(); # Cover case where domain_admin_id <> $_SESSION['user_id']
            execQuery("UPDATE subdomain SET subdomain_status = 'tochange' WHERE domain_id = ?", [$domainId]);
        } elseif ($domainType == 'als') {
            $stmt = execQuery(
                "
                    UPDATE domain_aliases AS t1
                    JOIN domain AS t2 USING(domain_id)
                    SET t1.alias_status = 'tochange', t1.external_mail = ?
                    WHERE t1.alias_id = ?
                    AND t1.alias_status = 'ok'
                    AND t2.domain_admin_id = ?
                ",
                [$action == 'activate' ? 'on' : 'off', $domainId, $_SESSION['user_id']]
            );
            $stmt->rowCount() or showBadRequestErrorPage(); # Cover case where t2.domain_admin_id <> $_SESSION['user_id']
            execQuery(
                "
                    UPDATE subdomain_alias AS t1
                    JOIN domain_aliases AS t2 ON(t2.domain_id = ?)
                    SET subdomain_alias_status = 'tochange'
                    WHERE t1.alias_id = t2.alias_id
                ",
                $domainId
            );
        } else {
            showBadRequestErrorPage();
        }

        $db->commit();

        if ($action == 'activate') {
            writeLog(sprintf('External mail feature has been activared by %s', $_SESSION['user_logged']));
            setPageMessage(tr('External mail server feature scheduled for activation.'), 'success');
            return;
        }

        writeLog(sprintf('External mail feature has been deactivated by %s', $_SESSION['user_logged']));
        setPageMessage(tr('External mail server feature scheduled for deactivation.'), 'success');
    } catch (DatabaseException $e) {
        $db->rollBack();
        throw $e;
    }
}

/**
 * Generate an external mail server item
 *
 * @access private
 * @param TemplateEngine $tpl Template instance
 * @param string $externalMail Status of external mail for the domain
 * @param int $domainId Domain id
 * @param string $domainName Domain name
 * @param string $status Item status
 * @param string $type Domain type (normal for domain or alias for domain alias)
 * @return void
 */
function generateItem($tpl, $externalMail, $domainId, $domainName, $status, $type)
{
    if ($status == 'ok') {
        if ($externalMail == 'off') {
            $tpl->assign([
                'DOMAIN'          => decodeIdna($domainName),
                'STATUS'          => ($status == 'ok') ? tr('Deactivated') : humanizeDomainStatus($status),
                'DOMAIN_TYPE'     => $type,
                'DOMAIN_ID'       => $domainId,
                'TR_ACTIVATE'     => ($status == 'ok') ? tr('Activate') : tr('N/A'),
                'DEACTIVATE_LINK' => ''
            ]);
            $tpl->parse('ACTIVATE_LINK', 'activate_link');
            return;
        }

        $tpl->assign([
            'DOMAIN'        => decodeIdna($domainName),
            'STATUS'        => ($status == 'ok') ? tr('Activated') : humanizeDomainStatus($status),
            'DOMAIN_TYPE'   => $type,
            'DOMAIN_ID'     => $domainId,
            'ACTIVATE_LINK' => '',
            'TR_DEACTIVATE' => ($status == 'ok') ? tr('Deactivate') : tr('N/A'),
        ]);
        $tpl->parse('DEACTIVATE_LINK', 'deactivate_link');
        return;
    }

    $tpl->assign([
        'DOMAIN'          => decodeIdna($domainName),
        'STATUS'          => humanizeDomainStatus($status),
        'ACTIVATE_LINK'   => '',
        'DEACTIVATE_LINK' => ''
    ]);
}

/**
 * Generate external mail server item list
 *
 * @access private
 * @param TemplateEngine $tpl Template engine
 * @param int $domainId Domain id
 * @param string $domainName Domain name
 * @return void
 */
function generateItemList($tpl, $domainId, $domainName)
{
    $stmt = execQuery('SELECT domain_status, external_mail FROM domain WHERE domain_id = ?', [$domainId]);
    $data = $stmt->fetch();

    generateItem($tpl, $data['external_mail'], $domainId, $domainName, $data['domain_status'], 'dmn');

    $tpl->parse('ITEM', '.item');
    $stmt = execQuery(
        'SELECT alias_id, alias_name, alias_status, external_mail FROM domain_aliases WHERE domain_id = ?', [$domainId]
    );

    if (!$stmt->rowCount()) {
        return;
    }

    while ($data = $stmt->fetch()) {
        generateItem($tpl, $data['external_mail'], $data['alias_id'], $data['alias_name'], $data['alias_status'], 'als');
        $tpl->parse('ITEM', '.item');
    }
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
        $translations = $e->getParam('translations');
        $translations['core']['datatable'] = getDataTablesPluginTranslations(false);
    });

    $tpl->assign([
        'TR_PAGE_TITLE' => tr('Client / Mail / External Mail Feature'),
        'TR_INTRO'      => tr('Below you can activate the external mail feature for your domains (including their subdomains). In such case, you must not forgot to add the DNS MX and SPF records for your external mail server through the custom DNS interface, or through your own DNS management interface if you make use of an external DNS server.'),
        'TR_DOMAIN'     => tr('Domain'),
        'TR_STATUS'     => tr('Status'),
        'TR_ACTION'     => tr('Action'),
        'TR_DEACTIVATE' => tr('Deactivate'),
        'TR_CANCEL'     => tr('Cancel')
    ]);

    $domainProps = getCustomerProperties($_SESSION['user_id']);
    $domainId = $domainProps['domain_id'];
    $domainName = $domainProps['domain_name'];
    generateItemList($tpl, $domainId, $domainName);
}

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('external_mail') or showBadRequestErrorPage();

if (isset($_GET['action']) && isset($_GET['domain_id']) && isset($_GET['domain_type'])) {
    $action = cleanInput($_GET['action']);
    $domainId = intval($_GET['domain_id']);
    $domainType = cleanInput($_GET['domain_type']);

    switch ($action) {
        case 'activate':
        case 'deactivate':
            updateExternalMailFeature($action, $domainId, $domainType);
            sendDaemonRequest();
            break;
        default:
            showBadRequestErrorPage();
    }

    redirectTo('mail_external.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'          => 'shared/layouts/ui.tpl',
    'page'            => 'client/mail_external.tpl',
    'page_message'    => 'layout',
    'item'            => 'page',
    'activate_link'   => 'item',
    'deactivate_link' => 'item'
]);
generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
