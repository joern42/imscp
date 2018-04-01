<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

use iMSCP\Net as Net;
use iMSCP\TemplateEngine;
use iMSCP_Events as Events;
use iMSCP_Registry as Registry;
use Zend_Session as Session;

/***********************************************************************************************************************
 * Functions
 */

/**
 * Send Json response
 *
 * @param int $statusCode HTTPD status code
 * @param array $data JSON data
 * @return void
 */
function sendJsonResponse($statusCode = 200, array $data = [])
{
    header('Cache-Control: no-cache, must-revalidate');
    header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
    header('Content-type: application/json');

    switch ($statusCode) {
        case 400:
            header('Status: 400 Bad Request');
            break;
        case 404:
            header('Status: 404 Not Found');
            break;
        case 500:
            header('Status: 500 Internal Server Error');
            break;
        case 501:
            header('Status: 501 Not Implemented');
            break;
        default:
            header('Status: 200 OK');
    }

    echo json_encode($data);
    exit;
}

/**
 * Generates page
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generatePage($tpl)
{
    generateIpsList($tpl);
    generateDevicesList($tpl);

    $ipConfigMode = isset($_POST['ip_config_mode']) && in_array($_POST['ip_config_mode'], ['auto', 'manual']) ? $_POST['ip_config_mode'] : 'auto';

    $tpl->assign([
        'VALUE_IP'         => isset($_POST['ip_number']) ? tohtml($_POST['ip_number']) : '',
        'VALUE_IP_NETMASK' => isset($_POST['ip_netmask']) ? tohtml($_POST['ip_netmask']) : 24,
        'IP_CONFIG_AUTO'   => $ipConfigMode == 'auto' ? ' checked' : '',
        'IP_CONFIG_MANUAL' => $ipConfigMode == 'manual' ? ' checked' : ''
    ]);
}

/**
 * Generates IPs list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateIpsList($tpl)
{
    $assignedIps = [];
    $stmt = execute_query('SELECT reseller_ips FROM reseller_props');
    while ($row = $stmt->fetch()) {
        $resellerIps = explode(';', $row['reseller_ips'], -1);
        foreach ($resellerIps as $ipId) {
            if (!in_array($ipId, $assignedIps)) {
                $assignedIps[] = $ipId;
            }
        }
    }

    $stmt = execute_query('SELECT * FROM server_ips');
    if (!$stmt->rowCount()) {
        $tpl->assign('IP_ADDRESSES_BLOCK', '');
        set_page_message(tohtml(tr('No IP address found.')), 'info');
        return;
    }

    $cfg = Registry::get('config');
    $isIPv6Allowed = $cfg['IPV6_SUPPORT'] == 'yes';
    $net = Net::getInstance();
    $baseServerIp = ($net->getVersion($cfg['BASE_SERVER_IP']) == 6) ? $net->compress($cfg['BASE_SERVER_IP']) : $cfg['BASE_SERVER_IP'];


    while ($row = $stmt->fetch()) {
        $ipAddrVersion = $net->getVersion($row['ip_number']) == 6;
        if ($ipAddrVersion == 6 && !$isIPv6Allowed) {
            continue;
        }

        $ipAddr = ($ipAddrVersion == 6) ? $net->compress($row['ip_number']) : $row['ip_number'];

        if ($baseServerIp === $ipAddr) {
            $actionName = $row['ip_status'] == 'ok' ? tohtml(tr('Protected')) : tohtml(translate_dmn_status($row['ip_status']));
            $actionIpId = NULL;
        } elseif (in_array($row['ip_id'], $assignedIps)) {
            $actionName = ($row['ip_status'] == 'ok') ? tohtml(tr('Assigned to at least one reseller')) : tohtml(translate_dmn_status($row['ip_status']));
            $actionIpId = NULL;
        } elseif ($row['ip_status'] == 'ok') {
            $actionName = tohtml(tr('Delete'));
            $actionIpId = $row['ip_id'];
        } else {
            $actionName = tohtml(translate_dmn_status($row['ip_status']));
            $actionIpId = NULL;
        }

        $tpl->assign([
            'IP'           => tohtml(($row['ip_number'] == '0.0.0.0') ? tohtml(tr('Any')) : tohtml($row['ip_number'])),
            'IP_NETMASK'   => $net->getIpPrefixLength($net->compress($row['ip_number'])) ?: $row['ip_netmask'] ?: tohtml(tr('N/A')),
            'IP_EDITABLE'  => ($row['ip_status'] == 'ok' && $baseServerIp != $ipAddr && $row['ip_config_mode'] != 'manual') ? true : false,
            'NETWORK_CARD' => ($row['ip_card'] === NULL) ? '' : (($row['ip_card'] !== 'any') ? tohtml($row['ip_card']) : tohtml(tr('Any')))
        ]);

        if ($row['ip_status'] == 'ok' && $row['ip_card'] != 'any' && $row['ip_number'] !== '0.0.0.0') {
            $tpl->assign([
                'IP_ID'            => $row['ip_id'],
                'IP_CONFIG_AUTO'   => $row['ip_config_mode'] != 'manual' ? ' checked' : '',
                'IP_CONFIG_MANUAL' => $row['ip_config_mode'] == 'manual' ? ' checked' : ''
            ]);
            $tpl->parse('IP_CONFIG_MODE_BLOCK', 'ip_config_mode_block');
        } else {
            $tpl->assign('IP_CONFIG_MODE_BLOCK', tohtml(tr('N/A')));
        }

        if ($actionIpId === NULL) {
            $tpl->assign('IP_ACTION_DELETE', $actionName);
        } else {
            $tpl->assign([
                'ACTION_NAME'  => $actionName,
                'ACTION_IP_ID' => $actionIpId
            ]);
            $tpl->parse('IP_ACTION_DELETE', 'ip_action_delete');
        }

        $tpl->parse('IP_ADDRESS_BLOCK', '.ip_address_block');
    }
}

/**
 * Generates network devices list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateDevicesList($tpl)
{
    $netDevices = array_filter(Net::getInstance()->getDevices(), function ($device) {
        return $device != 'lo';
    });

    if (empty($netDevices)) {
        set_page_message(tohtml(tr('Could not find any network interface. You cannot add new IP addresses.')), 'error');
        $tpl->assign('IP_ADDRESS_FORM_BLOCK', '');
        return;
    }

    sort($netDevices);
    foreach ($netDevices as $netDevice) {
        $tpl->assign([
            'NETWORK_CARD' => $netDevice,
            'SELECTED'     => isset($_POST['ip_card']) && $_POST['ip_card'] == $netDevice ? ' selected' : ''
        ]);
        $tpl->parse('NETWORK_CARD_BLOCK', '.network_card_block');
    }
}

/**
 * Reconfigure all server IP addresses
 *
 * @return void
 */
