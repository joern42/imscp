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

return [
    // Set the isp logos path
    'ISP_LOGO_PATH'                       => '/ispLogos',

    // Default Language (if not overriden by admin)
    'USER_INITIAL_LANG'                   => \Locale::acceptFromHttp($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? 'en_GB') ?: 'en_GB',

    // Session timeout in minutes
    'SESSION_TIMEOUT'                     => 30,

    // SQL variables
    'MAX_SQL_DATABASE_LENGTH'             => 64,
    'MAX_SQL_USER_LENGTH'                 => 16,
    'MAX_SQL_PASS_LENGTH'                 => 32,

    // Captcha background color
    'LOSTPASSWORD_CAPTCHA_BGCOLOR'        => [176, 222, 245],
    // Captcha text color
    'LOSTPASSWORD_CAPTCHA_TEXTCOLOR'      => [1, 53, 920],
    // Captcha imagewidth
    'LOSTPASSWORD_CAPTCHA_WIDTH'          => 276,
    // Captcha imagehigh
    'LOSTPASSWORD_CAPTCHA_HEIGHT'         => 30,

    // Captcha fontfiles (have to be under compatible open source license)
    'LOSTPASSWORD_CAPTCHA_FONTS'          => [
        'FreeMono.ttf', 'FreeMonoBold.ttf', 'FreeMonoBoldOblique.ttf', 'FreeMonoOblique.ttf',
        'FreeSans.ttf', 'FreeSansBold.ttf', 'FreeSansBoldOblique.ttf', 'FreeSansOblique.ttf',
        'FreeSerif.ttf', 'FreeSerifBold.ttf', 'FreeSerifBoldItalic.ttf', 'FreeSerifItalic.ttf'
    ],

    // The following settings can be overridden via the control panel - (admin/settings.php)

    // Domain rows pagination
    'DOMAIN_ROWS_PER_PAGE'                => 10,

    // Enable or disable support system
    'IMSCP_SUPPORT_SYSTEM'                => 1,

    // Enable or disable lost password support
    'LOSTPASSWORD'                        => 1,
    // Uniq keys timeout in minutes
    'LOSTPASSWORD_TIMEOUT'                => 30,

    // Enable/disable countermeasures for bruteforce and dictionary attacks
    'BRUTEFORCE'                          => 1,
    // Enable/disable waiting time between login/captcha attempts
    'BRUTEFORCE_BETWEEN'                  => 1,
    // Max login/captcha attempts before waiting time
    'BRUTEFORCE_MAX_ATTEMPTS_BEFORE_WAIT' => 2,
    // Waiting time between login/captcha attempts
    'BRUTEFORCE_BETWEEN_TIME'             => 30,
    // Blocking time in minutes
    'BRUTEFORCE_BLOCK_TIME'               => 15,
    // Max login attempts before blocking time
    'BRUTEFORCE_MAX_LOGIN'                => 5,
    // Max captcha attempts before blocking time
    'BRUTEFORCE_MAX_CAPTCHA'              => 5,

    // Enable or disable maintenance mode
    // 1: Maintenance mode enabled
    // 0: Maintenance mode disabled
    'MAINTENANCEMODE'                     => 0,

    // Minimum password chars
    'PASSWD_CHARS'                        => 6,
    // Enable or disable strong passwords
    // 1: Strong password enabled
    // 0: Strong password disabled
    'PASSWD_STRONG'                       => 1,

    // Logging Mailer default level (messages sent to DEFAULT_ADMIN_ADDRESS)
    //
    // 0                    : No logging
    // E_USER_ERROR (256)   : errors are logged
    // E_USER_WARNING (512) : Warnings and errors are logged
    // E_USER_NOTICE (1024) : Notice, warnings and errors are logged
    //
    // Note: PHP's E_USER_* constants are used for simplicity.
    //
    'LOG_LEVEL'                           => E_USER_ERROR,

    // Count default abuse, hostmaster, postmaster and webmaster mail accounts
    // in user mail accounts limit
    // 1: default mail accounts are counted
    // 0: default mail accounts are NOT counted
    'COUNT_DEFAULT_EMAIL_ADDRESSES'       => 0,
    // Protectdefault abuse, hostmaster, postmaster and webmaster mail accounts
    // against change and deletion
    'PROTECT_DEFAULT_EMAIL_ADDRESSES'     => 1,
    // Use hard mail suspension when suspending a domain:
    // 1: mail accounts are hard suspended (completely unreachable)
    // 0: mail accounts are soft suspended (passwords are modified so user can't access the accounts)
    'HARD_MAIL_SUSPENSION'                => 1,

    // Prevent external login (i.e. check for valid local referer) separated in admin, reseller and client.
    // This option allows to use external login scripts
    //
    // 1: prevent external login, check for referer, more secure
    // 0: allow external login, do not check for referer, less security (risky)
    'PREVENT_EXTERNAL_LOGIN_ADMIN'        => 1,
    'PREVENT_EXTERNAL_LOGIN_RESELLER'     => 1,
    'PREVENT_EXTERNAL_LOGIN_CLIENT'       => 1,

    // Automatic search for new version
    'CHECK_FOR_UPDATES'                   => 0,
    'ENABLE_SSL'                          => 1,

    // Server traffic settings
    'SERVER_TRAFFIC_LIMIT'                => 0,
    'SERVER_TRAFFIC_WARN'                 => 0
];
