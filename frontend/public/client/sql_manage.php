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
 * Can add SQL user for the given SQL database?
 *
 * @param int $sqldId SQL database unique identifier
 * @return bool
 */
function canAddSQLUserForDatabase($sqldId)
{
    $userId = Application::getInstance()->getAuthService()->getIdentity()->getUserId();
    $domainProps = getCustomerProperties($userId);

    if ($domainProps['domain_sqlu_limit'] == 0) {
        return true;
    }

    if (Counting::getCustomerSqlUsersCount($domainProps['domain_id']) >= $domainProps['domain_sqlu_limit']) {
        // Count all SQL users that are owned by the customer, excluding those
        // that are already assigned to $sqldId
        return execQuery(
                '
                SELECT COUNT(sqlu_id)
                FROM sql_user AS t1
                JOIN sql_database as t2 USING(sqld_id)
                WHERE t2.sqld_id <> ?
                AND t2.domain_id = ?
                AND CONCAT(t1.sqlu_name, t1.sqlu_host) NOT IN(
                SELECT CONCAT(sqlu_name, sqlu_host) FROM sql_user WHERE sqld_id = ?
            )',
                [$sqldId, getCustomerMainDomainId($userId), $sqldId]
            )->fetchColumn() > 0;
    }

    return true;
}

/**
 * Generates database sql users list
 *
 * @param TemplateEngine $tpl Template engine
 * @param int $sqldId Database unique identifier
 * @return void
 */
function generateDatabaseSqlUserList(TemplateEngine $tpl, $sqldId)
{
    $stmt = execQuery('SELECT sqlu_id, sqlu_name, sqlu_host FROM sql_user WHERE sqld_id = ? ORDER BY sqlu_name', [$sqldId]);

    if (!$stmt->rowCount()) {
        $tpl->assign('SQL_USERS_LIST', '');
        return;
    }

    $tpl->assign([
        'SQL_USERS_LIST'          => '',
        'TR_DB_USER'              => toHtml(tr('User')),
        'TR_DB_USER_HOST'         => toHtml(tr('Host')),
        'TR_DB_USER_HOST_TOOLTIP' => toHtml(tr('Host from which SQL user is allowed to connect to SQL server'), 'htmlAttr')
    ]);

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'DB_USER'      => toHtml($row['sqlu_name']),
            'DB_USER_HOST' => toHtml(decodeIdna($row['sqlu_host'])),
            'DB_USER_JS'   => toJs($row['sqlu_name']),
            'SQLU_ID'      => toHtml($row['sqlu_id'], 'htmlAttr')
        ]);
        $tpl->parse('SQL_USERS_LIST', '.sql_users_list');
    }
}

/**
 * Generates databases list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $stmt = execQuery('SELECT sqld_id, sqld_name FROM sql_database WHERE domain_id = ? ORDER BY sqld_name ', [
        getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId())
    ]);

    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('You do not have databases.'), 'static_info');
        $tpl->assign('SQL_DATABASES_USERS_LIST', '');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'SQLD_ID'    => $row['sqld_id'],
            'DB_NAME'    => toHtml($row['sqld_name']),
            'DB_NAME_JS' => toJs($row['sqld_name'])
        ]);

        if (!canAddSQLUserForDatabase($row['sqld_id'])) {
            $tpl->assign('SQL_USER_ADD_LINK', '');
        } else {
            $tpl->parse('SQL_USER_ADD_LINK', 'sql_user_add_link');
        }

        generateDatabaseSqlUserList($tpl, $row['sqld_id']);
        $tpl->parse('SQL_DATABASES_LIST', '.sql_databases_list');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('sql') or View::showBadRequestErrorPage();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                   => 'shared/layouts/ui.tpl',
    'page'                     => 'client/sql_manage.tpl',
    'page_message'             => 'layout',
    'sql_databases_users_list' => 'page',
    'sql_databases_list'       => 'sql_databases_users_list',
    'sql_users_list'           => 'sql_databases_list',
    'sql_user_add_link'        => 'sql_databases_list'
]);
$tpl->assign([
    'TR_PAGE_TITLE'              => toHtml(tr('Client / Databases / Overview')),
    'TR_MANAGE_SQL'              => toHtml(tr('Manage SQL')),
    'TR_DELETE'                  => toHtml(tr('Delete')),
    'TR_DATABASE'                => toHtml(tr('Database Name and Users')),
    'TR_CHANGE_PASSWORD'         => toHtml(tr('Update password')),
    'TR_ACTIONS'                 => toHtml(tr('Actions')),
    'TR_DATABASE_USERS'          => toHtml(tr('Database users')),
    'TR_ADD_USER'                => toHtml(tr('Add SQL user')),
    'TR_DATABASE_MESSAGE_DELETE' => toJs(tr("This database will be permanently deleted. This process cannot be recovered. All users linked to this database will also be deleted if not linked to another database. Are you sure you want to delete the '%s' database?", '%s')),
    'TR_USER_MESSAGE_DELETE'     => toJs(tr('Are you sure you want delete the %s SQL user?', '%s'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
