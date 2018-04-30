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
use iMSCP\Functions\Counting;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Get first step data
 *
 * @return bool TRUE if parameters from first step are found, FALSE otherwise
 */
function getFirstStepData()
{
    global $dmnName, $hpId;

    foreach (['dmn_name', 'dmn_expire', 'dmn_url_forward', 'dmn_type_forward', 'dmn_host_forward', 'dmn_tpl'] as $data) {
        if (!array_key_exists($data, Application::getInstance()->getSession())) {
            return false;
        }
    }

    $dmnName = Application::getInstance()->getSession()['dmn_name'];
    $hpId = Application::getInstance()->getSession()['dmn_tpl'];
    return true;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generatePage($tpl)
{
    global $hpName, $php, $cgi, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskspace, $backup, $dns, $extMail,
           $webFolderProtection;

    $tpl->assign([
        'VL_TEMPLATE_NAME'  => toHtml($hpName, 'htmlAttr'),
        'MAX_SUBDMN_CNT'    => toHtml($sub, 'htmlAttr'),
        'MAX_DMN_ALIAS_CNT' => toHtml($als, 'htmlAttr'),
        'MAX_MAIL_CNT'      => toHtml($mail, 'htmlAttr'),
        'MAIL_QUOTA'        => toHtml($mailQuota, 'htmlAttr'),
        'MAX_FTP_CNT'       => toHtml($ftp, 'htmlAttr'),
        'MAX_SQL_CNT'       => toHtml($sqld, 'htmlAttr'),
        'VL_MAX_SQL_USERS'  => toHtml($sqlu, 'htmlAttr'),
        'VL_MAX_TRAFFIC'    => toHtml($traffic, 'htmlAttr'),
        'VL_MAX_DISK_USAGE' => toHtml($diskspace, 'htmlAttr'),
        'VL_EXTMAILY'       => $extMail == '_yes_' ? ' checked' : '',
        'VL_EXTMAILN'       => $extMail == '_yes_' ? '' : ' checked',
        'VL_PHPY'           => $php == '_yes_' ? ' checked' : '',
        'VL_PHPN'           => $php == '_yes_' ? '' : ' checked',
        'VL_CGIY'           => $cgi == '_yes_' ? ' checked' : '',
        'VL_CGIN'           => $cgi == '_yes_' ? '' : ' checked'
    ]);

    if (!Counting::resellerHasFeature('subdomains')) {
        $tpl->assign('SUBDOMAIN_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('domain_aliases')) {
        $tpl->assign('ALIAS_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('custom_dns_records')) {
        $tpl->assign('CUSTOM_DNS_RECORDS_FEATURE', '');
    } else {
        $tpl->assign([
            'VL_DNSY' => $dns == '_yes_' ? ' checked' : '',
            'VL_DNSN' => $dns == '_yes_' ? '' : ' checked'
        ]);
    }

    if (!Counting::resellerHasFeature('mail')) {
        $tpl->assign('MAIL_FEATURE', '');
        $tpl->assign('EXT_MAIL_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('ftp')) {
        $tpl->assign('FTP_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('sql')) {
        $tpl->assign('SQL_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('backup')) {
        $tpl->assign('BACKUP_FEATURE', '');
    } else {
        $tpl->assign([
            'VL_BACKUPD' => in_array('_dmn_', $backup) ? ' checked' : '',
            'VL_BACKUPS' => in_array('_sql_', $backup) ? ' checked' : '',
            'VL_BACKUPM' => in_array('_mail_', $backup) ? ' checked' : ''
        ]);
    }

    $tpl->assign([
        'VL_WEB_FOLDER_PROTECTION_YES' => $webFolderProtection == '_yes_' ? ' checked' : '',
        'VL_WEB_FOLDER_PROTECTION_NO'  => $webFolderProtection == '_yes_' ? '' : ' checked'
    ]);

    $phpini = PHPini::getInstance();

    if (!$phpini->resellerHasPermission('phpiniSystem')) {
        $tpl->assign('PHP_EDITOR_BLOCK', '');
        return;
    }

    $tpl->assign([
        'PHP_EDITOR_YES'         => $phpini->clientHasPermission('phpiniSystem') ? ' checked' : '',
        'PHP_EDITOR_NO'          => $phpini->clientHasPermission('phpiniSystem') ? '' : ' checked',
        'TR_PHP_EDITOR'          => toHtml(tr('PHP Editor')),
        'TR_PHP_EDITOR_SETTINGS' => toHtml(tr('PHP Settings')),
        'TR_SETTINGS'            => toHtml(tr('PHP Settings')),
        'TR_DIRECTIVES_VALUES'   => toHtml(tr('PHP Configuration options')),
        'TR_FIELDS_OK'           => toHtml(tr('All fields are valid.')),
        'TR_MIB'                 => toHtml(tr('MiB')),
        'TR_SEC'                 => toHtml(tr('Sec.'))
    ]);

    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $translations = $e->getParam('translations');
        $translations['core']['close'] = tr('Close');
        $translations['core']['fields_ok'] = tr('All fields are valid.');
        $translations['core']['out_of_range_value_error'] = tr('Value for the PHP %%s directive must be in range %%d to %%d.');
        $translations['core']['lower_value_expected_error'] = tr('%%s cannot be greater than %%s.');
        $translations['core']['error_field_stack'] = Application::getInstance()->getRegistry()->has('errFieldsStack')
            ? Application::getInstance()->getRegistry()->get('errFieldsStack') : [];
    });

    $permissionsBlock = false;

    if (!$phpini->resellerHasPermission('phpiniConfigLevel')) {
        $tpl->assign('PHPINI_PERM_CONFIG_LEVEL_BLOCK', '');
    } else {
        if ($phpini->getResellerPermission('phpiniConfigLevel') == 'per_site') {
            $tpl->assign([
                'TR_PHPINI_PERM_CONFIG_LEVEL'         => toHtml(tr('PHP configuration level')),
                'TR_PHPINI_PERM_CONFIG_LEVEL_HELP'    => toHtml(tr('Per site: Different PHP configuration for each customer domain, including subdomains<br>Per domain: Identical PHP configuration for each customer domain, including subdomains<br>Per user: Identical PHP configuration for all customer domains, including subdomains'), 'htmlAttr'),
                'TR_PER_DOMAIN'                       => toHtml(tr('Per domain')),
                'TR_PER_SITE'                         => toHtml(tr('Per site')),
                'TR_PER_USER'                         => toHtml(tr('Per user')),
                'PHPINI_PERM_CONFIG_LEVEL_PER_DOMAIN' => $phpini->getClientPermission('phpiniConfigLevel') == 'per_domain' ? ' checked' : '',
                'PHPINI_PERM_CONFIG_LEVEL_PER_SITE'   => $phpini->getClientPermission('phpiniConfigLevel') == 'per_site' ? ' checked' : '',
                'PHPINI_PERM_CONFIG_LEVEL_PER_USER'   => $phpini->getClientPermission('phpiniConfigLevel') == 'per_user' ? ' checked' : '',
            ]);
        } else {
            $tpl->assign([
                'TR_PHPINI_PERM_CONFIG_LEVEL'             => toHtml(tr('PHP configuration level')),
                'PHPINI_PERM_CONFIG_LEVEL_PER_SITE_BLOCK' => '',
                'TR_PHPINI_PERM_CONFIG_LEVEL_HELP'        => toHtml(tr('Per domain: Identical PHP configuration for each customer domain, including subdomains<br>Per user: Identical PHP configuration for all customer domains, including subdomains'), 'htmlAttr'),
                'TR_PER_DOMAIN'                           => toHtml(tr('Per domain')),
                'TR_PER_USER'                             => toHtml(tr('Per user')),
                'PHPINI_PERM_CONFIG_LEVEL_PER_DOMAIN'     => $phpini->getClientPermission('phpiniConfigLevel') == 'per_domain' ? ' checked' : '',
                'PHPINI_PERM_CONFIG_LEVEL_PER_SITE'       => $phpini->getClientPermission('phpiniConfigLevel') == 'per_site' ? ' checked' : '',
                'PHPINI_PERM_CONFIG_LEVEL_PER_USER'       => $phpini->getClientPermission('phpiniConfigLevel') == 'per_user' ? ' checked' : '',
            ]);
        }

        $permissionsBlock = true;
    }

    if (!$phpini->resellerHasPermission('phpiniAllowUrlFopen')) {
        $tpl->assign('PHP_EDITOR_ALLOW_URL_FOPEN_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_CAN_EDIT_ALLOW_URL_FOPEN' => tr('Can edit the PHP %s configuration option', '<strong>allow_url_fopen</strong>'),
            'ALLOW_URL_FOPEN_YES'         => $phpini->clientHasPermission('phpiniAllowUrlFopen') ? ' checked' : '',
            'ALLOW_URL_FOPEN_NO'          => $phpini->clientHasPermission('phpiniAllowUrlFopen') ? '' : ' checked'
        ]);
        $permissionsBlock = true;
    }

    if (!$phpini->resellerHasPermission('phpiniDisplayErrors')) {
        $tpl->assign('PHP_EDITOR_DISPLAY_ERRORS_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_CAN_EDIT_DISPLAY_ERRORS' => tr('Can edit the PHP %s configuration option', '<strong>display_errors</strong>'),
            'DISPLAY_ERRORS_YES'         => $phpini->clientHasPermission('phpiniDisplayErrors') ? ' checked' : '',
            'DISPLAY_ERRORS_NO'          => $phpini->clientHasPermission('phpiniDisplayErrors') ? '' : ' checked'
        ]);
        $permissionsBlock = true;
    }

    if (strpos(Application::getInstance()->getConfig()['iMSCP::Servers::Httpd'], '::Apache2::') !== false) {
        $apacheConfig = loadServiceConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/apache/apache.data');
        $isApacheItk = $apacheConfig['HTTPD_MPM'] == 'itk';
    } else {
        $isApacheItk = false;
    }

    if ($isApacheItk) {
        $tpl->assign([
            'PHP_EDITOR_DISABLE_FUNCTIONS_BLOCK' => '',
            'PHP_EDITOR_MAIL_FUNCTION_BLOCK'     => ''
        ]);
    } else {
        if ($phpini->resellerHasPermission('phpiniDisableFunctions')) {
            $tpl->assign([
                'TR_CAN_EDIT_DISABLE_FUNCTIONS' => tr('Can edit the PHP %s configuration option', '<strong>disable_functions</strong>'),
                'DISABLE_FUNCTIONS_YES'         => $phpini->getClientPermission('phpiniDisableFunctions') == 'yes' ? ' checked' : '',
                'DISABLE_FUNCTIONS_NO'          => $phpini->getClientPermission('phpiniDisableFunctions') == 'no' ? ' checked' : '',
                'DISABLE_FUNCTIONS_EXEC'        => $phpini->getClientPermission('phpiniDisableFunctions') == 'exec' ? ' checked' : '',
                'TR_ONLY_EXEC'                  => toHtml(tr('Only exec'))
            ]);
        } else {
            $tpl->assign('PHP_EDITOR_DISABLE_FUNCTIONS_BLOCK', '');
        }

        if ($phpini->resellerHasPermission('phpiniMailFunction')) {
            $tpl->assign([
                'TR_CAN_USE_MAIL_FUNCTION' => tr('Can use the PHP %s function', '<strong>mail</strong>'),
                'MAIL_FUNCTION_YES'        => $phpini->clientHasPermission('phpiniMailFunction') ? ' checked' : '',
                'MAIL_FUNCTION_NO'         => $phpini->clientHasPermission('phpiniMailFunction') ? '' : ' checked'
            ]);
        } else {
            $tpl->assign('PHP_EDITOR_MAIL_FUNCTION_BLOCK', '');
        }

        $permissionsBlock = true;
    }

    if (!$permissionsBlock) {
        $tpl->assign('PHP_EDITOR_PERMISSIONS_BLOCK', '');
    } else {
        $tpl->assign([
            'TR_PERMISSIONS' => toHtml(tr('Permissions')),
            'TR_ONLY_EXEC'   => toHtml(tr("Only exec"))
        ]);
    }

    $tpl->assign([
        'TR_POST_MAX_SIZE'          => tr('PHP %s configuration option', '<strong>post_max_size</strong>'),
        'POST_MAX_SIZE'             => toHtml($phpini->getIniOption('phpiniPostMaxSize'), 'htmlAttr'),
        'TR_UPLOAD_MAX_FILEZISE'    => tr('PHP %s configuration option', '<strong>upload_max_filesize</strong>'),
        'UPLOAD_MAX_FILESIZE'       => toHtml($phpini->getIniOption('phpiniUploadMaxFileSize'), 'htmlAttr'),
        'TR_MAX_EXECUTION_TIME'     => tr('PHP %s configuration option', '<strong>max_execution_time</strong>'),
        'MAX_EXECUTION_TIME'        => toHtml($phpini->getIniOption('phpiniMaxExecutionTime'), 'htmlAttr'),
        'TR_MAX_INPUT_TIME'         => tr('PHP %s configuration option', '<strong>max_input_time</strong>'),
        'MAX_INPUT_TIME'            => toHtml($phpini->getIniOption('phpiniMaxInputTime'), 'htmlAttr'),
        'TR_MEMORY_LIMIT'           => tr('PHP %s configuration option', '<strong>memory_limit</strong>'),
        'MEMORY_LIMIT'              => toHtml($phpini->getIniOption('phpiniMemoryLimit'), 'htmlAttr'),
        'POST_MAX_SIZE_LIMIT'       => toHtml($phpini->getResellerPermission('phpiniPostMaxSize'), 'htmlAttr'),
        'UPLOAD_MAX_FILESIZE_LIMIT' => toHtml($phpini->getResellerPermission('phpiniUploadMaxFileSize'), 'htmlAttr'),
        'MAX_EXECUTION_TIME_LIMIT'  => toHtml($phpini->getResellerPermission('phpiniMaxExecutionTime'), 'htmlAttr'),
        'MAX_INPUT_TIME_LIMIT'      => toHtml($phpini->getResellerPermission('phpiniMaxInputTime'), 'htmlAttr'),
        'MEMORY_LIMIT_LIMIT'        => toHtml($phpini->getResellerPermission('phpiniMemoryLimit'), 'htmlAttr')
    ]);
}

/**
 * Get hosting plan data
 *
 * @return void
 */
function getHostingPlanData()
{
    global $hpId, $hpName, $php, $cgi, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskspace, $backup, $dns, $extMail,
           $webFolderProtection;

    if ($hpId == 0) {
        return;
    }

    $stmt = execQuery('SELECT name, props FROM hosting_plans WHERE reseller_id = ? AND id = ?', [
        Application::getInstance()->getAuthService()->getIdentity()->getUserId(), $hpId
    ]);
    $stmt->rowCount() or View::showBadRequestErrorPage();

    $row = $stmt->fetch();

    list(
        $php, $cgi, $sub, $als, $mail, $ftp, $sqld, $sqlu, $traffic, $diskspace, $backup, $dns, $phpEditor, $phpiniConfigLevel,
        $phpiniAllowUrlFopen, $phpiniDisplayErrors, $phpiniDisableFunctions, $phpiniMailFunction, $phpiniPostMaxSize, $phpiniUploadMaxFileSize,
        $phpiniMaxExecutionTime, $phpiniMaxInputTime, $phpiniMemoryLimit, $extMail, $webFolderProtection, $mailQuota
        ) = explode(';', $row['props']);

    $backup = explode('|', $backup);
    $mailQuota = ($mailQuota != '0') ? $mailQuota / 1048576 : '0';
    $hpName = $row['name'];

    $phpini = PHPini::getInstance();
    $phpini->setClientPermission('phpiniSystem', $phpEditor);
    $phpini->setClientPermission('phpiniConfigLevel', $phpiniConfigLevel);
    $phpini->setClientPermission('phpiniAllowUrlFopen', $phpiniAllowUrlFopen);
    $phpini->setClientPermission('phpiniDisplayErrors', $phpiniDisplayErrors);
    $phpini->setClientPermission('phpiniDisableFunctions', $phpiniDisableFunctions);
    $phpini->setClientPermission('phpiniMailFunction', $phpiniMailFunction);

    $phpini->setIniOption('phpiniMemoryLimit', $phpiniMemoryLimit); // Must be set before phpiniPostMaxSize
    $phpini->setIniOption('phpiniPostMaxSize', $phpiniPostMaxSize); // Must be set before phpiniUploadMaxFileSize
    $phpini->setIniOption('phpiniUploadMaxFileSize', $phpiniUploadMaxFileSize);
    $phpini->setIniOption('phpiniMaxExecutionTime', $phpiniMaxExecutionTime);
    $phpini->setIniOption('phpiniMaxInputTime', $phpiniMaxInputTime);
}

/**
 * Check input data
 *
 * @return bool TRUE if all data are valid, FALSE otherwise
 */
function checkInputData()
{
    global $php, $cgi, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskspace, $backup, $dns, $extMail, $webFolderProtection;

    $sub = isset($_POST['nreseller_max_subdomain_cnt']) ? cleanInput($_POST['nreseller_max_subdomain_cnt']) : $sub;
    $als = isset($_POST['nreseller_max_alias_cnt']) ? cleanInput($_POST['nreseller_max_alias_cnt']) : $als;
    $mail = isset($_POST['nreseller_max_mail_cnt']) ? cleanInput($_POST['nreseller_max_mail_cnt']) : $mail;
    $mailQuota = isset($_POST['nreseller_mail_quota']) ? cleanInput($_POST['nreseller_mail_quota']) : $mailQuota;
    $ftp = isset($_POST['nreseller_max_ftp_cnt']) ? cleanInput($_POST['nreseller_max_ftp_cnt']) : $ftp;
    $sqld = isset($_POST['nreseller_max_sql_db_cnt']) ? cleanInput($_POST['nreseller_max_sql_db_cnt']) : $sqld;
    $sqlu = isset($_POST['nreseller_max_sql_user_cnt']) ? cleanInput($_POST['nreseller_max_sql_user_cnt']) : $sqlu;
    $traffic = isset($_POST['nreseller_max_traffic']) ? cleanInput($_POST['nreseller_max_traffic']) : $traffic;
    $diskspace = isset($_POST['nreseller_max_disk']) ? cleanInput($_POST['nreseller_max_disk']) : $diskspace;
    $php = isset($_POST['php']) ? cleanInput($_POST['php']) : $php;
    $cgi = isset($_POST['cgi']) ? cleanInput($_POST['cgi']) : $cgi;
    $dns = isset($_POST['dns']) ? cleanInput($_POST['dns']) : $dns;
    $backup = isset($_POST['backup']) && is_array($_POST['backup']) ? $_POST['backup'] : $backup;
    $extMail = isset($_POST['external_mail']) ? cleanInput($_POST['external_mail']) : $extMail;
    $webFolderProtection = isset($_POST['web_folder_protection']) ? cleanInput($_POST['web_folder_protection']) : $webFolderProtection;

    $php = $php == '_yes_' ? '_yes_' : '_no_';
    $cgi = $cgi == '_yes_' ? '_yes_' : '_no_';
    $dns = Counting::resellerHasFeature('custom_dns_records') && $dns == '_yes_' ? '_yes_' : '_no_';
    $backup = Counting::resellerHasFeature('backup') ? array_intersect($backup, ['_dmn_', '_sql_', '_mail_']) : [];
    $extMail = $extMail == '_yes_' ? '_yes_' : '_no_';
    $webFolderProtection = $webFolderProtection == '_yes_' ? '_yes_' : '_no_';
    $errFieldsStack = [];

    // Subdomains limit
    if (!Counting::resellerHasFeature('subdomains')) {
        $sub = '-1';
    } elseif (!validateLimit($sub, -1)) {
        View::setPageMessage(tr('Incorrect subdomain limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_subdomain_cnt';
    }

    if (!Counting::resellerHasFeature('domain_aliases')) {
        $als = '-1';
    } elseif (!validateLimit($als, -1)) {
        View::setPageMessage(tr('Incorrect alias limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_alias_cnt';
    }

    // Mail accounts limit
    if (!Counting::resellerHasFeature('mail')) {
        $mail = '-1';
    } elseif (!validateLimit($mail, -1)) {
        View::setPageMessage(tr('Incorrect mail accounts limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_mail_cnt';
    }

    // Mail quota limit
    if (!validateLimit($mailQuota, NULL)) {
        View::setPageMessage(tr('Incorrect mail quota.'), 'error');
        $errFieldsStack[] = 'nreseller_mail_quota';
    } elseif ($diskspace != '0' && $mailQuota > $diskspace) {
        View::setPageMessage(tr('Mail quota cannot be bigger than disk space limit.'), 'error');
        $errFieldsStack[] = 'nreseller_mail_quota';
    } elseif ($diskspace != '0' && $mailQuota == '0') {
        View::setPageMessage(tr('Mail quota cannot be unlimited. Max value is %d MiB.', $diskspace), 'error');
        $errFieldsStack[] = 'nreseller_mail_quota';
    }

    // Ftp accounts limit
    if (!Counting::resellerHasFeature('ftp')) {
        $ftp = '-1';
    } elseif (!validateLimit($ftp, -1)) {
        View::setPageMessage(tr('Incorrect FTP accounts limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_ftp_cnt';
    }

    // SQL database limit
    if (!Counting::resellerHasFeature('sql_db')) {
        $sqld = -1;
    } elseif (!validateLimit($sqld, -1)) {
        View::setPageMessage(tr('Incorrect SQL databases limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_sql_db_cnt';
    } elseif ($sqld != -1 && $sqlu == -1) {
        View::setPageMessage(tr('SQL users limit is disabled.'), 'error');
        $errFieldsStack[] = 'nreseller_max_sql_db_cnt';
        $errFieldsStack[] = 'nreseller_max_sql_user_cnt';
    }

    // SQL users limit
    if (!Counting::resellerHasFeature('sql_user')) {
        $sqlu = -1;
    } elseif (!validateLimit($sqlu, -1)) {
        View::setPageMessage(tr('Incorrect SQL users limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_sql_user_cnt';
    } elseif ($sqlu != -1 && $sqld == -1) {
        View::setPageMessage(tr("SQL databases limit is disabled."), 'error');
        $errFieldsStack[] = 'nreseller_max_sql_user_cnt';
        $errFieldsStack[] = 'nreseller_max_sql_db_cnt';
    }

    // Monthly traffic limit
    if (!validateLimit($traffic, NULL)) {
        View::setPageMessage(tr('Incorrect monthly traffic limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_traffic';
    }

    // Disk space limit
    if (!validateLimit($diskspace, NULL)) {
        View::setPageMessage(tr('Incorrect disk space limit.'), 'error');
        $errFieldsStack[] = 'nreseller_max_disk';
    }

    // PHP Editor feature
    $phpini = PHPini::getInstance();

    if (isset($_POST['php_ini_system']) && $php != '_no_' && $phpini->resellerHasPermission('phpiniSystem')) {
        $phpini->setClientPermission('phpiniSystem', cleanInput($_POST['php_ini_system']));

        if ($phpini->clientHasPermission('phpiniSystem')) {
            if (isset($_POST['phpini_perm_config_level'])) {
                $phpini->setClientPermission('phpiniConfigLevel', cleanInput($_POST['phpini_perm_config_level']));
            }

            if (isset($_POST['phpini_perm_allow_url_fopen'])) {
                $phpini->setClientPermission('phpiniAllowUrlFopen', cleanInput($_POST['phpini_perm_allow_url_fopen']));
            }

            if (isset($_POST['phpini_perm_display_errors'])) {
                $phpini->setClientPermission('phpiniDisplayErrors', cleanInput($_POST['phpini_perm_display_errors']));
            }

            if (isset($_POST['phpini_perm_disable_functions'])) {
                $phpini->setClientPermission('phpiniDisableFunctions', cleanInput($_POST['phpini_perm_disable_functions']));
            }

            if (isset($_POST['phpini_perm_mail_function'])) {
                $phpini->setClientPermission('phpiniMailFunction', cleanInput($_POST['phpini_perm_mail_function']));
            }

            if (isset($_POST['memory_limit'])) { // Must be set before phpiniPostMaxSize
                $phpini->setIniOption('phpiniMemoryLimit', cleanInput($_POST['memory_limit']));
            }

            if (isset($_POST['post_max_size'])) { // Must be set before phpiniUploadMaxFileSize
                $phpini->setIniOption('phpiniPostMaxSize', cleanInput($_POST['post_max_size']));
            }

            if (isset($_POST['upload_max_filesize'])) {
                $phpini->setIniOption('phpiniUploadMaxFileSize', cleanInput($_POST['upload_max_filesize']));
            }

            if (isset($_POST['max_execution_time'])) {
                $phpini->setIniOption('phpiniMaxExecutionTime', cleanInput($_POST['max_execution_time']));
            }

            if (isset($_POST['max_input_time'])) {
                $phpini->setIniOption('phpiniMaxInputTime', cleanInput($_POST['max_input_time']));
            }
        }
    }

    if (!empty($errFieldsStack)) {
        Application::getInstance()->getRegistry()->set('errFieldsStack', $errFieldsStack);
        return false;
    }

    return true;
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

// Initialize global variables
global $dmnName, $hpId;
$hpName = 'Custom';
$sub = $als = $mail = $mailQuota = $ftp = $sqld = $sqlu = $traffic = $diskspace = '0';
$php = $cgi = $dns = $extMail = '_no_';
$webFolderProtection = '_yes_';
$backup = [];

if (!getFirstStepData()) {
    View::setPageMessage(tr('Domain data were altered. Please try again.'), 'error');
    unsetMessages();
    redirectTo('user_add1.php');
}

$identity = Application::getInstance()->getAuthService()->getIdentity();

$phpini = PHPini::getInstance();
$phpini->loadResellerPermissions($identity->getUserId()); // Load reseller PHP permissions
$phpini->loadClientPermissions(); // Load client default PHP permissions
$phpini->loadIniOptions(); // Load domain default PHP configuration options

if (isset($_POST['uaction']) && 'user_add2_nxt' == $_POST['uaction'] && !isset(Application::getInstance()->getSession()['step_one'])) {
    if (checkInputData()) {
        Application::getInstance()->getSession()['step_two_data'] = "$dmnName;0";
        Application::getInstance()->getSession()['ch_hpprops'] =
            "$php;$cgi;$sub;$als;$mail;$ftp;$sqld;$sqlu;$traffic;$diskspace;" . implode('|', $backup) . ";$dns;" .
            $phpini->getClientPermission('phpiniSystem') . ';' .
            $phpini->getClientPermission('phpiniConfigLevel') . ';' .
            $phpini->getClientPermission('phpiniAllowUrlFopen') . ';' .
            $phpini->getClientPermission('phpiniDisplayErrors') . ';' .
            $phpini->getClientPermission('phpiniDisableFunctions') . ';' .
            $phpini->getClientPermission('phpiniMailFunction') . ';' .
            $phpini->getIniOption('phpiniPostMaxSize') . ';' .
            $phpini->getIniOption('phpiniUploadMaxFileSize') . ';' .
            $phpini->getIniOption('phpiniMaxExecutionTime') . ';' .
            $phpini->getIniOption('phpiniMaxInputTime') . ';' .
            $phpini->getIniOption('phpiniMemoryLimit') . ';' .
            $extMail . ';' . $webFolderProtection . ';' . $mailQuota * 1048576;

        if (validateHostingPlanLimits(Application::getInstance()->getSession()['ch_hpprops'], $identity->getUserId())) {
            redirectTo('user_add3.php');
        }
    }
} else {
    unset(Application::getInstance()->getSession()['step_one']);
    getHostingPlanData();
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                                  => 'shared/layouts/ui.tpl',
    'page'                                    => 'reseller/user_add2.tpl',
    'page_message'                            => 'layout',
    'subdomain_feature'                       => 'page',
    'alias_feature'                           => 'page',
    'mail_feature'                            => 'page',
    'custom_dns_records_feature'              => 'page',
    'ext_mail_feature'                        => 'page',
    'ftp_feature'                             => 'page',
    'sql_feature'                             => 'page',
    'backup_feature'                          => 'page',
    'php_editor_block'                        => 'page',
    'php_editor_permissions_block'            => 'php_editor_block',
    'phpini_perm_config_level_block'          => 'php_editor_permissions_block',
    'phpini_perm_config_level_per_site_block' => 'phpini_perm_config_level_block',
    'php_editor_allow_url_fopen_block'        => 'php_editor_permissions_block',
    'php_editor_display_errors_block'         => 'php_editor_permissions_block',
    'php_editor_disable_functions_block'      => 'php_editor_permissions_block',
    "php_mail_function_block"                 => 'php_editor_permissions_block',
    'php_editor_default_values_block'         => 'php_editor_block'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                 => toHtml(tr('Reseller / Customers / Add Customer - Next Step')),
    'TR_ADD_USER'                   => toHtml(tr('Add user')),
    'TR_HOSTING_PLAN'               => toHtml(tr('Hosting plan')),
    'TR_NAME'                       => toHtml(tr('Name')),
    'TR_MAX_DOMAIN'                 => toHtml(tr('Domains limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_SUBDOMAIN'              => toHtml(tr('Subdomains limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_DOMAIN_ALIAS'           => toHtml(tr('Domain aliases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_MAIL_COUNT'             => toHtml(tr('Mail accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAIL_QUOTA'                 => toHtml(tr('Mail quota [MiB]')) . '<br><i>(0 ∞)</i>',
    'TR_MAX_FTP'                    => toHtml(tr('FTP accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_SQL_DB'                 => toHtml(tr('SQL databases limit')) . '<br/><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_SQL_USERS'              => toHtml(tr('SQL users limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_TRAFFIC'                => toHtml(tr('Monthly traffic limit [MiB]')) . '<br><i>(0 ∞)</i>',
    'TR_MAX_DISK_USAGE'             => toHtml(tr('Disk space limit [MiB]')) . '<br><i>(0 ∞)</i>',
    'TR_EXTMAIL'                    => toHtml(tr('External mail server')),
    'TR_PHP'                        => toHtml(tr('PHP')),
    'TR_CGI'                        => toHtml(tr('CGI')),
    'TR_BACKUP'                     => toHtml(tr('Backup')),
    'TR_BACKUP_DOMAIN'              => toHtml(tr('Domain')),
    'TR_BACKUP_SQL'                 => toHtml(tr('SQL')),
    'TR_BACKUP_MAIL'                => toHtml(tr('Mail')),
    'TR_DNS'                        => toHtml(tr('Custom DNS records')),
    'TR_YES'                        => toHtml(tr('Yes'), 'htmlAttr'),
    'TR_NO'                         => toHtml(tr('No'), 'htmlAttr'),
    'TR_NEXT_STEP'                  => toHtml(tr('Next step')),
    'TR_FEATURES'                   => toHtml(tr('Features')),
    'TR_LIMITS'                     => toHtml(tr('Limits')),
    'TR_WEB_FOLDER_PROTECTION'      => toHtml(tr('Web folder protection')),
    'TR_WEB_FOLDER_PROTECTION_HELP' => toHtml(tr('If set to `yes`, Web folders will be protected against deletion.')),
    'TR_SOFTWARE_SUPP'              => toHtml(tr('Software installer'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
