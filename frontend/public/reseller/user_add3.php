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

use iMSCP\Crypt as Crypt;
use iMSCP\PHPini;
use iMSCP\TemplateEngine;
use iMSCP_Events as Events;
use iMSCP_Exception as iMSCPException;
use iMSCP_Registry as Registry;
use Zend_Form as Form;

/**
 * Get data from previous step
 *
 * @return bool
 */
function getPreviousStepData()
{
    global $adminName, $hpId, $dmnName, $dmnExpire, $dmnUrlForward, $dmnTypeForward, $dmnHostForward;

    $dmnExpire = $_SESSION['dmn_expire'];
    $dmnUrlForward = $_SESSION['dmn_url_forward'];
    $dmnTypeForward = $_SESSION['dmn_type_forward'];
    $dmnHostForward = $_SESSION['dmn_host_forward'];

    if (isset($_SESSION['step_one'])) {
        $stepTwo = $_SESSION['dmn_name'] . ';' . $_SESSION['dmn_tpl'];
        $hpId = $_SESSION['dmn_tpl'];
        unset($_SESSION['dmn_name']);
        unset($_SESSION['dmn_tpl']);
        unset($_SESSION['chtpl']);
        unset($_SESSION['step_one']);
    } elseif (isset($_SESSION['step_two_data'])) {
        $stepTwo = $_SESSION['step_two_data'];
        unset($_SESSION['step_two_data']);
    } elseif (isset($_SESSION['local_data'])) {
        $stepTwo = $_SESSION['local_data'];
        unset($_SESSION['local_data']);
    } else {
        $stepTwo = "'';0";
    }

    list($dmnName, $hpId) = explode(';', $stepTwo);
    $adminName = $dmnName;

    if (!validateDomainName($dmnName) || $hpId == '') {
        return false;
    }

    return true;
}

/**
 * Add customer user
 *
 * @throws Exception
 * @throws iMSCP_Exception
 * @param Form $form
 * @return void
 */
