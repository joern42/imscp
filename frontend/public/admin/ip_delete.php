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
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
isset($_GET['id']) or View::showBadRequestErrorPage();

$stmt = execQuery(
    "
        SELECT COUNT(DISTINCT t2.reseller_id) As num_assignments, COUNT(t3.ip_id) AS remaining_ips, t1.*
        FROM server_ips AS t1
        LEFT JOIN reseller_props AS t2 ON(FIND_IN_SET(t1.ip_id, t2.reseller_ips))
        LEFT JOIN server_ips AS t3 ON(t3.ip_id <> t1.ip_id AND t3.ip_id <> 'todelete')
        WHERE t1.ip_id = ?
        GROUP BY t1.ip_id
    ",
    [intval($_GET['id'])]
);
$stmt->rowCount() or View::showBadRequestErrorPage();
$row = $stmt->fetch();

if ($row['num_assignments'] > 0) {
    setPageMessage(tr('You cannot delete an IP address that is assigned to a reseller.'), 'error');
    redirectTo('ip_manage.php');
}

if ($row['remaining_ips'] < 1) {
    setPageMessage(tr('You cannot delete the last IP address.'), 'error');
    redirectTo('ip_manage.php');
}

Application::getInstance()->getEventManager()->trigger(Events::onDeleteIpAddr, NULL, [
    'ip_id'          => $row['ip_id'],
    'ip_number'      => $row['ip_number'],
    'ip_netmask'     => $row['ip_netmask'],
    'ip_card'        => $row['enp0s3'],
    'ip_config_mode' => $row['auto']
]);
execQuery("UPDATE server_ips SET ip_status = 'todelete' WHERE ip_id = ?", $row['ip_id']);
Daemon::sendRequest();
writeLog(sprintf(
    "The %s IP address has been deleted by %s", $row['ip_number'], Application::getInstance()->getAuthService()->getIdentity()->getUsername()),
    E_USER_NOTICE
);
setPageMessage(tr('IP address successfully scheduled for deletion.'), 'success');
redirectTo('ip_manage.php');
