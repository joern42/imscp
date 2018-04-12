<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

use iMSCP\TemplateEngine;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/***********************************************************************************************************************
 * Functions
 */

/**
 * Reject a domain alias order
 *
 * @throws Zend_Exception
 * @throws iMSCP_Exception
 * @throws iMSCP_Exception_Database
 */
function reseller_rejectOrder()
{
    isset($_GET['id']) or showBadRequestErrorPage();
    $domainAliasId = intval($_GET['id']);

    $stmt = exec_query(
        "
            SELECT t1.alias_id
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(admin_id = domain_admin_id)
            WHERE t1.alias_id = ?
            AND t1.alias_status = 'ordered'
            AND t3.created_by = ?
        ",
        [$domainAliasId, $_SESSION['user_id']]
    );
    $stmt->rowCount() or showBadRequestErrorPage();

    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();

    try {
        $db->beginTransaction();
        exec_query("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'als'", [$domainAliasId]);
        exec_query('DELETE FROM domain_aliases WHERE alias_id = ?', [$domainAliasId]);
        $db->commit();
        write_log(sprintf('A domain alias order has been rejected by %s.', $_SESSION['user_logged']), E_USER_NOTICE);
        set_page_message(tohtml(tr('Domain alias order successfully rejected.')), 'success');
    } catch (iMSCP_Exception $e) {
        $db->rollBack();
        write_log(sprintf('System was unable to reject a domain alias order: %s', $e->getMessage()), E_USER_ERROR);
        set_page_message(tohtml(tr("Couldn't reject the domain alias order. An unexpected error occurred.")), 'error');
    }
}

/**
 * Approve a domain alias order
 *
 * @throws Zend_Exception
 * @throws iMSCP_Exception
 * @throws iMSCP_Exception_Database
 */
function reseller_approveOrder()
{
    isset($_GET['id']) or showBadRequestErrorPage();
    $domainAliasId = intval($_GET['id']);

    $stmt = exec_query(
        "
        SELECT t1.*, t2.domain_client_ips, t3.email
        FROM domain_aliases AS t1
        JOIN domain AS t2 USING(domain_id)
        JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
        WHERE t1.alias_id = ?
        AND t1.alias_status = 'ordered'
        AND t3.created_by = ?
    ",
        [$domainAliasId, $_SESSION['user_id']]
    );
    $stmt->rowCount() or showBadRequestErrorPage();
    $row = $stmt->fetch();

    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();

    try {
        $db->beginTransaction();

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

        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeAddDomainAlias, [
            'domainId'        => $row['domain_id'],
            'domainAliasName' => $row['alias_name'],
            'domainAliasIps'  => $row['alias_ips'],
            'mountPoint'      => $row['alias_mount'],
            'documentRoot'    => $row['alias_document_root'],
            'forwardUrl'      => $row['url_forward'],
            'forwardType'     => $row['type_forward'],
            'forwardHost'     => $row['host_forward']
        ]);
        exec_query("UPDATE domain_aliases SET alias_ips = ?, alias_status = 'toadd' WHERE alias_id = ?", [
            implode(',', $row['alias_ips']), $domainAliasId
        ]);
        createDefaultMailAccounts($row['domain_id'], $row['email'], $row['alias_name'], MT_ALIAS_FORWARD, $domainAliasId);
        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterAddDomainAlias, [
            'domainId'        => $row['domain_id'],
            'domainAliasName' => $row['alias_name'],
            'domainAliasIps'  => $row['alias_ips'],
            'mountPoint'      => $row['alias_mount'],
            'documentRoot'    => $row['alias_document_root'],
            'forwardUrl'      => $row['url_forward'],
            'forwardType'     => $row['type_forward'],
            'forwardHost'     => $row['host_forward']
        ]);

        $db->commit();
        send_request();
        write_log(sprintf('A domain alias order has been approved by %s.', $_SESSION['user_logged']), E_USER_NOTICE);
        set_page_message(tohtml(tr('Order successfully approved.')), 'success');
    } catch (iMSCP_Exception $e) {
        $db->rollBack();
        write_log(sprintf('System was unable to approve a domain alias order: %s', $e->getMessage()), E_USER_ERROR);
        set_page_message(tohtml(tr("Couldn't approve the domain alias order. An unexpected error occurred.")), 'error');
    }
}

/**
 * Generate page data
 *
 * @return array
 */
