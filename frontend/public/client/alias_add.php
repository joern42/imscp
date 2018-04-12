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

use iMSCP\PHPini;
use iMSCP\TemplateEngine;
use iMSCP_Authentication as Authentication;
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

/***********************************************************************************************************************
 * Functions
 */

/**
 * Send alias order email
 *
 * @param  string $aliasName
 * @return bool TRUE on success, FALSE on failure
 */
function send_alias_order_email($aliasName)
{
    $stmt = exec_query('SELECT admin_name, created_by, fname, lname, email FROM admin WHERE admin_id = ?', [$_SESSION['user_id']]);
    $row = $stmt->fetch();
    $data = get_alias_order_email($row['created_by']);
    $ret = send_mail([
        'mail_id'      => 'alias-order-msg',
        'fname'        => $row['fname'],
        'lname'        => $row['lname'],
        'username'     => $row['admin_name'],
        'email'        => $row['email'],
        'subject'      => $data['subject'],
        'message'      => $data['message'],
        'placeholders' => [
            '{CUSTOMER}' => decode_idna($row['admin_name']),
            '{ALIAS}'    => $aliasName
        ]
    ]);

    if (!$ret) {
        write_log(sprintf("Couldn't send domain alias order email to %s", $row['admin_name']), E_USER_ERROR);
        return false;
    }

    return true;
}

/**
 * Get domains list
 *
 * @return array Domains list
 */
function getDomainsList()
{
    static $domainsList = NULL;

    if (NULL !== $domainsList) {
        return $domainsList;
    }

    $domainsList = [];
    $mainDmnProps = get_domain_default_props($_SESSION['user_id']);

    if ($mainDmnProps['url_forward'] == 'no') {
        $domainsList = [[
            'name'        => $mainDmnProps['domain_name'],
            'id'          => $mainDmnProps['domain_id'],
            'type'        => 'dmn',
            'mount_point' => '/'
        ]];
    }

    $stmt = exec_query(
        "
            SELECT CONCAT(t1.subdomain_name, '.', t2.domain_name) AS name, t1.subdomain_mount AS mount_point
            FROM subdomain AS t1
            JOIN domain AS t2 USING(domain_id)
            WHERE t1.domain_id = ?
            AND t1.subdomain_status = 'ok'
            AND t1.subdomain_url_forward = 'no'
            UNION ALL
            SELECT alias_name AS name, alias_mount AS mount_point
            FROM domain_aliases
            WHERE domain_id = ?
            AND alias_status = 'ok'
            AND url_forward = 'no'
            UNION ALL
            SELECT CONCAT(t1.subdomain_alias_name, '.', t2.alias_name) AS name, t1.subdomain_alias_mount AS mount_point
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            WHERE t2.domain_id = ?
            AND t1.subdomain_alias_status = 'ok'
            AND t1.subdomain_alias_url_forward = 'no'
        ",
        [$mainDmnProps['domain_id'], $mainDmnProps['domain_id'], $mainDmnProps['domain_id']]
    );

    if ($stmt->rowCount()) {
        $domainsList = array_merge($domainsList, $stmt->fetchAll());
        usort($domainsList, function ($a, $b) {
            return strnatcmp(decode_idna($a['name']), decode_idna($b['name']));
        });
    }

    return $domainsList;
}

/**
 * Add domain alias
 *
 * @return bool TRUE on success, FALSE on failure
 */
