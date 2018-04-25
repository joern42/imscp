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

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function admin_generateLanguagesList(TemplateEngine $tpl)
{
    $defaultLanguage = Application::getInstance()->getConfig()['USER_INITIAL_LANG'];

    foreach (getAvailableLanguages() as $language) {
        $tpl->assign([
            'LANGUAGE_NAME'             => toHtml($language['language']),
            'NUMBER_TRANSLATED_STRINGS' => $language['locale'] == \Locale::getDefault()
                ? $language['translatedStrings'] : toHtml(tr('%d strings translated', $language['translatedStrings'])),
            'LANGUAGE_CREATION_DATE'    => toHtml($language['creation']),
            'LAST_TRANSLATOR'           => toHtml($language['lastTranslator']),
            'LOCALE_CHECKED'            => $language['locale'] == $defaultLanguage ? ' checked' : '',
            'LOCALE'                    => toHtml($language['locale'], 'htmlAttr')
        ]);
        $tpl->parse('LANGUAGE_BLOCK', '.language_block');
    }
}

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

if (isset($_POST['uaction'])) {
    if ($_POST['uaction'] == 'uploadLanguage') {
        if (importMachineObjectFile()) {
            setPageMessage(tr('Language file successfully installed.'), 'success');
        }
    } elseif ($_POST['uaction'] == 'changeLanguage') {
        if (changeDefaultLanguage()) {
            setPageMessage(tr('Default language successfully updated.'), 'success');
        } else {
            setPageMessage(tr('Unknown language name.'), 'error');
        }
    } elseif ($_POST['uaction'] == 'rebuildIndex') {
        buildLanguagesIndex();
        setPageMessage(tr('Languages index was successfully re-built.'), 'success');
    }

    redirectTo('multilanguage.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'            => 'shared/layouts/ui.tpl',
    'page'              => 'admin/multilanguage.phtml',
    'page_message'      => 'layout',
    'languages_block'   => 'page',
    'language_block_js' => 'page',
    'language_block'    => 'languages_block'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                => toHtml(tr('Admin / Settings / Languages')),
    'TR_MULTILANGUAGE'             => toHtml(tr('Internationalization')),
    'TR_LANGUAGE_NAME'             => toHtml(tr('Language')),
    'TR_NUMBER_TRANSLATED_STRINGS' => toHtml(tr('Translated strings')),
    'TR_LANGUAGE_CREATION_DATE'    => toHtml(tr('Creation date')),
    'TR_LAST_TRANSLATOR'           => toHtml(tr('Last translator')),
    'TR_DEFAULT_LANGUAGE'          => toHtml(tr('Default language')),
    'TR_DEFAULT'                   => toHtml(tr('Default')),
    'TR_SAVE'                      => toHtml(tr('Save'), 'htmlAttr'),
    'TR_IMPORT_NEW_LANGUAGE'       => toHtml(tr('Import new language file')),
    'TR_LANGUAGE_FILE'             => toHtml(tr('Language file')),
    'TR_REBUILD_INDEX'             => toHtml(tr('Rebuild languages index'), 'htmlAttr'),
    'TR_UPLOAD_HELP'               => toHtml(tr('Only gettext Machine Object files (MO files) are accepted.'), 'htmlAttr'),
    'TR_IMPORT'                    => toHtml(tr('Import'), 'htmlAttr')
]);
View::generateNavigation($tpl);
admin_generateLanguagesList($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