function reseller_generatePageData()
{
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
    $where = 'WHERE t3.created_by = ' . quoteValue($_SESSION['user_id'], PDO::PARAM_INT) . " AND t1.alias_status = 'ordered'";
    if (isset($_GET['sSearch']) && $_GET['sSearch'] != '') {
        $where .= ' AND (';
        for ($i = 0; $i < $nbColumns; $i++) {
            $where .= "{$columnAliases[$i]} LIKE " . quoteValue('%'.$_GET['sSearch']. '%') . ' OR ';
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
    $rResult = execute_query(
        "
            SELECT SQL_CALC_FOUND_ROWS t1.alias_id, " . implode(', ', $columnAliases) . "
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
            $where $order $limit
        "
    );

    /* Total records after filtering (without limit) */
    $iTotalDisplayRecords = execute_query('SELECT FOUND_ROWS()')->fetchColumn();
    /* Total record before any filtering */
    $iTotalRecords = exec_query(
        "
            SELECT COUNT(t1.alias_id)
            FROM domain_aliases AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.domain_admin_id)
            WHERE t3.created_by = ?
            AND t1.alias_status = 'ordered'
        ",
        [$_SESSION['user_id']]
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
        $aliasName = decode_idna($data['alias_name']);

        for ($i = 0; $i < $nbColumns; $i++) {
            if ($columns[$i] == 'alias_name') {
                $row[$columns[$i]] = '<span class="icon i_disabled">' . decode_idna($data[$columns[$i]]) . '</span>';
            } elseif ($columns[$i] == 't3.admin_name') {
                $row[$columns[$i]] = tohtml(decode_idna($data[$columns[$i]]));
            } else {
                $row[$columns[$i]] = tohtml($data[$columns[$i]]);
            }
        }

        $actions = "<a href=\"alias_orders.php?action=approve&id={$data['alias_id']}\" class=\"icon i_open\">$trActivate</a>";
        $actions .= "\n<a href=\"alias_orders.php?action=reject&id={$data['alias_id']}\" "
            . "onclick=\"return reject_alias_order(this, '" . tojs($aliasName) . "')\" class=\"icon i_close\">$trReject</a>";
        $row['actions'] = $actions;
        $output['aaData'][] = $row;
    }

    return $output;
}

/***********************************************************************************************************************
 * Main
 */

require 'imscp-lib.php';

check_login('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptStart);
resellerHasFeature('domain_aliases') && resellerHasCustomers() or showBadRequestErrorPage();

if (isset($_GET['action'])) {
    if ($_GET['action'] == 'reject') {
        reseller_rejectOrder();
    } elseif ($_GET['action'] == 'approve') {
        reseller_approveOrder();
    } else {
        showBadRequestErrorPage();
    }

    redirectTo('alias_orders.php');
}

if (!is_xhr()) {
    /** @var $tpl TemplateEngine */
    $tpl = new TemplateEngine();
    $tpl->define([
        'layout'       => 'shared/layouts/ui.tpl',
        'page'         => 'reseller/alias_orders.tpl',
        'page_message' => 'layout'
    ]);
    $tpl->assign([
        'TR_PAGE_TITLE'  => tohtml(tr('Reseller / Customers / Ordered Domain Aliases')),
        'TR_ALIAS_NAME'  => tohtml(tr('Domain alias name')),
        'TR_MOUNT_POINT' => tohtml(tr('Mount point')),
        'TR_FORWARD_URL' => tohtml(tr('Forward URL')),
        'TR_STATUS'      => tohtml(tr('Status')),
        'TR_CUSTOMER'    => tohtml(tr('Customer')),
        'TR_ACTIONS'     => tohtml(tr('Actions')),
        'TR_PROCESSING'  => tohtml(tr('Processing...'))
    ]);

    Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
        $translation = $e->getParam('translations');
        $translation['core']['dataTable'] = getDataTablesPluginTranslations(false);
        $translation['core']['reject_domain_alias_order'] = tr('Are you sure you want to reject the order for the %s domain alias?', '%s');
    });
    generateNavigation($tpl);
    generatePageMessage($tpl);

    $tpl->parse('LAYOUT_CONTENT', 'page');
    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptEnd, ['templateEngine' => $tpl]);
    $tpl->prnt();

    unsetMessages();
} else {
    header('Cache-Control: no-cache, must-revalidate');
    header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
    header('Content-type: application/json');
    header('Status: 200 OK');
    echo json_encode(reseller_generatePageData());
}
