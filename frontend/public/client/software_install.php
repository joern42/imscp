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

use iMSCP\TemplateEngine;
use iMSCP\VirtualFileSystem as VirtualFileSystem;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/**
 * Set FTP root dir
 *
 * @param null|TemplateEngine $tpl
 * @return void
 */
function setFtpRootDir($tpl = NULL)
{
    $domainProps = getCustomerProperties($_SESSION['user_id']);

    if (!isXhr()) {
        list($mountPoint, $documentRoot) = getDomainMountpoint($domainProps['domain_id'], 'dmn', $_SESSION['user_id']);

        $tpl->assign('DOCUMENT_ROOT', toHtml(normalizePath($documentRoot)));

        # Set parameters for the FTP chooser
        $_SESSION['ftp_chooser_domain_id'] = $domainProps['domain_id'];
        $_SESSION['ftp_chooser_user'] = $_SESSION['user_logged'];
        $_SESSION['ftp_chooser_root_dir'] = normalizePath($mountPoint . '/' . $documentRoot);
        $_SESSION['ftp_chooser_hidden_dirs'] = [];
        $_SESSION['ftp_chooser_unselectable_dirs'] = [];
        return;
    }

    header('Cache-Control: no-cache, must-revalidate');
    header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
    header('Content-type: application/json');

    $data = [];

    if (!isset($_POST['domain_id']) || !isset($_POST['domain_type'])) {
        header('Status: 400 Bad Request');
        $data['message'] = tr('Bad request.');
    } else {
        try {
            list($mountPoint, $documentRoot) = getDomainMountpoint(
                intval($_POST['domain_id']), cleanInput($_POST['domain_type']), $_SESSION['user_id']
            );

            # Update parameters for the FTP chooser
            $_SESSION['ftp_chooser_domain_id'] = $domainProps['domain_id'];
            $_SESSION['ftp_chooser_user'] = $_SESSION['user_logged'];
            $_SESSION['ftp_chooser_root_dir'] = normalizePath($mountPoint . '/' . $documentRoot);
            $_SESSION['ftp_chooser_hidden_dirs'] = [];
            $_SESSION['ftp_chooser_unselectable_dirs'] = [];

            header('Status: 200 OK');
            $data['document_root'] = normalizePath($documentRoot);
        } catch (iMSCP_Exception $e) {
            header('Status: 400 Bad Request');
            $data['message'] = tr('Bad request.') . ' ' . $e->getMessage();
        }
    }

    echo json_encode($data);
    exit;
}

/**
 * Generate Page
 *
 * @throws iMSCP_Exception
 * @param TemplateEngine $tpl
 * @param int $softwareId Software unique identifier
 * @return void
 */
function client_generatePage($tpl, $softwareId)
{
    $domainProperties = getCustomerProperties($_SESSION['user_id']);
    $stmt = execQuery('SELECT created_by FROM admin WHERE admin_id = ?', [$_SESSION['user_id']]);

    if (!$stmt->rowCount()) {
        throw new iMSCP_Exception('An unexpected error occurred. Please contact your reseller.');
    }

    $row = $stmt->fetch();
    get_software_props_install($tpl, $domainProperties['domain_id'], $softwareId, $row['created_by'], $domainProperties['domain_sqld_limit']);
}

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);
customerHasFeature('aps') && isset($_GET['id']) or showBadRequestErrorPage();

$softwareId = intval($_GET['id']);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'            => 'shared/layouts/ui.tpl',
    'page'              => 'client/software_install.tpl',
    'page_message'      => 'layout',
    'software_item'     => 'page',
    'show_domain_list'  => 'page',
    'software_install'  => 'page',
    'no_software'       => 'page',
    'require_installdb' => 'page'
]);

