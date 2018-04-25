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

// Switch back to admin
if (isset(Application::getInstance()->getSession()['logged_from']) && isset(Application::getInstance()->getSession()['logged_from_id'])
    && isset($_GET['action']) && $_GET['action'] == 'go_back'
) {
    Login::changeUserInterface(Application::getInstance()->getSession()['user_id'], Application::getInstance()->getSession()['logged_from_id']);
}

if (isset(Application::getInstance()->getSession()['user_id']) && isset($_GET['to_id'])) {
    // Switch to customer
    $toUserId = intval($_GET['to_id']);

    if (isset(Application::getInstance()->getSession()['logged_from']) && isset(Application::getInstance()->getSession()['logged_from_id'])) {
        // Admin logged as reseller
        $fromUserId = Application::getInstance()->getSession()['logged_from_id'];
    } else {
        // reseller to customer
        $fromUserId = Application::getInstance()->getSession()['user_id'];
        execQuery('SELECT COUNT(admin_id) FROM admin WHERE admin_id = ? AND created_by = ?', [$toUserId, $fromUserId])->fetchColumn() > 0 or
        View::showBadRequestErrorPage();
    }

    Login::changeUserInterface($fromUserId, $toUserId);
}

View::showBadRequestErrorPage();
