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
use iMSCP\Functions\View;
use iMSCP\Model\SuIdentityInterface;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);

$tpl = new TemplateEngine();
$tpl->define('layout', 'shared/layouts/ui.tpl');
$tpl->define([
    'page'                => 'client/language.tpl',
    'page_message'        => 'layout',
    'languages_available' => 'page',
    'def_language'        => 'languages_available'
]);

$identity = Application::getInstance()->getAuthService()->getIdentity();

if ($identity instanceof SuIdentityInterface) {
    $customerCurrentLanguage = getUserGuiProperties($identity->getUserId())[0];
} else {
    $customerCurrentLanguage = Application::getInstance()->getSession()['user_def_lang'];
}

if (Application::getInstance()->getRequest()->isPost()) {
    $customerNewLanguage = cleanInput($_POST['def_language']);
    in_array($customerNewLanguage, getAvailableLanguages(true)) or View::showBadRequestErrorPage();

    if ($customerCurrentLanguage != $customerNewLanguage) {
        execQuery('UPDATE user_gui_props SET lang = ? WHERE user_id = ?', [
            $customerNewLanguage, Application::getInstance()->getAuthService()->getIdentity()->getUserId()
        ]);

        if (!($identity instanceof SuIdentityInterface)) {
            Application::getInstance()->getSession()['user_def_lang'] = $customerNewLanguage;
        }

        View::setPageMessage(tr('Language has been updated.'), 'success');
    } else {
        View::setPageMessage(tr('Nothing has been changed.'), 'info');
    }

    redirectTo('language.php');
}

$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / Profile / Language'),
    'TR_GENERAL_INFO'    => tr('General information'),
    'TR_LANGUAGE'        => tr('Language'),
    'TR_CHOOSE_LANGUAGE' => tr('Choose your language'),
    'TR_UPDATE'          => tr('Update')
]);
View::generateNavigation($tpl);
View::generateLanguagesList($tpl, $customerCurrentLanguage);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
