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

use iMSCP\Functions\Daemon;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use iMSCP\Plugin\AbstractPlugin;

/**
 * Get user errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getUserErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT admin_name, admin_status, admin_id
            FROM admin
            WHERE admin_type = 'user'
            AND admin_status NOT IN ('ok', 'toadd', 'tochange', 'tochangepwd', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['USER_ITEM' => '', 'TR_USER_MESSAGE' => tr('No error found')]);
        $tpl->parse('USER_MESSAGE', 'user_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'USER_MESSAGE' => '',
            'USER_NAME'    => toHtml(decodeIdna($row['admin_name'])),
            'USER_ERROR'   => toHtml($row['admin_status']),
            'CHANGE_ID'    => toHtml($row['admin_id']),
            'CHANGE_TYPE'  => 'user'
        ]);
        $tpl->parse('USER_ITEM', '.user_item');
    }
}

/**
 * Get domain errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getDmnErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT domain_name, domain_status, domain_id
            FROM domain
            WHERE domain_status
            NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['DMN_ITEM' => '', 'TR_DMN_MESSAGE' => tr('No error found')]);
        $tpl->parse('DMN_MESSAGE', 'dmn_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'DMN_MESSAGE' => '',
            'DMN_NAME'    => toHtml(decodeIdna($row['domain_name'])),
            'DMN_ERROR'   => toHtml($row['domain_status']),
            'CHANGE_ID'   => toHtml($row['domain_id']),
            'CHANGE_TYPE' => 'domain'
        ]);
        $tpl->parse('DMN_ITEM', '.dmn_item');
    }
}

/**
 * Get domain aliases errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getAlsErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT alias_name, alias_status, alias_id
            FROM domain_aliases
            WHERE alias_status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete', 'ordered')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['ALS_ITEM' => '', 'TR_ALS_MESSAGE' => tr('No error found')]);
        $tpl->parse('ALS_MESSAGE', 'als_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'ALS_MESSAGE' => '',
            'ALS_NAME'    => toHtml(decodeIdna($row['alias_name'])),
            'ALS_ERROR'   => toHtml($row['alias_status']),
            'CHANGE_ID'   => $row['alias_id'],
            'CHANGE_TYPE' => 'alias',
        ]);
        $tpl->parse('ALS_ITEM', '.als_item');
    }
}

/**
 * Get subdomains errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getSubErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT subdomain_name, subdomain_status, subdomain_id, domain_name
            FROM subdomain
            LEFT JOIN domain ON (subdomain.domain_id = domain.domain_id)
            WHERE subdomain_status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete'                )
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['SUB_ITEM' => '', 'TR_SUB_MESSAGE' => tr('No error found')]);
        $tpl->parse('SUB_MESSAGE', 'sub_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'SUB_MESSAGE' => '',
            'SUB_NAME'    => toHtml(decodeIdna($row['subdomain_name'] . '.' . $row['domain_name'])),
            'SUB_ERROR'   => toHtml($row['subdomain_status']),
            'CHANGE_ID'   => $row['subdomain_id'],
            'CHANGE_TYPE' => 'subdomain'
        ]);
        $tpl->parse('SUB_ITEM', '.sub_item');
    }
}

/**
 * Get subdomain aliases errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getAlssubErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT subdomain_alias_name, subdomain_alias_status, subdomain_alias_id, alias_name
            FROM subdomain_alias
            LEFT JOIN domain_aliases ON (subdomain_alias_id = domain_aliases.alias_id)
            WHERE subdomain_alias_status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['ALSSUB_ITEM' => '', 'TR_ALSSUB_MESSAGE' => tr('No error found')]);
        $tpl->parse('ALSSUB_MESSAGE', 'alssub_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'ALSSUB_MESSAGE' => '',
            'ALSSUB_NAME'    => toHtml(decodeIdna($row['subdomain_alias_name'] . '.' . $row['alias_name'])),
            'ALSSUB_ERROR'   => toHtml($row['subdomain_alias_status']),
            'CHANGE_ID'      => $row['subdomain_alias_id'],
            'CHANGE_TYPE'    => 'subdomain_alias'
        ]);
        $tpl->parse('ALSSUB_ITEM', '.alssub_item');
    }
}

/**
 * Get custom dns errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getCustomDNSErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT domain_dns, domain_dns_status, domain_dns_id
            FROM domain_dns
            WHERE domain_dns_status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['CUSTOM_DNS_ITEM' => '', 'TR_CUSTOM_DNS_MESSAGE' => tr('No error found')]);
        $tpl->parse('CUSTOM_DNS_MESSAGE', 'custom_dns_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'CUSTOM_DNS_MESSAGE' => '',
            'CUSTOM_DNS_NAME'    => toHtml(decodeIdna($row['domain_dns'])),
            'CUSTOM_DNS_ERROR'   => toHtml($row['domain_dns_status']),
            'CHANGE_ID'          => toHtml($row['domain_dns_id']),
            'CHANGE_TYPE'        => 'custom_dns'
        ]);
        $tpl->parse('CUSTOM_DNS_ITEM', '.custom_dns_item');
    }
}

/**
 * Gets htaccess errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getHtaccessErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT id, dmn_id, auth_name AS name, status, 'htaccess' AS type
            FROM htaccess
            WHERE status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'todelete')
            UNION ALL
            SELECT id, dmn_id, ugroup AS name, status, 'htgroup' AS type
            FROM htaccess_groups
            WHERE status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'todelete')
            UNION ALL
            SELECT id, dmn_id, uname AS name, status, 'htpasswd' AS type
            FROM htaccess_users
            WHERE status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['HTACCESS_ITEM' => '', 'TR_HTACCESS_MESSAGE' => tr('No error found')]);
        $tpl->parse('HTACCESS_MESSAGE', 'htaccess_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'HTACCESS_MESSAGE' => '',
            'HTACCESS_NAME'    => toHtml($row['name']),
            'HTACCESS_TYPE'    => toHtml($row['type']),
            'HTACCESS_ERROR'   => toHtml($row['status']),
            'CHANGE_ID'        => $row['id'],
            'CHANGE_TYPE'      => $row['type']
        ]);
        $tpl->parse('HTACCESS_ITEM', '.htaccess_item');
    }
}

/**
 * Get FTP user errors
 *
 * @param TemplateEngine $tpl
 */
