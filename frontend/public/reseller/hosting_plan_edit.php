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
 * Load hosting plan
 *
 * @param int $id Hosting plan unique identifier
 * @return bool TRUE on success, FALSE on failure
 */
function loadHostingPlan($id)
{
    global $id, $name, $description, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskSpace, $php, $cgi, $backup, $dns, $extMail,
           $webFolderProtection, $status;

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    $stmt = execQuery('SELECT * FROM hosting_plans WHERE id = ? AND reseller_id = ?', [$id, $identity->getUserId()]);
    if (!$stmt->rowCount()) {
        return false;
    }

    $data = $stmt->fetch();
    $name = $data['name'];
    $description = $data['description'];
    $status = $data['status'];

    list(
        $php, $cgi, $sub, $als, $mail, $ftp, $sqld, $sqlu, $traffic, $diskSpace, $backup, $dns, $phpEditor, $phpConfigLevel, $phpAllowUrlFopen,
        $phpDisplayErrors, $phpDisableFunctions, $phpiniMailFunction, $phpPostMaxSizeValue, $phpUploadMaxFilesizeValue, $phpMaxExecutionTimeValue,
        $phpMaxInputTimeValue, $phpMemoryLimitValue, $extMail, $webFolderProtection, $mailQuota
        ) = explode(';', $data['props']);

    $backup = explode('|', $backup);
    $mailQuota = $mailQuota / 1048576;

    $phpini = PHPini::getInstance();
    $phpini->loadResellerPermissions($identity->getUserId());
    $phpini->loadClientPermissions();
    $phpini->loadIniOptions();

    $phpini->setClientPermission('phpiniSystem', $phpEditor);
    $phpini->setClientPermission('phpiniConfigLevel', $phpConfigLevel);
    $phpini->setClientPermission('phpiniAllowUrlFopen', $phpAllowUrlFopen);
    $phpini->setClientPermission('phpiniDisplayErrors', $phpDisplayErrors);
    $phpini->setClientPermission('phpiniDisableFunctions', $phpDisableFunctions);
    $phpini->setClientPermission('phpiniMailFunction', $phpiniMailFunction);
    // Must be set before phpiniPostMaxSize
    $phpini->setIniOption('phpiniMemoryLimit', $phpMemoryLimitValue);
    // Must be set before phpiniUploadMaxFileSize
    $phpini->setIniOption('phpiniPostMaxSize', $phpPostMaxSizeValue);
    $phpini->setIniOption('phpiniUploadMaxFileSize', $phpUploadMaxFilesizeValue);
    $phpini->setIniOption('phpiniMaxExecutionTime', $phpMaxExecutionTimeValue);
    $phpini->setIniOption('phpiniMaxInputTime', $phpMaxInputTimeValue);
    $phpini->setIniOption('phpiniMemoryLimit', $phpMemoryLimitValue);
    return true;
}

