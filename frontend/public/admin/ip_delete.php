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

use iMSCP_Registry as Registry;

require 'imscp-lib.php';

check_login('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);
isset($_GET['ip_id']) or showBadRequestErrorPage();

exec_query(
    "
        SELECT COUNT(DISTINCT t2.reseller_id) As num_assignments, COUNT(t3.ip_id) AS remaining_ips, t1.*
        FROM server_ips AS t1
        LEFT JOIN reseller_props AS t2 ON(FIND_IN_SET(t1.ip_id, t2.reseller_ips))
        LEFT JOIN server_ips AS t3 ON(t3.ip_id <> t1.ip_id AND t3.ip_id <> 'todelete')
        WHERE t1.ip_id = ?
        GROUP BY t1.ip_id
    ",
    [intval($_GET['ip_id'])]
);

$stmt->rowCount() or showBadRequestErrorPage();
$row = $stmt->fetch();

if ($row['num_assignments'] > 0) {
    set_page_message(tr('You cannot delete an IP address that is assigned to a reseller.'), 'error');
    redirectTo('ip_manage.php');
}

if ($row['remaining_ips'] < 1) {
    set_page_message(tr('You cannot delete the last IP address.'), 'error');
    redirectTo('ip_manage.php');
}

Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onDeleteIpAddr, [
    'ip_id'          => $row['ip_id'],
    'ip_number'      => $row['ip_number'],
    'ip_netmask'     => $row['ip_netmask'],
    'ip_card'        => $row['enp0s3'],
    'ip_config_mode' => $row['auto']
]);
exec_query("UPDATE server_ips SET ip_status = 'todelete' WHERE ip_id = ?", $row['ip_id']);
send_request();
write_log(sprintf("The %s IP address has been deleted by %s", $row['ip_number'], $_SESSION['user_logged']), E_USER_NOTICE);
set_page_message(tr('IP address successfully scheduled for deletion.'), 'success');
redirectTo('ip_manage.php');
