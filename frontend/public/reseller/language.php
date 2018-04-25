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

use iMSCP\Functions\Login;
use iMSCP\Functions\View;

Login::checkLogin('reseller');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'              => 'shared/layouts/ui.tpl',
    'page'                => 'reseller/language.tpl',
    'page_message'        => 'layout',
    'languages_available' => 'page',
    'def_language'        => 'languages_available'
]);

if (isset(Application::getInstance()->getSession()['logged_from']) && isset(Application::getInstance()->getSession()['logged_from_id'])) {
    list($resellerCurrentLanguage) = getUserGuiProperties(Application::getInstance()->getSession()['user_id']);
} else {
    $resellerCurrentLanguage = Application::getInstance()->getSession()['user_def_lang'];
}

if (!empty($_POST)) {
    $resellerNewLanguage = cleanInput($_POST['def_language']);
    in_array($resellerNewLanguage, getAvailableLanguages(true), true) or View::showBadRequestErrorPage();

    if ($resellerCurrentLanguage != $resellerNewLanguage) {
        execQuery('UPDATE user_gui_props SET lang = ? WHERE user_id = ?', [$resellerNewLanguage, Application::getInstance()->getSession()['user_id']]);

        if (!isset(Application::getInstance()->getSession()['logged_from_id'])) {
            unset(Application::getInstance()->getSession()['user_def_lang']);
            Application::getInstance()->getSession()['user_def_lang'] = $resellerNewLanguage;
        }

        setPageMessage(tr('Language has been updated.'), 'success');
    } else {
        setPageMessage(tr('Nothing has been changed.'), 'info');
    }

    redirectTo('language.php');
}

$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Reseller / Profile / Language'),
    'TR_LANGUAGE'        => tr('Language'),
    'TR_CHOOSE_LANGUAGE' => tr('Choose your language'),
    'TR_UPDATE'          => tr('Update')
]);
View::generateNavigation($tpl);
View::generateLanguagesList($tpl, $resellerCurrentLanguage);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
