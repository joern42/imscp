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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\View;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::userHasFeature('webProtectedAreas') && isset($_GET['gname']) or View::showBadRequestErrorPage();

$db = Application::getInstance()->getDb();

try {
    $db->getDriver()->getConnection()->beginTransaction();

    $identity = Application::getInstance()->getAuthService()->getIdentity();
    $htgroupId = intval($_GET['gname']);
    $domainId = getCustomerMainDomainId($identity->getUserId());

    // Schedule deletion or update of any .htaccess files in which the htgroup was used
    $stmt = execQuery('SELECT * FROM htaccess WHERE dmn_id = ?', [$domainId]);

    while ($row = $stmt->fetch()) {
        $htgroupList = explode(',', $row['group_id']);
        $candidate = array_search($htgroupId, $htgroupList);

        if ($candidate === false) {
            continue;
        }

        unset($htgroupList[$candidate]);

        if (empty($htgroupList)) {
            $status = 'todelete';
        } else {
            $htgroupList = implode(',', $htgroupList);
            $status = 'tochange';
        }

        execQuery('UPDATE htaccess SET group_id = ?, status = ? WHERE id = ?', [$htgroupList, $status, $row['id']]);
    }

    // Schedule htgroup deletion
    execQuery("UPDATE htaccess_groups SET status = 'todelete' WHERE id = ? AND dmn_id = ?", [$htgroupId, $domainId]);
    $db->getDriver()->getConnection()->commit();
    View::setPageMessage(tr('Htaccess group successfully scheduled for deletion.'), 'success');
    Daemon::sendRequest();
    writeLog(sprintf('%s deleted Htaccess group ID: %s', getProcessorUsername($identity), $htgroupId), E_USER_NOTICE);
} catch (\Exception $e) {
    $db->getDriver()->getConnection()->rollBack();
    View::setPageMessage(tr('An unexpected error occurred. Please contact your reseller.'), 'error');
    writeLog(sprintf('Could not delete htaccess group: %s', $e->getMessage()));
}

redirectTo('protected_user_manage.php');
