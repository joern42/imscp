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
use iMSCP\Config\DbConfig;
use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$config = Application::getInstance()->getConfig();

if (Application::getInstance()->getRequest()->isPost()) {
    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditAdminGeneralSettings);

    $checkForUpdate = isset($_POST['checkforupdate']) ? cleanInput($_POST['checkforupdate']) : $config['CHECK_FOR_UPDATES'];

    $lostPasswd = isset($_POST['lostpassword']) ? cleanInput($_POST['lostpassword']) : $config['LOSTPASSWORD'];
    $lostPasswdTimeout = isset($_POST['lostpassword_timeout']) ? cleanInput($_POST['lostpassword_timeout']) : $config['LOSTPASSWORD_TIMEOUT'];

    $passwdStrong = isset($_POST['passwd_strong']) ? cleanInput($_POST['passwd_strong']) : $config['PASSWD_STRONG'];
    $passwdChars = isset($_POST['passwd_chars']) ? cleanInput($_POST['passwd_chars']) : $config['PASSWD_CHARS'];

    $bruteforce = isset($_POST['bruteforce']) ? cleanInput($_POST['bruteforce']) : $config['BRUTEFORCE'];
    $bruteforceBetween = isset($_POST['bruteforce_between'])
        ? cleanInput($_POST['bruteforce_between']) : $config['BRUTEFORCE_BETWEEN'];
    $bruteforceMaxLogin = isset($_POST['bruteforce_max_login'])
        ? cleanInput($_POST['bruteforce_max_login']) : $config['BRUTEFORCE_MAX_LOGIN'];
    $bruteforceBlockTime = isset($_POST['bruteforce_block_time'])
        ? cleanInput($_POST['bruteforce_block_time']) : $config['BRUTEFORCE_BLOCK_TIME'];
    $bruteforceBetweenTime = isset($_POST['bruteforce_block_time'])
        ? cleanInput($_POST['bruteforce_between_time']) : $config['BRUTEFORCE_BETWEEN_TIME'];
    $bruteforceMaxCapcha = isset($_POST['bruteforce_max_capcha'])
        ? cleanInput($_POST['bruteforce_max_capcha']) : $config['BRUTEFORCE_MAX_CAPTCHA'];
    $bruteforceMaxAttemptsBeforeWait = isset($_POST['bruteforce_max_attempts_before_wait'])
        ? cleanInput($_POST['bruteforce_max_attempts_before_wait']) : $config['BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'];

    $countDefaultEmails = isset($_POST['count_default_email_addresses'])
        ? cleanInput($_POST['count_default_email_addresses']) : $config['COUNT_DEFAULT_EMAIL_ADDRESSES'];
    $protecttDefaultEmails = isset($_POST['protect_default_email_addresses'])
        ? cleanInput($_POST['protect_default_email_addresses']) : $config['PROTECT_DEFAULT_EMAIL_ADDRESSES'];
    $hardMailSuspension = isset($_POST['hard_mail_suspension'])
        ? cleanInput($_POST['hard_mail_suspension']) : $config['HARD_MAIL_SUSPENSION'];
    $emailQuotaSyncMode = isset($_POST['email_quota_sync_mode'])
        ? cleanInput($_POST['email_quota_sync_mode']) : $config['EMAIL_QUOTA_SYNC_MODE'];

    $userInitialLang = isset($_POST['def_language'])
        ? cleanInput($_POST['def_language']) : $config['USER_INITIAL_LANG'];
    $supportSystem = isset($_POST['support_system'])
        ? cleanInput($_POST['support_system']) : $config['IMSCP_SUPPORT_SYSTEM'];
    $domainRowsPerPage = isset($_POST['domain_rows_per_page'])
        ? cleanInput($_POST['domain_rows_per_page']) : $config['DOMAIN_ROWS_PER_PAGE'];
    $logLevel = isset($_POST['log_level']) && in_array($_POST['log_level'], ['0', 'E_USER_ERROR', 'E_USER_WARNING', 'E_USER_NOTICE'])
        ? $_POST['log_level'] : $config['LOG_LEVEL'];
    $prevExtLoginAdmin = isset($_POST['prevent_external_login_admin'])
        ? cleanInput($_POST['prevent_external_login_admin']) : $config['PREVENT_EXTERNAL_LOGIN_ADMIN'];
    $prevExtLoginReseller = isset($_POST['prevent_external_login_reseller'])
        ? cleanInput($_POST['prevent_external_login_reseller']) : $config['PREVENT_EXTERNAL_LOGIN_RESELLER'];
    $prevExtLoginClient = isset($_POST['prevent_external_login_client'])
        ? cleanInput($_POST['prevent_external_login_client']) : $config['PREVENT_EXTERNAL_LOGIN_CLIENT'];
    $enableSSL = isset($_POST['enableSSL']) ? cleanInput($_POST['enableSSL']) : $config['ENABLE_SSL'];

    if (!isNumber($checkForUpdate) || !isNumber($lostPasswd) || !isNumber($passwdStrong) || !isNumber($bruteforce) || !isNumber($bruteforceBetween)
        || !isNumber($countDefaultEmails) || !isNumber($protecttDefaultEmails) || !isNumber($hardMailSuspension) || !isNumber($emailQuotaSyncMode)
        || !isNumber($supportSystem) || !isNumber($prevExtLoginAdmin) || !isNumber($prevExtLoginReseller) || !isNumber($prevExtLoginClient)
        || !isNumber($enableSSL) || !in_array($userInitialLang, getAvailableLanguages(true), true)
    ) {
        View::showBadRequestErrorPage();
    }

    if (!isNumber($lostPasswdTimeout) || !isNumber($passwdChars) || !isNumber($bruteforceMaxLogin) || !isNumber($bruteforceBlockTime)
        || !isNumber($bruteforceBetweenTime) || !isNumber($bruteforceMaxCapcha) || !isNumber($bruteforceMaxAttemptsBeforeWait)
        || !isNumber($domainRowsPerPage)
    ) {
        View::setPageMessage(tr('Only positive numbers are allowed.'), 'error');
    } else {
        $dbConfig = Application::getInstance()->getDbConfig();
        $dbConfig['CHECK_FOR_UPDATES'] = $checkForUpdate;
        $dbConfig['LOSTPASSWORD'] = $lostPasswd;
        $dbConfig['LOSTPASSWORD_TIMEOUT'] = $lostPasswdTimeout;
        $dbConfig['PASSWD_STRONG'] = $passwdStrong;
        $dbConfig['PASSWD_CHARS'] = $passwdChars;
        $dbConfig['BRUTEFORCE'] = $bruteforce;
        $dbConfig['BRUTEFORCE_BETWEEN'] = $bruteforceBetween;
        $dbConfig['BRUTEFORCE_MAX_LOGIN'] = $bruteforceMaxLogin;
        $dbConfig['BRUTEFORCE_BLOCK_TIME'] = $bruteforceBlockTime;
        $dbConfig['BRUTEFORCE_BETWEEN_TIME'] = $bruteforceBetweenTime;
        $dbConfig['BRUTEFORCE_MAX_CAPTCHA'] = $bruteforceMaxCapcha;
        $dbConfig['BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'] = $bruteforceMaxAttemptsBeforeWait;
        $dbConfig['COUNT_DEFAULT_EMAIL_ADDRESSES'] = $countDefaultEmails;
        $dbConfig['PROTECT_DEFAULT_EMAIL_ADDRESSES'] = $protecttDefaultEmails;
        $dbConfig['HARD_MAIL_SUSPENSION'] = $hardMailSuspension;
        $dbConfig['EMAIL_QUOTA_SYNC_MODE'] = $emailQuotaSyncMode;
        $dbConfig['USER_INITIAL_LANG'] = $userInitialLang;
        $dbConfig['IMSCP_SUPPORT_SYSTEM'] = $supportSystem;
        $dbConfig['DOMAIN_ROWS_PER_PAGE'] = $domainRowsPerPage > 0 ? $domainRowsPerPage : 1;
        $dbConfig['LOG_LEVEL'] = defined($logLevel) ? constant($logLevel) : 0;
        $dbConfig['PREVENT_EXTERNAL_LOGIN_ADMIN'] = $prevExtLoginAdmin;
        $dbConfig['PREVENT_EXTERNAL_LOGIN_RESELLER'] = $prevExtLoginReseller;
        $dbConfig['PREVENT_EXTERNAL_LOGIN_CLIENT'] = $prevExtLoginClient;
        $dbConfig['ENABLE_SSL'] = $enableSSL;

        Application::getInstance()->getCache()->removeItem('merged_config'); // Force new merge
        Application::getInstance()->getEventManager()->trigger(Events::onAfterEditAdminGeneralSettings);

        $updtCount = $dbConfig->countQueries(DbConfig::UPDATE_QUERY_COUNTER);
        $newCount = $dbConfig->countQueries(DbConfig::INSERT_QUERY_COUNTER);

        if ($updtCount > 0) {
            View::setPageMessage(ntr('The configuration parameter has been updated.', '%d configuration parameters were updated', $updtCount, $updtCount), 'success');
        }

        if ($newCount > 0) {
            View::setPageMessage(ntr('A new configuration parameter has been created.', '%d configuration parameters were created', $newCount, $newCount), 'success');
        }

        if ($newCount == 0 && $updtCount == 0) {
            View::setPageMessage(tr('Nothing has been changed.'), 'info');
        } else {
            writeLog(sprintf('Settings were updated by %s.', Application::getInstance()->getAuthService()->getIdentity()->getUsername()), E_USER_NOTICE);
        }
    }

    redirectTo('settings.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/settings.tpl',
    'page_message' => 'layout',
    'def_language' => 'page'
]);