/**
 * Generate PHP editor block
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePhpBlock(TemplateEngine $tpl)
{
    $phpini = PHPini::getInstance();

    if (!$phpini->resellerHasPermission('phpiniSystem')) {
        $tpl->assign('PHP_EDITOR_BLOCK', '');
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
        $translations['core']['close'] = toHtml(tr('Close'));
        $translations['core']['fields_ok'] = toHtml(tr('All fields are valid.'));
        $translations['core']['out_of_range_value_error'] = toHtml(tr('Value for the PHP %%s directive must be in range %%d to %%d.'));
        $translations['core']['lower_value_expected_error'] = toHtml(tr('%%s cannot be greater than %%s.'));
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
                'PHPINI_PERM_CONFIG_LEVEL_PER_SITE_BLOCK' => '',
                'TR_PHPINI_PERM_CONFIG_LEVEL'             => toHtml(tr('PHP configuration level')),
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
                'TR_ONLY_EXEC'                  => tr('Only exec'),
                'DISABLE_FUNCTIONS_EXEC'        => $phpini->getClientPermission('phpiniDisableFunctions') == 'exec' ? ' checked' : '',
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
            'TR_PERMISSIONS' => toHtml(tr('PHP Permissions')),
            'TR_ONLY_EXEC'   => toHtml(tr('Only exec'))
        ]);
    }

    $tpl->assign([
        'TR_POST_MAX_SIZE'          => tr('PHP %s configuration option', '<b>post_max_size</b>'),
        'POST_MAX_SIZE'             => toHtml($phpini->getIniOption('phpiniPostMaxSize'), 'htmlAttr'),
        'TR_UPLOAD_MAX_FILEZISE'    => tr('PHP %s configuration option', '<b>upload_max_filesize</b>'),
        'UPLOAD_MAX_FILESIZE'       => toHtml($phpini->getIniOption('phpiniUploadMaxFileSize'), 'htmlAttr'),
        'TR_MAX_EXECUTION_TIME'     => tr('PHP %s configuration option', '<b>max_execution_time</b>'),
        'MAX_EXECUTION_TIME'        => toHtml($phpini->getIniOption('phpiniMaxExecutionTime'), 'htmlAttr'),
        'TR_MAX_INPUT_TIME'         => tr('PHP %s configuration option', '<b>max_input_time</b>'),
        'MAX_INPUT_TIME'            => toHtml($phpini->getIniOption('phpiniMaxInputTime'), 'htmlAttr'),
        'TR_MEMORY_LIMIT'           => tr('PHP %s configuration option', '<b>memory_limit</b>'),
        'MEMORY_LIMIT'              => toHtml($phpini->getIniOption('phpiniMemoryLimit'), 'htmlAttr'),
        'POST_MAX_SIZE_LIMIT'       => toHtml($phpini->getResellerPermission('phpiniPostMaxSize'), 'htmlAttr'),
        'UPLOAD_MAX_FILESIZE_LIMIT' => toHtml($phpini->getResellerPermission('phpiniUploadMaxFileSize'), 'htmlAttr'),
        'MAX_EXECUTION_TIME_LIMIT'  => toHtml($phpini->getResellerPermission('phpiniMaxExecutionTime'), 'htmlAttr'),
        'MAX_INPUT_TIME_LIMIT'      => toHtml($phpini->getResellerPermission('phpiniMaxInputTime'), 'htmlAttr'),
        'MEMORY_LIMIT_LIMIT'        => toHtml($phpini->getResellerPermission('phpiniMemoryLimit'), 'htmlAttr')
    ]);
}

/**
 * Generate page
 *
 * @param $tpl TemplateEngine
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    global $id, $name, $description, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskSpace, $php, $cgi, $backup, $dns, $extMail,
           $webFolderProtection, $status;

    $tpl->assign([
        'ID'                      => toHtml($id, 'htmlAttr'),
        'NAME'                    => toHtml($name, 'htmlAttr'),
        'DESCRIPTION'             => toHtml($description),
        'MAX_SUB'                 => toHtml($sub, 'htmlAttr'),
        'MAX_ALS'                 => toHtml($als, 'htmlAttr'),
        'MAX_MAIL'                => toHtml($mail, 'htmlAttr'),
        'MAIL_QUOTA'              => toHtml($mailQuota, 'htmlAttr'),
        'MAX_FTP'                 => toHtml($ftp, 'htmlAttr'),
        'MAX_SQLD'                => toHtml($sqld, 'htmlAttr'),
        'MAX_SQLU'                => toHtml($sqlu, 'htmlAttr'),
        'MONTHLY_TRAFFIC'         => toHtml($traffic, 'htmlAttr'),
        'MAX_DISKSPACE'           => toHtml($diskSpace, 'htmlAttr'),
        'PHP_YES'                 => $php == '_yes_' ? ' checked' : '',
        'PHP_NO'                  => $php == '_yes_' ? '' : ' checked',
        'CGI_YES'                 => $cgi == '_yes_' ? ' checked' : '',
        'CGI_NO'                  => $cgi == '_yes_' ? '' : ' checked',
        'DNS_YES'                 => $dns == '_yes_' ? ' checked' : '',
        'DNS_NO'                  => $dns == '_yes_' ? '' : ' checked',
        'EXTMAIL_YES'             => $extMail == '_yes_' ? ' checked' : '',
        'EXTMAIL_NO'              => $extMail == '_yes_' ? '' : ' checked',
        'BACKUPD'                 => in_array('_dmn_', $backup) ? ' checked' : '',
        'BACKUPS'                 => in_array('_sql_', $backup) ? ' checked' : '',
        'BACKUPM'                 => in_array('_mail_', $backup) ? ' checked' : '',
        'PROTECT_WEB_FOLDERS_YES' => $webFolderProtection == '_yes_' ? ' checked' : '',
        'PROTECT_WEB_FOLDERS_NO'  => $webFolderProtection == '_yes_' ? '' : ' checked',
        'STATUS_YES'              => $status ? ' checked' : '',
        'STATUS_NO'               => !$status ? ' checked' : ''
    ]);

    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $translations = $e->getParam('translations');
        $translations['core']['error_field_stack'] = Application::getInstance()->getRegistry()->has('errFieldsStack')
            ? Application::getInstance()->getRegistry()->get('errFieldsStack') : [];
    });

    if (!Counting::resellerHasFeature('subdomains')) {
        $tpl->assign('NB_SUBDOMAIN', '');
    }

    if (!Counting::resellerHasFeature('domain_aliases')) {
        $tpl->assign('NB_DOMAIN_ALIASES', '');
    }

    if (!Counting::resellerHasFeature('mail')) {
        $tpl->assign('NB_MAIL', '');
    }

    if (!Counting::resellerHasFeature('ftp')) {
        $tpl->assign('NB_FTP', '');
    }

    if (!Counting::resellerHasFeature('sql_db')) {
        $tpl->assign('NB_SQLD', '');
    }

    if (!Counting::resellerHasFeature('sql_user')) {
        $tpl->assign('NB_SQLU', '');
    }

    if (!Counting::resellerHasFeature('php')) {
        $tpl->assign('PHP_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('php_editor')) {
        $tpl->assign('PHP_EDITOR_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('cgi')) {
        $tpl->assign('CGI_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('custom_dns_records')) {
        $tpl->assign('CUSTOM_DNS_RECORDS_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('external_mail')) {
        $tpl->assign('EXT_MAIL_FEATURE', '');
    }

    if (!Counting::resellerHasFeature('backup')) {
        $tpl->assign('BACKUP_FEATURE', '');
    }

    generatePhpBlock($tpl);
}

/**
 * Check input data
 *
 * @return bool TRUE if data are valid, FALSE otherwise
 */
