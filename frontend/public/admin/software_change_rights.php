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

use iMSCP_Registry as Registry;

require 'imscp-lib.php';

checkLogin('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);

isset($_REQUEST['id']) or showBadRequestErrorPage();

$softwareId = intval($_REQUEST['id']);

if (isset($_POST['change']) && $_POST['change'] == 'add') {
    ignore_user_abort(true);

    $resellerId = cleanInput($_POST['selected_reseller']);
    $stmt = execQuery('SELECT * FROM web_software WHERE software_id = ?', [$softwareId]);
    $stmt->rowCount() or showBadRequestErrorPage();
    $row = $stmt->fetch();

    if ($resellerId == 'all') {
        $stmt = executeQuery("SELECT reseller_id FROM reseller_props WHERE software_allowed = 'yes' AND softwaredepot_allowed = 'yes'");

        if (!$stmt->rowCount()) {
            setPageMessage(tr('No resellers found.'), 'error');
            redirectTo('software_rights.php?id=' . $softwareId);
        }

        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();

        while ($row2 = $stmt->fetch()) {
            $cnt = execQuery(
                'SELECT COUNT(reseller_id) FROM web_software WHERE reseller_id = ? AND software_master_id = ?', [$row2['reseller_id'], $softwareId]
            )->fetchColumn();

            if ($cnt != 0) {
                continue;
            }

            execQuery(
                "
                    INSERT INTO web_software (
                        software_master_id, reseller_id, software_name, software_version, software_language, software_type, software_db,
                        software_archive, software_installfile, software_prefix, software_link, software_desc, software_active, software_status,
                        rights_add_by, software_depot
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ok', ?, 'yes'
                )
                ",
                [
                    $softwareId, $row2['reseller_id'], $row['software_name'], $row['software_version'], $row['software_language'],
                    $row['software_type'], $row['software_db'], $row['software_archive'], $row['software_installfile'], $row['software_prefix'],
                    $row['software_link'], $row['software_desc'], $row['software_active'], $_SESSION['user_id']
                ]
            );

            update_existing_client_installations_sw_depot($db->lastInsertId(), $softwareId, $row2['reseller_id']);
        }
    } else {
        execQuery(
            "
                INSERT INTO web_software (
                    software_master_id, reseller_id, software_name, software_version, software_language, software_type, software_db, software_archive,
                    software_installfile, software_prefix, software_link, software_desc, software_active, software_status, rights_add_by,
                    software_depot
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ok', ?, 'yes'
                )
            ",
            [
                $softwareId, $resellerId, $row['software_name'], $row['software_version'], $row['software_language'], $row['software_type'],
                $row['software_db'], $row['software_archive'], $row['software_installfile'], $row['software_prefix'], $row['software_link'],
                $row['software_desc'], $row['software_active'], $_SESSION['user_id']
            ]
        );

        update_existing_client_installations_sw_depot(
            Registry::get('iMSCP_Application')->getDatabase()->lastInsertId(), $softwareId, $resellerId
        );
    }

    setPageMessage(tr('Rights successfully added.'), 'success');
    redirectTo("software_rights.php?id=$softwareId");
}

execQuery('DELETE FROM web_software WHERE software_master_id = ? AND reseller_id = ?', [$softwareId, intval($_GET['reseller_id'])]);
execQuery('UPDATE web_software_inst SET software_res_del = 1 WHERE software_master_id = ?', [$softwareId]);
setPageMessage(tr('Rights successfully removed.'), 'success');
redirectTo("software_rights.php?id=$softwareId");

