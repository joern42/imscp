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
use iMSCP\Functions\Counting;
use iMSCP\Functions\View;

/**
 * Check SQL permissions
 *
 * @param TemplateEngine $tpl
 * @param int $sqldId Database unique identifier
 * @return void
 */
function checkSqlUserPermissions(TemplateEngine $tpl, $sqldId)
{
    global $canAddNewSQLUser;

    $canAddNewSQLUser = true;
    $domainProps = getClientProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());

    if ($domainProps['domain_sqlu_limit'] != 0 && Counting::getCustomerSqlUsersCount($domainProps['domain_id']) >= $domainProps['domain_sqlu_limit']) {
        View::setPageMessage(tr("SQL users limit is reached. You cannot add new SQL users."), 'static_info');
        $canAddNewSQLUser = false;
        $tpl->assign('CREATE_SQLUSER', '');
    }

    $stmt = execQuery('SELECT COUNT(sqld_id) FROM sql_database JOIN domain USING(domain_id) WHERE sqld_id = ? AND domain_id = ?', [
        $sqldId, $domainProps['domain_id']
    ]);
    $stmt->fetchColumn() or View::showBadRequestErrorPage();
}

/**
 * Get SQL user list
 *
 * @param TemplateEngine $tpl
 * @param int $sqldId Database unique identifier
 * @return void
 */
function generateSqlUserList(TemplateEngine $tpl, $sqldId)
{
    global $canAddNewSQLUser;

    // Select all SQL users that are owned by the customer except those that are
    // already assigned to $sqldId
    $stmt = execQuery(
        "
            SELECT MAX(t1.sqlu_id) AS sqlu_id, t1.sqlu_name, t1.sqlu_host
            FROM sql_user AS t1
            JOIN sql_database AS t2 USING(sqld_id)
            WHERE t2.sqld_id <> ?
            AND t2.domain_id = ?
            AND CONCAT(t1.sqlu_name, t1.sqlu_host) NOT IN(SELECT CONCAT(sqlu_name, sqlu_host) FROM sql_user WHERE sqld_id = ?)
            GROUP BY t1.sqlu_name, t1.sqlu_host
        ",
        [$sqldId, getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId()), $sqldId]
    );

    if ($stmt->rowCount()) {
        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'SQLUSER_ID'  => $row['sqlu_id'],
                'SQLUSER_IDN' => toHtml($row['sqlu_name'] . '@' . decodeIdna($row['sqlu_host'])),
            ]);
            $tpl->parse('SQLUSER_LIST', '.sqluser_list');
        }

        return;
    }

    $canAddNewSQLUser or View::showBadRequestErrorPage();

    $tpl->assign('SHOW_SQLUSER_LIST', '');
}

/**
 * Does the given SQL user already exists?
 *
 * @param string $sqlUser SQL user name
 * @param string $sqlUserHost SQL user host
 * @return bool TRUE if the given sql user already exists, FALSE otherwise
 */
function isSqlUser($sqlUser, $sqlUserHost)
{
    return execQuery('SELECT COUNT(User) FROM mysql.user WHERE User = ? AND Host = ?', [$sqlUser, $sqlUserHost])->fetchColumn() > 0;
}

/**
 * Add SQL user for the given database
 *
 * @param int $sqldId Database unique identifier
 * @return void
 */