function addDomainAlias()
{
    global $mainDmnProps;

    $ret = true;
    $domainAliasName = isset($_POST['domain_alias_name']) ? mb_strtolower(clean_input($_POST['domain_alias_name'])) : '';

    // Check for domain alias name
    if ($domainAliasName == '') {
        set_page_message(tr('You must enter a domain alias name.'), 'error');
        $ret = false;
    } else {
        // www is considered as an alias of the domain alias
        while (strpos($domainAliasName, 'www.') === 0) {
            $domainAliasName = substr($domainAliasName, 4);
        }

        // Check for domain alias name syntax
        global $dmnNameValidationErrMsg;
        if (!isValidDomainName($domainAliasName)) {
            set_page_message(tohtml($dmnNameValidationErrMsg), 'error');
            $ret = false;
        } elseif (imscp_domain_exists($domainAliasName, $_SESSION['user_created_by'])) {
            // Check for domain alias existence
            set_page_message(tr('Domain %s is unavailable.', "<strong>$domainAliasName</strong>"), 'error');
            $ret = false;
        }
    }

    // Check for domain alias IP addresses
    $domainAliasIps = [];
    if (empty($_POST['alias_ips'])) {
        set_page_message(tohtml(tr('You must assign at least one IP address to that domain alias.')), 'error');
        $ret = false;
    } elseif (!is_array($_POST['alias_ips'])) {
        showBadRequestErrorPage();
    } else {
        $clientIps = explode(',', $mainDmnProps['domain_client_ips']);
        $domainAliasIps = array_intersect($_POST['alias_ips'], $clientIps);
        if (count($domainAliasIps) < count($_POST['alias_ips'])) {
            // Situation where unknown IP address identifier has been submitten
            showBadRequestErrorPage();
        }
    }

    if ($ret === FALSE) {
        return false;
    }

    $domainAliasNameAscii = encode_idna($domainAliasName);

    // Set default mount point
    $mountPoint = "/$domainAliasNameAscii";

    // Check for shared mount point option
    if (isset($_POST['shared_mount_point']) && $_POST['shared_mount_point'] == 'yes') { // We are safe here
        if (!isset($_POST['shared_mount_point_domain'])) {
            showBadRequestErrorPage();
        }

        $sharedMountPointDomain = clean_input($_POST['shared_mount_point_domain']);
        $domainList = getDomainsList();
        !empty($domainList) or showBadRequestErrorPage();

        // Get shared mount point
        foreach ($domainList as $domain) {
            if ($domain['name'] == $sharedMountPointDomain) {
                $mountPoint = $domain['mount_point'];
            }
        }
    }

    // Default values
    $documentRoot = '/htdocs';
    $forwardUrl = 'no';
    $forwardType = NULL;
    $forwardHost = 'Off';

    // Check for URL forwarding option
    if (isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' && isset($_POST['forward_type'])
        && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
    ) {
        isset($_POST['forward_url_scheme']) && !isset($_POST['forward_url']) or showBadRequestErrorPage();

        $forwardUrl = clean_input($_POST['forward_url_scheme']) . clean_input($_POST['forward_url']);
        $forwardType = clean_input($_POST['forward_type']);
        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }

        try {
            try {
                $uri = iMSCP_Uri_Redirect::fromString($forwardUrl);
            } catch (Zend_Uri_Exception $e) {
                throw new iMSCP_Exception(tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>"));
            }

            $uri->setHost(encode_idna(mb_strtolower($uri->getHost()))); // Normalize URI host
            $uri->setPath(rtrim(utils_normalizePath($uri->getPath()), '/') . '/'); // Normalize URI path

            if ($uri->getHost() == $domainAliasNameAscii
                && ($uri->getPath() == '/' && in_array($uri->getPort(), ['', 80, 443]))
            ) {
                throw new iMSCP_Exception(
                    tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>") . ' ' .
                    tr('Domain alias %s cannot be forwarded on itself.', "<strong>$domainAliasName</strong>")
                );
            }

            if ($forwardType == 'proxy') {
                $port = $uri->getPort();
                if ($port && $port < 1025) {
                    throw new iMSCP_Exception(tr('Unallowed port in forward URL. Only ports above 1024 are allowed.', 'error'));
                }
            }

            $forwardUrl = $uri->getUri();
        } catch (Exception $e) {
            set_page_message($e->getMessage(), 'error');
            return false;
        }
    }

    # See http://youtrack.i-mscp.net/issue/IP-1486
    $isSuUser = isset($_SESSION['logged_from_type']);

    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();

    try {
        $db->beginTransaction();

        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onBeforeAddDomainAlias, [
            'domainId'        => $mainDmnProps['domain_id'],
            'domainAliasName' => $domainAliasNameAscii,
            'domainAliasIps'  => $domainAliasIps,
            'mountPoint'      => $mountPoint,
            'documentRoot'    => $documentRoot,
            'forwardUrl'      => $forwardUrl,
            'forwardType'     => $forwardType,
            'forwardHost'     => $forwardHost
        ]);
        exec_query(
            '
                INSERT INTO domain_aliases (
                    domain_id, alias_name, alias_status, alias_mount, alias_document_root, alias_ips, url_forward, type_forward, host_forward
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [
                $mainDmnProps['domain_id'], $domainAliasNameAscii, $isSuUser ? 'toadd' : 'ordered', $mountPoint, $documentRoot,
                implode(',', $domainAliasIps), $forwardUrl, $forwardType, $forwardHost
            ]
        );

        $domainAliasId = $db->lastInsertId();

        // Create the phpini entry for that domain alias

        $phpini = PHPini::getInstance();
        $phpini->loadResellerPermissions($_SESSION['user_created_by']);
        $phpini->loadClientPermissions($_SESSION['user_id']);

        if ($phpini->getClientPermission('phpiniConfigLevel') == 'per_user') {
            // Set INI options, based on main domain INI options
            $phpini->loadIniOptions($_SESSION['user_id'], $mainDmnProps['domain_id'], 'dmn');
        } else {
            $phpini->loadIniOptions(); // Set default INI options
        }

        $phpini->saveIniOptions($_SESSION['user_id'], $domainAliasId, 'als');

        if ($isSuUser) {
            createDefaultMailAccounts(
                $mainDmnProps['domain_id'], Authentication::getInstance()->getIdentity()->email, $domainAliasNameAscii, MT_ALIAS_FORWARD,
                $domainAliasId
            );
        }

        Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onAfterAddDomainAlias, [
            'domainId'        => $mainDmnProps['domain_id'],
            'domainAliasId'   => $domainAliasId,
            'domainAliasName' => $domainAliasNameAscii,
            'domainAliasIps'  => $domainAliasIps,
            'mountPoint'      => $mountPoint,
            'documentRoot'    => $documentRoot,
            'forwardUrl'      => $forwardUrl,
            'forwardType'     => $forwardType,
            'forwardHost'     => $forwardHost
        ]);

        $db->commit();

        if ($isSuUser) {
            send_request();
            write_log(sprintf('A new domain alias (%s) has been created by %s', $domainAliasName, $_SESSION['user_logged']), E_USER_NOTICE);
            set_page_message(tr('Domain alias successfully created.'), 'success');
        } else {
            send_alias_order_email($domainAliasName);
            write_log(sprintf('A new domain alias (%s) has been ordered by %s', $domainAliasName, $_SESSION['user_logged']), E_USER_NOTICE);
            set_page_message(tr('Domain alias successfully ordered.'), 'success');
        }
    } catch (iMSCP_Exception $e) {
        $db->rollBack();
        write_log(sprintf('System was unable to create the %s domain alias: %s', $domainAliasName, $e->getMessage()), E_USER_ERROR);
        set_page_message(tr('Could not create domain alias. An unexpected error occurred.'), 'error');
        return false;
    }

    return true;
}