if (!empty($_POST)) {
    if (isXhr()) {
        setFtpRootDir();
    }

    if (!isset($_POST['selected_domain']) || !isset($_POST['other_dir']) || !isset($_POST['install_username']) || !isset($_POST['install_password'])
        || !isset($_POST['install_email'])
    ) {
        showBadRequestErrorPage();
    }

    # Required data
    $otherDir = normalizePath(cleanInput($_POST['other_dir']));
    $appLoginName = cleanInput($_POST['install_username']);
    $appPassword = cleanInput($_POST['install_password']);
    $appEmail = cleanInput($_POST['install_email']);
    $stmt = execQuery(
        '
            SELECT software_master_id, software_db, software_name, software_version, software_language, software_prefix, software_depot
            FROM web_software
            WHERE software_id = ?
        ',
        [$softwareId]
    );
    $stmt->rowCount() or showBadRequestErrorPage();
    $softwareData = $stmt->fetch();
    $postData = explode(';', $_POST['selected_domain']);

    if (sizeof($postData) != 2) {
        showBadRequestErrorPage();
    }

    $domainId = intval($postData[0]);
    $domainType = cleanInput($postData[1]);
    $domainProps = getCustomerProperties($_SESSION['user_id']);
    $aliasId = $subId = $aliasSubId = 0;

    switch ($domainType) {
        case 'dmn':
            $stmt = execQuery(
                "
                  SELECT '/' AS mpoint, document_root
                  FROM domain
                  WHERE domain_id = ?
                  AND domain_admin_id = ?
                  AND domain_status = 'ok'
                  AND url_forward = 'no'
                ",
                [$domainId, $_SESSION['user_id']]
            );
            break;
        case 'sub':
            $subId = $domainId;
            $stmt = execQuery(
                "
                  SELECT subdomain_mount AS mpoint, subdomain_document_root AS document_root
                  FROM subdomain
                  WHERE subdomain_id = ?
                  AND domain_id = ?
                  AND subdomain_url_forward = 'no'
                  AND subdomain_status = 'ok'
                ",
                [$domainId, $domainProps['domain_id']]
            );
            break;
        case 'als':
            $aliasId = $domainId;
            $stmt = execQuery(
                "
                  SELECT alias_mount AS mpoint, alias_document_root AS document_root
                  FROM domain_aliases
                  WHERE alias_id = ?
                  AND domain_id = ?
                  AND alias_status = 'ok'
                  AND url_forward = 'no'
                ",
                [$domainId, $domainProps['domain_id']]
            );
            break;
        case 'alssub':
            $aliasSubId = $domainId;
            $stmt = execQuery(
                "
                  SELECT subdomain_alias_mount AS mpoint, subdomain_alias_document_root AS document_root
                  FROM subdomain_alias
                  JOIN domain_aliases USING(alias_id)
                  WHERE subdomain_alias_id = ?
                  AND subdomain_alias_url_forward = 'no'
                  AND domain_id = ?
                  AND subdomain_alias_status = 'ok'
                ",
                [$domainId, $domainProps['domain_id']]
            );
            break;
        default:
            showBadRequestErrorPage();
            exit;
    }

    $row = $stmt->fetch();
    $installPath = normalizePath($row['mpoint'] . '/htdocs/' . $otherDir);
    $error = false;

    $vfs = new VirtualFileSystem($_SESSION['user_logged']);
    if (!$vfs->exists($installPath, VirtualFileSystem::VFS_TYPE_DIR)) {
        setPageMessage(tr("The directory %s doesn't exist. Please create that directory using your file manager.", $otherDir), 'error');
        $error = true;
    } else {
        $stmt = execQuery(
            'SELECT software_name, software_version FROM web_software_inst WHERE domain_id = ? AND path = ?', [$domainId, $installPath]
        );

        if ($stmt->rowCount()) {
            $row = $stmt->fetch();
            setPageMessage(tr('Please select another directory. %s (%s) is installed there.', $row['software_name'], $row['software_version']), 'error');
            $error = true;
        }
    }

    # Check application username
    if (strpos($appLoginName, ',') !== FALSE || !validateUsername($appLoginName)) {
        setPageMessage(tr('Invalid username.'), 'error');
        $error = true;
    }

    # Check application password
    if (strpos($appPassword, ',') !== FALSE || !checkPasswordSyntax($appPassword)) {
        $error = true;
    }

    # Check application email
    if (strpos($appEmail, ',') !== FALSE || !ValidateEmail($appEmail)) {
        setPageMessage(tr('Invalid email address.'), 'error');
        $error = true;
    }

    # Check application database if required
    if ($softwareData['software_db']) {
        if (!isset($_POST['database_name']) || !isset($_POST['database_user']) || !isset($_POST['database_pwd'])) {
            showBadRequestErrorPage();
        }

        $appDatabase = cleanInput($_POST['database_name']);
        $appSqlUser = cleanInput($_POST['database_user']);
        $appSqlPassword = cleanInput($_POST['database_pwd']);

        # Checks that database exists and is owned by the customer
        $stmt = execQuery('SELECT sqld_id FROM sql_database WHERE domain_id = ? AND sqld_name = ?', [$domainProps['domain_id'], $appDatabase]);
        if (!$stmt->rowCount()) {
            setPageMessage(tr("Unknown %s database. Database must exists.", $appDatabase), 'error');
            $error = true;
        } else {
            $row = $stmt->fetch();

            # Check that SQL user belongs to the given database
            $stmt = execQuery('SELECT COUNT(sqlu_id) FROM sql_user WHERE sqld_id = ? AND sqlu_name = ?', [$row['sqld_id'], $appSqlUser]);
            if ($stmt->fetchColumn() < 1) {
                setPageMessage(tr('Invalid SQL user. SQL user must exists and belong to the provided database.'), 'error');
                $error = true;
            } # Check database connection using provided SQL user/password
            elseif (!check_db_connection($appDatabase, $appSqlUser, $appSqlPassword)) {
                setPageMessage(tr("Could not connect to the %s database. Please check the password.", $appDatabase), 'error');
                $error = true;
            }
        }

        $softwarePrefix = $softwareData['software_prefix'];
    } else {
        $softwarePrefix = $appDatabase = $appSqlUser = $appSqlPassword = 'no_required';
    }

    if ($error) {
        return;
    }

    execQuery(
        "
            INSERT INTO web_software_inst (
                domain_id, alias_id, subdomain_id, subdomain_alias_id, software_id, software_master_id, software_name, software_version,
                software_language, path, software_prefix, db, database_user, database_tmp_pwd, install_username, install_password, install_email,
                software_status, software_depot
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'toadd', ?
            )
        ",
        [
            $domainProps['domain_id'], $aliasId, $subId, $aliasSubId, $softwareId, $softwareData['software_master_id'],
            $softwareData['software_name'], $softwareData['software_version'], $softwareData['software_language'], $installPath, $softwarePrefix,
            $appDatabase, $appSqlUser, $appSqlPassword, $appLoginName, $appPassword, encodeIdna($appEmail), $softwareData['software_depot']
        ]
    );

    writeLog(sprintf('%s added new software instance: %s', $_SESSION['user_logged'], $softwareData['software_name']), E_USER_NOTICE);
    sendDaemonRequest();
    setPageMessage(tr('Software instance has been scheduled for installation'), 'success');
    redirectTo('software.php');

} else {
    setFtpRootDir($tpl);
    $otherDir = $appPassword = $appDatabase = $appDatabase = $appSqlUser = '';
    $appLoginName = 'admin';
    $appEmail = iMSCP_Authentication::getInstance()->getIdentity()->email;
}

