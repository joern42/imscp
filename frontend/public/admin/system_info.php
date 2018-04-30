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
use iMSCP\Functions\View;
use Zend\EventManager\Event;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkAuthentication(AuthenticationService::ADMIN_CHECK_AUTH_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$tpl = new TemplateEngine();
$tpl->define([
    'layout'       => 'shared/layouts/ui.tpl',
    'page'         => 'admin/system_info.phtml',
    'page_message' => 'layout',
    'device_block' => 'page'
]);
$tpl->info = json_decode(execQuery("SELECT `value` FROM `config` WHERE `name` = 'iMSCP_INFO'")->fetchColumn(), true);
$sysinfo = new SystemInfo();
$tpl->assign([
    'CPU_MODEL'       => toHtml($sysinfo->cpu['model']),
    'CPU_CORES'       => toHtml($sysinfo->cpu['cpus']),
    'CPU_CLOCK_SPEED' => toHtml($sysinfo->cpu['cpuspeed']),
    'CPU_CACHE'       => toHtml($sysinfo->cpu['cache']),
    'CPU_BOGOMIPS'    => toHtml($sysinfo->cpu['bogomips']),
    'UPTIME'          => toHtml($sysinfo->uptime),
    'KERNEL'          => toHtml($sysinfo->kernel),
    'LOAD'            => toHtml(sprintf('%s %s %s', $sysinfo->load[0], $sysinfo->load[1], $sysinfo->load[2])),
    'RAM_TOTAL'       => toHtml(bytesHuman($sysinfo->ram['total'] * 1024)),
    'RAM_USED'        => toHtml(bytesHuman($sysinfo->ram['used'] * 1024)),
    'RAM_FREE'        => toHtml(bytesHuman($sysinfo->ram['free'] * 1024)),
    'SWAP_TOTAL'      => toHtml(bytesHuman($sysinfo->swap['total'] * 1024)),
    'SWAP_USED'       => toHtml(bytesHuman($sysinfo->swap['used'] * 1024)),
    'SWAP_FREE'       => toHtml(bytesHuman($sysinfo->swap['free'] * 1024))
]);

foreach ($sysinfo->filesystem as $device) {
    $tpl->assign([
        'MOUNT'     => toHtml($device['mount']),
        'TYPE'      => toHtml($device['fstype']),
        'PARTITION' => toHtml($device['disk']),
        'PERCENT'   => toHtml($device['percent']),
        'FREE'      => toHtml(bytesHuman($device['free'] * 1024)),
        'USED'      => toHtml(bytesHuman($device['used'] * 1024)),
        'SIZE'      => toHtml(bytesHuman($device['size'] * 1024))
    ]);
    $tpl->parse('DEVICE_BLOCK', '.device_block');
}

$tpl->assign([
    'TR_PAGE_TITLE'               => toHtml(tr('Admin / System Tools / System Information')),
    'TR_DISTRIBUTION_INFO'        => toHtml(tr('Distribution')),
    'TR_DISTRIBUTION_NAME'        => toHtml(tr('Name')),
    'TR_iMSCP_INFO'               => toHtml(tr('i-MSCP Info')),
    'TR_IMSCP_VERSION'            => toHtml(tr('Version')),
    'TR_IMSCP_CODENAME'           => toHtml(tr('Codename')),
    'TR_IMSCP_BUILD'              => toHtml(tr('Build')),
    'TR_iMSCP_SERVERS_INFO'       => toHtml(tr('Servers info')),
    'TR_IMSCP_PLUGIN_API_VERSION' => toHtml(tr('Plugin API version')),
    'TR_IMSCP_NAMED_SERVER'       => toHtml(tr('NAMED')),
    'TR_IMSCP_HTTPD_SERVER'       => toHtml(tr('HTTPD')),
    'TR_IMSCP_FTPD_SERVER'        => toHtml(tr('FTPD')),
    'TR_IMSCP_MTA_SERVER'         => toHtml(tr('MTA')),
    'TR_IMSCP_PHP_SERVER'         => toHtml(tr('PHP')),
    'TR_IMSCP_PO_SERVER'          => toHtml(tr('IMAP/POP')),
    'TR_IMSCP_SQL_SERVER'         => toHtml(tr('SQL')),
    'TR_IMSCP_CRON_SERVER'        => toHtml(tr('CRON')),
    'TR_SYSTEM_INFO'              => toHtml(tr('System')),
    'TR_KERNEL'                   => toHtml(tr('Kernel Version')),
    'TR_UPTIME'                   => toHtml(tr('Uptime')),
    'TR_LOAD'                     => toHtml(tr('Load (1 Min, 5 Min, 15 Min)')),
    'TR_CPU_INFO'                 => toHtml(tr('Processor Info')),
    'TR_CPU'                      => toHtml(tr('Processor')),
    'TR_CPU_MODEL'                => toHtml(tr('Model')),
    'TR_CPU_CORES'                => toHtml(tr('Cores')),
    'TR_CPU_CLOCK_SPEED'          => toHtml(tr('Clock speed (MHz)')),
    'TR_CPU_CACHE'                => toHtml(tr('Cache')),
    'TR_CPU_BOGOMIPS'             => toHtml(tr('Bogomips')),
    'TR_MEMORY_INFO'              => toHtml(tr('Memory Info')),
    'TR_RAM'                      => toHtml(tr('Memory data')),
    'TR_TOTAL'                    => toHtml(tr('Total')),
    'TR_USED'                     => toHtml(tr('Used')),
    'TR_FREE'                     => toHtml(tr('Free')),
    'TR_SWAP'                     => toHtml(tr('Swap data')),
    'TR_FILE_SYSTEM_INFO'         => toHtml(tr('Filesystem Info')),
    'TR_MOUNT'                    => toHtml(tr('Mount point')),
    'TR_TYPE'                     => toHtml(tr('Type')),
    'TR_PARTITION'                => toHtml(tr('Partition')),
    'TR_PERCENT'                  => toHtml(tr('Percent')),
    'TR_SIZE'                     => toHtml(tr('Size'))
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations();
});
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