/**
 * Generate page
 *
 * @param $tpl TemplateEngine
 * @return void
 */
function generatePage(TemplateEngine $tpl)
{
    $forwardType = isset($_POST['forward_type']) && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
        ? $_POST['forward_type'] : '302';
    $forwardHost = $forwardType == 'proxy' && isset($_POST['forward_host']) ? 'On' : 'Off';

    $tpl->assign([
        'DOMAIN_ALIAS_NAME'  => isset($_POST['domain_alias_name']) ? tohtml($_POST['domain_alias_name']) : '',
        'FORWARD_URL_YES'    => isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? ' checked' : '',
        'FORWARD_URL_NO'     => isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? '' : ' checked',
        'HTTP_YES'           => isset($_POST['forward_url_scheme']) && $_POST['forward_url_scheme'] == 'http://' ? ' selected' : '',
        'HTTPS_YES'          => isset($_POST['forward_url_scheme']) && $_POST['forward_url_scheme'] == 'https://' ? ' selected' : '',
        'FORWARD_URL'        => isset($_POST['forward_url']) ? tohtml($_POST['forward_url'], 'htmlAttr') : '',
        'FORWARD_TYPE_301'   => $forwardType == '301' ? ' checked' : '',
        'FORWARD_TYPE_302'   => $forwardType == '302' ? ' checked' : '',
        'FORWARD_TYPE_303'   => $forwardType == '303' ? ' checked' : '',
        'FORWARD_TYPE_307'   => $forwardType == '307' ? ' checked' : '',
        'FORWARD_TYPE_PROXY' => $forwardType == 'proxy' ? ' checked' : '',
        'FORWARD_HOST'       => $forwardHost == 'On' ? ' checked' : ''
    ]);

    $domainList = getDomainsList();

    if (!empty($domainList)) {
        $tpl->assign([
            'SHARED_MOUNT_POINT_YES' => isset($_POST['shared_mount_point']) && $_POST['shared_mount_point'] == 'yes' ? ' checked' : '',
            'SHARED_MOUNT_POINT_NO'  => isset($_POST['shared_mount_point']) && $_POST['shared_mount_point'] == 'yes' ? '' : ' checked'
        ]);

        foreach ($domainList as $domain) {
            $tpl->assign([
                'DOMAIN_NAME'                        => tohtml($domain['name']),
                'DOMAIN_NAME_UNICODE'                => tohtml(decode_idna($domain['name'])),
                'SHARED_MOUNT_POINT_DOMAIN_SELECTED' => isset($_POST['shared_mount_point_domain'])
                && $_POST['shared_mount_point_domain'] == $domain['name'] ? ' selected' : ''
            ]);
            $tpl->parse('SHARED_MOUNT_POINT_DOMAIN', '.shared_mount_point_domain');
        }
    } else {
        $tpl->assign('SHARED_MOUNT_POINT_OPTION_JS', '');
        $tpl->assign('SHARED_MOUNT_POINT_OPTION', '');
    }

    client_generate_ip_list($tpl, $_SESSION['user_id'], isset($_POST['alias_ips']) && is_array($_POST['alias_ips']) ? $_POST['alias_ips'] : []);
}