function debugger_getFtpUserErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT userid, status
            FROM ftp_users
            WHERE status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'toenable', 'todisable', 'todelete')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['FTP_ITEM' => '', 'TR_FTP_MESSAGE' => tr('No error found')]);
        $tpl->parse('FTP_MESSAGE', 'ftp_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'FTP_MESSAGE' => '',
            'FTP_NAME'    => toHtml(decodeIdna($row['userid'])),
            'FTP_ERROR'   => toHtml($row['status']),
            'CHANGE_ID'   => toHtml($row['userid']),
            'CHANGE_TYPE' => 'ftp'
        ]);
        $tpl->parse('FTP_ITEM', '.ftp_item');
    }
}

/**
 * Get mails errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getMailsErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "
            SELECT mail_acc, domain_id, mail_type, status, mail_id FROM mail_users
            WHERE status NOT IN ('ok', 'disabled', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete', 'ordered')
        "
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['MAIL_ITEM' => '', 'TR_MAIL_MESSAGE' => tr('No error found')]);
        $tpl->parse('MAIL_MESSAGE', 'mail_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $searchedId = $row['domain_id'];
        $mailAcc = $row['mail_acc'];
        $mailType = $row['mail_type'];
        $mailId = $row['mail_id'];
        $mailStatus = $row['status'];

        switch ($mailType) {
            case Mail::MT_NORMAL_MAIL:
            case Mail::MT_NORMAL_FORWARD:
            case Mail::MT_NORMAL_MAIL . ',' . Mail::MT_NORMAL_FORWARD:
                $query = "SELECT CONCAT('@', domain_name) AS domain_name FROM domain WHERE domain_id = ?";
                break;
            case Mail::MT_SUBDOM_MAIL:
            case Mail::MT_SUBDOM_FORWARD:
            case Mail::MT_SUBDOM_MAIL . ',' . Mail::MT_SUBDOM_FORWARD:
                $query = "
                    SELECT CONCAT('@', subdomain_name, '.', IF(t2.domain_name IS NULL,'" . tr('missing domain') . "',t2.domain_name)) AS 'domain_name'
                    FROM subdomain AS t1
                    LEFT JOIN domain AS t2 ON (t1.domain_id = t2.domain_id)
                    WHERE subdomain_id = ?
                ";
                break;
            case Mail::MT_ALSSUB_MAIL:
            case Mail::MT_ALSSUB_FORWARD:
            case Mail::MT_ALSSUB_MAIL . ',' . Mail::MT_ALSSUB_FORWARD:
                $query = "
                    SELECT CONCAT('@', t1.subdomain_alias_name, '.', IF(t2.alias_name IS NULL,'" . tr('missing alias')
                    . "',t2.alias_name) ) AS domain_name
                    FROM subdomain_alias AS t1
                    LEFT JOIN domain_aliases AS t2 ON (t1.alias_id = t2.alias_id)
                    WHERE subdomain_alias_id = ?
                ";
                break;
            case Mail::MT_NORMAL_CATCHALL:
            case Mail::MT_ALIAS_CATCHALL:
            case Mail::MT_ALSSUB_CATCHALL:
            case Mail::MT_SUBDOM_CATCHALL:
                $query = 'SELECT mail_addr AS domain_name FROM mail_users WHERE mail_id = ?';
                $searchedId = $mailId;
                $mailAcc = '';
                break;
            case Mail::MT_ALIAS_MAIL:
            case Mail::MT_ALIAS_FORWARD:
            case Mail::MT_ALIAS_MAIL . ',' . Mail::MT_ALIAS_FORWARD:
                $query = "SELECT CONCAT('@', alias_name) AS domain_name FROM domain_aliases WHERE alias_id = ?";
                break;
            default:
                throw new \Exception('FIXME: ' . __FILE__ . ':' . __LINE__ . $mailType);
        }

        $domainName = ltrim(execQuery($query, $searchedId)->fetchColumn(), '@');
        $tpl->assign([
            'MAIL_MESSAGE' => '',
            'MAIL_NAME'    => toHtml($mailAcc . '@' . ($domainName == '' ? ' ' . tr('orphan entry') : decodeIdna($domainName))),
            'MAIL_ERROR'   => toHtml($mailStatus),
            'CHANGE_ID'    => $mailId,
            'CHANGE_TYPE'  => 'mail'
        ]);
        $tpl->parse('MAIL_ITEM', '.mail_item');
    }
}

/**
 * Get IP errors
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function debugger_getIpErrors(TemplateEngine $tpl)
{
    $stmt = execQuery(
        "SELECT ip_id, ip_number, ip_card, ip_status FROM server_ips WHERE ip_status NOT IN ('ok', 'toadd', 'tochange', 'todelete')"
    );

    if (!$stmt->rowCount()) {
        $tpl->assign(['IP_ITEM' => '', 'TR_IP_MESSAGE' => tr('No error found')]);
        $tpl->parse('IP_MESSAGE', 'ip_message');
        return;
    }

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'IP_MESSAGE'  => '',
            'IP_NAME'     => toHtml((($row['ip_number'] == '0.0.0.0') ? tr('Any') : $row['ip_number'])
                . ' ' . '(' . $row['ip_card'] . (strpos($row['ip_number'], ':') == FALSE ? ':' . ($row['ip_id'] + 1000) : '') . ')'),
            'IP_ERROR'    => toHtml($row['ip_status']),
            'CHANGE_ID'   => toHtml($row['ip_id']),
            'CHANGE_TYPE' => 'ip'
        ]);
        $tpl->parse('IP_ITEM', '.ip_item');
    }
}

/**
 * Get plugin items errors
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function debugger_getPluginItemErrors(TemplateEngine $tpl)
{
    $pluginManager = Application::getInstance()->getPluginManager();

    /** @var AbstractPlugin[] $plugins */
    $plugins = $pluginManager->pluginGetLoaded();

    $itemFound = false;
    foreach ($plugins as $plugin) {
        $items = $plugin->getItemWithErrorStatus();

        if (!empty($items)) {
            $itemFound = true;
            foreach ($items as $item) {
                $tpl->assign([
                    'PLUGIN_ITEM_MESSAGE' => '',
                    'PLUGIN_NAME'         => toHtml($plugin->getName()) . ' (' . toHtml($item['item_name']) . ')',
                    'PLUGIN_ITEM_ERROR'   => toHtml($item['status']),
                    'CHANGE_ID'           => $item['item_id'],
                    'CHANGE_TYPE'         => toHtml($plugin->getName()),
                    'TABLE'               => toHtml($item['table']),
                    'FIELD'               => toHtml($item['field'])
                ]);
                $tpl->parse('PLUGIN_ITEM_ITEM', '.plugin_item_item');
            }
        }
    }

    if (!$itemFound) {
        $tpl->assign(['PLUGIN_ITEM_ITEM' => '', 'TR_PLUGIN_ITEM_MESSAGE' => tr('No error found')]);
        $tpl->parse('PLUGIN_ITEM_MESSAGE', 'plugin_item_message');
    }
}