function reconfigureIpAddresses()
{
    execute_query("UPDATE server_ips SET ip_status = 'tochange' WHERE ip_status <> 'todelete'");
    set_page_message(tohtml(tr('Server IP addresses scheduled for reconfiguration.')), 'success');
    send_request();
    redirectTo('ip_manage.php');
}

/**
 * Checks IP data
 *
 * @param string $ipAddr IP address
 * @param int $ipNetmask IP netmask
 * @param string $ipConfigMode IP configuration mode
 * @param string $ipCard IP network card
 * @param bool $checkDuplicate Whether or not check for duplicate IP
 * @return bool TRUE if data are valid, FALSE otherwise
 */
function checkIpData($ipAddr, $ipNetmask, $ipConfigMode, $ipCard, $checkDuplicate = true)
{
    $errFieldsStack = [];

    // Validate IP addr
    if (filter_var($ipAddr, FILTER_VALIDATE_IP, FILTER_FLAG_NO_RES_RANGE) === false) {
        set_page_message(tr('Wrong or unallowed IP address.'), 'error');
        $errFieldsStack[] = 'ip_number';
    }

    $net = Net::getInstance();
    $isIPv6 = $net->getVersion($ipAddr) == 6;
    $isIPv6Allowed = Registry::get('config')['IPV6_SUPPORT'] == 'yes';

    if (!$isIPv6Allowed && $isIPv6) {
        set_page_message(tohtml(tr('IPv6 support is currently disabled. You cannot add new IPv6 IP addresses.')), 'error');
        $errFieldsStack[] = 'ip_number';
    }

    // Validate IP netmask
    if (!ctype_digit($ipNetmask) || $ipNetmask < 1 || ($isIPv6 && (!$isIPv6Allowed || $ipNetmask > 128)) || (!$isIPv6 && $ipNetmask > 32)) {
        set_page_message(tohtml(tr('Wrong or unallowed IP netmask.')), 'error');
        $errFieldsStack[] = 'ip_netmask';
    }

    // Validate Network interface
    $networkCards = Net::getInstance()->getDevices();
    if (!in_array($ipCard, $networkCards) || $ipCard == 'lo') {
        showBadRequestErrorPage();
    }

    // Validate IP addr configuration mode
    if (!in_array($ipConfigMode, ['auto', 'manual'], true)) {
        showBadRequestErrorPage();
    }

    if ($checkDuplicate) {
        $net = Net::getInstance();

        if ($net->getVersion($ipAddr) == 6) {
            $ipAddr = $net->compress($ipAddr);
        }

        // Make sure that $ipAddr is not already under the control of i-MSCP
        $stmt = execute_query('SELECT ip_number FROM server_ips');
        while ($row = $stmt->fetch()) {
            $cIpaddr = ($net->getVersion($row['ip_number']) == 6) ? $net->compress($row['ip_number']) : $row['ip_number'];
            if ($cIpaddr === $ipAddr) {
                set_page_message(tohtml(tr('IP address already under the control of i-MSCP.')), 'error');
                $errFieldsStack[] = 'ip_number';
                break;
            }
        }
    }

    if (!empty($errFieldsStack)) {
        if (!is_xhr()) {
            Registry::set('errFieldsStack', $errFieldsStack);
        }

        return false;
    }

    return true;
}

