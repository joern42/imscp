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

isset($_GET['id']) or showBadRequestErrorPage();

$softwareId = intval($_GET['id']);
$stmt = execQuery('SELECT reseller_id, software_archive, software_depot FROM web_software WHERE software_id = ?', [$softwareId]);
$stmt->rowCount() or showBadRequestErrorPage();
$row = $stmt->fetch();

$cfg = Registry::get('config');
if ($row['software_depot'] == 'yes') {
    $filename = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/sw_depot/' . $row['software_archive'] . '-' . $softwareId . '.tar.gz';
} else {
    $filename = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $row['reseller_id'] . '/' . $row['software_archive'] . '-' . $softwareId . '.tar.gz';
}

if (!file_exists($filename)) {
    setPageMessage(tr('File does not exist. %1$s.tar.gz', $row['software_archive']), 'error');
    redirectTo('software_manage.php');
}

header("Cache-Control: public, must-revalidate");
header("Pragma: hack");
header("Content-Type: application/octet-stream");
header("Content-Length: " . (string)(filesize($filename)));
header('Content-Disposition: attachment; filename="' . $row['software_archive'] . '.tar.gz"');
header("Content-Transfer-Encoding: binary\n");

$fp = fopen($filename, 'rb');
$buffer = fread($fp, filesize($filename));
fclose($fp);
print $buffer;