/**
 * Change plugin item status
 *
 * @param string $pluginName Plugin name
 * @param string $table Table name
 * @param string $field Status field name
 * @param int $itemId item unique identifier
 * @return bool
 */
function debugger_changePluginItemStatus($pluginName, $table, $field, $itemId)
{
    $pluginManager = Application::getInstance()->getPluginManager();
    if ($pluginManager->pluginIsLoaded($pluginName)) {
        $pluginManager->pluginGet($pluginName)->changeItemStatus($table, $field, $itemId);
        return true;
    }

    return false;
}

/**
 * Returns the number of requests that still to run.
 *
 * Note: Without any argument, this function will trigger the getCountRequests() method on all enabled plugins
 *
 * @param string $statusField status database field name
 * @param string $tableName i-MSCP database table name
 * @return int Number of request
 */
function debugger_countRequests($statusField = NULL, $tableName = NULL)
{
    if (NULL !== $statusField && NULL !== $tableName) {
        $statusField = quoteIdentifier($statusField);
        $tableName = quoteIdentifier($tableName);
        $stmt = execQuery(
            "
                SELECT $statusField
                FROM $tableName
                WHERE $statusField IN ('toinstall', 'toupdate', 'touninstall', 'toadd', 'tochange', 'torestore', 'toenable', 'todisable','todelete')
            "
        );
        return $stmt->rowCount();
    }

    /** @var AbstractPlugin[] $plugins */
    $plugins = Application::getInstance()->getPluginManager()->pluginGetLoaded();
    $nbRequests = 0;

    if (!empty($plugins)) {
        foreach ($plugins as $plugin) {
            $nbRequests += $plugin->getCountRequests();
        }
    }

    return $nbRequests;
}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$rqstCount = debugger_countRequests('admin_status', 'admin');
$rqstCount += debugger_countRequests('domain_status', 'domain');
$rqstCount += debugger_countRequests('alias_status', 'domain_aliases');
$rqstCount += debugger_countRequests('subdomain_status', 'subdomain');
$rqstCount += debugger_countRequests('subdomain_alias_status', 'subdomain_alias');
$rqstCount += debugger_countRequests('domain_dns_status', 'domain_dns');
$rqstCount += debugger_countRequests('status', 'ftp_users');
$rqstCount += debugger_countRequests('status', 'mail_users');
$rqstCount += debugger_countRequests('status', 'htaccess');
$rqstCount += debugger_countRequests('status', 'htaccess_groups');
$rqstCount += debugger_countRequests('status', 'htaccess_users');
$rqstCount += debugger_countRequests('ip_status', 'server_ips');
$rqstCount += debugger_countRequests(); // Plugin items