function checkInputData()
{
    global $name, $description, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskSpace, $php, $cgi, $dns, $backup, $extMail,
           $webFolderProtection, $status;

    $name = isset($_POST['name']) ? cleanInput($_POST['name']) : $name;
    $description = isset($_POST['description']) ? cleanInput($_POST['description']) : $description;
    $sub = isset($_POST['sub']) ? cleanInput($_POST['sub']) : $sub;
    $als = isset($_POST['als']) ? cleanInput($_POST['als']) : $als;
    $mail = isset($_POST['mail']) ? cleanInput($_POST['mail']) : $mail;
    $mailQuota = isset($_POST['mail_quota']) ? cleanInput($_POST['mail_quota']) : $mailQuota;
    $ftp = isset($_POST['ftp']) ? cleanInput($_POST['ftp']) : $ftp;
    $sqld = isset($_POST['sql_db']) ? cleanInput($_POST['sql_db']) : $sqld;
    $sqlu = isset($_POST['sql_user']) ? cleanInput($_POST['sql_user']) : $sqlu;
    $traffic = isset($_POST['traff']) ? cleanInput($_POST['traff']) : $traffic;
    $diskSpace = isset($_POST['disk']) ? cleanInput($_POST['disk']) : $diskSpace;
    $php = isset($_POST['php']) ? cleanInput($_POST['php']) : $php;
    $cgi = isset($_POST['cgi']) ? cleanInput($_POST['cgi']) : $cgi;
    $dns = isset($_POST['dns']) ? cleanInput($_POST['dns']) : $dns;
    $backup = isset($_POST['backup']) && is_array($_POST['backup']) ? $_POST['backup'] : $backup;
    $extMail = isset($_POST['external_mail']) ? cleanInput($_POST['external_mail']) : $extMail;
    $webFolderProtection = isset($_POST['protected_webfolders']) ? cleanInput($_POST['protected_webfolders']) : $webFolderProtection;
    $status = isset($_POST['status']) ? cleanInput($_POST['status']) : $status;

    $php = $php === '_yes_' ? '_yes_' : '_no_';
    $cgi = $cgi === '_yes_' ? '_yes_' : '_no_';
    $dns = Counting::resellerHasFeature('custom_dns_records') && $dns === '_yes_' ? '_yes_' : '_no_';
    $backup = Counting::resellerHasFeature('backup') ? array_intersect($backup, ['_dmn_', '_sql_', '_mail_']) : [];
    $extMail = $extMail === '_yes_' ? '_yes_' : '_no_';
    $webFolderProtection = $webFolderProtection === '_yes_' ? '_yes_' : '_no_';
    $errFieldsStack = [];

    if ($name === '') {
        View::setPageMessage(tr('Name cannot be empty.'), 'error');
        $errFieldsStack[] = 'name';
    }

    if ($description === '') {
        View::setPageMessage(tr('Description cannot be empty.'), 'error');
        $errFieldsStack[] = 'description';
    }

    if (!Counting::resellerHasFeature('subdomains')) {
        $sub = '-1';
    } elseif (!validateLimit($sub, -1)) {
        View::setPageMessage(tr('Incorrect subdomain limit.'), 'error');
        $errFieldsStack[] = 'sub';
    }

    if (!Counting::resellerHasFeature('domain_aliases')) {
        $als = '-1';
    } elseif (!validateLimit($als, -1)) {
        View::setPageMessage(tr('Incorrect domain aliases limit.'), 'error');
        $errFieldsStack[] = 'als';
    }

    if (!Counting::resellerHasFeature('mail')) {
        $mail = '-1';
    } elseif (!validateLimit($mail, -1)) {
        View::setPageMessage(tr('Incorrect mail account limit.'), 'error');
        $errFieldsStack[] = 'mail';
    }

    if (!Counting::resellerHasFeature('ftp')) {
        $ftp = '-1';
    } elseif (!validateLimit($ftp, -1)) {
        View::setPageMessage(tr('Incorrect FTP accounts limit.'), 'error');
        $errFieldsStack[] = 'ftp';
    }

    if (!Counting::resellerHasFeature('sql_db')) {
        $sqld = '-1';
    } elseif (!validateLimit($sqld, -1)) {
        View::setPageMessage(tr('Incorrect SQL databases limit.'), 'error');
        $errFieldsStack[] = 'sql_db';
    } elseif ($sqlu != -1 && $sqld == -1) {
        View::setPageMessage(tr('SQL user limit is <i>disabled</i>.'), 'error');
        $errFieldsStack[] = 'sql_db';
        $errFieldsStack[] = 'sql_user';
    }

    if (!Counting::resellerHasFeature('sql_user')) {
        $sqlu = '-1';
    } elseif (!validateLimit($sqlu, -1)) {
        View::setPageMessage(tr('Incorrect SQL user limit.'), 'error');
        $errFieldsStack[] = 'sql_user';
    } elseif ($sqlu == -1 && $sqld != -1) {
        View::setPageMessage(tr('SQL database limit is not <i>disabled</i>.'), 'error');
        $errFieldsStack[] = 'sql_user';
        $errFieldsStack[] = 'sql_db';
    }

    if (!validateLimit($traffic, NULL)) {
        View::setPageMessage(tr('Incorrect monthly traffic limit.'), 'error');
        $errFieldsStack[] = 'traff';
    }

    if (!validateLimit($diskSpace, NULL)) {
        View::setPageMessage(tr('Incorrect disk space limit.'), 'error');
        $errFieldsStack[] = 'disk';
    }

    if ($mail != '-1') {
        if (!validateLimit($mailQuota, NULL)) {
            View::setPageMessage(tr('Wrong syntax for the mail quota value.'), 'error');
            $errFieldsStack[] = 'mail_quota';
        } elseif ($diskSpace != 0 && $mailQuota > $diskSpace) {
            View::setPageMessage(tr('Mail quota cannot be bigger than disk space limit.'), 'error');
            $errFieldsStack[] = 'mail_quota';
        } elseif ($diskSpace != 0 && $mailQuota == 0) {
            View::setPageMessage(tr('Mail quota cannot be unlimited. Max value is %d MiB.', $diskSpace), 'error');
            $errFieldsStack[] = 'mail_quota';
        }
    } else {
        $mailQuota = $diskSpace;
    }

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

            // Must be set before phpiniPostMaxSize
            if (isset($_POST['memory_limit'])) {
                $phpini->setIniOption('phpiniMemoryLimit', cleanInput($_POST['memory_limit']));
            }

            // Must be set before phpiniUploadMaxFileSize
            if (isset($_POST['post_max_size'])) {
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
        } else {
            $phpini->loadClientPermissions(); // Reset client permissions to their default value
            $phpini->loadIniOptions(); // Reset INI options to their default values
        }
    } else {
        $phpini->loadClientPermissions(); // Reset client permissions to their default value
        $phpini->loadIniOptions(); // Reset INI options to their default values
    }

    if (!empty($errFieldsStack)) {
        Application::getInstance()->getRegistry()->set('errFieldsStack', $errFieldsStack);
        return false;
    }

    return true;
}

