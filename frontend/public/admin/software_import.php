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

use iMSCP_Exception_Database as DatabaseException;
use iMSCP_Registry as Registry;

require 'imscp-lib.php';

checkLogin('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAdminScriptStart);

isset($_GET['id']) or showBadRequestErrorPage();

$softwareId = intval($_GET['id']);
$stmt = execQuery('SELECT * FROM web_software WHERE software_id = ?', [$softwareId]);

if (!$stmt->rowCount()) {
    showBadRequestErrorPage();
}

$row = $stmt->fetch();
$cfg = Registry::get('config');
$srcFile = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $row['reseller_id'] . '/' . $row['software_archive'] . '-' . $row['software_id'] . '.tar.gz';
$destFile = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/sw_depot/' . $row['software_archive'] . '-' . $row['software_id'] . '.tar.gz';

@copy($srcFile, $destFile);
@unlink($srcFile);

/** @var iMSCP_Database $db */
$db = Registry::get('iMSCP_Application')->getDatabase();

try {
    $db->beginTransaction();
    execQuery("UPDATE web_software SET reseller_id = ?, software_active = 1, software_depot = 'yes' WHERE software_id = ?", [
        $_SESSION['user_id'], $softwareId
    ]);
    execQuery(
        "
            INSERT INTO web_software (
                software_master_id, reseller_id, software_name, software_version, software_language, software_type, software_db, software_archive,
                software_installfile, software_prefix, software_link, software_desc, software_active, software_status, rights_add_by, software_depot
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'ok', ?, 'yes'
            )
        ",
        [
            $row['software_id'], $row['reseller_id'], $row['software_name'], $row['software_version'], $row['software_language'],
            $row['software_type'], $row['software_db'], $row['software_archive'], $row['software_installfile'], $row['software_prefix'],
            $row['software_link'], $row['software_desc'], $_SESSION['user_id']
        ]
    );
    update_existing_client_installations_res_upload($db->lastInsertId(), $row['reseller_id'], $row['software_id']);
    $db->commit();
    setPageMessage(tr('Software has been successfully imported.'), 'success');
    redirectTo('software_manage.php');
} catch (DatabaseException $e) {
    $db->rollBack();
    throw $e;
}
