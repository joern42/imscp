<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by i-MSCP Team
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

/***********************************************************************************************************************
 * Functions
 */

/**
 * Generate List of Domains assigned to IPs
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function listIPDomains($tpl)
{
    $stmt = execute_query('SELECT ip_id, ip_number FROM server_ips');

    while ($ip = $stmt->fetch()) {
        $stmt2 = exec_query(
            "
                SELECT t2.admin_name AS customer_name, t3.admin_name AS reseller_name
                FROM domain AS t1
                JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
                JOIN admin AS t3 ON (t3.admin_id = t2.created_by)
                WHERE ? REGEXP CONCAT('^(', (SELECT REPLACE((t1.domain_client_ips), ',', '|')), ')$')
            ",
            [$ip['ip_id']]
        );

        $customersCount = $stmt2->rowCount();

        $tpl->assign([
            'IP'           => tohtml(($ip['ip_number'] == '0.0.0.0') ? tr('Any') : $ip['ip_number']),
            'RECORD_COUNT' => tohtml(tr('Total customers') . ': ' . $customersCount)
        ]);

        if ($customersCount > 0) {
            while ($data = $stmt2->fetch()) {
                $tpl->assign([
                    'CUSTOMER_NAME' => tohtml(decode_idna($data['customer_name'])),
                    'RESELLER_NAME' => tohtml($data['reseller_name'])
                ]);
                $tpl->parse('CUSTOMER_ROW', '.customer_row');
            }
        } else {
            $tpl->assign('CUSTOMER_NAME', tr('No used yet'));
            $tpl->parse('CUSTOMER_row', 'customer_row');
        }

        $tpl->parse('IP_ROW', '.ip_row');
        $tpl->assign('CUSTOMER_ROW', '');
    }
}

/***********************************************************************************************************************
 * Main
 */

require 'imscp-lib.php';

check_login('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);

if (!systemHasCustomers()) {
    showBadRequestErrorPage();
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/ip_assignments.tpl',
    'page_message' => 'layout',
    'ip_row'       => 'page',
    'customer_row' => 'ip_row'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                => tr('Admin / Statistics / IP Assignments'),
    'TR_SERVER_STATISTICS'         => tr('Server statistics'),
    'TR_IP_ADMIN_USAGE_STATISTICS' => tr('Admin/IP usage statistics'),
    'TR_CUSTOMER_NAME'             => tr('Customer Name'),
    'TR_RESELLER_NAME'             => tr('Reseller Name')
]);

generateNavigation($tpl);
listIPDomains($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptEnd, [
    'templateEngine' => $tpl
]);
$tpl->prnt();

unsetMessages();
