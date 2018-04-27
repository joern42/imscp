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
use iMSCP\Functions\Login;
use iMSCP\Functions\View;

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);
Counting::systemHasAntiRootkits() or View::showBadRequestErrorPage();

$config = Application::getInstance()->getConfig();

$tpl = new TemplateEngine();
$tpl->define([
    'layout'           => 'shared/layouts/ui.tpl',
    'page'             => 'admin/rootkit_log.tpl',
    'page_message'     => 'layout',
    'antirootkits_log' => 'page'
]);
$tpl->assign('TR_PAGE_TITLE', tr('Admin / System Tools / Anti-Rootkits Logs'));

$antiRootkits = [];

if (isset($config['ANTIROOTKITS'])) {
    $antiRootkits = explode(',', $config['ANTIROOTKITS']);
}

$antiRootkits[] = 'Other';
$antiRootkitLogFiles = [
    'Chkrootkit' => 'CHKROOTKIT_LOG',
    'Rkhunter'   => 'RKHUNTER_LOG',
    'Other'      => 'OTHER_ROOTKIT_LOG'
];

foreach ($antiRootkitLogFiles as $antiRootkit => $logVar) {
    if (!in_array($antiRootkit, $antiRootkits) || !isset($config[$logVar]) || $config[$logVar] == '') {
        unset($antiRootkitLogFiles[$antiRootkit]);
    }
}

if (!empty($antiRootkitLogFiles)) {
    $cache = Application::getInstance()->getCache();

    foreach ($antiRootkitLogFiles AS $antiRootkit => $logVar) {
        $logFile = $config[$logVar];
        $cacheId = 'iMSCP_Rootkit_' . pathinfo($logFile, PATHINFO_FILENAME);

        if (NULL === $content = $cache->getItem($cacheId)) {
            if (@is_readable($logFile) && @filesize($logFile) > 0) {
                $handle = fopen($logFile, 'r');
                $log = fread($handle, filesize($logFile));
                fclose($handle);
                $content = nl2br(toHtml($log));
                $content = '<div>' . $content . '</div>';
                $search = [];
                $replace = [];

                // rkhunter-like log colouring
                if ($antiRootkit == 'Rkhunter') {
                    $search [] = '/[^\-]WARNING/i';
                    $replace[] = '<strong style="color:orange">$0</strong>';
                    $search [] = '/([^a-z])(OK)([^a-z])/i';
                    $replace[] = '$1<span style="color:green">$2</span>$3';
                    $search [] = '/[ \t]+clean[ \t]+/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/Not found/i';
                    $replace[] = '<span style="color:blue">$0</span>';
                    $search [] = '/None found/i';
                    $replace[] = '<span style="color:magenta">$0</span>';
                    $search [] = '/Skipped/i';
                    $replace[] = '<span style="color:blue">$0</span>';
                    $search [] = '/unknown[^)]/i';
                    $replace[] = '<strong style="color:#bf55bf">$0</strong>';
                    $search [] = '/Unsafe/i';
                    $replace[] = '<strong style="color:#cfcf00">$0</strong>';
                    $search [] = '/[1-9][0-9]*[ \t]+vulnerable/i';
                    $replace[] = '<strong style="color:red">$0</strong>';
                    $search [] = '/0[ \t]+vulnerable/i';
                    $replace[] = '<span style="color:green">$0</span>';
                } elseif ($antiRootkit == 'Chkrootkit') {
                    // chkrootkit-like log colouring
                    $search [] = '/([^a-z][ \t]+)(INFECTED)/i';
                    $replace[] = '$1<strong style="color:red">$2</strong>';
                    $search [] = '/Nothing found/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/Nothing detected/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/Not infected/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/no packet sniffer/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/(: )(PACKET SNIFFER)/i';
                    $replace[] = '$1<span style="color:orange">$2</span>';
                    $search [] = '/not promisc/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/no suspect file(s|)/i';
                    $replace[] = '<span style="color:green">$0</span>';
                    $search [] = '/([0-9]+) process(|es) hidden/i';
                    $replace[] = '<span style="color:#cfcf00">$0</span>';
                }

                $content = preg_replace($search, $replace, $content);
            } else {
                $content = '<strong style="color:red">' . tr("%s doesn't exist or is empty.", $logFile) . '</strong>';
            }

            $cache->addItem($content, $cacheId, [], 86400);
        }

        $tpl->assign([
            'LOG'      => $content,
            'FILENAME' => $logFile
        ]);
        $tpl->parse('ANTIROOTKITS_LOG', '.antirootkits_log');
    }

    $tpl->assign('NB_LOG', sizeof($antiRootkitLogFiles));
} else {
    $tpl->assign('ANTIROOTKITS_LOG', '');
    setPageMessage(tr('No anti-rootkits logs'), 'static_info');
}

View::generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