function addCustomer(Form $form)
{
    global $hpId, $dmnName, $dmnExpire, $dmnUrlForward, $dmnTypeForward, $dmnHostForward, $clientIps, $adminName;

    $formIsValid = TRUE;

    if (isset($_POST['domain_client_ips']) && is_array($_POST['domain_client_ips'])) {
        $stmt = execQuery('SELECT reseller_ips FROM reseller_props WHERE reseller_id = ?', [$_SESSION['user_id']]);
        if (!$stmt->rowCount()) {
            throw new iMSCPException(sprintf('Could not find IPs for reseller with ID %s', $_SESSION['user_id']));
        }

        $clientIps = array_intersect($_POST['domain_client_ips'], explode(',', $stmt->fetchColumn()));
        if (count($clientIps) < count($_POST['domain_client_ips'])) {
            showBadRequestErrorPage();
        }
    } elseif (!isset($_POST['domain_client_ips'])) {
        setPageMessage(toHtml(tr('You must select at least one IP address.')), 'error');
        $formIsValid = FALSE;
    } else {
        showBadRequestErrorPage();
    }

    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                setPageMessage(toHtml($msg), 'error');
            }
        }

        $formIsValid = FALSE;
    }

    if (!$formIsValid) {
        return;
    }

    $cfg = Registry::get('config');

    if (isset($_SESSION['ch_hpprops'])) {
        $props = $_SESSION['ch_hpprops'];
        unset($_SESSION['ch_hpprops']);
    } else {
        $stmt = execQuery('SELECT props FROM hosting_plans WHERE reseller_id = ? AND id = ?', [$_SESSION['user_id'], $hpId]);
        $props = $stmt->fetchColumn();
    }

    list($php, $cgi, $sub, $als, $mail, $ftp, $sql_db, $sql_user, $traff, $disk, $backup, $dns, $aps, $phpEditor, $phpConfigLevel,
        $phpiniAllowUrlFopen, $phpiniDisplayErrors, $phpiniDisableFunctions, $phpMailFunction, $phpiniPostMaxSize, $phpiniUploadMaxFileSize,
        $phpiniMaxExecutionTime, $phpiniMaxInputTime, $phpiniMemoryLimit, $extMailServer, $webFolderProtection, $mailQuota
        ) = explode(';', $props);

    $php = str_replace('_', '', $php);
    $cgi = str_replace('_', '', $cgi);
    $backup = str_replace('_', '', $backup);
    $dns = str_replace('_', '', $dns);
    $aps = str_replace('_', '', $aps);
    $extMailServer = str_replace('_', '', $extMailServer);
    $webFolderProtection = str_replace('_', '', $webFolderProtection);

    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();

    try {
        $db->beginTransaction();

        execQuery(
            "
                INSERT INTO admin (
                    admin_name, admin_pass, admin_type, domain_created, created_by, fname, lname, firm, zip, city, state, country, email, phone, fax,
                    street1, street2, gender, admin_status
                ) VALUES (
                    ?, ?, ?, unix_timestamp(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'toadd'
                )
            ",
            [
                $adminName, Crypt::apr1MD5($form->getValue('admin_pass')), 'user', $_SESSION['user_id'], $form->getValue('fname'),
                $form->getValue('lname'), $form->getValue('firm'), $form->getValue('zip'), $form->getValue('city'), $form->getValue('state'),
                $form->getValue('country'), encodeIdna($form->getValue('email')), $form->getValue('phone'), $form->getValue('fax'),
                $form->getValue('street1'), $form->getValue('street2'), $form->getValue('gender')
            ]
        );

        $adminId = $db->lastInsertId();

        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeAddDomain, [
            'createdBy'     => $_SESSION['user_id'],
            'customerId'    => $adminId,
            'customerEmail' => $form->getValue('email'),
            'domainName'    => $dmnName,
            'domainIps'     => [$clientIps[0]],
            'mountPoint'    => '/',
            'documentRoot'  => '/htdocs',
            'forwardUrl'    => $dmnUrlForward,
            'forwardType'   => $dmnTypeForward,
            'forwardHost'   => $dmnHostForward
        ]);
        execQuery(
            '
                INSERT INTO domain (
                    domain_name, domain_admin_id, domain_created, domain_expires, domain_mailacc_limit, domain_ftpacc_limit, domain_traffic_limit,
                    domain_sqld_limit, domain_sqlu_limit, domain_status, domain_alias_limit, domain_subd_limit, domain_client_ips, domain_ips,
                    domain_disk_limit, domain_disk_usage, domain_php, domain_cgi, allowbackup, domain_dns, domain_software_allowed, phpini_perm_system,
                    phpini_perm_config_level, phpini_perm_allow_url_fopen, phpini_perm_display_errors, phpini_perm_disable_functions,
                    phpini_perm_mail_function, domain_external_mail, web_folder_protection, mail_quota, url_forward,type_forward, host_forward
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [
                $dmnName, $adminId, time(), $dmnExpire, $mail, $ftp, $traff, $sql_db, $sql_user, 'toadd', $als, $sub, implode(',', $clientIps),
                $clientIps[0], $disk, 0, $php, $cgi, $backup, $dns, $aps, $phpEditor, $phpConfigLevel, $phpiniAllowUrlFopen, $phpiniDisplayErrors,
                $phpiniDisableFunctions, $phpMailFunction, $extMailServer, $webFolderProtection, $mailQuota, $dmnUrlForward, $dmnTypeForward,
                $dmnHostForward
            ]
        );

        $dmnId = $db->lastInsertId();

        $phpini = PhpIni::getInstance();
        $phpini->loadResellerPermissions($_SESSION['user_id']); // Load reseller PHP permissions
        $phpini->loadClientPermissions(); // Load client default PHP permissions
        $phpini->loadIniOptions(); // Load domain default PHP configuration options
        $phpini->setIniOption('phpiniMemoryLimit', $phpiniMemoryLimit); // Must be set before phpiniPostMaxSize
        $phpini->setIniOption('phpiniPostMaxSize', $phpiniPostMaxSize); // Must be set before phpiniUploadMaxFileSize
        $phpini->setIniOption('phpiniUploadMaxFileSize', $phpiniUploadMaxFileSize);
        $phpini->setIniOption('phpiniMaxExecutionTime', $phpiniMaxExecutionTime);
        $phpini->setIniOption('phpiniMaxInputTime', $phpiniMaxInputTime);
        $phpini->saveIniOptions($adminId, $dmnId, 'dmn');

        createDefaultMailAccounts($dmnId, $form->getValue('email'), $dmnName);
        sendWelcomeMail(
            $_SESSION['user_id'], $adminName, $form->getValue('admin_pass'), $form->getValue('email'), $form->getValue('fname'),
            $form->getValue('lname'), tr('Customer')
        );
        execQuery('INSERT INTO user_gui_props (user_id, lang, layout) VALUES (?, ?, ?)', [
            $adminId, $cfg['USER_INITIAL_LANG'], $cfg['USER_INITIAL_THEME']
        ]);
        recalculateResellerAssignments($_SESSION['user_id']);
        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterAddDomain, [
            'createdBy'     => $_SESSION['user_id'],
            'customerId'    => $adminId,
            'customerEmail' => $form->getValue('email'),
            'domainId'      => $dmnId,
            'domainName'    => $dmnName,
            'domainIps'     => [$clientIps[0]],
            'mountPoint'    => '/',
            'documentRoot'  => '/htdocs',
            'forwardUrl'    => $dmnUrlForward,
            'forwardType'   => $dmnTypeForward,
            'forwardHost'   => $dmnHostForward
        ]);
        $db->commit();
        sendDaemonRequest();
        writeLog(sprintf('A new customer (%s) has been created by: %s:', $adminName, $_SESSION['user_logged']), E_USER_NOTICE);
        setPageMessage(tr('Customer account successfully scheduled for creation.'), 'success');
        unsetMessages();
        redirectTo('users.php');
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
}

/**
 * Generates page
 *
 * @param  TemplateEngine $tpl Template engine
 * @param Form $form
 * @return void
 */
function generatePage(TemplateEngine $tpl, Form $form)
{
    global $hpId, $dmnName, $clientIps;

    $form->setDefault('admin_name', $dmnName);
    $tpl->form = $form;
    generateResellerIpsList($tpl, $_SESSION['user_id'], $clientIps ?: []);
    $_SESSION['local_data'] = "$dmnName;$hpId";
}

require 'imscp-lib.php';

checkLogin('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onResellerScriptStart);

if (!getPreviousStepData()) {
    setPageMessage(tr('Data were altered. Please try again.'), 'error');
    unsetMessages();
    redirectTo('user_add1.php');
}

$form = getUserLoginDataForm(false, true)->addElements(getUserPersonalDataForm()->getElements());
$form->setDefault('gender', 'U');

if (isset($_POST['uaction']) && 'user_add3_nxt' == $_POST['uaction'] && !isset($_SESSION['step_two_data'])) {
    addCustomer($form);
} else {
    unset($_SESSION['step_two_data']);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'reseller/user_add3.phtml',
    'page_message' => 'layout',
    'ip_entry'     => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Reseller / Customers / Add Customer - Next Step')));
generateNavigation($tpl);
generatePage($tpl, $form);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onResellerScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