/**
 * Edit IP address
 *
 * @return void
 */
function editIpAddr()
{
    try {
        if (!isset($_POST['ip_id'])) {
            sendJsonResponse(400, ['message' => tr('Bad request.')]);
        }

        $ipId = intval($_POST['ip_id']);

        $stmt = exec_query("SELECT * FROM server_ips WHERE ip_id = ? AND ip_status = 'ok'", [$ipId]);
        if (!$stmt->rowCount()) {
            sendJsonResponse(400, ['message' => tr('Bad request.')]);
        }

        $net = Net::getInstance();
        $row = $stmt->fetch();
        $ipNetmask = isset($_POST['ip_netmask'])
            ? clean_input($_POST['ip_netmask'])
            : ($net->getIpPrefixLength($row['ip_number']) ?: ($row['ip_netmask'] ?: ($net->getVersion() == 4 ? 24 : 64)));
        $ipCard = isset($_POST['ip_card']) ? clean_input($_POST['ip_card']) : $row['ip_card'];
        $ipConfigMode = isset($_POST['ip_config_mode'][$ipId]) ? clean_input($_POST['ip_config_mode'][$ipId]) : $row['ip_config_mode'];

        if (!checkIpData($row['ip_number'], $ipNetmask, $ipConfigMode, $ipCard, false)) {
            Session::namespaceUnset('pageMessages');
            sendJsonResponse(400, ['message' => tr('Bad request.')]);
        }

        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onEditIpAddr, [
            'ip_id'          => $ipId,
            'ip_number'      => $row['ip_number'],
            'ip_netmask'     => $ipNetmask,
            'ip_card'        => $ipCard,
            'ip_config_mode' => $ipConfigMode
        ]);
        exec_query("UPDATE server_ips SET ip_netmask = ?, ip_card = ?, ip_config_mode = ?, ip_status = 'tochange' WHERE ip_id = ?", [
            $ipNetmask, $ipCard, $ipConfigMode, $ipId
        ]);
        send_request();
        write_log(sprintf("Configuration for the %s IP address has been updated by %s", $row['ip_number'], $_SESSION['user_logged']), E_USER_NOTICE);
        set_page_message(tohtml(tr('IP address successfully scheduled for modification.')), 'success');
        sendJsonResponse(200);
    } catch (\Exception $e) {
        sendJsonResponse(500, ['message' => sprintf('An unexpected error occurred: %s', $e->getMessage())]);
    }
}

/**
 * Add IP addr
 *
 * @return void
 */
