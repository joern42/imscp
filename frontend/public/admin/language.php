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

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'              => 'shared/layouts/ui.tpl',
    'page'                => 'admin/language.tpl',
    'page_message'        => 'layout',
    'languages_available' => 'page',
    'def_language'        => 'languages_available'
]);

$adminCurrentLanguage = Application::getInstance()->getSession()['user_def_lang'];

if (Application::getInstance()->getRequest()->isPost()) {
    $adminNewLanguage = cleanInput($_POST['def_language']);

    if (!in_array($adminNewLanguage, getAvailableLanguages(true), true)) {
        View::showBadRequestErrorPage();
    }

    if ($adminCurrentLanguage != $adminNewLanguage) {
        execQuery('UPDATE user_gui_props SET lang = ? WHERE user_id = ?', [
            $adminNewLanguage, Application::getInstance()->getAuthService()->getIdentity()->getUserId()
        ]);
        Application::getInstance()->getSession()['user_def_lang'] = $adminNewLanguage;
        View::setPageMessage(tr('Language has been updated.'), 'success');
    } else {
        View::setPageMessage(tr('Nothing has been changed.'), 'info');
    }

    redirectTo('language.php');
}

$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Admin / Profile / Language'),
    'TR_LANGUAGE'        => tr('Language'),
    'TR_CHOOSE_LANGUAGE' => tr('Choose your language'),
    'TR_UPDATE'          => tr('Update')
]);
View::generateNavigation($tpl);
View::generateLanguagesList($tpl, $adminCurrentLanguage);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