/**
 * Update hosting plan
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function updateHostingPlan()
{
    global $id, $name, $description, $sub, $als, $mail, $mailQuota, $ftp, $sqld, $sqlu, $traffic, $diskSpace, $php, $cgi, $dns, $backup, $extMail,
           $webFolderProtection, $status;

    $phpini = PHPini::getInstance();
    $props = "$php;$cgi;$sub;$als;$mail;$ftp;$sqld;$sqlu;$traffic;$diskSpace;" . implode('|', $backup) . ";$dns";
    $props .= ';' . $phpini->getClientPermission('phpiniSystem');
    $props .= ';' . $phpini->getClientPermission('phpiniConfigLevel');
    $props .= ';' . $phpini->getClientPermission('phpiniAllowUrlFopen');
    $props .= ';' . $phpini->getClientPermission('phpiniDisplayErrors');
    $props .= ';' . $phpini->getClientPermission('phpiniDisableFunctions');
    $props .= ';' . $phpini->getClientPermission('phpiniMailFunction');
    $props .= ';' . $phpini->getIniOption('phpiniPostMaxSize');
    $props .= ';' . $phpini->getIniOption('phpiniUploadMaxFileSize');
    $props .= ';' . $phpini->getIniOption('phpiniMaxExecutionTime');
    $props .= ';' . $phpini->getIniOption('phpiniMaxInputTime');
    $props .= ';' . $phpini->getIniOption('phpiniMemoryLimit');
    $props .= ';' . $extMail . ';' . $webFolderProtection . ';' . $mailQuota * 1048576;

    if (!validateHostingPlanLimits($props, Application::getInstance()->getAuthService()->getIdentity()->getUserId())) {
        View::setPageMessage(tr('Hosting plan limits exceed your limits.'), 'error');
        return false;
    }

    execQuery('UPDATE hosting_plans SET name = ?, description = ?, props = ?, status = ? WHERE id = ?', [$name, $description, $props, $status, $id]);
    return true;
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);
isset($_GET['id']) or View::showBadRequestErrorPage();

global $id;
$id = intval($_GET['id']);

loadHostingPlan() or View::showBadRequestErrorPage();

if (Application::getInstance()->getRequest()->isPost() && checkInputData() && updateHostingPlan()) {
    View::setPageMessage(tr('Hosting plan successfully updated.'), 'success');
    redirectTo('hosting_plan.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                                  => 'shared/layouts/ui.tpl',
    'page'                                    => 'reseller/hosting_plan_edit.tpl',
    'page_message'                            => 'layout',
    'nb_subdomains'                           => 'page',
    'nb_domain_aliases'                       => 'page',
    'nb_mail'                                 => 'page',
    'nb_ftp'                                  => 'page',
    'nb_sqld'                                 => 'page',
    'nb_sqlu'                                 => 'page',
    'php_feature'                             => 'page',
    'php_editor_feature'                      => 'page',
    'php_editor_permissions_block'            => 'php_editor_feature',
    'phpini_perm_config_level_block'          => 'php_editor_permissions_block',
    'phpini_perm_config_level_per_site_block' => 'phpini_perm_config_level_block',
    'php_editor_allow_url_fopen_block'        => 'php_editor_permissions_block',
    'php_editor_display_errors_block'         => 'php_editor_permissions_block',
    'php_editor_disable_functions_block'      => 'php_editor_permissions_block',
    'php_editor_mail_function_block'          => 'php_editor_permissions_block',
    'php_editor_default_values_block'         => 'php_editor_feature',
    'cgi_feature'                             => 'page',
    'custom_dns_feature'                      => 'page',
    'backup_feature'                          => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                 => toHtml(tr('Reseller /Hosting Plans / Edit Hosting Plan')),
    'TR_HOSTING_PLAN'               => toHtml(tr('Hosting plan')),
    'TR_NAME'                       => toHtml(tr('Name')),
    'TR_DESCRIPTON'                 => toHtml(tr('Description')),
    'TR_HOSTING_PLAN_LIMITS'        => toHtml(tr('Limits')),
    'TR_MAX_SUB'                    => toHtml(tr('Subdomains limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_ALS'                    => toHtml(tr('Domain aliases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_MAIL'                   => toHtml(tr('Mail accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAIL_QUOTA'                 => toHtml(tr('Mail quota [MiB]')) . '<br><i>(0 ∞)</i>',
    'TR_MAX_FTP'                    => toHtml(tr('FTP accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_SQLD'                   => toHtml(tr('SQL databases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MAX_SQLU'                   => toHtml(tr('SQL users limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
    'TR_MONTHLY_TRAFFIC'            => toHtml(tr('Monthly traffic limit [MiB]')) . '<br/><i>(0 ∞)</i>',
    'TR_MAX_DISKSPACE'              => toHtml(tr('Disk space limit [MiB]')) . '<br/><i>(0 ∞)</i>',
    'TR_HOSTING_PLAN_FEATURES'      => toHtml(tr('Features')),
    'TR_PHP'                        => toHtml(tr('PHP')),
    'TR_CGI'                        => toHtml(tr('CGI')),
    'TR_DNS'                        => toHtml(tr('Custom DNS records')),
    'TR_SOFTWARE_SUPP'              => toHtml(tr('Software installer')),
    'TR_EXTMAIL'                    => toHtml(tr('External mail server')),
    'TR_WEB_FOLDER_PROTECTION'      => toHtml(tr('Web folder protection')),
    'TR_WEB_FOLDER_PROTECTION_HELP' => toHtml(tr('If set to `yes`, Web folders will be protected against deletion.')),
    'TR_BACKUP'                     => toHtml(tr('Backup')),
    'TR_BACKUP_DOMAIN'              => toHtml(tr('Domain')),
    'TR_BACKUP_SQL'                 => toHtml(tr('SQL')),
    'TR_BACKUP_MAIL'                => toHtml(tr('Mail')),
    'TR_AVAILABILITY'               => toHtml(tr('Hosting plan availability')),
    'TR_STATUS'                     => toHtml(tr('Available')),
    'TR_YES'                        => toHtml(tr('Yes')),
    'TR_NO'                         => toHtml(tr('No')),
    'TR_UPDATE'                     => toHtml(tr('Update'), 'htmlAttr'),
    'TR_CANCEL'                     => toHtml(tr('Cancel'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