function addIpAddr()
{
    $ipAddr = isset($_POST['ip_number']) ? clean_input($_POST['ip_number']) : '';
    $ipNetmask = isset($_POST['ip_netmask']) ? clean_input($_POST['ip_netmask']) : '';
    $ipCard = isset($_POST['ip_card']) ? clean_input($_POST['ip_card']) : '';
    $ipConfigMode = isset($_POST['ip_config_mode']) ? clean_input($_POST['ip_config_mode']) : '';

    if (!checkIpData($ipAddr, $ipNetmask, $ipConfigMode, $ipCard)) {
        return;
    }

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAddIpAddr, [
        'ip_number'      => $ipAddr,
        'ip_netmask'     => $ipNetmask,
        'ip_card'        => $ipCard,
        'ip_config_mode' => $ipConfigMode
    ]);

    exec_query("INSERT INTO server_ips (ip_number, ip_netmask, ip_card, ip_config_mode, ip_status) VALUES (?, ?, ?, ?, 'toadd')", [
        $ipAddr, $ipNetmask, $ipCard, $ipConfigMode
    ]);

    send_request();
    set_page_message(tohtml(tr('IP address successfully scheduled for addition.')), 'success');
    write_log(sprintf("An IP address (%s) has been added by %s", $ipAddr, $_SESSION['user_logged']), E_USER_NOTICE);
    redirectTo('ip_manage.php');
}

/***********************************************************************************************************************
 * Main
 */

require 'imscp-lib.php';

check_login('admin');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAdminScriptStart);

if (!empty($_POST)) {
    if (is_xhr()) {
        editIpAddr();
    }

    addIpAddr();
} elseif (isset($_GET['reconfigure'])) {
    reconfigureIpAddresses();
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                => 'shared/layouts/ui.tpl',
    'page'                  => 'admin/ip_manage.tpl',
    'page_message'          => 'layout',
    'ip_addresses_block'    => 'page',
    'ip_address_block'      => 'ip_addresses_block',
    'ip_config_mode_block'  => 'ip_address_block',
    'ip_action_delete'      => 'ip_address_block',
    'ip_address_form_block' => 'page',
    'network_card_block'    => 'ip_address_form_block'
]);
$tpl->assign([
    'TR_PAGE_TITLE'           => tohtml(tr('Admin / Settings / IP Management')),
    'TR_IP'                   => tohtml(tr('IP address')),
    'TR_IP_NETMASK'           => tohtml(tr('IP netmask')),
    'TR_ACTION'               => tohtml(tr('Action')),
    'TR_NETWORK_CARD'         => tohtml(tr('Network interface (NIC)')),
    'TR_RECONFIGURE'          => tohtml(tr('Force reconfiguration')),
    'TR_RECONFIGURE_TOOLTIP'  => tohtml(tr('Schedule reconfiguration of all server IP addresses.', 'htmlAttr')),
    'TR_ADD'                  => tohtml(tr('Add')),
    'TR_CANCEL'               => tohtml(tr('Cancel')),
    'TR_CONFIGURED_IPS'       => tohtml(tr('IP addresses under control of i-MSCP')),
    'TR_ADD_NEW_IP'           => tohtml(tr('Add new IP address')),
    'TR_TIP'                  => tohtml(tr('This interface allow to add or remove IP addresses.')),
    'TR_CONFIG_MODE'          => tohtml(tr('Configuration mode')),
    'TR_CONFIG_MODE_TOOLTIPS' => tohtml(tr("When set to 'Auto', the IP address is automatically configured.") . '<br>', 'htmlAttr')
        . tohtml(tr("When set to 'Manual', the configuration is left to the administrator.") . '<br><br>', 'htmlAttr')
        . tohtml(tr('Note that in manual mode, the NIC and the subnet mask are only indicative.'), 'htmlAttr'),
    'TR_AUTO'                 => tohtml(tr('Auto')),
    'TR_MANUAL'               => tohtml(tr('Manual'))
]);

Registry::get('iMSCP_Application')->getEventsManager()->registerListener('onGetJsTranslations', function ($e) {
    /** @var $e \iMSCP_Events_Event */
    $translation = $e->getParam('translations');
    $translation['core']['datatable'] = getDataTablesPluginTranslations(false);
    $translation['core']['err_fields_stack'] = Registry::isRegistered('errFieldsStack') ? Registry::get('errFieldsStack') : [];
    $translation['core']['confirm_deletion_msg'] = tr("Are you sure you want to delete the %%s IP address?");
    $translation['core']['confirm_reconfigure_msg'] = tr("Are you sure you want to schedule reconfiguration of all server IP addresses?");
    $translation['core']['edit_tooltip'] = tr("Click to edit");
});

generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAdminScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();

unsetMessages();
