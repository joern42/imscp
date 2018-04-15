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
use iMSCP_Events as Events;
use iMSCP_Exception as iMSCPException;
use iMSCP_Plugin_Bruteforce as BruteForcePlugin;
use iMSCP_Registry as Registry;

require_once 'imscp-lib.php';
require_once LIBRARY_PATH . '/Functions/LostPassword.php';

Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onLostPasswordScriptStart);
doSessionTimeout();

$cfg = Registry::get('config');
$cfg['LOSTPASSWORD'] or showNotFoundErrorPage();

if (!function_exists('imagecreatetruecolor')) {
    throw new iMSCPException(tr('PHP GD extension not loaded.'));
}

removeOldKeys($cfg['LOSTPASSWORD_TIMEOUT']);

if (isset($_GET['key'])) {
    $key = cleanInput($_GET['key']);
    if (sendPassword($key)) {
        setPageMessage(tr('Your password has been successfully scheduled for renewal. Check your mails.'), 'success');
    }

    redirectTo('index.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/simple.tpl',
    'page'         => 'lostpassword.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'    => tr('i-MSCP - Multi Server Control Panel / Lost Password'),
    'CONTEXT_CLASS'    => '',
    'productLongName'  => tr('internet Multi Server Control Panel'),
    'productLink'      => 'https://www.i-mscp.net',
    'productCopyright' => tr('© 2010-2018 i-MSCP Team<br>All Rights Reserved'),
    'TR_CAPCODE'       => tr('Security code'),
    'GET_NEW_IMAGE'    => tr('Get a new security code'),
    'CAPTCHA_WIDTH'    => toHtml($cfg['LOSTPASSWORD_CAPTCHA_WIDTH'], 'htmlAttr'),
    'CAPTCHA_HEIGHT'   => toHtml($cfg['LOSTPASSWORD_CAPTCHA_HEIGHT'], 'htmlAttr'),
    'TR_USERNAME'      => tr('Username'),
    'TR_SEND'          => tr('Send'),
    'TR_CANCEL'        => tr('Cancel'),
    'UNAME'            => isset($_POST['uname']) ? $_POST['uname'] : ''
]);

if (!empty($_POST)) {
    if ($cfg['BRUTEFORCE']) {
        $bruteForce = new BruteForcePlugin(Registry::get('iMSCP_Application')->getPluginManager(), 'captcha');
        if ($bruteForce->isWaiting() || $bruteForce->isBlocked()) {
            setPageMessage($bruteForce->getLastMessage(), 'error');
            redirectTo('index.php');
        }

        $bruteForce->logAttempt();
    }

    if (!isset($_POST['capcode']) || !isset($_POST['uname'])) {
        showBadRequestErrorPage();
    } elseif (!isset($_SESSION['capcode'])) {
        setPageMessage(tr('Security code has expired'), 'error');
    } elseif ($_POST['capcode'] == '' || $_POST['uname'] == '') {
        setPageMessage(tr('All fields are required.'), 'error');
    } else {
        $uname = cleanInput($_POST['uname']);
        $capcode = cleanInput($_POST['capcode']);
        if (strtolower($_SESSION['capcode']) !== strtolower($capcode)) {
            setPageMessage(tr('Wrong security code'), 'error');
        } else if (sendPasswordRequestValidation($uname)) {
            setPageMessage(tr('Your request for password renewal has been registered. You will receive a mail with instructions to complete the process.'), 'success');
            redirectTo('index.php');
        }
    }
}

generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onLostPasswordScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