if (isset($_GET['action'])) {
    if ($_GET['action'] == 'run') {
        if ($rqstCount > 0) {
            if (Daemon::sendRequest()) {
                setPageMessage(tr('Daemon request successful.'), 'success');
            } else {
                setPageMessage(tr('Daemon request failed.'), 'error');
            }
        } else {
            setPageMessage(tr('There is no pending task. Operation canceled.'), 'warning');
        }

        redirectTo('imscp_debugger.php');
        exit;
    }

    if ($_GET['action'] == 'change' && (isset($_GET['id']) && isset($_GET['type']))) {
        switch ($_GET['type']) {
            case 'user':
                $query = "UPDATE admin SET admin_status = 'tochange' WHERE admin_id = ?";
                break;
            case 'domain':
                $query = "UPDATE domain SET domain_status = 'tochange' WHERE domain_id = ?";
                break;
            case 'alias':
                $query = "UPDATE domain_aliases SET alias_status = 'tochange' WHERE alias_id = ?";
                break;
            case 'subdomain':
                $query = "UPDATE subdomain SET subdomain_status = 'tochange' WHERE subdomain_id = ?";
                break;
            case 'subdomain_alias':
                $query = "UPDATE subdomain_alias SET subdomain_alias_status = 'tochange' WHERE subdomain_alias_id = ?";
                break;
            case 'custom_dns':
                $query = "UPDATE domain_dns SET domain_dns_status = 'tochange' WHERE domain_dns_id = ?";
                break;
            case 'ftp':
                $query = "UPDATE ftp_users SET status = 'tochange' WHERE userid = ?";
                break;
            case 'mail':
                $query = "UPDATE mail_users SET status = 'tochange' WHERE mail_id = ?";
                break;
            case 'htaccess':
                $query = "UPDATE htaccess SET status = 'tochange'  WHERE id = ?";
                break;
            case 'htgroup':
                $query = "UPDATE htaccess_groups SET status = 'tochange' WHERE id = ?";
                break;
            case 'htpasswd':
                $query = "UPDATE htaccess_users SET status = 'tochange' WHERE id = ?";
                break;
            case 'ip':
                $query = "UPDATE server_ips SET ip_status = 'tochange' WHERE ip_id = ?";
                break;
            case 'plugin':
                $query = "UPDATE plugin SET plugin_status = 'tochange' WHERE plugin_id = ?";
                break;
            default:
                isset($_GET['table']) && isset($_GET['field']) or View::showBadRequestErrorPage();

                if (!debugger_changePluginItemStatus($_GET['type'], $_GET['table'], $_GET['field'], $_GET['id'])) {
                    setPageMessage(tr('Unknown type.'), 'error');
                } else {
                    setPageMessage(tr('Done'), 'success');
                }

                redirectTo('imscp_debugger.php');
                exit;
        }

        execQuery($query, [$_GET['id']]);
        setPageMessage(tr('Done'), 'success');
        redirectTo('imscp_debugger.php');
    }
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'              => 'shared/layouts/ui.tpl',
    'page'                => 'admin/imscp_debugger.tpl',
    'page_message'        => 'layout',
    'user_message'        => 'page',
    'user_item'           => 'page',
    'dmn_message'         => 'page',
    'dmn_item'            => 'page',
    'als_message'         => 'page',
    'als_item'            => 'page',
    'sub_message'         => 'page',
    'sub_item'            => 'page',
    'alssub_message'      => 'page',
    'alssub_item'         => 'page',
    'custom_dns_message'  => 'page',
    'custom_dns_item'     => 'page',
    'htaccess_message'    => 'page',
    'htaccess_item'       => 'page',
    'ftp_message'         => 'page',
    'ftp_item'            => 'page',
    'mail_message'        => 'page',
    'mail_item'           => 'page',
    'ip_message'          => 'page',
    'ip_item'             => 'page',
    'plugin_message'      => 'page',
    'plugin_item'         => 'page',
    'plugin_item_message' => 'page',
    'plugin_item_item'    => 'page'
]);
debugger_getUserErrors($tpl);
debugger_getDmnErrors($tpl);
debugger_getAlsErrors($tpl);
debugger_getSubErrors($tpl);
debugger_getAlssubErrors($tpl);
debugger_getCustomDNSErrors($tpl);
debugger_getFtpUserErrors($tpl);
debugger_getMailsErrors($tpl);
debugger_getHtaccessErrors($tpl);
debugger_getIpErrors($tpl);
debugger_getPluginItemErrors($tpl);
$tpl->assign([
    'TR_PAGE_TITLE'         => toHtml(tr('Admin / System Tools / Debugger')),
    'TR_USER_ERRORS'        => toHtml(tr('User errors')),
    'TR_DMN_ERRORS'         => toHtml(tr('Domain errors')),
    'TR_ALS_ERRORS'         => toHtml(tr('Domain alias errors')),
    'TR_SUB_ERRORS'         => toHtml(tr('Subdomain errors')),
    'TR_ALSSUB_ERRORS'      => toHtml(tr('Subdomain alias errors')),
    'TR_CUSTOM_DNS_ERRORS'  => toHtml(tr('Custom DNS errors')),
    'TR_FTP_ERRORS'         => toHtml(tr('FTP user errors')),
    'TR_MAIL_ERRORS'        => toHtml(tr('Mail account errors')),
    'TR_IP_ERRORS'          => toHtml(tr('IP errors')),
    'TR_HTACCESS_ERRORS'    => toHtml(tr('Htaccess, htgroups and htpasswd errors')),
    'TR_PLUGINS_ERRORS'     => toHtml(tr('Plugin errors')),
    'TR_PLUGIN_ITEM_ERRORS' => toHtml(tr('Plugin item errors')),
    'TR_PENDING_TASKS'      => toHtml(tr('Pending tasks')),
    'TR_EXEC_TASKS'         => toHtml(tr('Execute tasks')),
    'TR_CHANGE_STATUS'      => toHtml(tr('Change status of this item for a new attempt')),
    'EXEC_COUNT'            => toHtml($rqstCount)
]);
View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
