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

use iMSCP\Authentication\AuthenticationService;
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use Zend\Form\Form;

/**
 * Get data from previous step
 *
 * @return bool
 */
function getPreviousStepData()
{
    global $adminName, $hpId, $dmnName, $dmnExpire, $dmnUrlForward, $dmnTypeForward, $dmnHostForward;

    $session = Application::getInstance()->getSession();

    $dmnExpire = $session['dmn_expire'];
    $dmnUrlForward = $session['dmn_url_forward'];
    $dmnTypeForward = $session['dmn_type_forward'];
    $dmnHostForward = $session['dmn_host_forward'];

    if (isset($session['step_one'])) {
        $stepTwo = $session['dmn_name'] . ';' . $session['dmn_tpl'];
        $hpId = $session['dmn_tpl'];
        unset($session['dmn_name']);
        unset($session['dmn_tpl']);
        unset($session['chtpl']);
        unset($session['step_one']);
    } elseif (isset($session['step_two_data'])) {
        $stepTwo = $session['step_two_data'];
        unset($session['step_two_data']);
    } elseif (isset($session['local_data'])) {
        $stepTwo = $session['local_data'];
        unset($session['local_data']);
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
 * @param Form $form
 * @return void
 */
function addCustomer(Form $form)
{
    global $hpId, $dmnName, $dmnExpire, $dmnUrlForward, $dmnTypeForward, $dmnHostForward, $clientIps, $adminName;

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $session = Application::getInstance()->getSession();
    $formIsValid = TRUE;

    if (isset($_POST['domain_client_ips']) && is_array($_POST['domain_client_ips'])) {
        $stmt = execQuery('SELECT reseller_ips FROM reseller_props WHERE reseller_id = ?', [$identity->getUserId()]);
        if (!$stmt->rowCount()) {
            throw new \Exception(sprintf('Could not find IPs for reseller with ID %s', $identity->getUserId()));
        }

        $clientIps = array_intersect($_POST['domain_client_ips'], explode(',', $stmt->fetchColumn()));
        if (count($clientIps) < count($_POST['domain_client_ips'])) {
            View::showBadRequestErrorPage();
        }
    } elseif (!isset($_POST['domain_client_ips'])) {
        View::setPageMessage(toHtml(tr('You must select at least one IP address.')), 'error');
        $formIsValid = FALSE;
    } else {
        View::showBadRequestErrorPage();
    }

    if (!$form->isValid($_POST)) {
        foreach ($form->getMessages() as $msgsStack) {
            foreach ($msgsStack as $msg) {
                View::setPageMessage(toHtml($msg), 'error');
            }
        }

        $formIsValid = FALSE;
    }

    if (!$formIsValid) {
        return;
    }

    $cfg = Application::getInstance()->getConfig();

    if (isset($session['ch_hpprops'])) {
        $props = $session['ch_hpprops'];
        unset($session['ch_hpprops']);
    } else {
        $stmt = execQuery('SELECT props FROM hosting_plans WHERE reseller_id = ? AND id = ?', [$identity->getUserId(), $hpId]);
        $props = $stmt->fetchColumn();
    }

    list($php, $cgi, $sub, $als, $mail, $ftp, $sql_db, $sql_user, $traff, $disk, $backup, $dns, $phpEditor, $phpConfigLevel, $phpiniAllowUrlFopen,
        $phpiniDisplayErrors, $phpiniDisableFunctions, $phpMailFunction, $phpiniPostMaxSize, $phpiniUploadMaxFileSize, $phpiniMaxExecutionTime,
        $phpiniMaxInputTime, $phpiniMemoryLimit, $extMailServer, $webFolderProtection, $mailQuota) = explode(';', $props);

    $php = str_replace('_', '', $php);
    $cgi = str_replace('_', '', $cgi);
    $backup = str_replace('_', '', $backup);
    $dns = str_replace('_', '', $dns);
    $extMailServer = str_replace('_', '', $extMailServer);
    $webFolderProtection = str_replace('_', '', $webFolderProtection);

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

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
                $adminName, Crypt::bcrypt($form->getValue('admin_pass')), 'user', $identity->getUserId(), $form->getValue('fname'),
                $form->getValue('lname'), $form->getValue('firm'), $form->getValue('zip'), $form->getValue('city'), $form->getValue('state'),
                $form->getValue('country'), encodeIdna($form->getValue('email')), $form->getValue('phone'), $form->getValue('fax'),
                $form->getValue('street1'), $form->getValue('street2'), $form->getValue('gender')
            ]
        );

        $adminId = $db->getDriver()->getLastGeneratedValue();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddDomain, NULL, [
            'createdBy'     => $identity->getUserId(),
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
                    domain_disk_limit, domain_disk_usage, domain_php, domain_cgi, allowbackup, domain_dns, phpini_perm_system,
                    phpini_perm_config_level, phpini_perm_allow_url_fopen, phpini_perm_display_errors, phpini_perm_disable_functions,
                    phpini_perm_mail_function, domain_external_mail, web_folder_protection, mail_quota, url_forward,type_forward, host_forward
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [
                $dmnName, $adminId, time(), $dmnExpire, $mail, $ftp, $traff, $sql_db, $sql_user, 'toadd', $als, $sub, implode(',', $clientIps),
                $clientIps[0], $disk, 0, $php, $cgi, $backup, $dns, $phpEditor, $phpConfigLevel, $phpiniAllowUrlFopen, $phpiniDisplayErrors,
                $phpiniDisableFunctions, $phpMailFunction, $extMailServer, $webFolderProtection, $mailQuota, $dmnUrlForward, $dmnTypeForward,
                $dmnHostForward
            ]
        );

        $dmnId = $db->getDriver()->getLastGeneratedValue();

        $phpini = PhpIni::getInstance();
        $phpini->loadResellerPermissions($identity->getUserId()); // Load reseller PHP permissions
        $phpini->loadClientPermissions(); // Load client default PHP permissions
        $phpini->loadIniOptions(); // Load domain default PHP configuration options
        $phpini->setIniOption('phpiniMemoryLimit', $phpiniMemoryLimit); // Must be set before phpiniPostMaxSize
        $phpini->setIniOption('phpiniPostMaxSize', $phpiniPostMaxSize); // Must be set before phpiniUploadMaxFileSize
        $phpini->setIniOption('phpiniUploadMaxFileSize', $phpiniUploadMaxFileSize);
        $phpini->setIniOption('phpiniMaxExecutionTime', $phpiniMaxExecutionTime);
        $phpini->setIniOption('phpiniMaxInputTime', $phpiniMaxInputTime);
        $phpini->saveIniOptions($adminId, $dmnId, 'dmn');

        Mail::createDefaultMailAccounts($dmnId, $form->getValue('email'), $dmnName);
        Mail::sendWelcomeMail(
            $identity->getUserId(), $adminName, $form->getValue('admin_pass'), $form->getValue('email'), $form->getValue('fname'),
            $form->getValue('lname'), tr('Customer')
        );
        execQuery('INSERT INTO user_gui_props (user_id, lang, layout) VALUES (?, ?, ?)', [
            $adminId, $cfg['USER_INITIAL_LANG'], $cfg['USER_INITIAL_THEME']
        ]);
        recalculateResellerAssignments($identity->getUserId());
        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddDomain, NULL, [
            'createdBy'     => $identity->getUserId(),
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
        $db->getDriver()->getConnection()->commit();
        Daemon::sendRequest();
        writeLog(sprintf('A new customer (%s) has been created by: %s:', $adminName, getProcessorUsername($identity)), E_USER_NOTICE);
        View::setPageMessage(tr('Customer account successfully scheduled for creation.'), 'success');
        unsetMessages();
        redirectTo('users.php');
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
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
    View::generateResellerIpsList($tpl, Application::getInstance()->getAuthService()->getIdentity()->getUserId(), $clientIps ?: []);
    Application::getInstance()->getSession()['local_data'] = "$dmnName;$hpId";
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::RESELLER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

if (!getPreviousStepData()) {
    View::setPageMessage(tr('Data were altered. Please try again.'), 'error');
    unsetMessages();
    redirectTo('user_add1.php');
}

$form = getUserLoginDataForm(false, true)->addElements(getUserPersonalDataForm()->getElements());
$form->setDefault('gender', 'U');

if (isset($_POST['uaction']) && 'user_add3_nxt' == $_POST['uaction'] && !isset(Application::getInstance()->getSession()['step_two_data'])) {
    addCustomer($form);
} else {
    unset(Application::getInstance()->getSession()['step_two_data']);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'reseller/user_add3.phtml',
    'page_message' => 'layout',
    'ip_entry'     => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', toHtml(tr('Reseller / Customers / Add Customer - Next Step')));
View::generateNavigation($tpl);
generatePage($tpl, $form);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
