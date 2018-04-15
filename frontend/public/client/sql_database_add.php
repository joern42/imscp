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
use iMSCP_Registry as Registry;

/**
 * Add SQL database
 *
 * @return void
 */
function addSqlDb()
{
    isset($_POST['db_name']) or showBadRequestErrorPage();

    $dbName = cleanInput($_POST['db_name']);

    if ($_POST['db_name'] == '') {
        setPageMessage(tr('Please type database name.'), 'error');
        return;
    }

    $mainDmnId = getCustomerMainDomainId($_SESSION['user_id']);

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
        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeAddSqlDb, ['dbName' => $dbName]);
        executeQuery(sprintf('CREATE DATABASE IF NOT EXISTS %s', quoteIdentifier($dbName)));
        execQuery('INSERT INTO sql_database (domain_id, sqld_name) VALUES (?, ?)', [$mainDmnId, $dbName]);
        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterAddSqlDb, [
            'dbId'   => Registry::get('iMSCP_Application')->getDatabase()->lastInsertId(),
            'dbName' => $dbName
        ]);
        setPageMessage(tr('SQL database successfully created.'), 'success');
        writeLog(
            sprintf('A new database (%s) has been created by %s', $dbName, $_SESSION['user_logged']), E_USER_NOTICE
        );
    } catch (iMSCPException $e) {
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
    $cfg = Registry::get('config');

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

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptStart);
customerHasFeature('sql') && !customerSqlDbLimitIsReached() or showBadRequestErrorPage();

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
generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
