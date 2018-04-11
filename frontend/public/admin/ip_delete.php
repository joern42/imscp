<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "VHCS - Virtual Hosting Control System".
 *
 * The Initial Developer of the Original Code is moleSoftware GmbH.
 * Portions created by Initial Developer are Copyright (C) 2001-2006
 * by moleSoftware GmbH. All Rights Reserved.
 *
 * Portions created by the ispCP Team are Copyright (C) 2006-2010 by
 * isp Control Panel. All Rights Reserved.
 *
 * Portions created by the i-MSCP Team are Copyright (C) 2010-2018 by
 * i-MSCP - internet Multi Server Control Panel. All Rights Reserved.
 */

use iMSCP_Registry as Registry;

/***********************************************************************************************************************
 * Main
 */

require 'imscp-lib.php';

check_login('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);
isset($_GET['ip_id']) or showBadRequestErrorPage();

$ipId = intval($_GET['ip_id']);
($ipAddr = exec_query('SELECT ip_number FROM server_ips WHERE ip_id = ?', [$ipId])->fetchColumn() !== FALSE) or showBadRequestErrorPage();

$stmt = execute_query('SELECT reseller_ips FROM reseller_props');
while ($row = $stmt->fetch()) {
    if (in_array($ipId, explode(',', $row['reseller_ips']))) {
        set_page_message(tr('You cannot delete an IP that is assigned to a reseller.'), 'error');
        redirectTo('ip_manage.php');
    }
}

if (execute_query('SELECT COUNT(ip_id) FROM server_ips')->fetchColumn() < 2) {
    set_page_message(tr('You cannot delete the last active IP address.'), 'error');
    redirectTo('ip_manage.php');
}

Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onDeleteIpAddr);
exec_query("UPDATE server_ips SET ip_status = 'todelete' WHERE ip_id = ?", [$ipId]);
send_request();
write_log(sprintf("An IP address (%s) has been deleted by %s", $ipAddr, $_SESSION['user_logged']), E_USER_NOTICE);
set_page_message(tr('IP address successfully scheduled for deletion.'), 'success');
redirectTo('ip_manage.php');