function addSqlUser($sqldId)
{
    isset($_POST['uaction']) or View::showBadRequestErrorPage();

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $dmnId = getCustomerMainDomainId($identity->getUserId());

    if (!isset($_POST['reuse_sqluser'])) {
        $needUserCreate = true;

        if (!isset($_POST['user_name']) || !isset($_POST['user_host']) || !isset($_POST['pass']) || !isset($_POST['pass_rep'])) {
            View::showBadRequestErrorPage();
        }

        $user = cleanInput($_POST['user_name']);
        $host = cleanInput($_POST['user_host']);
        $password = cleanInput($_POST['pass']);
        $passwordConf = cleanInput($_POST['pass_rep']);

        if ($user == '') {
            View::setPageMessage(tr('Please enter an username.'), 'error');
            return;
        }

        if ($host == '') {
            View::setPageMessage(tr('Please enter an SQL user host.'), 'error');
            return;
        }

        $host = encodeIdna(cleanInput($_POST['user_host']));

        if ($host != '%' && $host !== 'localhost'
            && !Validator::getInstance()->hostname($host, ['allow' => ValidateHostname::ALLOW_DNS | ValidateHostname::ALLOW_IP])
        ) {
            View::setPageMessage(tr('Invalid SQL user host: %s', Validator::getInstance()->getLastValidationMessages()), 'error');
            return;
        }

        if ($password == '') {
            View::setPageMessage(tr('Please enter a password.'), 'error');
            return;
        }

        if ($password !== $passwordConf) {
            View::setPageMessage(tr('Passwords do not match.'), 'error');
            return;
        }

        if (!checkPasswordSyntax($password)) {
            return;
        }

        if (isset($_POST['use_dmn_id']) && $_POST['use_dmn_id'] == 'on' && isset($_POST['id_pos']) && $_POST['id_pos'] == 'start') {
            $user = $dmnId . '_' . cleanInput($_POST['user_name']);
        } elseif (isset($_POST['use_dmn_id']) && $_POST['use_dmn_id'] == 'on' && isset($_POST['id_pos']) && $_POST['id_pos'] == 'end') {
            $user = cleanInput($_POST['user_name']) . '_' . $dmnId;
        } else {
            $user = cleanInput($_POST['user_name']);
        }

        if (strlen($user) > 16) {
            View::setPageMessage(tr('SQL username is too long.'), 'error');
            return;
        }

        if (isSqlUser($user, $host) || in_array($user, ['debian-sys-maint', 'mysql.user', 'root'])) {
            View::setPageMessage(tr("The %s SQL user is not available or not permitted.", $user . '@' . decodeIdna($host)), 'error');
            return;
        }
    } elseif (isset($_POST['sqluser_id'])) { // Using existing SQL user as specified in input data
        $needUserCreate = false;
        $stmt = execQuery(
            '
                SELECT t1.sqlu_name, t1.sqlu_host
                FROM sql_user AS t1
                JOIN sql_database as t2 USING(sqld_id)
                WHERE t1.sqlu_id = ?
                AND t1.sqld_id <> ?
                AND t2.domain_id = ?
            ',
            [intval($_POST['sqluser_id']), $sqldId, $dmnId]
        );

        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();
        $user = $row['sqlu_name'];
        $host = $row['sqlu_host'];
    } else {
        View::showBadRequestErrorPage();
        return;
    }

    # Retrieve database to which SQL user should be assigned
    $stmt = execQuery('SELECT sqld_name FROM sql_database WHERE sqld_id = ? AND domain_id = ?', [$sqldId, $dmnId]);
    $stmt->rowCount() or View::showBadRequestErrorPage();
    $row = $stmt->fetch();

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddSqlUser, NULL, [
        'SqlUsername'     => $user,
        'SqlUserHost'     => $host,
        'SqlUserPassword' => isset($password) ? $password : ''
    ]);

    // Here we cannot use transaction due to statements that cause an implicit commit. Thus we execute
    // those statements first to let the i-MSCP database in clean state if one of them fails.
    // See https://dev.mysql.com/doc/refman/5.7/en/implicit-commit.html for more details

    if ($needUserCreate && isset($password)) {
        $mysqlConfig = loadServiceConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/mysql/mysql.data');
        if ($mysqlConfig['SQLD_VENDOR'] == 'MariaDB' || version_compare($mysqlConfig['SQLD_VERSION'], '5.7.6', '<')) {
            execQuery('CREATE USER ?@? IDENTIFIED BY ?', [$user, $host, $password]);
        } else {
            execQuery('CREATE USER ?@? IDENTIFIED BY ? PASSWORD EXPIRE NEVER', [$user, $host, $password]);
        }
    }

    // According MySQL documentation (http://dev.mysql.com/doc/refman/5.5/en/grant.html#grant-accounts-passwords)
    // The “_” and “%” wildcards are permitted when specifying database names in GRANT statements that grant privileges
    // at the global or database levels. This means, for example, that if you want to use a “_” character as part of a
    // database name, you should specify it as “\_” in the GRANT statement, to prevent the user from being able to
    // access additional databases matching the wildcard pattern; for example, GRANT ... ON `foo\_bar`.* TO ....
    //
    // In practice, without escaping, an user added for db `a_c` would also have access to a db `abc`.
    $row['sqld_name'] = preg_replace('/([%_])/', '\\\\$1', $row['sqld_name']);

    execQuery(sprintf('GRANT ALL PRIVILEGES ON %s.* TO ?@?', quoteIdentifier($row['sqld_name'])), [$user, $host]);
    execQuery('INSERT INTO sql_user (sqld_id, sqlu_name, sqlu_host) VALUES (?, ?, ?)', [$sqldId, $user, $host]);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterAddSqlUser, NULL, [
        'SqlUserId'       => Application::getInstance()->getDb()->getDriver()->getLastGeneratedValue(),
        'SqlUsername'     => $user,
        'SqlUserHost'     => $host,
        'SqlUserPassword' => isset($password) ? $password : '',
        'SqlDatabaseId'   => $sqldId
    ]);
    writeLog(sprintf('A SQL user has been added by %s', getProcessorUsername($identity)), E_USER_NOTICE);
    View::setPageMessage(tr('SQL user successfully added.'), 'success');
    redirectTo('sql_manage.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl
 * @param int $sqldId
 * @return void
 */
function generatePage(TemplateEngine $tpl, $sqldId)
{
    checkSqlUserPermissions($tpl, $sqldId);
    generateSqlUserList($tpl, $sqldId);

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

    if (isset($_POST['uaction']) && $_POST['uaction'] == 'add_user') {
        $tpl->assign([
            'USER_NAME'             => isset($_POST['user_name']) ? toHtml($_POST['user_name'], true) : '',
            'USER_HOST'             => isset($_POST['user_host']) ? toHtml($_POST['user_host'], true) : '',
            'USE_DMN_ID'            => isset($_POST['use_dmn_id']) && $_POST['use_dmn_id'] === 'on' ? ' checked' : '',
            'START_ID_POS_SELECTED' => isset($_POST['id_pos']) && $_POST['id_pos'] !== 'end' ? ' selected' : '',
            'END_ID_POS_SELECTED'   => isset($_POST['id_pos']) && $_POST['id_pos'] === 'end' ? ' selected' : ''
        ]);
    } else {
        $tpl->assign([
            'USER_NAME'             => '',
            'USER_HOST'             => toHtml(
                $cfg['DATABASE_USER_HOST'] == '127.0.0.1' ? 'localhost' : decodeIdna($cfg['DATABASE_USER_HOST'])
            ),
            'USE_DMN_ID'            => '',
            'START_ID_POS_SELECTED' => ' selected',
            'END_ID_POS_SELECTED'   => ''
        ]);
    }

    $tpl->assign('SQLD_ID', $sqldId);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('sql') && isset($_REQUEST['sqld_id']) or View::showBadRequestErrorPage();

$sqldId = intval($_REQUEST['sqld_id']);

if(Application::getInstance()->getRequest()->isPost()) {
    addSqlUser($sqldId);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'               => 'shared/layouts/ui.tpl',
    'page'                 => 'client/sql_user_add.tpl',
    'page_message'         => 'layout',
    'show_sqluser_list'    => 'page',
    'sqluser_list'         => 'show_sqluser_list',
    'create_sqluser'       => 'page',
    'mysql_prefix_yes'     => 'create_sqluser',
    'mysql_prefix_no'      => 'create_sqluser',
    'mysql_prefix_all'     => 'create_sqluser',
    'mysql_prefix_infront' => 'create_sqluser',
    'mysql_prefix_behind'  => 'create_sqluser'
]);
$tpl->assign([
    'TR_PAGE_TITLE'               => toHtml(tr('Client / Databases / Overview / Add SQL User')),
    'TR_USER_NAME'                => toHtml(tr('SQL user name')),
    'TR_USER_HOST'                => toHtml(tr('SQL user host')),
    'TR_USER_HOST_TIP'            => toHtml(tr("This is the host from which this SQL user must be allowed to connect to the SQL server. Enter the %s wildcard character to allow this SQL user to connect from any host.", '%'), 'htmlAttr'),
    'TR_USE_DMN_ID'               => toHtml(tr('SQL user prefix/suffix')),
    'TR_START_ID_POS'             => toHtml(tr('In front')),
    'TR_END_ID_POS'               => toHtml(tr('Behind')),
    'TR_ADD'                      => toHtml(tr('Add'), 'htmlAttr'),
    'TR_CANCEL'                   => toHtml(tr('Cancel')),
    'TR_ADD_EXIST'                => toHtml(tr('Assign'), 'htmlAttr'),
    'TR_PASS'                     => toHtml(tr('Password')),
    'TR_PASS_REP'                 => toHtml(tr('Repeat password')),
    'TR_SQL_USER_NAME'            => toHtml(tr('SQL users')),
    'TR_ASSIGN_EXISTING_SQL_USER' => toHtml(tr('Assign existing SQL user')),
    'TR_NEW_SQL_USER_DATA'        => toHtml(tr('New SQL user data'))
]);
View::generateNavigation($tpl);
generatePage($tpl, $sqldId);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
