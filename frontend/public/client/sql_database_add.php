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
 * Add SQL database
 *
 * @return void
 */
function addSqlDb()
{
    isset($_POST['db_name']) or View::showBadRequestErrorPage();

    $dbName = cleanInput($_POST['db_name']);

    if ($_POST['db_name'] == '') {
        setPageMessage(tr('Please type database name.'), 'error');
        return;
    }

    $mainDmnId = getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']);

    if (isset($_POST['use_dmn_id']) && $_POST['use_dmn_id'] == 'on') {
        if (isset($_POST['id_pos']) && $_POST['id_pos'] == 'start') {
            $dbName = $mainDmnId . '_' . $dbName;
        } elseif (isset($_POST['id_pos']) && $_POST['id_pos'] == 'end') {
            $dbName = $dbName . '_' . $mainDmnId;
        }
    }

    if (strlen($dbName) > 64) {
        setPageMessage(tr('Database name is too long.'), 'error');
        return;
    }

    if (in_array($dbName, ['information_schema', 'mysql', 'performance_schema', 'sys', 'test'])
        || execQuery('SHOW DATABASES LIKE ?', $dbName)->rowCount() > 0
    ) {
        setPageMessage(tr('Database name is unavailable or unallowed.'), 'error');
        return;
    }

    try {
        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddSqlDb, NULL, ['dbName' => $dbName]);
        execQuery(sprintf('CREATE DATABASE IF NOT EXISTS %s', quoteIdentifier($dbName)));
        execQuery('INSERT INTO sql_database (domain_id, sqld_name) VALUES (?, ?)', [$mainDmnId, $dbName]);
        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddSqlDb, NULL, [
            'dbId'   => Application::getInstance()->getDb()->getDriver()->getLastGeneratedValue(),
            'dbName' => $dbName
        ]);
        setPageMessage(tr('SQL database successfully created.'), 'success');
        writeLog(
            sprintf('A new database (%s) has been created by %s', $dbName, Application::getInstance()->getSession()['user_logged']), E_USER_NOTICE
        );
    } catch (\Exception $e) {
        writeLog(sprintf("Couldn't create the %s database: %s", $dbName, $e->getMessage()));
        setPageMessage(tr("Couldn't create the %s database.", $dbName), 'error');
    }

    redirectTo('sql_manage.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $cfg = Application::getInstance()->getConfig();

    if ($cfg['MYSQL_PREFIX'] != 'none') {
        $tpl->assign('MYSQL_PREFIX_YES', '');

        if ($cfg['MYSQL_PREFIX'] == 'behind') {
            $tpl->assign('MYSQL_PREFIX_INFRONT', '');
            $tpl->parse('MYSQL_PREFIX_BEHIND', 'mysql_prefix_behind');
            $tpl->assign('MYSQL_PREFIX_ALL', '');
        } else {
            $tpl->parse('MYSQL_PREFIX_INFRONT', 'mysql_prefix_infront');
            $tpl->assign([
                'MYSQL_PREFIX_BEHIND' => '',
                'MYSQL_PREFIX_ALL'    => ''
            ]);
        }
    } else {
        $tpl->assign([
            'MYSQL_PREFIX_NO'      => '',
            'MYSQL_PREFIX_INFRONT' => '',
            'MYSQL_PREFIX_BEHIND'  => ''
        ]);
        $tpl->parse('MYSQL_PREFIX_ALL', 'mysql_prefix_all');
    }

    $tpl->assign([
        'DB_NAME'               => isset($_POST['db_name']) ? toHtml($_POST['db_name'], 'htmlAttr') : '',
        'USE_DMN_ID'            => isset($_POST['use_dmn_id']) && $_POST['use_dmn_id'] === 'on' ? ' checked' : '',
        'START_ID_POS_SELECTED' => isset($_POST['id_pos']) && $_POST['id_pos'] !== 'end' ? ' checked' : '',
        'END_ID_POS_SELECTED'   => isset($_POST['id_pos']) && $_POST['id_pos'] === 'end' ? ' checked' : ''
    ]);
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('sql') && !customerSqlDbLimitIsReached() or View::showBadRequestErrorPage();

empty($_POST) or addSqlDb();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'               => 'shared/layouts/ui.tpl',
    'page'                 => 'client/sql_database_add.tpl',
    'page_message'         => 'layout',
    'mysql_prefix_yes'     => 'page',
    'mysql_prefix_no'      => 'page',
    'mysql_prefix_all'     => 'page',
    'mysql_prefix_infront' => 'page',
    'mysql_prefix_behind'  => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'   => toHtml(tr('Client / Databases / Add SQL Database')),
    'TR_DATABASE'     => toHtml(tr('Database')),
    'TR_DB_NAME'      => toHtml(tr('Database name')),
    'TR_USE_DMN_ID'   => toHtml(tr('Database prefix/suffix')),
    'TR_START_ID_POS' => toHtml(tr('In front')),
    'TR_END_ID_POS'   => toHtml(tr('Behind')),
    'TR_ADD'          => toHtml(tr('Add'), 'htmlAttr'),
    'TR_CANCEL'       => toHtml(tr('Cancel'))
]);
generatePage($tpl);
View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
