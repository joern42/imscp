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
 * Reject domain alias order
 *
 * @throws \Exception
 */
function rejectDomainAliasOrder()
{
    isset($_GET['id']) or View::showBadRequestErrorPage();
    $domainAliasId = intval($_GET['id']);

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    
    $stmt = execQuery(
        "
            SELECT t1.alias_id
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(admin_id = domain_admin_id)
            WHERE t1.alias_id = ?
            AND t1.alias_status = 'ordered'
            AND t3.created_by = ?
        ",
        [$domainAliasId, $identity->getUserId()]
    );
    $stmt->rowCount() or View::showBadRequestErrorPage();

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();
        execQuery("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'als'", [$domainAliasId]);
        execQuery('DELETE FROM domain_aliases WHERE alias_id = ?', [$domainAliasId]);
        $db->getDriver()->getConnection()->commit();
        writeLog(sprintf('A domain alias order has been rejected by %s.', $identity->getUsername()), E_USER_NOTICE);
        setPageMessage(toHtml(tr('Domain alias order successfully rejected.')), 'success');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to reject a domain alias order: %s', $e->getMessage()), E_USER_ERROR);
        setPageMessage(toHtml(tr("Couldn't reject the domain alias order. An unexpected error occurred.")), 'error');
    }
}

/**
 * Approve domain alias order
 *
 * @throws \Exception
 */
function approveDomainAliasOrder()
{
    isset($_GET['id']) or View::showBadRequestErrorPage();
    $domainAliasId = intval($_GET['id']);

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    
    $stmt = execQuery(
        "
            SELECT t1.*, t2.domain_client_ips, t3.email
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
            WHERE t1.alias_id = ?
            AND t1.alias_status = 'ordered'
            AND t3.created_by = ?
        ",
        [$domainAliasId, $identity->getUserId()]
    );
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        // Since domain alias has been ordered, the IP set while ordering could have
        // been unassigned or even removed. In such case, we set the domain alias with
        // the first IP address found in client IP addresses list.
        //
        // In fact, this should never occurs as IP addresses assigned to client's domains
        // and subdomains are synchronized with his new IP addresses list when the reseller
        // update his account properties. However, we still do that check for safety reasons.
        $clientIps = explode(',', $row['domain_client_ips']);
        $row['alias_ips'] = array_intersect(explode(',', $row['alias_ips'], $clientIps));
        if (empty($row['alias_ips'])) {
            $row['alias_ips'] = $clientIps[0];
        }
        unset($clientIps);

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddDomainAlias, NULL, [
            'domainId'        => $row['domain_id'],
            'domainAliasName' => $row['alias_name'],
            'domainAliasIps'  => $row['alias_ips'],
            'mountPoint'      => $row['alias_mount'],
            'documentRoot'    => $row['alias_document_root'],
            'forwardUrl'      => $row['url_forward'],
            'forwardType'     => $row['type_forward'],
            'forwardHost'     => $row['host_forward']
        ]);
        execQuery("UPDATE domain_aliases SET alias_ips = ?, alias_status = 'toadd' WHERE alias_id = ?", [
            implode(',', $row['alias_ips']), $domainAliasId
        ]);
        Mail::createDefaultMailAccounts($row['domain_id'], $row['email'], $row['alias_name'], Mail::MT_ALIAS_FORWARD, $domainAliasId);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddDomainAlias, NULL, [
            'domainId'        => $row['domain_id'],
            'domainAliasName' => $row['alias_name'],
            'domainAliasIps'  => $row['alias_ips'],
            'mountPoint'      => $row['alias_mount'],
            'documentRoot'    => $row['alias_document_root'],
            'forwardUrl'      => $row['url_forward'],
            'forwardType'     => $row['type_forward'],
            'forwardHost'     => $row['host_forward']
        ]);
        $db->getDriver()->getConnection()->commit();
        Daemon::sendRequest();
        writeLog(sprintf('A domain alias order has been approved by %s.', $identity->getUsername()), E_USER_NOTICE);
        setPageMessage(toHtml(tr('Order successfully approved.')), 'success');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to approve a domain alias order: %s', $e->getMessage()), E_USER_ERROR);
        setPageMessage(toHtml(tr("Couldn't approve the domain alias order. An unexpected error occurred.")), 'error');
    }
}

/**
 * Generate page data
 *
 * @return array
 */
