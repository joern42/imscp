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
use Zend\EventManager\Event;

/**
 * Get subdomain data
 *
 * @access private
 * @param int $subdomainId Subdomain unique identifier
 * @param string $subdomainType Subdomain Type
 * @return array|bool Subdomain data or FALSE on error
 */
function _client_getSubdomainData($subdomainId, $subdomainType)
{
    static $subdomainData = NULL;

    if (NULL !== $subdomainData) {
        return $subdomainData;
    }

    $mainDmnProps = getCustomerProperties(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    $domainId = $mainDmnProps['domain_id'];
    $domainName = $mainDmnProps['domain_name'];

    if ($subdomainType == 'dmn') {
        $query = '
            SELECT subdomain_name , subdomain_ips, subdomain_mount AS subdomain_mount, subdomain_document_root AS document_root,
              subdomain_url_forward AS url_forward, subdomain_type_forward AS type_forward,
              subdomain_host_forward AS host_forward
            FROM subdomain
            WHERE subdomain_id = ?
            AND domain_id = ?
            AND subdomain_status = ?
        ';
    } else {
        $query = '
            SELECT t1.subdomain_alias_name AS subdomain_name, t1.subdomain_alias_ips AS subdomain_ips, t1.subdomain_alias_mount AS subdomain_mount,
              t1.subdomain_alias_document_root AS document_root, t1.subdomain_alias_url_forward AS url_forward,
              t1.subdomain_alias_type_forward AS type_forward, t1.subdomain_alias_host_forward AS host_forward,
              t2.alias_name AS alias_name
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            WHERE subdomain_alias_id = ?
            AND t2.domain_id = ?
            AND t1.subdomain_alias_status = ?
        ';
    }

    $stmt = execQuery($query, [$subdomainId, $domainId, 'ok']);
    if (!$stmt->rowCount()) {
        return false;
    }

    $subdomainData = $stmt->fetch();

    if ($subdomainType == 'dmn') {
        $subdomainData['subdomain_name'] .= '.' . $domainName;
        $subdomainData['subdomain_name_utf8'] = decodeIdna($subdomainData['subdomain_name']);
    } else {
        $subdomainData['subdomain_name'] .= '.' . $subdomainData['alias_name'];
        $subdomainData['subdomain_name_utf8'] = decodeIdna($subdomainData['subdomain_name']);
    }

    return $subdomainData;
}

/**
 * Edit subdomain
 *
 * @return bool TRUE on success, FALSE on failure
 */
function client_editSubdomain()
{
    isset($_GET['id']) && isset($_GET['type']) && in_array($_GET['type'], ['dmn', 'als']) or View::showBadRequestErrorPage();

    $subdomainId = cleanInput($_GET['id']);
    $subdomainType = cleanInput($_GET['type']);
    $subdomainData = _client_getSubdomainData($subdomainId, $subdomainType);
    $subdomainData !== FALSE or View::showBadRequestErrorPage();

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    // Check for subdomain IP addresses
    $subdomainIps = [];
    if (!isset($_POST['subdomain_ips'])) {
        View::setPageMessage(toHtml(tr('You must assign at least one IP address to that subdomain.')), 'error');
        return false;
    } elseif (!is_array($_POST['subdomain_ips'])) {
        View::showBadRequestErrorPage();
    } else {
        $clientIps = explode(',', getCustomerProperties($identity->getUserId())['domain_client_ips']);
        $subdomainIps = array_intersect($_POST['subdomain_ips'], $clientIps);
        if (count($subdomainIps) < count($_POST['subdomain_ips'])) {
            // Situation where unknown IP address identifier has been submitten
            View::showBadRequestErrorPage();
        }
    }

    // Default values
    $documentRoot = $subdomainData['document_root'];
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
                throw new \Exception(tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>"));
            }

            $uri->setHost(encodeIdna(mb_strtolower($uri->getHost()))); // Normalize URI host
            $uri->setPath(rtrim(normalizePath($uri->getPath()), '/') . '/'); // Normalize URI path

            if ($uri->getHost() == $subdomainData['subdomain_name'] && ($uri->getPath() == '/' && in_array($uri->getPort(), ['', 80, 443]))) {
                throw new \Exception(
                    tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>") . ' ' .
                    tr('Subdomain %s cannot be forwarded on itself.', "<strong>{$subdomainData['subdomain_name_utf8']}</strong>")
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
            View::setPageMessage($e->getMessage(), 'error');
            return false;
        }
    } // Check for alternative DocumentRoot option
    elseif (isset($_POST['document_root'])) {
        $documentRoot = normalizePath('/' . cleanInput($_POST['document_root']));
        if ($documentRoot !== '') {
            $vfs = new VirtualFileSystem($identity->getUsername(), $subdomainData['subdomain_mount'] . '/htdocs');
            if ($documentRoot !== '/' && !$vfs->exists($documentRoot, VirtualFileSystem::VFS_TYPE_DIR)) {
                View::setPageMessage(tr('The new document root must pre-exists inside the /htdocs directory.'), 'error');
                return false;
            }
        }
        $documentRoot = normalizePath('/htdocs' . $documentRoot);
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditSubdomain, NULL, [
        'subdomainId'   => $subdomainId,
        'subdomainName' => $subdomainData['subdomain_name'],
        'subdomainIps'  => $subdomainIps,
        'subdomainType' => $subdomainType,
        'mountPoint'    => $subdomainData['subdomain_mount'],
        'documentRoot'  => $documentRoot,
        'forwardUrl'    => $forwardUrl,
        'forwardType'   => $forwardType,
        'forwardHost'   => $forwardHost
    ]);

    if ($subdomainType == 'dmn') {
        $query = "
            UPDATE subdomain
            SET subdomain_ips = ?, subdomain_document_root = ?, subdomain_url_forward = ?, subdomain_type_forward = ?, subdomain_host_forward = ?,
                subdomain_status = 'tochange'
            WHERE subdomain_id = ?
        ";
    } else {
        $query = "
            UPDATE subdomain_alias
            SET subdomain_alias_ips = ?, subdomain_alias_document_root = ?, subdomain_alias_url_forward = ?, subdomain_alias_type_forward = ?,
                subdomain_alias_host_forward = ?, subdomain_alias_status = 'tochange'
            WHERE subdomain_alias_id = ?
        ";
    }

    execQuery($query, [implode(',', $subdomainIps), $documentRoot, $forwardUrl, $forwardType, $forwardHost, $subdomainId]);

    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditSubdomain, NULL, [
        'subdomainId'   => $subdomainId,
        'subdomainName' => $subdomainData['subdomain_name'],
        'subdomainIps'  => $subdomainIps,
        'subdomainType' => $subdomainType,
        'mountPoint'    => $subdomainData['subdomain_mount'],
        'documentRoot'  => $documentRoot,
        'forwardUrl'    => $forwardUrl,
        'forwardType'   => $forwardType,
        'forwardHost'   => $forwardHost
    ]);

    Daemon::sendRequest();
    writeLog(sprintf('%s updated properties of the %s subdomain', getProcessorUsername($identity), $subdomainData['subdomain_name_utf8']), E_USER_NOTICE);
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
    isset($_GET['id']) && isset($_GET['type']) && in_array($_GET['type'], ['dmn', 'als']) or View::showBadRequestErrorPage();

    $subdomainId = intval($_GET['id']);
    $subdomainType = cleanInput($_GET['type']);
    $subdomainData = _client_getSubdomainData($subdomainId, $subdomainType);
    $subdomainData !== FALSE or View::showBadRequestErrorPage();
    $subdomainData['subdomain_ips'] = explode(',', $subdomainData['subdomain_ips']);
    $forwardHost = 'Off';

    $identity = Application::getInstance()->getAuthService()->getIdentity();

    if (!Application::getInstance()->getRequest()->isPost()) {
        View::generateClientIpsList($tpl, $identity->getUserId(), $subdomainData['subdomain_ips']);

        $documentRoot = strpos($subdomainData['document_root'], '/htdocs') !== FALSE ? substr($subdomainData['document_root'], 7) : '';
        if ($subdomainData['url_forward'] != 'no') {
            $urlForwarding = true;
            $uri = iMSCP_Uri_Redirect::fromString($subdomainData['url_forward']);
            $uri->setHost(decodeIdna($uri->getHost()));
            $forwardUrlScheme = $uri->getScheme() . '://';
            $forwardUrl = substr($uri->getUri(), strlen($forwardUrlScheme));
            $forwardType = $subdomainData['type_forward'];
            $forwardHost = $subdomainData['host_forward'];
        } else {
            $urlForwarding = false;
            $forwardUrlScheme = 'http://';
            $forwardUrl = '';
            $forwardType = '302';
        }
    } else {
        View::generateClientIpsList(
            $tpl, $identity->getUserId(), isset($_POST['subdomain_ips']) && is_array($_POST['subdomain_ips']) ? $_POST['subdomain_ips'] : []
        );

        $documentRoot = (isset($_POST['document_root'])) ? $_POST['document_root'] : '';
        $urlForwarding = (isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes') ? true : false;
        $forwardUrlScheme = isset($_POST['forward_url_scheme']) ? $_POST['forward_url_scheme'] : 'http://';
        $forwardUrl = isset($_POST['forward_url']) ? $_POST['forward_url'] : '';
        $forwardType = (isset($_POST['forward_type']) && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true))
            ? $_POST['forward_type'] : '302';

        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }
    }

    $tpl->assign([
        'SUBDOMAIN_ID'       => $subdomainId,
        'SUBDOMAIN_TYPE'     => $subdomainType,
        'SUBDOMAIN_NAME'     => toHtml($subdomainData['subdomain_name_utf8']),
        'DOCUMENT_ROOT'      => toHtml($documentRoot),
        'FORWARD_URL_YES'    => $urlForwarding ? ' checked' : '',
        'FORWARD_URL_NO'     => $urlForwarding ? '' : ' checked',
        'HTTP_YES'           => $forwardUrlScheme == 'http://' ? ' selected' : '',
        'HTTPS_YES'          => $forwardUrlScheme == 'https://' ? ' selected' : '',
        'FORWARD_URL'        => toHtml($forwardUrl),
        'FORWARD_TYPE_301'   => $forwardType == '301' ? ' checked' : '',
        'FORWARD_TYPE_302'   => $forwardType == '302' ? ' checked' : '',
        'FORWARD_TYPE_303'   => $forwardType == '303' ? ' checked' : '',
        'FORWARD_TYPE_307'   => $forwardType == '307' ? ' checked' : '',
        'FORWARD_TYPE_PROXY' => $forwardType == 'proxy' ? ' checked' : '',
        'FORWARD_HOST'       => $forwardHost == 'On' ? ' checked' : ''
    ]);

    // Cover the case where URL forwarding feature is activated and that the
    // default /htdocs directory doesn't exist yet
    if ($subdomainData['url_forward'] != 'no') {
        $vfs = new VirtualFileSystem($identity->getUsername(), $subdomainData['subdomain_mount']);
        if (!$vfs->exists('/htdocs')) {
            $tpl->assign('DOCUMENT_ROOT_BLOC', '');
            return;
        }
    }

    # Set parameters for the FTP chooser
    Application::getInstance()->getSession()['ftp_chooser_domain_id'] = getCustomerMainDomainId($identity->getUserId());
    Application::getInstance()->getSession()['ftp_chooser_user'] = $identity->getUsername();
    Application::getInstance()->getSession()['ftp_chooser_root_dir'] = normalizePath($subdomainData['subdomain_mount'] . '/htdocs');
    Application::getInstance()->getSession()['ftp_chooser_hidden_dirs'] = [];
    Application::getInstance()->getSession()['ftp_chooser_unselectable_dirs'] = [];
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::USER_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);
Counting::customerHasFeature('subdomains') or View::showBadRequestErrorPage();

if (Application::getInstance()->getRequest()->isPost() && client_editSubdomain()) {
    View::setPageMessage(tr('Subdomain successfully scheduled for update'), 'success');
    redirectTo('domains_manage.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'client/subdomain_edit.tpl',
    'page_message'       => 'layout',
    'ip_entry'           => 'page',
    'document_root_bloc' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'             => toHtml(tr('Client / Domains / Edit Subdomain')),
    'TR_SUBDOMAIN'              => toHtml(tr('Subdomain')),
    'TR_SUBDOMAIN_NAME'         => toHtml(tr('Name')),
    'TR_SUBDOMAIN_IPS'          => toHtml(tr('IP addresses')),
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
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
