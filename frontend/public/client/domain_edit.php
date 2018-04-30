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
use iMSCP\Functions\Daemon;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Get domain data
 *
 * @access private
 * @param int $domainId Domain unique identifier
 * @return array|bool Domain data or FALSE on error
 */
function _client_getDomainData($domainId)
{
    static $domainData = NULL;

    if (NULL !== $domainData) {
        return $domainData;
    }

    $stmt = execQuery(
        "
            SELECT domain_name, document_root, url_forward, type_forward, host_forward
            FROM domain
            WHERE domain_id = ?
            AND domain_admin_id = ?
            AND domain_status = 'ok'
        ",
        [$domainId, Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
    );

    if (!$stmt->rowCount()) {
        return false;
    }

    $domainData = $stmt->fetch();
    $domainData['domain_name_utf8'] = decodeIdna($domainData['domain_name']);
    return $domainData;
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

    $domainId = intval($_GET['id']);
    $domainData = _client_getDomainData($domainId);
    $domainData !== false or View::showBadRequestErrorPage();
    $forwardHost = 'Off';

    if (!Application::getInstance()->getRequest()->isPost()) {
        $documentRoot = strpos($domainData['document_root'], '/htdocs') !== FALSE ? substr($domainData['document_root'], 7) : '';

        if ($domainData['url_forward'] != 'no') {
            $urlForwarding = true;
            $uri = iMSCP_Uri_Redirect::fromString($domainData['url_forward']);
            $uri->setHost(decodeIdna($uri->getHost()));
            $forwardUrlScheme = $uri->getScheme() . '://';
            $forwardUrl = substr($uri->getUri(), strlen($forwardUrlScheme));
            $forwardType = $domainData['type_forward'];
            $forwardHost = $domainData['host_forward'];
        } else {
            $urlForwarding = false;
            $forwardUrlScheme = 'http';
            $forwardUrl = '';
            $forwardType = '302';
        }
    } else {
        $documentRoot = isset($_POST['document_root']) ? $_POST['document_root'] : '';
        $urlForwarding = isset($_POST['url_forwarding']) && $_POST['url_forwarding'] == 'yes' ? true : false;
        $forwardUrlScheme = isset($_POST['forward_url_scheme']) ? $_POST['forward_url_scheme'] : 'http://';
        $forwardUrl = isset($_POST['forward_url']) ? $_POST['forward_url'] : '';
        $forwardType = isset($_POST['forward_type']) && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
            ? $_POST['forward_type'] : '302';

        if ($forwardType == 'proxy' && isset($_POST['forward_host'])) {
            $forwardHost = 'On';
        }
    }

    $tpl->assign([
        'DOMAIN_ID'          => $domainId,
        'DOMAIN_NAME'        => toHtml($domainData['domain_name_utf8']),
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
    if ($domainData['url_forward'] != 'no') {
        $vfs = new VirtualFileSystem(Application::getInstance()->getAuthService()->getIdentity()->getUsername());
        if (!$vfs->exists('/htdocs')) {
            $tpl->assign('DOCUMENT_ROOT_BLOC', '');
            return;
        }
    }

    # Set parameters for the FTP chooser
    Application::getInstance()->getSession()['ftp_chooser_domain_id'] = $domainId;
    Application::getInstance()->getSession()['ftp_chooser_user'] = Application::getInstance()->getAuthService()->getIdentity()->getUsername();
    Application::getInstance()->getSession()['ftp_chooser_root_dir'] = '/htdocs';
    Application::getInstance()->getSession()['ftp_chooser_hidden_dirs'] = [];
    Application::getInstance()->getSession()['ftp_chooser_unselectable_dirs'] = [];
}

/**
 * Edit domain
 *
 * @return bool TRUE on success, FALSE on failure
 */
function client_editDomain()
{
    if (!isset($_GET['id'])) {
        View::showBadRequestErrorPage();
    }

    $domainId = intval($_GET['id']);
    $domainData = _client_getDomainData($domainId);

    if ($domainData === false) {
        View::showBadRequestErrorPage();
    }

    // Default values
    $documentRoot = $domainData['document_root'];
    $forwardUrl = 'no';
    $forwardType = NULL;
    $forwardHost = 'Off';

    // Check for URL forwarding option
    if (isset($_POST['url_forwarding'])
        && $_POST['url_forwarding'] == 'yes'
        && isset($_POST['forward_type'])
        && in_array($_POST['forward_type'], ['301', '302', '303', '307', 'proxy'], true)
    ) {
        if (!isset($_POST['forward_url_scheme']) || !isset($_POST['forward_url'])) {
            View::showBadRequestErrorPage();
        }

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

            if ($uri->getHost() == $domainData['domain_name']
                && ($uri->getPath() == '/' && in_array($uri->getPort(), ['', 80, 443]))
            ) {
                throw new \Exception(
                    tr('Forward URL %s is not valid.', "<strong>$forwardUrl</strong>") . ' ' .
                    tr('Domain %s cannot be forwarded on itself.', "<strong>{$domainData['domain_name_utf8']}</strong>")
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
            $vfs = new VirtualFileSystem(Application::getInstance()->getAuthService()->getIdentity()->getUsername(), '/htdocs');

            if ($documentRoot !== '/' && !$vfs->exists($documentRoot, VirtualFileSystem::VFS_TYPE_DIR)) {
                View::setPageMessage(tr('The new document root must pre-exists inside the /htdocs directory.'), 'error');
                return false;
            }
        }

        $documentRoot = normalizePath('/htdocs' . $documentRoot);
    }

    Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditDomain, NULL, [
        'domainId'     => $domainId,
        'domainName'   => $domainData['domain_name'],
        'domainIps'    => $domainIps,
        'mountPoint'   => '/',
        'documentRoot' => $documentRoot,
        'forwardUrl'   => $forwardUrl,
        'forwardType'  => $forwardType,
        'forwardHost'  => $forwardHost
    ]);
    execQuery(
        'UPDATE domain SET document_root = ?, url_forward = ?, type_forward = ?, host_forward = ?, domain_status = ?WHERE domain_id = ?', [
        $documentRoot, $forwardUrl, $forwardType, $forwardHost, 'tochange', $domainId
    ]);
    Application::getInstance()->getEventManager()->trigger(Events::onAfterEditDomain, NULL, [
        'domainId'     => $domainId,
        'domainName'   => $domainData['domain_name'],
        'domainIps'    => $domainIps,
        'mountPoint'   => '/',
        'documentRoot' => $documentRoot,
        'forwardUrl'   => $forwardUrl,
        'forwardType'  => $forwardType,
        'forwardHost'  => $forwardHost
    ]);
    Daemon::sendRequest();
    writeLog(sprintf('The %s domain properties were updated by', Application::getInstance()->getAuthService()->getIdentity()->getUsername(), getProcessorUsername(Application::getInstance()->getAuthService()->getIdentity())), E_USER_NOTICE);
    return true;
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);

if (Application::getInstance()->getRequest()->isPost() && client_editDomain()) {
    View::setPageMessage(tr('Domain successfully scheduled for update.'), 'success');
    redirectTo('domains_manage.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'             => 'shared/layouts/ui.tpl',
    'page'               => 'client/domain_edit.tpl',
    'page_message'       => 'layout',
    'document_root_bloc' => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'             => tr('Client / Domains / Edit Domain'),
    'TR_DOMAIN'                 => tr('Domain'),
    'TR_DOMAIN_NAME'            => tr('Domain name'),
    'TR_DOCUMENT_ROOT'          => tr('Document root'),
    'TR_DOCUMENT_ROOT_TOOLTIP'  => tr("You can set an alternative document root. This is mostly needed when using a PHP framework such as Symfony. Note that the new document root will live inside the default  `/htdocs' document root. Be aware that the directory for the new document root must pre-exist."),
    'TR_CHOOSE_DIR'             => tr('Choose dir'),
    'TR_URL_FORWARDING'         => tr('URL forwarding'),
    'TR_FORWARD_TO_URL'         => tr('Forward to URL'),
    'TR_URL_FORWARDING_TOOLTIP' => tr('Allows to forward any request made to this domain to a specific URL.'),
    'TR_YES'                    => tr('Yes'),
    'TR_NO'                     => tr('No'),
    'TR_HTTP'                   => 'http://',
    'TR_HTTPS'                  => 'https://',
    'TR_FORWARD_TYPE'           => tr('Forward type'),
    'TR_301'                    => '301',
    'TR_302'                    => '302',
    'TR_303'                    => '303',
    'TR_307'                    => '307',
    'TR_PROXY'                  => toHtml(tr('Proxy')),
    'TR_PROXY_PRESERVE_HOST'    => tr('Preserve Host'),
    'TR_UPDATE'                 => tr('Update'),
    'TR_CANCEL'                 => tr('Cancel')
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['close'] = tr('Close');
    $translations['core']['ftp_directories'] = tr('Select your own document root');
});
View::generateNavigation($tpl);
client_generatePage($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