$tpl->assign([
    'TR_PAGE_TITLE'               => tr('Client / Webtools / Software / Software Installation'),
    'SOFTWARE_ID'                 => toHtml($softwareId),
    'TR_NAME'                     => tr('Software'),
    'TR_TYPE'                     => tr('Type'),
    'TR_DB'                       => tr('Database required'),
    'TR_SELECT_DOMAIN'            => tr('Target domain'),
    'TR_CANCEL'                   => tr('Cancel'),
    'TR_INSTALL'                  => tr('Install'),
    'TR_PATH'                     => tr('Installation path'),
    'TR_CHOOSE_DIR'               => tr('Choose dir'),
    'TR_DATABASE_DATA'            => tr('Database data'),
    'TR_DATABASE_NAME'            => tr('Database name'),
    'TR_DATABASE_USER'            => tr('Database user'),
    'TR_DATABASE_PWD'             => tr('Database password'),
    'TR_INSTALLATION'             => tr('Installation details'),
    'TR_INSTALLATION_INFORMATION' => tr('Username and password for application login'),
    'TR_INSTALL_USER'             => tr('Login username'),
    'TR_INSTALL_PWD'              => tr('Login password'),
    'TR_INSTALL_EMAIL'            => tr('Email address'),
    'VAL_OTHER_DIR'               => toHtml($otherDir),
    'VAL_INSTALL_USERNAME'        => toHtml($appLoginName),
    'VAL_INSTALL_PASSWORD'        => toHtml($appPassword),
    'VAL_INSTALL_EMAIL'           => toHtml(decodeIdna($appEmail)),
    'VAL_DATABASE_NAME'           => toHtml($appDatabase),
    'VAL_DATABASE_USER'           => toHtml($appSqlUser)
]);
Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['close'] = tr('Close');
    $translations['core']['ftp_directories'] = tr('Ftp directories');
});
client_generatePage($tpl, $softwareId);
generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