if ($config['CHECK_FOR_UPDATES']) {
    $tpl->assign([
        'CHECK_FOR_UPDATES_SELECTED_ON'  => ' selected',
        'CHECK_FOR_UPDATES_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'CHECK_FOR_UPDATES_SELECTED_ON'  => '',
        'CHECK_FOR_UPDATES_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['LOSTPASSWORD']) {
    $tpl->assign([
        'LOSTPASSWORD_SELECTED_ON'  => ' selected',
        'LOSTPASSWORD_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'LOSTPASSWORD_SELECTED_ON' => '',
        'LOSTPASSWORD_SELECTED_OFF', ' selected'
    ]);
}

if ($config['PASSWD_STRONG']) {
    $tpl->assign([
        'PASSWD_STRONG_ON'  => ' selected',
        'PASSWD_STRONG_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'PASSWD_STRONG_ON'  => '',
        'PASSWD_STRONG_OFF' => ' selected'
    ]);
}

if ($config['BRUTEFORCE']) {
    $tpl->assign([
        'BRUTEFORCE_SELECTED_ON'  => 'selected',
        'BRUTEFORCE_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'BRUTEFORCE_SELECTED_ON'  => '',
        'BRUTEFORCE_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['BRUTEFORCE_BETWEEN']) {
    $tpl->assign([
        'BRUTEFORCE_BETWEEN_SELECTED_ON'  => ' selected',
        'BRUTEFORCE_BETWEEN_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'BRUTEFORCE_BETWEEN_SELECTED_ON'  => '',
        'BRUTEFORCE_BETWEEN_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['IMSCP_SUPPORT_SYSTEM']) {
    $tpl->assign([
        'SUPPORT_SYSTEM_SELECTED_ON'  => ' selected',
        'SUPPORT_SYSTEM_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'SUPPORT_SYSTEM_SELECTED_ON'  => '',
        'SUPPORT_SYSTEM_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['PROTECT_DEFAULT_EMAIL_ADDRESSES']) {
    $tpl->assign([
        'PROTECT_DEFAULT_EMAIL_ADDRESSES_ON'  => ' selected',
        'PROTECT_DEFAULT_EMAIL_ADDRESSES_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'PROTECT_DEFAULT_EMAIL_ADDRESSESL_ON' => '',
        'PROTECT_DEFAULT_EMAIL_ADDRESSES_OFF' => ' selected'
    ]);
}

if ($config['COUNT_DEFAULT_EMAIL_ADDRESSES']) {
    $tpl->assign([
        'COUNT_DEFAULT_EMAIL_ADDRESSES_ON'  => ' selected',
        'COUNT_DEFAULT_EMAIL_ADDRESSES_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'COUNT_DEFAULT_EMAIL_ADDRESSES_ON'  => '',
        'COUNT_DEFAULT_EMAIL_ADDRESSES_OFF' => ' selected'
    ]);
}

if ($config['HARD_MAIL_SUSPENSION']) {
    $tpl->assign([
        'HARD_MAIL_SUSPENSION_ON'  => ' selected',
        'HARD_MAIL_SUSPENSION_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'HARD_MAIL_SUSPENSION_ON'  => '',
        'HARD_MAIL_SUSPENSION_OFF' => ' selected'
    ]);
}

if (isset($config['EMAIL_QUOTA_SYNC_MODE']) && $config['EMAIL_QUOTA_SYNC_MODE']) {
    $tpl->assign([
        'REDISTRIBUTE_EMAIl_QUOTA_YES' => ' selected',
        'REDISTRIBUTE_EMAIl_QUOTA_NO'  => ''
    ]);
} else {
    $tpl->assign([
        'REDISTRIBUTE_EMAIl_QUOTA_YES' => '',
        'REDISTRIBUTE_EMAIl_QUOTA_NO'  => ' selected'
    ]);
}

if ($config['PREVENT_EXTERNAL_LOGIN_ADMIN']) {
    $tpl->assign([
        'PREVENT_EXTERNAL_LOGIN_ADMIN_SELECTED_ON'  => ' selected',
        'PREVENT_EXTERNAL_LOGIN_ADMIN_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'PREVENT_EXTERNAL_LOGIN_ADMIN_SELECTED_ON'  => '',
        'PREVENT_EXTERNAL_LOGIN_ADMIN_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['PREVENT_EXTERNAL_LOGIN_RESELLER']) {
    $tpl->assign([
        'PREVENT_EXTERNAL_LOGIN_RESELLER_SELECTED_ON'  => ' selected',
        'PREVENT_EXTERNAL_LOGIN_RESELLER_SELECTED_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'PREVENT_EXTERNAL_LOGIN_RESELLER_SELECTED_ON'  => '',
        'PREVENT_EXTERNAL_LOGIN_RESELLER_SELECTED_OFF' => ' selected'
    ]);
}

if ($config['PREVENT_EXTERNAL_LOGIN_CLIENT']) {
    $tpl->assign([
            'PREVENT_EXTERNAL_LOGIN_CLIENT_SELECTED_ON'  => ' selected',
            'PREVENT_EXTERNAL_LOGIN_CLIENT_SELECTED_OFF' => ''
        ]
    );
} else {
    $tpl->assign([
        'PREVENT_EXTERNAL_LOGIN_CLIENT_SELECTED_ON'  => '',
        'PREVENT_EXTERNAL_LOGIN_CLIENT_SELECTED_OFF' => ' selected'
    ]);
}

switch ($config['LOG_LEVEL']) {
    case 0:
        $tpl->assign([
            'LOG_LEVEL_SELECTED_OFF'     => ' selected',
            'LOG_LEVEL_SELECTED_NOTICE'  => '',
            'LOG_LEVEL_SELECTED_WARNING' => '',
            'LOG_LEVEL_SELECTED_ERROR'   => ''
        ]);
        break;
    case E_USER_NOTICE:
        $tpl->assign([
            'LOG_LEVEL_SELECTED_OFF'     => '',
            'LOG_LEVEL_SELECTED_NOTICE'  => ' selected',
            'LOG_LEVEL_SELECTED_WARNING' => '',
            'LOG_LEVEL_SELECTED_ERROR'   => ''
        ]);
        break;
    case E_USER_WARNING:
        $tpl->assign([
            'LOG_LEVEL_SELECTED_OFF'     => '',
            'LOG_LEVEL_SELECTED_NOTICE'  => '',
            'LOG_LEVEL_SELECTED_WARNING' => ' selected',
            'LOG_LEVEL_SELECTED_ERROR'   => ''
        ]);
        break;
    default:
        $tpl->assign([
            'LOG_LEVEL_SELECTED_OFF'     => '',
            'LOG_LEVEL_SELECTED_NOTICE'  => '',
            'LOG_LEVEL_SELECTED_WARNING' => '',
            'LOG_LEVEL_SELECTED_ERROR'   => ' selected'
        ]);
}

if ($config['ENABLE_SSL']) {
    $tpl->assign([
        'ENABLE_SSL_ON'  => ' selected',
        'ENABLE_SSL_OFF' => ''
    ]);
} else {
    $tpl->assign([
        'ENABLE_SSL_ON'  => '',
        'ENABLE_SSL_OFF' => ' selected'
    ]);
}

$tpl->assign([
    'TR_PAGE_TITLE'                          => toHtml(tr('Admin / Settings')),
    'TR_UPDATES'                             => toHtml(tr('Updates')),
    'LOSTPASSWORD_TIMEOUT_VALUE'             => toHtml($config['LOSTPASSWORD_TIMEOUT'], 'htmlAttr'),
    'PASSWD_CHARS'                           => toHtml($config['PASSWD_CHARS'], 'htmlAttr'),
    'BRUTEFORCE_MAX_LOGIN_VALUE'             => toHtml($config['BRUTEFORCE_MAX_LOGIN'], 'htmlAttr'),
    'BRUTEFORCE_BLOCK_TIME_VALUE'            => toHtml($config['BRUTEFORCE_BLOCK_TIME'], 'htmlAttr'),
    'BRUTEFORCE_BETWEEN_TIME_VALUE'          => toHtml($config['BRUTEFORCE_BETWEEN_TIME'], 'htmlAttr'),
    'BRUTEFORCE_MAX_CAPTCHA'                 => toHtml($config['BRUTEFORCE_MAX_CAPTCHA'], 'htmlAttr'),
    'BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'    => toHtml($config['BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT'], 'htmlAttr'),
    'DOMAIN_ROWS_PER_PAGE'                   => toHtml($config['DOMAIN_ROWS_PER_PAGE'], 'htmlAttr'),
    'TR_SETTINGS'                            => toHtml(tr('Settings')),
    'TR_MESSAGE'                             => toHtml(tr('Message')),
    'TR_LOSTPASSWORD'                        => toHtml(tr('Lost password')),
    'TR_LOSTPASSWORD_TIMEOUT'                => toHtml(tr('Activation link expire time in minutes')),
    'TR_PASSWORD_SETTINGS'                   => toHtml(tr('Password settings')),
    'TR_PASSWD_STRONG'                       => toHtml(tr('Strong passwords')),
    'TR_PASSWD_CHARS'                        => toHtml(tr('Password minimum length')),
    'TR_BRUTEFORCE'                          => toHtml(tr('Bruteforce detection')),
    'TR_BRUTEFORCE_BETWEEN'                  => toHtml(tr('Blocking time between logins and captcha attempts')),
    'TR_BRUTEFORCE_MAX_LOGIN'                => toHtml(tr('Max number of login attempts')),
    'TR_BRUTEFORCE_BLOCK_TIME'               => toHtml(tr('Blocktime in minutes')),
    'TR_BRUTEFORCE_BETWEEN_TIME'             => toHtml(tr('Blocking time between login/captcha attempts in seconds')),
    'TR_BRUTEFORCE_MAX_CAPTCHA'              => toHtml(tr('Maximum number of captcha validation attempts')),
    'TR_BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT' => toHtml(tr('Maximum number of validation attempts before waiting restriction intervenes')),
    'TR_OTHER_SETTINGS'                      => toHtml(tr('Other settings')),
    'TR_MAIL_SETTINGS'                       => toHtml(tr('Email settings')),
    'TR_COUNT_DEFAULT_EMAIL_ADDRESSES'       => toHtml(tr('Count default mail accounts in customers mail limit')),
    'PROTECT_DEFAULT_EMAIL_ADDRESSES'        => toHtml(tr('Protect default mail accounts against change and removal')),
    'TR_HARD_MAIL_SUSPENSION'                => toHtml(tr('Mail accounts are hard suspended')),
    'TR_EMAIL_QUOTA_SYNC_MODE'               => toHtml(tr('Redistribute unused quota across existing mail accounts')),
    'TR_USER_INITIAL_LANG'                   => toHtml(tr('Panel default language')),
    'TR_SUPPORT_SYSTEM'                      => toHtml(tr('Support system')),
    'TR_ENABLED'                             => toHtml(tr('Enabled')),
    'TR_DISABLED'                            => toHtml(tr('Disabled')),
    'TR_YES'                                 => toHtml(tr('Yes')),
    'TR_NO'                                  => toHtml(tr('No')),
    'TR_UPDATE'                              => toHtml(tr('Update')),
    'TR_SERVERPORTS'                         => toHtml(tr('Server ports')),
    'TR_ADMIN'                               => toHtml(tr('Admin')),
    'TR_RESELLER'                            => toHtml(tr('Reseller')),
    'TR_DOMAIN_ROWS_PER_PAGE'                => toHtml(tr('Domains per page')),
    'TR_LOG_LEVEL'                           => toHtml(tr('Mail Log Level')),
    'TR_E_USER_OFF'                          => toHtml(tr('Disabled')),
    'TR_E_USER_NOTICE'                       => toHtml(tr('Notices, Warnings and Errors')),
    'TR_E_USER_WARNING'                      => toHtml(tr('Warnings and Errors')),
    'TR_E_USER_ERROR'                        => toHtml(tr('Errors')),
    'TR_CHECK_FOR_UPDATES'                   => toHtml(tr('Check for update')),
    'TR_ENABLE_SSL'                          => toHtml(tr('Enable SSL')),
    'TR_SSL_HELP'                            => toHtml(tr('Defines whether or not customers can add/change SSL certificates for their domains.')),
    'TR_PREVENT_EXTERNAL_LOGIN_ADMIN'        => toHtml(tr('Prevent external login for admins')),
    'TR_PREVENT_EXTERNAL_LOGIN_RESELLER'     => toHtml(tr('Prevent external login for resellers')),
    'TR_PREVENT_EXTERNAL_LOGIN_CLIENT'       => toHtml(tr('Prevent external login for clients'))
]);
View::generateNavigation($tpl);
View::generateLanguagesList($tpl, $config['USER_INITIAL_LANG']);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
