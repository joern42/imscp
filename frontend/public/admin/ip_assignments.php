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
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $stmt = execQuery('SELECT ip_id, ip_number FROM server_ips ORDER BY LENGTH(ip_number), ip_number');
    $ips = $stmt->fetchAll();
    $sip = isset($_POST['ip_address']) && in_array($_POST['ip_address'], array_column($ips, 'ip_id')) ? $_POST['ip_address'] : $ips[0]['ip_id'];

    foreach ($ips as $ip) {
        $tpl->assign([
            'IP_VALUE'    => toHtml($ip['ip_id']),
            'IP_NUM'      => toHtml($ip['ip_number'] == '0.0.0.0' ? tr('Any') : $ip['ip_number']),
            'IP_SELECTED' => $ip['ip_id'] == $sip ? ' selected' : ''
        ]);
        $tpl->parse('IP_ENTRY', '.ip_entry');
    }

    $stmt = execQuery(
        "
            SELECT GROUP_CONCAT(t2.admin_name ORDER BY t2.admin_name) AS customer_names, t3.admin_name AS reseller_name
            FROM domain AS t1
            JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
            JOIN admin AS t3 ON(t3.admin_id = t2.created_by)
            WHERE FIND_IN_SET(?, t1.domain_client_ips)
            GROUP BY t1.domain_admin_id
        ",
        [$sip]
    );

    if ($stmt->rowCount()) {
        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'TR_RESELLER_NAME'   => toHtml(tr('Reseller Name')),
                'TR_CUSTOMER_NAMES'  => toHtml(tr('Customer Names')),
                'NO_ASSIGNMENTS_MSG' => '',
                'RESELLER_NAME'      => toHtml($row['reseller_name']),
                'CUSTOMER_NAMES'     => toHtml(implode('<br>', array_map('decodeIdna', explode(',', $row['customer_names'])))),
            ]);
            $tpl->parse('ASSIGNMENT_ROW', '.assignment_row');
        }
        return;
    }
    $stmt = execQuery(
        "
            SELECT t2.admin_name AS reseller_name
            FROM reseller_props AS t1 JOIN admin AS t2 ON(t2.admin_id = t1.reseller_id)
            WHERE FIND_IN_SET(?, t1.reseller_ips)
        ",
        [$sip]
    );

    if ($stmt->rowCount() > 0) {
        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'TR_RESELLER_NAME'   => toHtml(tr('Reseller Name')),
                'TR_CUSTOMER_NAMES'  => toHtml(tr('Customer Names')),
                'NO_ASSIGNMENTS_MSG' => '',
                'RESELLER_NAME'      => toHtml($row['reseller_name']),
                'CUSTOMER_NAMES'     => toHtml(tr('Not assigned to any customer yet.')),
            ]);
            $tpl->parse('ASSIGNMENT_ROW', '.assignment_row');
        }
        return;
    }
    $tpl->assign([
        'TR_IP_NOT_ASSIGNED_YET' => toHtml(tr('This IP address has not been assigned to any reseller yet.')),
        'ASSIGNMENT_ROWS'        => ''
    ]);

}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
Counting::systemHasCustomers() or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'admin/ip_assignments.tpl',
    'page_message'       => 'layout',
    'ip_entry'           => 'page',
    'no_assignments_msg' => 'page',
    'assignment_rows'    => 'page',
    'assignment_row'     => 'assignment_rows',
]);
$tpl->assign([
    'TR_PAGE_TITLE'     => toHtml(tr('Admin / Statistics / IP Assignments')),
    'TR_DROPDOWN_LABEL' => toHtml(tr('Select an IP address to see its assignments'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