/***********************************************************************************************************************
 * Main
 */

require_once 'imscp-lib.php';

check_login('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptStart);
customerHasFeature('domain_aliases') or showBadRequestErrorPage();

$mainDmnProps = get_domain_default_props($_SESSION['user_id']);
$domainAliasesCount = get_customer_domain_aliases_count($mainDmnProps['domain_id']);

if ($mainDmnProps['domain_alias_limit'] != 0 && $domainAliasesCount >= $mainDmnProps['domain_alias_limit']) {
    set_page_message(tr('You have reached the maximum number of domain aliases allowed by your subscription.'), 'warning');
    redirectTo('domains_manage.php');
}

if (!empty($_POST) && addDomainAlias()) {
    redirectTo('domains_manage.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                       => 'shared/layouts/ui.tpl',
    'page'                         => 'client/alias_add.tpl',
    'page_message'                 => 'layout',
    'ip_entry'                     => 'page',
    'shared_mount_point_option_js' => 'page',
    'shared_mount_point_option'    => 'page',
    'shared_mount_point_domain'    => 'shared_mount_point_option'
]);
$tpl->assign([
    'TR_PAGE_TITLE'                 => tohtml(tr('Client / Domains / Add Domain Alias')),
    'TR_DOMAIN_ALIAS'               => tohtml(tr('Domain alias')),
    'TR_DOMAIN_ALIAS_NAME'          => tohtml(tr('Name')),
    'TR_DOMAIN_ALIAS_IPS'           => tohtml(tr('IP addresses')),
    'TR_SHARED_MOUNT_POINT'         => tohtml(tr('Shared mount point')),
    'TR_SHARED_MOUNT_POINT_TOOLTIP' => tohtml(tr('Allows to share the mount point of another domain.'), 'htmlAttr'),
    'TR_URL_FORWARDING'             => tohtml(tr('URL forwarding')),
    'TR_URL_FORWARDING_TOOLTIP'     => tohtml(tr('Allows to forward any request made to this domain to a specific URL.'), 'htmlAttr'),
    'TR_FORWARD_TO_URL'             => tohtml(tr('Forward to URL')),
    'TR_YES'                        => tohtml(tr('Yes')),
    'TR_NO'                         => tohtml(tr('No')),
    'TR_HTTP'                       => tohtml('http://'),
    'TR_HTTPS'                      => tohtml('https://'),
    'TR_FORWARD_TYPE'               => tohtml(tr('Forward type')),
    'TR_301'                        => tohtml('301'),
    'TR_302'                        => tohtml('302'),
    'TR_303'                        => tohtml('303'),
    'TR_307'                        => tohtml('307'),
    'TR_PROXY'                      => tohtml(tr('Proxy')),
    'TR_PROXY_PRESERVE_HOST'        => tohtml(tr('Preserve Host')),
    'TR_ADD'                        => tohtml(tr('Add'), 'htmlAttr'),
    'TR_CANCEL'                     => tohtml(tr('Cancel'))
]);

Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['available'] = tr('Available');
    $translations['core']['assigned'] = tr('Assigned');
});

generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();

unsetMessages();
