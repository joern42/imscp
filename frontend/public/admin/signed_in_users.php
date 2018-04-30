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

/**
 * Sign out an user
 *
 * @return void
 */
function signOutUser()
{
    $request = Application::getInstance()->getRequest();
    $action = $request->getQuery('action');
    $sid = $request->getQuery('sid');

    if (NULL === $action || NULL === $sid) {
        return;
    }

    $action = 'signout' or View::showBadRequestErrorPage();

    $stmt = Application::getInstance()->getDb()->createStatement('SELECT user_name FROM login WHERE session_id = ? AND user_name IS NOT NULL');
    $result = $stmt->execute([$sid])->getResource();
    if ($result->rowCount() < 1) {
        View::setPageMessage(tr('Session with ID %s not found', 'warning'));
        return;
    }

    $sessUsername = $result->fetch()['user_name'];
    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $csid = session_id();

    if ($csid == $sid) {
        View::showBadRequestErrorPage();
        View::setPageMessage(tr('You cannot act on your own session.'), 'error');
        redirectTo('signed_in_users.php');
    }

    // Close $csid session
    session_write_close();

    // destroy $sid session
    session_id($sid);
    session_start();
    session_destroy();

    Application::getInstance()->getDb()->createStatement('DELETE FROM login WHERE session_id = ? AND user_name IS NOT NULL')->execute([$sid]);

    // Restore $csid session
    session_id($csid);
    session_start();

    View::setPageMessage(tr('User has been successfully signed out.'), 'success');
    writeLog(sprintf('%s user has been signed out by %s', $sessUsername, $identity->getUsername()), E_USER_NOTICE);
    redirectTo('signed_in_users.php');
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generatePage($tpl)
{
    signOutUser();

    $session = Application::getInstance()->getSession();
    $thissid = $session->getManager()->getId();
    $stmt = Application::getInstance()->getDb()->createStatement(
        '
            SELECT t1.session_id, t1.ipaddr, t1.user_name, t1.lastaccess, t2.admin_type
            FROM login AS t1
            JOIN admin AS t2 ON(t2.admin_name = t1.user_name)
        '
    );
    $result = $stmt->execute()->getResource();

    $cusername = Application::getInstance()->getAuthService()->getIdentity()->getUsername();

    while ($row = $result->fetch()) {
        $tpl->assign([
            'USERNAME'    => toHtml($row['user_name'])
                . ($row['user_name'] == $cusername && $thissid != $row['session_id'] ? ' (' . tr('from another browser') . ')' : ''),
            'USER_TYPE'   => toHtml($row['admin_type']),
            'IP_ADDRESS'  => toHtml($row['ipaddr']),
            'LAST_ACCESS' => toHtml(date('G:i:s', $row['lastaccess'])),
            'SID'         => toHtml($row['session_id'], 'htmlAttr')
        ]);

        if ($thissid == $row['session_id']) {
            $tpl->assign('SESSION_ACTIONS_BLOCK', '');
        } else {
            $tpl->parse('SESSION_ACTIONS_BLOCK', 'session_actions_block');
        }

        $tpl->parse('SESSION_BLOCK', '.session_block');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                => 'shared/layouts/ui.tpl',
    'page'                  => 'admin/signed_in_users.tpl',
    'page_message'          => 'layout',
    'session_block'         => 'page',
    'session_actions_block' => 'session_block'
]);
$tpl->assign([
    'TR_PAGE_TITLE'   => toHtml(tr('Admin / Users / Sessions')),
    'TR_USERNAME'     => toHtml(tr('Username')),
    'TR_IP_ADDRESS'   => toHtml(tr('IP address')),
    'TR_USER_TYPE'    => toHtml(tr('User type')),
    'TR_LAST_ACCESS'  => toHtml(tr('Last access')),
    'TR_ACTIONS'      => toHtml(tr('Actions')),
    'TR_ACT_SIGN_OUT' => toHtml(tr('Sign out user')),
    'TR_ACT_DESTROY'  => toHtml(tr('Destroy user session'))
]);
View::generateNavigation($tpl);
generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
