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
 * Update SQL user password
 *
 * @param int $sqluId SQL user unique identifier
 * @çeturn void
 */
function updateSqlUserPassword($sqluId)
{
    $stmt = execQuery('SELECT sqlu_name, sqlu_host FROM sql_user WHERE sqlu_id = ?', [$sqluId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    isset($_POST['password']) && isset($_POST['password_confirmation']) or View::showBadRequestErrorPage();

    $password = cleanInput($_POST['password']);
    $passwordConf = cleanInput($_POST['password_confirmation']);

    if ($password == '') {
        setPageMessage(tr('The password cannot be empty.'), 'error');
        return;
    }

    if ($passwordConf == '') {
        setPageMessage(tr('Please confirm the password.'), 'error');
        return;
    }

    if ($password !== $passwordConf) {
        setPageMessage(tr('Passwords do not match.'), 'error');
        return;
    }

    if (!checkPasswordSyntax($password)) {
        return;
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditSqlUser, NULL, [
        'sqlUserId'       => $sqluId,
        'sqlUserPassword' => $password
    ]);

    // Here we cannot use transaction due to statements that cause an implicit commit. Thus we execute
    // those statements first to let the i-MSCP database in clean state if one of them fails.
    // See https://dev.mysql.com/doc/refman/5.7/en/implicit-commit.html for more details
    
    // Update SQL user password in the mysql system tables;
    $mysqlConfig = loadConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/mysql/mysql.data');
    if ($mysqlConfig['SQLD_VENDOR'] == 'MariaDB' || version_compare($mysqlConfig['SQLD_VERSION'], '5.7.6', '<')) {
        execQuery('SET PASSWORD FOR ?@? = PASSWORD(?)', [$row['sqlu_name'], $row['sqlu_host'], $password]);
    } else {
        execQuery('ALTER USER ?@? IDENTIFIED BY ? PASSWORD EXPIRE NEVER', [$row['sqlu_name'], $row['sqlu_host'], $password]);
    }

    setPageMessage(tr('SQL user password successfully updated.'), 'success');
    writeLog(sprintf('%s updated %s@%s SQL user password.', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), $row['sqlu_name'], $row['sqlu_host']), E_USER_NOTICE);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditSqlUser, NULL, [
        'sqlUserId'       => $sqluId,
        'sqlUserPassword' => $password
    ]);
    redirectTo('sql_manage.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param int $sqluId SQL user unique identifier
 * @return void
 */
function generatePage(TemplateEngine $tpl, $sqluId)
{
    $stmt = execQuery('SELECT sqlu_name, sqlu_host FROM sql_user WHERE sqlu_id = ?', [$sqluId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();
    $tpl->assign([
        'USER_NAME' => toHtml($row['sqlu_name']),
        'SQLU_ID'   => toHtml($sqluId, 'htmlAttr')
    ]);
}

/**
 * Checks if SQL user permissions
 *
 * @param  int $sqlUserId SQL user unique identifier
 * @return bool TRUE if the logged-in user has permission on SQL user, FALSE otherwise
 */
function checkSqlUserPerms($sqlUserId)
{
    return execQuery(
            '
            SELECT COUNT(t1.sqlu_id)
            FROM sql_user AS t1
            JOIN sql_database AS t2 USING(sqld_id)
            JOIN domain AS t3 USING(domain_id)
            WHERE t1.sqlu_id = ?
            AND t3.domain_admin_id = ?
        ',
            [$sqlUserId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
        )->fetchColumn() > 0;
}

require 'application.php';

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('sql') && isset($_REQUEST['sqlu_id']) or View::showBadRequestErrorPage();

$sqluId = intval($_REQUEST['sqlu_id']);

checkSqlUserPerms($sqluId) or View::showBadRequestErrorPage();

empty($_POST) or updateSqlUserPassword($sqluId);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'client/sql_change_password.tpl',
    'page_message' => 'layout'
]);
$tpl->assign([
    'TR_PAGE_TITLE'            => toHtml(tr('Client / Databases / Overview / Update SQL User Password')),
    'TR_SQL_USER_PASSWORD'     => toHtml(tr('SQL user password')),
    'TR_DB_USER'               => toHtml(tr('User')),
    'TR_PASSWORD'              => toHtml(tr('Password')),
    'TR_PASSWORD_CONFIRMATION' => toHtml(tr('Password confirmation')),
    'TR_UPDATE'                => toHtml(tr('Update'), 'htmlAttr'),
    'TR_CANCEL'                => toHtml(tr('Cancel'))
]);
View::generateNavigation($tpl);
generatePage($tpl, $sqluId);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
