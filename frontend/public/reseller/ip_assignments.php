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
use iMSCP_Registry as Registry;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage($tpl)
{
    #echo '<pre>';
    #print_r($_SESSION);

    $ips = exec_query(
        "
            SELECT t2.ip_id, t2.ip_number
            FROM reseller_props AS t1
            JOIN server_ips AS t2 ON(FIND_IN_SET(t2.ip_id, t1.reseller_ips))
            WHERE t1.reseller_id = ?
            ORDER BY LENGTH(t2.ip_number), t2.ip_number
        ",
        [$_SESSION['user_id']]
    )->fetchAll();

    $sip = isset($_POST['ip_address']) && in_array($_POST['ip_address'], array_column($ips, 'ip_id')) ? $_POST['ip_address'] : $ips[0]['ip_id'];

    foreach ($ips as $ip) {
        $tpl->assign([
            'IP_VALUE'    => tohtml($ip['ip_id']),
            'IP_NUM'      => tohtml($ip['ip_number'] == '0.0.0.0' ? tr('Any') : $ip['ip_number']),
            'IP_SELECTED' => $ip['ip_id'] == $sip ? ' selected' : ''
        ]);
        $tpl->parse('IP_ENTRY', '.ip_entry');
    }

    $stmt = exec_query(
        "
            SELECT GROUP_CONCAT(t2.admin_name ORDER BY t2.admin_name) AS customer_names
            FROM domain AS t1
            JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
            WHERE FIND_IN_SET(?, t1.domain_client_ips) 
            GROUP BY t1.domain_admin_id
        ",
        [$sip]
    );

    if ($stmt->rowCount()) {
        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'TR_CUSTOMER_NAMES'  => tohtml(tr('Customer Names')),
                'NO_ASSIGNMENTS_MSG' => '',
                'CUSTOMER_NAMES'     => tohtml(implode('<br>', array_map('decode_idna', explode(',', $row['customer_names'])))),
            ]);
            $tpl->parse('ASSIGNMENT_ROW', '.assignment_row');
        }
        return;
    }

    $tpl->assign([
        'TR_IP_NOT_ASSIGNED_YET' => tohtml(tr('This IP address has not been assigned to any customer yet.')),
        'ASSIGNMENT_ROWS'        => ''
    ]);

}

require 'imscp-lib.php';

check_login('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptStart);
resellerHasCustomers() or showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'reseller/ip_assignments.tpl',
    'page_message'       => 'layout',
    'ip_entry'           => 'page',
    'no_assignments_msg' => 'page',
    'assignment_rows'    => 'page',
    'assignment_row'     => 'assignment_rows',
]);
$tpl->assign([
    'TR_PAGE_TITLE'     => tohtml(tr('Reseller / Statistics / IP Assignments')),
    'TR_DROPDOWN_LABEL' => tohtml(tr('Select an IP address to see its assignments'))
]);

generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptEnd, [
    'templateEngine' => $tpl
]);
$tpl->prnt();

unsetMessages();