function generatePage()
{
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $columns = ['alias_name', 'alias_mount', 'url_forward', 'admin_name'];
    $columnAliases = ['t1.alias_name', 't1.alias_mount', 't1.url_forward', 't3.admin_name'];
    $nbColumns = count($columns);

    /* Paging */
    $limit = '';
    if (isset($_GET['iDisplayStart']) && isset($_GET['iDisplayLength']) && $_GET['iDisplayLength'] != '-1') {
        $limit = 'LIMIT ' . intval($_GET['iDisplayStart']) . ', ' . intval($_GET['iDisplayLength']);
    }

    /* Ordering */
    $order = '';
    if (isset($_GET['iSortCol_0'])) {
        $order = 'ORDER BY ';
        if (isset($_GET['iSortingCols'])) {
            $iSortingCols = intval($_GET['iSortingCols']);
            for ($i = 0; $i < $iSortingCols; $i++) {
                if (isset($_GET['iSortCol_' . $i]) && isset($_GET['bSortable_' . intval($_GET['iSortCol_' . $i])])
                    && $_GET['bSortable_' . intval($_GET['iSortCol_' . $i])] == 'true' && isset($_GET['sSortDir_' . $i])
                    && in_array($_GET['sSortDir_' . $i], ['asc', 'desc'], true)
                ) {
                    $order .= $columnAliases[intval($_GET['iSortCol_' . $i])] . ' ' . $_GET['sSortDir_' . $i] . ', ';
                }
            }
        }

        $order = substr_replace($order, '', -2);
        if ($order == 'ORDER BY') {
            $order = '';
        }
    }

    /* Filtering */
    $where = 'WHERE t3.created_by = ' . $identity->getUserId() . " AND t1.alias_status = 'ordered'";
    if (isset($_GET['sSearch']) && $_GET['sSearch'] != '') {
        $where .= ' AND (';
        for ($i = 0; $i < $nbColumns; $i++) {
            $where .= "{$columnAliases[$i]} LIKE " . quoteValue('%' . $_GET['sSearch'] . '%') . ' OR ';
        }
        $where = substr_replace($where, '', -3);
        $where .= ')';
    }

    /* Individual column filtering */
    for ($i = 0; $i < $nbColumns; $i++) {
        if (isset($_GET["bSearchable_$i"]) && $_GET["bSearchable_$i"] == 'true' && isset($_GET["sSearch_$i"]) && $_GET["sSearch_$i"] != '') {
            $where .= 'AND ' . $columnAliases[$i] . ' LIKE ' . quoteValue('%' . $_GET["sSearch_$i"] . '%');
        }
    }

    /* Get data to display */
    $rResult = execQuery(
        "
            SELECT SQL_CALC_FOUND_ROWS t1.alias_id, " . implode(', ', $columnAliases) . "
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
            $where $order $limit
        "
    );

    /* Total records after filtering (without limit) */
    $iTotalDisplayRecords = execQuery('SELECT FOUND_ROWS()')->fetchColumn();
    /* Total record before any filtering */
    $iTotalRecords = execQuery(
        "
            SELECT COUNT(t1.alias_id)
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
            WHERE t3.created_by = ?
            AND t1.alias_status = 'ordered'
        ",
        [$identity->getUserId()]
    )->fetchColumn();

    /* Output */
    $output = [
        'sEcho'                => intval($_GET['sEcho']),
        'iTotalDisplayRecords' => $iTotalDisplayRecords,
        'iTotalRecords'        => $iTotalRecords,
        'aaData'               => []
    ];

    $trActivate = tr('Approve');
    $trReject = tr('Reject');

    while ($data = $rResult->fetch()) {
        $row = [];
        $aliasName = decodeIdna($data['alias_name']);

        for ($i = 0; $i < $nbColumns; $i++) {
            if ($columns[$i] == 'alias_name') {
                $row[$columns[$i]] = '<span class="icon i_disabled">' . decodeIdna($data[$columns[$i]]) . '</span>';
            } elseif ($columns[$i] == 't3.admin_name') {
                $row[$columns[$i]] = toHtml(decodeIdna($data[$columns[$i]]));
            } else {
                $row[$columns[$i]] = toHtml($data[$columns[$i]]);
            }
        }

        $actions = "<a href=\"alias_orders.php?action=approve&id={$data['alias_id']}\" class=\"icon i_open\">$trActivate</a>";
        $actions .= "\n<a href=\"alias_orders.php?action=reject&id={$data['alias_id']}\" "
            . "onclick=\"return reject_alias_order(this, '" . toJs($aliasName) . "')\" class=\"icon i_close\">$trReject</a>";
        $row['actions'] = $actions;
        $output['aaData'][] = $row;
    }

    return $output;
}

require 'application.php';

Login::checkLogin('reseller');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
resellerHasFeature('domain_aliases') && Counting::resellerHasCustomers() or View::showBadRequestErrorPage();

if (isset($_GET['action'])) {
    if ($_GET['action'] == 'reject') {
        rejectDomainAliasOrder();
    } elseif ($_GET['action'] == 'approve') {
        approveDomainAliasOrder();
    } else {
        View::showBadRequestErrorPage();
    }

    redirectTo('alias_orders.php');
}

if (!isXhr()) {
    $tpl = new TemplateEngine();
    $tpl->define([
        'layout'       => 'shared/layouts/ui.tpl',
        'page'         => 'reseller/alias_orders.tpl',
        'page_message' => 'layout'
    ]);
    $tpl->assign([
        'TR_PAGE_TITLE'  => toHtml(tr('Reseller / Customers / Ordered Domain Aliases')),
        'TR_ALIAS_NAME'  => toHtml(tr('Domain alias name')),
        'TR_MOUNT_POINT' => toHtml(tr('Mount point')),
        'TR_FORWARD_URL' => toHtml(tr('Forward URL')),
        'TR_STATUS'      => toHtml(tr('Status')),
        'TR_CUSTOMER'    => toHtml(tr('Customer')),
        'TR_ACTIONS'     => toHtml(tr('Actions')),
        'TR_PROCESSING'  => toHtml(tr('Processing...'))
    ]);
    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $translation = $e->getParam('translations');
        $translation['core']['dataTable'] = View::getDataTablesPluginTranslations(false);
        $translation['core']['reject_domain_alias_order'] = tr('Are you sure you want to reject the order for the %s domain alias?', '%s');
    });
    View::generateNavigation($tpl);
    generatePageMessage($tpl);
    $tpl->parse('LAYOUT_CONTENT', 'page');
    Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
    $tpl->prnt();
    unsetMessages();
} else {
    header('Cache-Control: no-cache, must-revalidate');
    header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
    header('Content-type: application/json');
    header('Status: 200 OK');
    echo json_encode(generatePage());
}
