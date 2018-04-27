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

use iMSCP\Functions\Counting;
use iMSCP\Functions\Daemon;
use iMSCP\Functions\Login;
use iMSCP\Functions\Mail;
use iMSCP\Functions\View;
use iMSCP\Model\SuIdentityInterface;
use Zend\EventManager\Event;

/**
 * Send alias order email
 *
 * @param  string $aliasName
 * @return bool TRUE on success, FALSE on failure
 */
function send_alias_order_email($aliasName)
{
    $stmt = execQuery('SELECT admin_name, created_by, fname, lname, email FROM admin WHERE admin_id = ?', [
        Application::getInstance()->getAuthService()->getIdentity()->getUserId()
    ]);
    $row = $stmt->fetch();
    $data = Mail::getDomainAliasOrderEmail($row['created_by']);
    $ret = Mail::sendMail([
        'mail_id'      => 'alias-order-msg',
        'fname'        => $row['fname'],
        'lname'        => $row['lname'],
        'username'     => $row['admin_name'],
        'email'        => $row['email'],
        'subject'      => $data['subject'],
        'message'      => $data['message'],
        'placeholders' => [
            '{CUSTOMER}' => decodeIdna($row['admin_name']),
            '{ALIAS}'    => $aliasName
        ]
    ]);

    if (!$ret) {
        writeLog(sprintf("Couldn't send domain alias order email to %s", $row['admin_name']), E_USER_ERROR);
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
    $mainDmnProps = getCustomerProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());

    if ($mainDmnProps['url_forward'] == 'no') {
        $domainsList = [[
            'name'        => $mainDmnProps['domain_name'],
            'id'          => $mainDmnProps['domain_id'],
            'type'        => 'dmn',
            'mount_point' => '/'
        ]];
    }

    $stmt = execQuery(
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
            return strnatcmp(decodeIdna($a['name']), decodeIdna($b['name']));
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
    $domainAliasName = isset($_POST['domain_alias_name']) ? mb_strtolower(cleanInput($_POST['domain_alias_name'])) : '';

    // Check for domain alias name
    if ($domainAliasName == '') {
        setPageMessage(tr('You must enter a domain alias name.'), 'error');
        $ret = false;
    } else {
        // www is considered as an alias of the domain alias
        while (strpos($domainAliasName, 'www.') === 0) {
            $domainAliasName = substr($domainAliasName, 4);
        }

        // Check for domain alias name syntax
        global $dmnNameValidationErrMsg;
        if (!validateDomainName($domainAliasName)) {
            setPageMessage(toHtml($dmnNameValidationErrMsg), 'error');
            $ret = false;
        } elseif (isKnownDomain($domainAliasName, Application::getInstance()->getSession()['user_created_by'])) {
            // Check for domain alias existence
            setPageMessage(tr('Domain %s is unavailable.', "<strong>$domainAliasName</strong>"), 'error');
            $ret = false;
        }
    }

    // Check for domain alias IP addresses
    $domainAliasIps = [];
    if (!isset($_POST['alias_ips'])) {
        setPageMessage(toHtml(tr('You must assign at least one IP address to that domain alias.')), 'error');
        $ret = false;
    } elseif (!is_array($_POST['alias_ips'])) {
        View::showBadRequestErrorPage();
    } else {
        $clientIps = explode(',', $mainDmnProps['domain_client_ips']);
        $domainAliasIps = array_intersect($_POST['alias_ips'], $clientIps);
        if (count($domainAliasIps) < count($_POST['alias_ips'])) {
            // Situation where unknown IP address identifier has been submitten
            View::showBadRequestErrorPage();
        }
    }

    if ($ret === FALSE) {
        return false;
    }

    $domainAliasNameAscii = encodeIdna($domainAliasName);

    // Set default mount point
    $mountPoint = "/$domainAliasNameAscii";

    // Check for shared mount point option
    if (isset($_POST['shared_mount_point']) && $_POST['shared_mount_point'] == 'yes') { // We are safe here
        if (!isset($_POST['shared_mount_point_domain'])) {
            View::showBadRequestErrorPage();
        }

        $sharedMountPointDomain = cleanInput($_POST['shared_mount_point_domain']);
        $domainList = getDomainsList();
        !empty($domainList) or View::showBadRequestErrorPage();

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
        isset($_POST['forward_url_scheme']) && !isset($_POST['forward_url']) or View::showBadRequestErrorPage();

        $forwardUrl = cleanInput($_POST['forward_url_scheme']) . cleanInput($_POST['forward_url']);
        $forwardType = cleanInput($_POST['forward_type']);
        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }

        try {
            try {
                $uri = iMSCP_Uri_Redirect::fromString($forwardUrl);
            } catch (Zend_Uri_Exception $e) {
                throw new \Exception(tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>"));
            }

            $uri->setHost(encodeIdna(mb_strtolower($uri->getHost()))); // Normalize URI host
            $uri->setPath(rtrim(normalizePath($uri->getPath()), '/') . '/'); // Normalize URI path

            if ($uri->getHost() == $domainAliasNameAscii && ($uri->getPath() == '/' && in_array($uri->getPort(), ['', 80, 443]))) {
                throw new \Exception(
                    tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>") . ' ' .
                    tr('Domain alias %s cannot be forwarded on itself.', "<strong>$domainAliasName</strong>")
                );
            }

            if ($forwardType == 'proxy') {
                $port = $uri->getPort();
                if ($port && $port < 1025) {
                    throw new \Exception(tr('Unallowed port in forward URL. Only ports above 1024 are allowed.', 'error'));
                }
            }

            $forwardUrl = $uri->getUri();
        } catch (\Exception $e) {
            setPageMessage($e->getMessage(), 'error');
            return false;
        }
    }

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    # See http://youtrack.i-mscp.net/issue/IP-1486
    $isSuIdentity = $identity instanceof SuIdentityInterface;

    $db = Application::getInstance()->getDb();

    try {
        $db->getDriver()->getConnection()->beginTransaction();

        Application::getInstance()->getEventManager()->trigger(Events::onBeforeAddDomainAlias, NULL, [
            'domainId'        => $mainDmnProps['domain_id'],
            'domainAliasName' => $domainAliasNameAscii,
            'domainAliasIps'  => $domainAliasIps,
            'mountPoint'      => $mountPoint,
            'documentRoot'    => $documentRoot,
            'forwardUrl'      => $forwardUrl,
            'forwardType'     => $forwardType,
            'forwardHost'     => $forwardHost
        ]);
        execQuery(
            '
                INSERT INTO domain_aliases (
                    domain_id, alias_name, alias_status, alias_mount, alias_document_root, alias_ips, url_forward, type_forward, host_forward
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [
                $mainDmnProps['domain_id'], $domainAliasNameAscii, $isSuIdentity ? 'toadd' : 'ordered', $mountPoint, $documentRoot,
                implode(',', $domainAliasIps), $forwardUrl, $forwardType, $forwardHost
            ]
        );

        $domainAliasId = $db->getDriver()->getLastGeneratedValue();

        // Create the phpini entry for that domain alias

        $phpini = PHPini::getInstance();
        $phpini->loadResellerPermissions($identity->getUserCreatedBy());
        $phpini->loadClientPermissions($identity->getUserId());

        if ($phpini->getClientPermission('phpiniConfigLevel') == 'per_user') {
            // Set INI options, based on custoerm primary domain INI options
            $phpini->loadIniOptions($identity->getUserId(), $mainDmnProps['domain_id'], 'dmn');
        } else {
            $phpini->loadIniOptions(); // Set default INI options
        }

        $phpini->saveIniOptions($identity->getUserId(), $domainAliasId, 'als');

        if ($isSuIdentity) {
            Mail::createDefaultMailAccounts(
                $mainDmnProps['domain_id'], $identity->getUserEmail(), $domainAliasNameAscii, Mail::MT_ALIAS_FORWARD, $domainAliasId
            );
        }

        Application::getInstance()->getEventManager()->trigger(Events::onAfterAddDomainAlias, NULL, [
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

        $db->getDriver()->getConnection()->commit();

        if ($isSuIdentity) {
            Daemon::sendRequest();
            writeLog(sprintf('A new domain alias (%s) has been created by %s', $domainAliasName, $identity->getSuUsername(), E_USER_NOTICE));
            setPageMessage(tr('Domain alias successfully created.'), 'success');
        } else {
            send_alias_order_email($domainAliasName);
            writeLog(sprintf('A new domain alias (%s) has been ordered by %s', $domainAliasName, $identity->getUsername(), E_USER_NOTICE));
            setPageMessage(tr('Domain alias successfully ordered.'), 'success');
        }
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        writeLog(sprintf('System was unable to create the %s domain alias: %s', $domainAliasName, $e->getMessage()), E_USER_ERROR);
        setPageMessage(tr('Could not create domain alias. An unexpected error occurred.'), 'error');
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
        'DOMAIN_ALIAS_NAME'  => isset($_POST['domain_alias_name']) ? toHtml($_POST['domain_alias_name']) : '',
        'FORWARD_URL_YES'    => isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? ' checked' : '',
        'FORWARD_URL_NO'     => isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? '' : ' checked',
        'HTTP_YES'           => isset($_POST['forward_url_scheme']) && $_POST['forward_url_scheme'] == 'http://' ? ' selected' : '',
        'HTTPS_YES'          => isset($_POST['forward_url_scheme']) && $_POST['forward_url_scheme'] == 'https://' ? ' selected' : '',
        'FORWARD_URL'        => isset($_POST['forward_url']) ? toHtml($_POST['forward_url'], 'htmlAttr') : '',
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
                'DOMAIN_NAME'                        => toHtml($domain['name']),
                'DOMAIN_NAME_UNICODE'                => toHtml(decodeIdna($domain['name'])),
                'SHARED_MOUNT_POINT_DOMAIN_SELECTED' => isset($_POST['shared_mount_point_domain'])
                && $_POST['shared_mount_point_domain'] == $domain['name'] ? ' selected' : ''
            ]);
            $tpl->parse('SHARED_MOUNT_POINT_DOMAIN', '.shared_mount_point_domain');
        }
    } else {
        $tpl->assign('SHARED_MOUNT_POINT_OPTION_JS', '');
        $tpl->assign('SHARED_MOUNT_POINT_OPTION', '');
    }

    View::generateClientIpsList(
        $tpl,
        Application::getInstance()->getAuthService()->getIdentity()->getUserId(),
        isset($_POST['alias_ips']) && is_array($_POST['alias_ips']) ? $_POST['alias_ips'] : []
    );
}

require 'application.php';

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('domain_aliases') or View::showBadRequestErrorPage();

$mainDmnProps = getCustomerProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
$domainAliasesCount = Counting::getCustomerDomainAliasesCount($mainDmnProps['domain_id']);

if ($mainDmnProps['domain_alias_limit'] != 0 && $domainAliasesCount >= $mainDmnProps['domain_alias_limit']) {
    setPageMessage(tr('You have reached the maximum number of domain aliases allowed by your subscription.'), 'warning');
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
    'TR_PAGE_TITLE'                 => toHtml(tr('Client / Domains / Add Domain Alias')),
    'TR_DOMAIN_ALIAS'               => toHtml(tr('Domain alias')),
    'TR_DOMAIN_ALIAS_NAME'          => toHtml(tr('Name')),
    'TR_DOMAIN_ALIAS_IPS'           => toHtml(tr('IP addresses')),
    'TR_SHARED_MOUNT_POINT'         => toHtml(tr('Shared mount point')),
    'TR_SHARED_MOUNT_POINT_TOOLTIP' => toHtml(tr('Allows to share the mount point of another domain.'), 'htmlAttr'),
    'TR_URL_FORWARDING'             => toHtml(tr('URL forwarding')),
    'TR_URL_FORWARDING_TOOLTIP'     => toHtml(tr('Allows to forward any request made to this domain to a specific URL.'), 'htmlAttr'),
    'TR_FORWARD_TO_URL'             => toHtml(tr('Forward to URL')),
    'TR_YES'                        => toHtml(tr('Yes')),
    'TR_NO'                         => toHtml(tr('No')),
    'TR_HTTP'                       => toHtml('http://'),
    'TR_HTTPS'                      => toHtml('https://'),
    'TR_FORWARD_TYPE'               => toHtml(tr('Forward type')),
    'TR_301'                        => toHtml('301'),
    'TR_302'                        => toHtml('302'),
    'TR_303'                        => toHtml('303'),
    'TR_307'                        => toHtml('307'),
    'TR_PROXY'                      => toHtml(tr('Proxy')),
    'TR_PROXY_PRESERVE_HOST'        => toHtml(tr('Preserve Host')),
    'TR_ADD'                        => toHtml(tr('Add'), 'htmlAttr'),
    'TR_CANCEL'                     => toHtml(tr('Cancel'))
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['available'] = tr('Available');
    $translations['core']['assigned'] = tr('Assigned');
});
View::generateNavigation($tpl);
generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
