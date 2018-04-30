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

use iMSCP\Functions\LostPassword;
use iMSCP\Functions\View;
use iMSCP\Plugin\Bruteforce;

require_once 'application.php';

Application::getInstance()->getEventManager()->trigger(Events::onLostPasswordScriptStart);

$config = Application::getInstance()->getConfig();
$config['LOSTPASSWORD'] or View::showNotFoundErrorPage();

$request = Application::getInstance()->getRequest();

if ($request->getQuery('captcha')) {
    LostPassword::generateCaptcha('capcode');
    exit;
}

if ($request->getQuery('key')) {
    LostPassword::removeOldKeys($config['LOSTPASSWORD_TIMEOUT']);

    $key = cleanInput($request->getQuery('key'));
    if (LostPassword::sendPassword($key)) {
        View::setPageMessage(toHtml(tr('Your password has been successfully scheduled for renewal. Check your mails.')), 'success');
    }

    redirectTo('index.php');
}

if (Application::getInstance()->getRequest()->isPost()) {
    if ($config['BRUTEFORCE']) {
        $bruteForce = new Bruteforce(Application::getInstance()->getPluginManager(), Bruteforce::CAPTCHA_TARGET);
        if ($bruteForce->isWaiting() || $bruteForce->isBlocked()) {
            View::setPageMessage($bruteForce->getLastMessage(), 'error');
            goto RENDERING;
        }
        $bruteForce->logAttempt();
    }

    if (NULL === $request->getPost('capcode') || NULL === $request->getPost('uname')) {
        View::showBadRequestErrorPage();
    } elseif (!isset(Application::getInstance()->getSession()['capcode'])) {
        View::setPageMessage(toHtml(tr('Security code has expired')), 'error');
    } elseif (!$request->getPost('capcode') || !$request->getPost('uname')) {
        View::setPageMessage(toHtml(tr('All fields are required.')), 'error');
    } else {
        $uname = cleanInput($request->getPost('uname'));
        $capcode = cleanInput($request->getPost('capcode'));
        if (strtolower(Application::getInstance()->getSession()['capcode']) !== strtolower($capcode)) {
            View::setPageMessage(toHtml(tr('Wrong security code')), 'error');
        } else if (LostPassword::sendPasswordRequestValidation($uname)) {
            View::setPageMessage(toHtml(tr('Your request for password renewal has been taken into account. You will receive a mail in few seconds.')), 'success');
            redirectTo('index.php');
        }
    }
}

RENDERING:

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/simple.tpl',
    'page'         => 'lostpassword.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'    => toHtml(tr('i-MSCP - Multi Server Control Panel / Lost Password')),
    'productLongName'  => toHtml(tr('internet Multi Server Control Panel')),
    'productLink'      => toHtml('https://www.i-mscp.net', 'htmlAttr'),
    'productCopyright' => toHtml(tr('© 2010-2018 i-MSCP - All Rights Reserved')),
    'TR_CAPCODE'       => toHtml(tr('Security code')),
    'GET_NEW_CAPTCHA'  => toHtml(tr('Click on this image to get a new security code'), 'htmlAttr'),
    'CAPTCHA_WIDTH'    => toHtml($config['LOSTPASSWORD_CAPTCHA_WIDTH'], 'htmlAttr'),
    'CAPTCHA_HEIGHT'   => toHtml($config['LOSTPASSWORD_CAPTCHA_HEIGHT'], 'htmlAttr'),
    'TR_USERNAME'      => toHtml(tr('Username')),
    'TR_SEND'          => toHtml(tr('Send')),
    'TR_CANCEL'        => toHtml(tr('Cancel')),
    'UNAME'            => toHtml($request->getPost('uname', ''), 'htmlAttr')
]);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onLostPasswordScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
