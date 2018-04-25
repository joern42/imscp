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
use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Get domain alias data
 *
 * @access private
 * @param int $domainAliasId Subdomain unique identifier
 * @return array|bool Domain alias data or FALSE on error
 */
function _client_getAliasData($domainAliasId)
{
    static $domainAliasData = NULL;

    if (NULL !== $domainAliasData) {
        return $domainAliasData;
    }

    $stmt = execQuery(
        "
            SELECT alias_name, alias_ips, alias_mount, alias_document_root, url_forward, type_forward, host_forward
            FROM domain_aliases
            WHERE alias_id = ?
            AND domain_id = ?
            AND alias_status = 'ok'
        ",
        [$domainAliasId, getCustomerMainDomainId(Application::getInstance()->getSession()['user_id'])]
    );

    if (!$stmt->rowCount()) {
        return false;
    }

    $domainAliasData = $stmt->fetch();
    $domainAliasData['alias_name_utf8'] = decodeIdna($domainAliasData['alias_name']);
    return $domainAliasData;
}

/**
 * Edit domain alias
 *
 * @return bool TRUE on success, FALSE on failure
 */
function client_editDomainAlias()
{
    isset($_GET['id']) or View::showBadRequestErrorPage();

    $domainAliasId = intval($_GET['id']);
    $domainAliasData = _client_getAliasData($domainAliasId);
    $domainAliasData !== FALSE or View::showBadRequestErrorPage();

    // Check for domain alias IP addresses
    $domainAliasIps = [];
    if (!isset($_POST['alias_ips'])) {
        setPageMessage(toHtml(tr('You must assign at least one IP address to that domain alias.')), 'error');
        return false;
    } elseif (!is_array($_POST['alias_ips'])) {
        View::showBadRequestErrorPage();
    } else {
        $clientIps = explode(',', getCustomerProperties(Application::getInstance()->getSession()['user_id'])['domain_client_ips']);
        $domainAliasIps = array_intersect($_POST['alias_ips'], $clientIps);
        if (count($domainAliasIps) < count($_POST['alias_ips'])) {
            // Situation where unknown IP address identifier has been submitten
            View::showBadRequestErrorPage();
        }
    }

    // Default values
    $documentRoot = $domainAliasData['alias_document_root'];
    $forwardUrl = 'no';
    $forwardType = NULL;
    $forwardHost = 'Off';

    // Check for URL forwarding option
    if (isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' && isset($_POST['forward_type'])
        && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
    ) {
        isset($_POST['forward_url_scheme']) && isset($_POST['forward_url']) or View::showBadRequestErrorPage();

        $forwardUrl = cleanInput($_POST['forward_url_scheme']) . cleanInput($_POST['forward_url']);
        $forwardType = cleanInput($_POST['forward_type']);
        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }

        try {
            try {
                $uri = iMSCP_Uri_Redirect::fromString($forwardUrl);
            } catch (Zend_Uri_Exception $e) {
                throw new iMSCP_Exception(tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>"));
            }

            $uri->setHost(encodeIdna(mb_strtolower($uri->getHost()))); // Normalize URI host
            $uri->setPath(rtrim(normalizePath($uri->getPath()), '/') . '/'); // Normalize URI path

            if ($uri->getHost() == $domainAliasData['alias_name'] && ($uri->getPath() == '/' && in_array($uri->getPort(), ['', 80, 443]))) {
                throw new \Exception(
                    tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>") . ' '
                    . tr('Domain alias %s cannot be forwarded on itself.', "<strong>{$domainAliasData['alias_name_utf8']}</strong>")
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
    } // Check for alternative DocumentRoot option
    elseif (isset($_POST['document_root'])) {
        $documentRoot = normalizePath('/' . cleanInput($_POST['document_root']));
        if ($documentRoot !== '') {
            $vfs = new VirtualFileSystem(Application::getInstance()->getSession()['user_logged'], $domainAliasData['alias_mount'] . '/htdocs');
            if ($documentRoot !== '/' && !$vfs->exists($documentRoot, VirtualFileSystem::VFS_TYPE_DIR)) {
                setPageMessage(tr('The new document root must pre-exists inside the /htdocs directory.'), 'error');
                return false;
            }
        }
        $documentRoot = normalizePath('/htdocs' . $documentRoot);
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditDomainAlias, [
        'domainAliasId'  => $domainAliasId,
        'domainAliasIps' => $domainAliasIps,
        'mountPoint'     => $domainAliasData['alias_mount'],
        'documentRoot'   => $documentRoot,
        'forwardUrl'     => $forwardUrl,
        'forwardType'    => $forwardType,
        'forwardHost'    => $forwardHost
    ]);
    execQuery(
        '
          UPDATE domain_aliases
          SET alias_document_root = ?, alias_ips = ?, url_forward = ?, type_forward = ?, host_forward = ?, alias_status = ?
          WHERE alias_id = ?
        ',
        [$documentRoot, implode(',', $domainAliasIps), $forwardUrl, $forwardType, $forwardHost, 'tochange', $domainAliasId]
    );
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditDomainAlias, [
        'domainAliasId'  => $domainAliasId,
        'domainAliasIps' => $domainAliasIps,
        'mountPoint'     => $domainAliasData['alias_mount'],
        'documentRoot'   => $documentRoot,
        'forwardUrl'     => $forwardUrl,
        'forwardType'    => $forwardType,
        'forwardHost'    => $forwardHost
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('%s updated properties of the %s domain alias', Application::getInstance()->getSession()['user_logged'], $domainAliasData['alias_name_utf8']), E_USER_NOTICE);
    return true;
}

/**
 * Generate page
 *
 * @param $tpl TemplateEngine
 * @return void
 */
function client_generatePage($tpl)
{
    isset($_GET['id']) or View::showBadRequestErrorPage();

    $domainAliasId = intval($_GET['id']);
    $domainAliasData = _client_getAliasData($domainAliasId);
    $domainAliasData !== FALSE or View::showBadRequestErrorPage();
    $domainAliasData['alias_ips'] = explode(',', $domainAliasData['alias_ips']);
    $forwardHost = 'Off';

    if (empty($_POST)) {
        View::generateClientIpsList($tpl, Application::getInstance()->getSession()['user_id'], $domainAliasData['alias_ips']);

        $documentRoot = strpos($domainAliasData['alias_document_root'], '/htdocs') !== FALSE
            ? substr($domainAliasData['alias_document_root'], 7) : '';

        if ($domainAliasData['url_forward'] != 'no') {
            $urlForwarding = true;
            $uri = iMSCP_Uri_Redirect::fromString($domainAliasData['url_forward']);
            $uri->setHost(decodeIdna($uri->getHost()));
            $forwardUrlScheme = $uri->getScheme() . '://';
            $forwardUrl = substr($uri->getUri(), strlen($forwardUrlScheme));
            $forwardType = $domainAliasData['type_forward'];
            $forwardHost = $domainAliasData['host_forward'];
        } else {
            $urlForwarding = false;
            $forwardUrlScheme = 'http';
            $forwardUrl = '';
            $forwardType = '302';
        }
    } else {
        View::generateClientIpsList(
            $tpl, Application::getInstance()->getSession()['user_id'], isset($_POST['alias_ips']) && is_array($_POST['alias_ips']) ? $_POST['alias_ips'] : []
        );

        $documentRoot = isset($_POST['document_root']) ? $_POST['document_root'] : '';
        $urlForwarding = isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? true : false;
        $forwardUrlScheme = isset($_POST['forward_url_scheme']) ? $_POST['forward_url_scheme'] : 'http://';
        $forwardUrl = isset($_POST['forward_url']) ? $_POST['forward_url'] : '';
        $forwardType = (
            isset($_POST['forward_type']) && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
        ) ? $_POST['forward_type'] : '302';

        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }
    }

    $tpl->assign([
        'DOMAIN_ALIAS_ID'    => $domainAliasId,
        'DOMAIN_ALIAS_NAME'  => toHtml($domainAliasData['alias_name_utf8']),
        'DOCUMENT_ROOT'      => toHtml($documentRoot),
        'FORWARD_URL_YES'    => ($urlForwarding) ? ' checked' : '',
        'FORWARD_URL_NO'     => ($urlForwarding) ? '' : ' checked',
        'HTTP_YES'           => ($forwardUrlScheme == 'http://') ? ' selected' : '',
        'HTTPS_YES'          => ($forwardUrlScheme == 'https://') ? ' selected' : '',
        'FORWARD_URL'        => toHtml($forwardUrl, 'htmlAttr'),
        'FORWARD_TYPE_301'   => ($forwardType == '301') ? ' checked' : '',
        'FORWARD_TYPE_302'   => ($forwardType == '302') ? ' checked' : '',
        'FORWARD_TYPE_303'   => ($forwardType == '303') ? ' checked' : '',
        'FORWARD_TYPE_307'   => ($forwardType == '307') ? ' checked' : '',
        'FORWARD_TYPE_PROXY' => ($forwardType == 'proxy') ? ' checked' : '',
        'FORWARD_HOST'       => ($forwardHost == 'On') ? ' checked' : ''
    ]);

    // Cover the case where URL forwarding feature is activated and that the
    // default /htdocs directory doesn't exist yet
    if ($domainAliasData['url_forward'] != 'no') {
        $vfs = new VirtualFileSystem(Application::getInstance()->getSession()['user_logged'], $domainAliasData['alias_mount']);
        if (!$vfs->exists('/htdocs')) {
            $tpl->assign('DOCUMENT_ROOT_BLOC', '');
            return;
        }
    }

    # Set parameters for the FTP chooser
    Application::getInstance()->getSession()['ftp_chooser_domain_id'] = getCustomerMainDomainId(Application::getInstance()->getSession()['user_id']);
    Application::getInstance()->getSession()['ftp_chooser_user'] = Application::getInstance()->getSession()['user_logged'];
    Application::getInstance()->getSession()['ftp_chooser_root_dir'] = normalizePath($domainAliasData['alias_mount'] . '/htdocs');
    Application::getInstance()->getSession()['ftp_chooser_hidden_dirs'] = [];
    Application::getInstance()->getSession()['ftp_chooser_unselectable_dirs'] = [];
}

Login::checkLogin('user');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
customerHasFeature('domain_aliases') or View::showBadRequestErrorPage();

if (!empty($_POST) && client_editDomainAlias()) {
    setPageMessage(tr('Domain alias successfully scheduled for update.'), 'success');
    redirectTo('domains_manage.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'client/alias_edit.tpl',
    'page_message'       => 'layout',
    'ip_entry'           => 'page',
    'document_root_bloc' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'             => toHtml(tr('Client / Domains / Edit Domain Alias')),
    'TR_DOMAIN_ALIAS'           => toHtml(tr('Domain alias')),
    'TR_DOMAIN_ALIAS_NAME'      => toHtml(tr('Name')),
    'TR_DOMAIN_ALIAS_IPS'       => toHtml(tr('IP addresses')),
    'TR_DOCUMENT_ROOT'          => toHtml(tr('Document root')),
    'TR_DOCUMENT_ROOT_TOOLTIP'  => toHtml(tr("You can set an alternative document root. This is mostly needed when using a PHP framework such as Symfony. Note that the new document root will live inside the default  `/htdocs' document root. Be aware that the directory for the new document root must pre-exist."), 'htmlAttr'),
    'TR_CHOOSE_DIR'             => toHtml(tr('Choose dir')),
    'TR_URL_FORWARDING'         => toHtml(tr('URL forwarding')),
    'TR_FORWARD_TO_URL'         => toHtml(tr('Forward to URL')),
    'TR_URL_FORWARDING_TOOLTIP' => toHtml(tr('Allows to forward any request made to this domain to a specific URL.'), 'htmlAttr'),
    'TR_YES'                    => toHtml(tr('Yes')),
    'TR_NO'                     => toHtml(tr('No')),
    'TR_HTTP'                   => toHtml('http://'),
    'TR_HTTPS'                  => toHtml('https://'),
    'TR_FORWARD_TYPE'           => toHtml(tr('Forward type')),
    'TR_301'                    => toHtml('301'),
    'TR_302'                    => toHtml('302'),
    'TR_303'                    => toHtml('303'),
    'TR_307'                    => toHtml('307'),
    'TR_PROXY'                  => toHtml(tr('Proxy')),
    'TR_PROXY_PRESERVE_HOST'    => toHtml(tr('Preserve Host')),
    'TR_UPDATE'                 => toHtml(tr('Update'), 'htmlAttr'),
    'TR_CANCEL'                 => toHtml(tr('Cancel'))
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['close'] = tr('Close');
    $translations['core']['ftp_directories'] = tr('Select your own document root');
    $translations['core']['available'] = tr('Available');
    $translations['core']['assigned'] = tr('Assigned');
});
View::generateNavigation($tpl);
client_generatePage($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
