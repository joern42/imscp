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
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generates domains list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateDomainsList($tpl)
{
    global $baseServerVhostUtf8;
    $cfg = Application::getInstance()->getConfig();

    $stmt = execQuery(
        "
            SELECT t1.domain_id, t1.domain_name, t1.document_root, t1.domain_status, t1.url_forward, t2.status as ssl_status
            FROM domain AS t1
            LEFT JOIN ssl_certs AS t2 ON(t2.domain_id = t1.domain_id AND t2.domain_type = 'dmn')
            WHERE domain_admin_id = ?
            ORDER BY domain_name
        ",
        [Application::getInstance()->getAuthService()->getIdentity()->getUserId()]
    );

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'DOMAIN_NAME'          => toHtml(decodeIdna($row['domain_name'])),
            'DOMAIN_MOUNT_POINT'   => toHtml($row['url_forward'] == 'no' ? '/' : tr('N/A')),
            'DOMAIN_DOCUMENT_ROOT' => toHtml($row['url_forward'] == 'no' ? normalizePath($row['document_root']) : tr('N/A')),
            'DOMAIN_REDIRECT'      => toHtml($row['url_forward'] == 'no' ? tr('N/A') : $row['url_forward']),
            'DOMAIN_STATUS'        => humanizeItemStatus($row['domain_status']),
            'DOMAIN_SSL_STATUS'    => is_null($row['ssl_status']) ? toHtml(tr('Disabled')) : (in_array($row['ssl_status'], ['toadd', 'tochange', 'todelete', 'ok'])
                ? humanizeItemStatus($row['ssl_status']) : '<span style="color:red;font-weight:bold">' . tr('Invalid SSL certificate') . "</span>")
        ]);

        if (in_array($row['domain_status'], ['ok', 'disabled'])) {
            $tpl->assign([
                'DMN_STATUS_CHANGE' => '',
                'DMN_STATUS_ERROR'  => ''
            ]);

            if ($row['domain_status'] == 'disabled') {
                $tpl->assign([
                    'DMN_STATUS_OK' => '',
                    'DMN_ACTIONS'   => toHtml(tr('N/A'))
                ]);
                $tpl->parse('DMN_STATUS_DISABLED', 'dmn_status_disabled');
            } else {
                if ($cfg['CLIENT_DOMAIN_ALT_URLS'] == 'yes') {
                    $tpl->assign([
                        'ALTERNATE_URL'         => toHtml("dmn{$row['domain_id']}.$baseServerVhostUtf8", 'htmlAttr'),
                        'TR_ALT_URL'            => toHtml(tr('Alt. URL')),
                        'ALTERNATE_URL_TOOLTIP' => toHtml(tr('Alternate URL to reach your website.'), 'htmlAttr')
                    ]);
                    $tpl->parse('DMN_ALT_URL', 'sub_alt_url');
                } else {
                    $tpl->assign('DMN_ALT_URL', '');
                }

                $tpl->assign([
                    'DOMAIN_EDIT_LINK' => toHtml("domain_edit.php?id={$row['domain_id']}", 'htmlAttr'),
                    'DOMAIN_EDIT'      => toHtml(tr('Edit')),
                    'CERT_SCRIPT'      => toHtml("cert_view.php?id={$row['domain_id']}&type=dmn", 'htmlAttr'),
                    'VIEW_CERT'        => toHtml(Counting::userHasFeature('webSSL') ? tr('Manage SSL certificate') : tr('View SSL certificate'))
                ]);
                $tpl->assign('DMN_STATUS_DISABLED', '');
                $tpl->parse('DMN_STATUS_OK', 'dmn_status_ok');
                $tpl->parse('DMN_ACTIONS', 'dmn_actions');
            }
        } elseif (!in_array($row['domain_status'], ['toadd', 'tochange', 'toenable', 'todisable', 'todisable'])) {
            $tpl->assign([
                'DMN_STATUS_OK'       => '',
                'DMN_STATUS_DISABLED' => '',
                'DMN_STATUS_CHANGE'   => '',
                'DMN_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('DMN_STATUS_ERROR', 'dmn_status_error');
        } else {
            $tpl->assign([
                'DMN_STATUS_OK'       => '',
                'DMN_STATUS_DISABLED' => '',
                'DMN_STATUS_ERROR'    => '',
                'DMN_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('DMM_STATUS_CHANGE', 'dmn_status_change');
        }

        $tpl->parse('DMN_ITEM', '.dmn_item');
    }
}

/**
 * Generates domain aliases list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateDomainAliasesList($tpl)
{
    if (!Counting::userHasFeature('domain_aliases')) {
        $tpl->assign('ALS_BLOCK', '');
        return;
    }

    global $baseServerVhostUtf8;
    $cfg = Application::getInstance()->getConfig();

    $domainId = getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    $stmt = execQuery(
        "
            SELECT t1.alias_id, t1.alias_name, t1.alias_status, t1.alias_mount, t1.alias_document_root, t1.url_forward, t2.status AS ssl_status
            FROM domain_aliases AS t1
            LEFT JOIN ssl_certs AS t2 ON(t1.alias_id = t2.domain_id AND t2.domain_type = 'als')
            WHERE t1.domain_id = ?
            ORDER BY t1.alias_mount, t1.alias_name
        ",
        [$domainId]
    );

    if (!$stmt->rowCount()) {
        $tpl->assign([
            'ALS_MSG'   => tr('You do not have domain aliases.'),
            'ALS_ITEMS' => ''
        ]);
        return;
    }

    $tpl->assign('ALS_MESSAGE', '');

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'ALS_NAME'          => toHtml(decodeIdna($row['alias_name'])),
            'ALS_MOUNT_POINT'   => toHtml($row['url_forward'] == 'no' ? normalizePath($row['alias_mount']) : tr('N/A')),
            'ALS_DOCUMENT_ROOT' => toHtml($row['url_forward'] == 'no' ? normalizePath($row['alias_document_root']) : tr('N/A')),
            'ALS_REDIRECT'      => toHtml($row['url_forward'] == 'no' ? tr('N/A') : $row['url_forward']),
            'ALS_STATUS'        => humanizeItemStatus($row['alias_status']),
            'ALS_SSL_STATUS'    => is_null($row['ssl_status']) ? toHtml(tr('Disabled')) : (in_array($row['ssl_status'], ['toadd', 'tochange', 'todelete', 'ok'])
                ? humanizeItemStatus($row['ssl_status']) : '<span style="color:red;font-weight:bold">' . tr('Invalid SSL certificate') . "</span>"),
            'ALS_RECORD_TYPE'   => 'als',
        ]);

        if (in_array($row['alias_status'], ['ok', 'disabled', 'ordered'])) {
            $tpl->assign([
                'ALS_STATUS_CHANGE' => '',
                'ALS_STATUS_ERROR'  => ''
            ]);

            if ($row['alias_status'] == 'disabled') {
                $tpl->assign([
                    'ALS_STATUS_OK' => '',
                    'ALS_ACTIONS'   => toHtml(tr('N/A'))
                ]);
                $tpl->parse('ALS_STATUS_DISABLED', 'als_status_disabled');
            } elseif ($row['alias_status'] == 'ordered') {
                $tpl->assign([
                    'ALS_STATUS_OK'          => '',
                    'ALS_ACTIONS_RESTRICTED' => '',
                    'ALS_ACTION'             => toHtml(tr('Cancel order')),
                    'ALS_ACTION_SCRIPT'      => toHtml("alias_order_cancel.php?id={$row['alias_id']}", 'htmlAttr'),
                    'ALS_RECORD_TYPE'        => 'als_order',
                ]);
                $tpl->parse('ALS_ACTIONS', 'als_actions');
                $tpl->parse('ALS_STATUS_DISABLED', 'als_status_disabled');
            } else {
                if ($cfg['CLIENT_DOMAIN_ALT_URLS'] == 'yes') {
                    $tpl->assign([
                        'ALTERNATE_URL'         => toHtml("als{$row['alias_id']}.$baseServerVhostUtf8", 'htmlAttr'),
                        'TR_ALT_URL'            => toHtml(tr('Alt. URL')),
                        'ALTERNATE_URL_TOOLTIP' => toHtml(tr('Alternate URL to reach your website.'), 'htmlAttr')
                    ]);
                    $tpl->parse('ALS_ALT_URL', 'als_alt_url');
                } else {
                    $tpl->assign('ALS_ALT_URL', '');
                }

                $tpl->assign([
                    'ALS_EDIT_LINK'     => toHtml("alias_edit.php?id={$row['alias_id']}", 'htmlAttr'),
                    'ALS_EDIT'          => toHtml(tr('Edit')),
                    'CERT_SCRIPT'       => toHtml("cert_view.php?id={$row['alias_id']}&type=als", 'htmlAttr'),
                    'VIEW_CERT'         => toHtml(Counting::userHasFeature('webSSL') ? tr('Manage SSL certificate') : tr('View SSL certificate')),
                    'ALS_ACTION'        => toHtml($row['alias_status'] == 'ordered' ? tr('Delete order') : tr('Delete')),
                    'ALS_ACTION_SCRIPT' => toHtml($row['alias_status'] == 'ordered' ? "alias_order_delete.php?id={$row['alias_id']}" : "alias_delete.php?id={$row['alias_id']}", 'htmlAttr')
                ]);
                $tpl->assign('ALS_STATUS_DISABLED', '');
                $tpl->parse('ALS_STATUS_OK', 'als_status_ok');
                $tpl->parse('ALS_ACTIONS', 'als_actions');
            }
        } elseif (!in_array($row['alias_status'], ['toadd', 'tochange', 'toenable', 'todisable', 'todisable'])) {
            $tpl->assign([
                'ALS_STATUS_OK'       => '',
                'ALS_STATUS_DISABLED' => '',
                'ALS_STATUS_CHANGE'   => '',
                'ALS_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('ALS_STATUS_ERROR', 'als_status_error');
        } else {
            $tpl->assign([
                'ALS_STATUS_OK'       => '',
                'ALS_STATUS_DISABLED' => '',
                'ALS_STATUS_ERROR'    => '',
                'ALS_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('ALS_STATUS_CHANGE', 'als_status_change');
        }

        $tpl->parse('ALS_ITEM', '.als_item');
    }
}

/**
 * Generates subdomains list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateSubdomainsList($tpl)
{
    if (!Counting::userHasFeature('webSubdomains')) {
        $tpl->assign('SUB_BLOCK', '');
        return;
    }

    global $baseServerVhostUtf8;
    $cfg = Application::getInstance()->getConfig();
    $domainId = getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId());

    $stmt = execQuery(
        "
            SELECT t1.subdomain_id, t1.subdomain_name, 'dmn' AS sub_type, t1.subdomain_mount, t1.subdomain_document_root, t1.subdomain_status,
                t1.subdomain_url_forward, t2.domain_name, t3.status AS ssl_status
            FROM subdomain AS t1
            JOIN domain AS t2 USING(domain_id)
            LEFT JOIN ssl_certs AS t3 ON(t1.subdomain_id = t3.domain_id AND t3.domain_type = 'sub')
            WHERE t1.domain_id = ?
            UNION ALL
            SELECT t1.subdomain_alias_id, t1.subdomain_alias_name, 'als', t1.subdomain_alias_mount, t1.subdomain_alias_document_root,
                t1.subdomain_alias_status, t1.subdomain_alias_url_forward, t2.alias_name, t3.status
            FROM subdomain_alias AS t1
            JOIN domain_aliases AS t2 USING(alias_id)
            LEFT JOIN ssl_certs AS t3 ON(t1.subdomain_alias_id = t3.domain_id AND t3.domain_type = 'alssub')
            WHERE t2.domain_id = ?
        ",
        [$domainId, $domainId]
    );

    if (!$stmt->rowCount()) {
        $tpl->assign([
            'SUB_MSG'   => tr('You do not have subdomains.'),
            'SUB_ITEMS' => ''
        ]);
        return;
    }

    $tpl->assign('SUB_MESSAGE', '');

    while ($row = $stmt->fetch()) {
        $tpl->assign([
            'SUB_NAME'          => toHtml(decodeIdna($row['subdomain_name'])),
            'SUB_ALIAS_NAME'    => toHtml(decodeIdna($row['domain_name'])),
            'SUB_MOUNT_POINT'   => toHtml($row['subdomain_url_forward'] == 'no' ? normalizePath($row['subdomain_mount']) : tr('N/A')),
            'SUB_DOCUMENT_ROOT' => toHtml($row['subdomain_url_forward'] == 'no' ? normalizePath($row['subdomain_document_root']) : tr('N/A')),
            'SUB_REDIRECT'      => toHtml($row['subdomain_url_forward'] == 'no' ? tr('N/A') : $row['subdomain_url_forward']),
            'SUB_STATUS'        => humanizeItemStatus($row['subdomain_status']),
            'SUB_SSL_STATUS'    => is_null($row['ssl_status']) ? toHtml(tr('Disabled')) : (in_array($row['ssl_status'], ['toadd', 'tochange', 'todelete', 'ok'])
                ? humanizeItemStatus($row['ssl_status']) : '<span style="color:red;font-weight: bold">' . tr('Invalid SSL certificate') . "</span>")
        ]);

        if (in_array($row['subdomain_status'], ['ok', 'disabled'])) {
            $tpl->assign([
                'SUB_STATUS_CHANGE' => '',
                'SUB_STATUS_ERROR'  => ''
            ]);

            if ($row['subdomain_status'] == 'disabled') {
                $tpl->assign([
                    'SUB_STATUS_OK' => '',
                    'SUB_ACTIONS'   => toHtml(tr('N/A'))
                ]);
                $tpl->parse('SUB_STATUS_DISABLED', 'sub_status_disabled');
            } else {
                if ($cfg['CLIENT_DOMAIN_ALT_URLS'] == 'yes') {
                    $tpl->assign([
                        'ALTERNATE_URL'         => toHtml(($row['sub_type'] == 'dmn' ? 'sub' : 'alssub') . $row['subdomain_id'] . '.' . $baseServerVhostUtf8, 'htmlAttr'),
                        'TR_ALT_URL'            => toHtml(tr('Alt. URL')),
                        'ALTERNATE_URL_TOOLTIP' => toHtml(tr('Alternate URL to reach your website.'), 'htmlAttr')
                    ]);
                    $tpl->parse('SUB_ALT_URL', 'sub_alt_url');
                } else {
                    $tpl->assign('SUB_ALT_URL', '');
                }

                if ($row['sub_type'] == 'dmn') {
                    $actionScript = "subdomain_delete.php?id={$row['subdomain_id']}";
                    $certScript = "cert_view.php?id={$row['subdomain_id']}&type=sub";
                } else {
                    $actionScript = "alssub_delete.php?id={$row['subdomain_id']}";
                    $certScript = "cert_view.php?id={$row['subdomain_id']}&type=alssub";
                }

                $tpl->assign([
                    'SUB_EDIT_LINK'     => toHtml("subdomain_edit.php?id={$row['subdomain_id']}&type={$row['sub_type']}", 'htmlAttr'),
                    'SUB_EDIT'          => toHtml(tr('Edit')),
                    'CERT_SCRIPT'       => toHtml($certScript, 'htmlAttr'),
                    'VIEW_CERT'         => toHtml(Counting::userHasFeature('webSSL') ? tr('Manage SSL certificate') : tr('View SSL certificate')),
                    'SUB_ACTION'        => toHtml(tr('Delete')),
                    'SUB_ACTION_SCRIPT' => toHtml($actionScript, 'htmlAttr')
                ]);

                $tpl->assign('SUB_STATUS_DISABLED', '');
                $tpl->parse('SUB_STATUS_OK', 'sub_status_ok');
                $tpl->parse('SUB_ACTIONS', 'sub_actions');
            }
        } elseif (!in_array($row['subdomain_status'], ['toadd', 'tochange', 'toenable', 'todisable', 'todisable'])) {
            $tpl->assign([
                'SUB_STATUS_OK'       => '',
                'SUB_STATUS_DISABLED' => '',
                'SUB_STATUS_CHANGE'   => '',
                'SUB_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('SUB_STATUS_ERROR', 'sub_status_error');
        } else {
            $tpl->assign([
                'SUB_STATUS_OK'       => '',
                'SUB_STATUS_DISABLED' => '',
                'SUB_STATUS_ERROR'    => '',
                'SUB_ACTIONS'         => toHtml(tr('N/A'))
            ]);
            $tpl->parse('SUB_STATUS_CHANGE', 'sub_status_change');
        }

        $tpl->parse('SUB_ITEM', '.sub_item');
    }
}

/**
 * Generates custom DNS record action
 *
 * @access private
 * @param string $action Action
 * @param string|null $id Custom DNS record unique identifier
 * @param string $status Custom DNS record status
 * @param string $ownedBy Owner of the DNS record
 * @return array
 */
function generateCustomDnsRecordAction($action, $id, $status, $ownedBy = 'custom_dns_feature')
{
    if (in_array($status, ['toadd', 'tochange', 'todelete'])) {
        return [tr('N/A'), '#'];
    }

    if ($action == 'edit' && $ownedBy == 'custom_dns_feature') {
        return [tr('Edit'), toHtml("dns_edit.php?id=$id", 'htmlAttr')];
    }

    if ($ownedBy == 'custom_dns_feature') {
        return [tr('Delete'), toHtml("dns_delete.php?id=$id", 'htmlAttr')];
    }

    return [tr('N/A'), '#'];
}

/**
 * Generates custom DNS records list
 *
 * @param TemplateEngine $tpl Template engine
 * @return void
 */
function generateCustomDnsRecordsList($tpl)
{
    if (!Counting::userHasFeature('dnsEditor')) {
        $filterCond = "AND owned_by <> 'custom_dns_feature'";
    } else {
        $filterCond = '';
    }

    $stmt = execQuery(
        "
            SELECT t1.*, IFNULL(t3.alias_name, t2.domain_name) zone_name
            FROM domain_dns AS t1
            LEFT JOIN domain AS t2 USING (domain_id)
            LEFT JOIN domain_aliases AS t3 USING (alias_id)
            WHERE t1.domain_id = ?
            $filterCond
            ORDER BY t1.domain_id, t1.alias_id, t1.domain_dns, t1.domain_type
        ",
        [getCustomerMainDomainId(Application::getInstance()->getAuthService()->getIdentity()->getUserId())]
    );

    if (!$stmt->rowCount()) {
        if (Counting::userHasFeature('dnsEditor')) {
            $tpl->assign([
                'DNS_MSG'   => tr('You do not have custom DNS resource records.'),
                'DNS_ITEMS' => ''
            ]);
            return;
        }

        $tpl->assign('DNS_BLOCK', '');
        return;
    } else {
        $tpl->assign('DNS_MESSAGE', '');
    }

    while ($row = $stmt->fetch()) {
        list($actionEdit, $actionScriptEdit) = generateCustomDnsRecordAction('edit', $row['domain_dns_id'], $row['domain_dns_status'], $row['owned_by']);

        if ($row['owned_by'] !== 'custom_dns_feature') {
            $tpl->assign('DNS_DELETE_LINK', '');
        } else {
            list($actionDelete, $actionScriptDelete) = generateCustomDnsRecordAction('Delete', $row['domain_dns_id'], $row['domain_dns_status']);
            $tpl->assign([
                'DNS_ACTION_SCRIPT_DELETE' => $actionScriptDelete,
                'DNS_ACTION_DELETE'        => $actionDelete,
                'DNS_TYPE_RECORD'          => tr("%s record", $row['domain_type'])
            ]);
            $tpl->parse('DNS_DELETE_LINK', '.dns_delete_link');
        }

        $dnsName = $row['domain_dns'];
        $ttl = tr('Default');
        if (preg_match('/^(?P<name>([^\s]+))(?:\s+(?P<ttl>\d+))/', $dnsName, $matches)) {
            $dnsName = (substr($matches['name'], -1) == '.') ? $matches['name'] : "{$matches['name']}.{$row['zone_name']}.";
            $ttl = $matches['ttl'] . ' ' . tr('Sec.');
        } else {
            $dnsName = (substr($row['domain_dns'], -1) == '.') ? $row['domain_dns'] : "{$row['domain_dns']}.{$row['zone_name']}.";
        }

        $status = humanizeItemStatus($row['domain_dns_status'], true);
        $tpl->assign([
            'DNS_DOMAIN'             => toHtml(decodeIdna($row['zone_name'])),
            'DNS_NAME'               => toHtml($dnsName),
            'DNS_TTL'                => toHtml($ttl),
            'DNS_CLASS'              => toHtml($row['domain_class']),
            'DNS_TYPE'               => toHtml($row['domain_type']),
            'LONG_DNS_DATA'          => toHtml($row['domain_text'], 'htmlAttr'),
            'SHORT_DNS_DATA'         => toHtml(strlen($row['domain_text']) > 30 ? substr($row['domain_text'], 0, 30) . ' ...' : $row['domain_text']),
            'LONG_DNS_STATUS'        => toHtml(nl2br($status), 'htmlAttr'),
            'SHORT_DNS_STATUS'       => strlen($status) > 15 ? substr($status, 0, 15) . ' ...' : $status,
            'DNS_ACTION_SCRIPT_EDIT' => $actionScriptEdit,
            'DNS_ACTION_EDIT'        => $actionEdit
        ]);
        $tpl->parse('DNS_ITEM', '.dns_item');
        $tpl->assign('DNS_DELETE_LINK', '');
    }
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::USER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                 => 'shared/layouts/ui.tpl',
    'page_message'           => 'layout',
    'page'                   => 'client/domains_manage.tpl',
    'dmn_item'               => 'page',
    'dmn_status_ok'          => 'dmn_item',
    'dmn_alt_url'            => 'dmn_status_ok',
    'dmn_status_disabled'    => 'dmn_item',
    'dmn_status_change'      => 'dmn_item',
    'dmn_status_error'       => 'dmn_item',
    'dmn_actions'            => 'dmn_item',
    'als_block'              => 'page',
    'als_message'            => 'als_block',
    'als_items'              => 'als_block',
    'als_item'               => 'als_items',
    'als_status_ok'          => 'als_item',
    'als_alt_url'            => 'als_status_ok',
    'als_status_disabled'    => 'als_item',
    'als_status_change'      => 'als_item',
    'als_status_error'       => 'als_item',
    'als_actions'            => 'als_item',
    'als_actions_restricted' => 'als_actions',
    'sub_block'              => 'page',
    'sub_message'            => 'sub_block',
    'sub_items'              => 'sub_block',
    'sub_item'               => 'sub_items',
    'sub_status_ok'          => 'sub_item',
    'sub_alt_url'            => 'sub_status_ok',
    'sub_status_disabled'    => 'sub_item',
    'sub_status_change'      => 'sub_item',
    'sub_status_error'       => 'sub_item',
    'sub_actions'            => 'sub_item',
    'dns_block'              => 'page',
    'dns_message'            => 'dns_block',
    'dns_items'              => 'dns_block',
    'dns_item'               => 'dns_items',
    'dns_edit_link'          => 'dns_item',
    'dns_delete_link'        => 'dns_item'
]);
$tpl->assign([
    'TR_PAGE_TITLE'     => tr('Client / Domains'),
    'TR_DOMAINS'        => tr('Domains'),
    'TR_ZONE'           => tr('Zone'),
    'TR_TTL'            => tr('TTL'),
    'TR_DOMAIN_ALIASES' => tr('Domain aliases'),
    'TR_SUBDOMAINS'     => tr('Subdomains'),
    'TR_NAME'           => tr('Name'),
    'TR_MOUNT_POINT'    => tr('Mount point'),
    'TR_DOCUMENT_ROOT'  => tr('Document root'),
    'TR_REDIRECT'       => tr('Redirect'),
    'TR_STATUS'         => tr('Status'),
    'TR_SSL_STATUS'     => tr('SSL status'),
    'TR_ACTIONS'        => tr('Actions'),
    'TR_DNS'            => tr('Custom DNS resource records'),
    'TR_DNS_NAME'       => tr('Name'),
    'TR_DNS_CLASS'      => tr('Class'),
    'TR_DNS_TYPE'       => tr('Type'),
    'TR_DNS_STATUS'     => tr('Status'),
    'TR_DNS_ACTION'     => tr('Actions'),
    'TR_DNS_DATA'       => tr('Record data'),
    'TR_DOMAIN_NAME'    => tr('Domain')
]);

Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $translations = $e->getParam('translations');
    $translations['core']['als_delete_alert'] = tr('Are you sure you want to delete this domain alias?');
    $translations['core']['als_order_cancel_alert'] = tr('Are you sure you want to cancel this domain alias order?');
    $translations['core']['sub_delete_alert'] = tr('Are you sure you want to delete this subdomain?');
    $translations['core']['dns_delete_alert'] = tr('Are you sure you want to delete this DNS record?');
    $translations['core']['dataTable'] = View::getDataTablesPluginTranslations(false);
});

global $baseServerVhostUtf8;
if (Application::getInstance()->getConfig()['CLIENT_DOMAIN_ALT_URLS'] == 'yes') {
    $baseServerVhostUtf8 = decodeIdna(Application::getInstance()->getConfig()->get('BASE_SERVER_VHOST'));
}

View::generateNavigation($tpl);
generateDomainsList($tpl);
generateSubdomainsList($tpl);
generateDomainAliasesList($tpl);
generateCustomDnsRecordsList($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onClientScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
