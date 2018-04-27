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

use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use iMSCP\Plugin\PluginManager as PluginManager;
use iMSCP\Utility\OpcodeCache;
use Zend\EventManager\Event;

/**
 * Upload plugin archive into the frontend/plugins directory
 *
 * Supported archives: tar.gz and tar.bz2
 *
 * @param PluginManager $pluginManager
 * @return bool TRUE on success, FALSE on failure
 */
function uploadPlugin($pluginManager)
{
    isset($_FILES['plugin_archive']) or View::showBadRequestErrorPage();

    $pluginName = 'dummy.xxxxxxx';
    $pluginDirectory = $pluginManager->pluginGetDirectory();
    $tmpDirectory = FRONTEND_ROOT_DIR . '/data/tmp';
    $ret = false;

    # Upload plugin archive into frontend/data/tmp directory (eg. frontend/data/tmp/PluginName.tar.gz)
    $tmpArchPath = uploadFile('plugin_archive', [function ($tmpDirectory) {
        $tmpFilePath = $_FILES['plugin_archive']['tmp_name'];
        if (!validateMimeType($tmpFilePath, ['application/x-gzip', 'application/x-bzip2',])) {
            setPageMessage(tr('Only tar.gz and tar.bz2 archives are supported.'), 'error');
            return false;
        }

        $pluginArchiveSize = $_FILES['plugin_archive']['size'];
        $maxUploadFileSize = getMaxFileUpload();

        if ($pluginArchiveSize > $maxUploadFileSize) {
            setPageMessage(tr('Plugin archive exceeds the maximum upload size'), 'error');
            return false;
        }

        return $tmpDirectory . '/' . $_FILES['plugin_archive']['name'];
    }, $tmpDirectory]);

    if ($tmpArchPath === false) {
        redirectTo('settings_plugins.php');
    }

    try {
        $arch = new \PharData($tmpArchPath);
        $pluginName = $arch->getBasename();

        // Abort early if the plugin is known and is protected
        if ($pluginManager->pluginIsKnown($pluginName) && $pluginManager->pluginIsProtected($pluginName)) {
            throw new \Exception(tr('You cannot update a protected plugin.'));
        }

        // Check for plugin integrity (Any plugin must provide at least two files: $pluginName.php and info.php files
        foreach ([$pluginName, 'info'] as $file) {
            if (!isset($arch["$pluginName/$file.php"])) {
                throw new \Exception(tr("%s doesn't look like an i-MSCP plugin archive. File %s is missing.", $pluginName, "$pluginName/$file.php"));
            }
        }

        // Check for plugin compatibility
        $pluginManager->pluginCheckCompat($pluginName, include("phar:///$tmpArchPath/$pluginName/info.php"));

        # Backup current plugin directory in temporary directory if exists
        if ($pluginManager->pluginIsKnown($pluginName)) {
            if (!@rename("$pluginDirectory/$pluginName", "$tmpDirectory/$pluginName" . '-old')) {
                throw new \Exception(tr("Could not backup current %s plugin directory.", $pluginName));
            }
        }

        # Extract new plugin archive
        $arch->extractTo($pluginDirectory, NULL, true);
        $ret = true;
    } catch (\Exception $e) {
        setPageMessage($e->getMessage(), 'error');

        if (!empty($pluginName) && is_dir("$tmpDirectory/$pluginName" . '-old')) {
            // Try to restore previous plugin directory on error
            if (!@rename("$tmpDirectory/$pluginName" . '-old', "$pluginDirectory/$pluginName")) {
                setPageMessage(tr('Could not restore ancient %s plugin directory', $pluginName), 'error');
            }
        }
    }

    // Cleanup
    @unlink($tmpArchPath);
    removeDirectory("$tmpDirectory/$pluginName");
    removeDirectory("$tmpDirectory/$pluginName" . '-old');
    return $ret;
}

/**
 * Translate the given plugin status
 *
 * @param string $pluginStatus Plugin status to translate
 * @return string Translated plugin status
 */
function translateStatus($pluginStatus)
{
    switch ($pluginStatus) {
        case 'uninstalled':
            return tr('Uninstalled');
        case 'toinstall':
            return tr('Installation in progress...');
        case 'touninstall':
            return tr('Uninstallation in progress...');
        case 'toupdate':
            return tr('Update in progress...');
        case 'tochange':
            return tr('Reconfiguration in progress...');
        case 'toenable':
            return tr('Activation in progress...');
        case 'todisable':
            return tr('Deactivation in progress...');
        case 'enabled':
            return tr('Activated');
        case 'disabled':
            return tr('Deactivated');
        default:
            return tr('Unknown status');
    }
}

/**
 * Generates plugin list
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param PluginManager $pluginManager
 * @return void
 */
function generatePage($tpl, $pluginManager)
{
    $pluginList = $pluginManager->pluginGetList('all', false, false);

    if (empty($pluginList)) {
        $tpl->assign('PLUGINS_BLOCK', '');
        setPageMessage(tr('Plugin list is empty.'), 'static_info');
        return;
    }

    natsort($pluginList);
    $cacheFile = PERSISTENT_PATH . '/protected_plugins.php';

    foreach ($pluginList as $pluginName) {
        $pluginInfo = $pluginManager->pluginGetInfo($pluginName);
        $pluginStatus = $pluginManager->pluginGetStatus($pluginName);

        if (is_array($pluginInfo['author'])) {
            if (count($pluginInfo['author']) == 2) {
                $pluginInfo['author'] = implode(' ' . tr('and') . ' ', $pluginInfo['author']);
            } else {
                $lastEntry = array_pop($pluginInfo['author']);
                $pluginInfo['author'] = implode(', ', $pluginInfo['author']);
                $pluginInfo['author'] .= ' ' . tr('and') . ' ' . $lastEntry;
            }
        }

        $tpl->assign([
            'PLUGIN_NAME'        => toHtml($pluginName),
            'PLUGIN_DESCRIPTION' => tr($pluginInfo['desc']),
            'PLUGIN_STATUS'      => $pluginManager->pluginHasError($pluginName) ? tr('Unexpected error') : translateStatus($pluginStatus),
            'PLUGIN_VERSION'     => isset($pluginInfo['__nversion__']) ? toHtml($pluginInfo['__nversion__']) : tr('Unknown'),
            'PLUGIN_BUILD'       => (isset($pluginInfo['build']) && $pluginInfo['build'] > 0) ? toHtml($pluginInfo['build']) : tr('N/A'),
            'PLUGIN_AUTHOR'      => toHtml($pluginInfo['author']),
            'PLUGIN_MAILTO'      => toHtml($pluginInfo['email']),
            'PLUGIN_SITE'        => toHtml($pluginInfo['url'])
        ]);

        if ($pluginManager->pluginHasError($pluginName)) {
            $tpl->assign(
                'PLUGIN_STATUS_DETAILS',
                tr('An unexpected error occurred: %s', '<br><br>' . $pluginManager->pluginGetError($pluginName))
            );
            $tpl->parse('PLUGIN_STATUS_DETAILS_BLOCK', 'plugin_status_details_block');
            $tpl->assign([
                'PLUGIN_DEACTIVATE_LINK' => '',
                'PLUGIN_ACTIVATE_LINK'   => '',
                'PLUGIN_PROTECTED_LINK'  => ''
            ]);
        } else {
            $tpl->assign('PLUGIN_STATUS_DETAILS_BLOCK', '');

            if ($pluginManager->pluginIsProtected($pluginName)) { // Protected plugin
                $tpl->assign([
                    'PLUGIN_ACTIVATE_LINK'   => '',
                    'PLUGIN_DEACTIVATE_LINK' => '',
                    'TR_UNPROTECT_TOOLTIP'   => tr('To unprotect this plugin, you must edit the %s file', $cacheFile)
                ]);
                $tpl->parse('PLUGIN_PROTECTED_LINK', 'plugin_protected_link');
            } elseif ($pluginManager->pluginIsUninstalled($pluginName)) { // Uninstalled plugin
                $tpl->assign([
                    'PLUGIN_DEACTIVATE_LINK' => '',
                    'ACTIVATE_ACTION'        => $pluginManager->pluginIsInstallable($pluginName) ? 'install' : 'enable',
                    'TR_ACTIVATE_TOOLTIP'    => $pluginManager->pluginIsInstallable($pluginName)
                        ? tr('Install this plugin') : tr('Activate this plugin'),
                    'UNINSTALL_ACTION'       => 'delete',
                    'TR_UNINSTALL_TOOLTIP'   => tr('Delete this plugin'),
                    'PLUGIN_PROTECTED_LINK'  => ''
                ]);
                $tpl->parse('PLUGIN_ACTIVATE_LINK', 'plugin_activate_link');
            } elseif ($pluginManager->pluginIsDisabled($pluginName)) { // Disabled plugin
                $tpl->assign([
                    'PLUGIN_DEACTIVATE_LINK' => '',
                    'ACTIVATE_ACTION'        => 'enable',
                    'TR_ACTIVATE_TOOLTIP'    => tr('Activate this plugin'),
                    'UNINSTALL_ACTION'       => $pluginManager->pluginIsUninstallable($pluginName) ? 'uninstall' : 'delete',
                    'TR_UNINSTALL_TOOLTIP'   => $pluginManager->pluginIsUninstallable($pluginName)
                        ? tr('Uninstall this plugin') : tr('Delete this plugin'),
                    'PLUGIN_PROTECTED_LINK'  => ''
                ]);
                $tpl->parse('PLUGIN_ACTIVATE_LINK', 'plugin_activate_link');
            } elseif ($pluginManager->pluginIsEnabled($pluginName)) { // Enabled plugin
                $tpl->assign([
                    'PLUGIN_ACTIVATE_LINK'  => '',
                    'PLUGIN_PROTECTED_LINK' => ''
                ]);

                $tpl->parse('PLUGIN_DEACTIVATE_LINK', 'plugin_deactivate_link');
            } else { // Plugin with unknown status
                $tpl->assign([
                    'PLUGIN_DEACTIVATE_LINK' => '',
                    'PLUGIN_ACTIVATE_LINK'   => '',
                    'PLUGIN_PROTECTED_LINK'  => ''
                ]);
            }
        }

        $tpl->parse('PLUGIN_BLOCK', '.plugin_block');
    }
}

/**
 * Check plugin action
 *
 * @param PluginManager $pluginManager
 * @param string $pluginName Name of plugin on which the action is being performed
 * @param string $action Action Plugin action name ( install|uninstall|update|change|enable|disable|delete|protect )
 * @return bool TRUE if the plugin action is allowed, FALSE otherwise
 */
function checkAction($pluginManager, $pluginName, $action)
{
    if ($pluginManager->pluginIsProtected($pluginName)) {
        setPageMessage(tr('Plugin %s is protected.', $pluginName), 'warning');
        return false;
    }

    $ret = true;
    $pluginStatus = $pluginManager->pluginGetStatus($pluginName);

    switch ($action) {
        case 'install':
            if (!$pluginManager->pluginIsInstallable($pluginName) || !in_array($pluginStatus, ['toinstall', 'uninstalled'])) {
                setPageMessage(tr('Plugin %s cannot be installed.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'uninstall':
            if (!$pluginManager->pluginIsUninstallable($pluginName) || !in_array($pluginStatus, ['touninstall', 'disabled'])) {
                setPageMessage(tr('Plugin %s cannot be uninstalled.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'update':
            if ($pluginStatus != 'toupdate') {
                setPageMessage(tr('Plugin %s cannot be updated.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'change':
            if ($pluginStatus != 'tochange') {
                setPageMessage(tr('Plugin %s cannot be reconfigured.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'enable':
            if (!in_array($pluginStatus, ['toenable', 'disabled', 'uninstalled'])) {
                setPageMessage(tr('Plugin %s cannot be activated.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'disable':
            if (!in_array($pluginStatus, ['todisable', 'enabled', 'installed'])) {
                setPageMessage(tr('Plugin %s cannot be deactivated.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        case 'delete':
            if ($pluginStatus != 'todelete') {
                if ($pluginManager->pluginIsUninstallable($pluginName)) {
                    if ($pluginStatus != 'uninstalled') {
                        $ret = false;
                    }
                } elseif (!in_array($pluginStatus, ['uninstalled', 'disabled'])) {
                    $ret = false;
                }

                if (!$ret) {
                    setPageMessage(tr('Plugin %s cannot be deleted.', $pluginName), 'warning');
                }
            }

            break;
        case 'protect':
            if ($pluginStatus != 'enabled') {
                setPageMessage(tr('Plugin %s cannot be protected.', $pluginName), 'warning');
                $ret = false;
            }

            break;
        default:
            View::showBadRequestErrorPage();
    }

    return $ret;
}

/**
 * Do the given action for the given plugin
 *
 * @param PluginManager $pluginManager
 * @param string $pluginName Plugin name
 * @param string $action Action ( install|uninstall|update|change|enable|disable|delete|protect )
 * @return void
 */
function doAction($pluginManager, $pluginName, $action)
{
    $pluginManager->pluginIsKnown($pluginName) or View::showBadRequestErrorPage();

    try {
        if (in_array($action, ['install', 'update', 'enable'])) {
            $pluginManager->pluginCheckCompat($pluginName, $pluginManager->pluginLoad($pluginName)->getInfo());
        }

        if (!checkAction($pluginManager, $pluginName, $action)) {
            return;
        }

        $ret = call_user_func([$pluginManager, 'plugin' . ucfirst($action)], $pluginName);

        if ($ret === false) {
            setPageMessage(tr('An unexpected error occurred.'));
            return;
        }

        if ($ret == PluginManager::ACTION_FAILURE || $ret == PluginManager::ACTION_STOPPED) {
            $msg = $ret == PluginManager::ACTION_FAILURE ? tr('Action has failed.') : tr('Action has been stopped.');

            switch ($action) {
                case 'install':
                    $msg = tr('Could not install the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'uninstall':
                    $msg = tr('Could not uninstall the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'update':
                    $msg = tr('Could not update the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'change':
                    $msg = tr('Could not change the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'enable':
                    $msg = tr('Could not enable the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'disable':
                    $msg = tr('Could not disable the %s plugin: %s', $pluginName, $msg);
                    break;
                case 'delete':
                    $msg = tr('Could not delete the %s plugin: %s', $pluginName, $msg);
                    break;
                default:
                    $msg = tr('Could not protect the %s plugin: %s', $pluginName, $msg);
            }

            setPageMessage($msg, 'error');
            return;
        }

        $msg = '';

        if ($action != 'delete' && $pluginManager->pluginHasBackend($pluginName)) {
            switch ($action) {
                case 'install':
                    $msg = tr('Plugin %s scheduled for installation.', $pluginName);
                    break;
                case 'uninstall':
                    $msg = tr('Plugin %s scheduled for uninstallation.', $pluginName);
                    break;
                case 'update':
                    $msg = tr('Plugin %s scheduled for update.', $pluginName);
                    break;
                case 'change':
                    $msg = tr('Plugin %s scheduled for change.', $pluginName);
                    break;
                case 'enable':
                    $msg = tr('Plugin %s scheduled for activation.', $pluginName);
                    break;
                case 'disable':
                    $msg = tr('Plugin %s scheduled for deactivation.', $pluginName);
                    break;
                case 'protect':
                    $msg = tr('Plugin %s protected.', $pluginName);
            }

            setPageMessage($msg, 'success');
            return;
        }

        switch ($action) {
            case 'install':
                $msg = tr('Plugin %s installed.', $pluginName);
                break;
            case 'uninstall':
                $msg = tr('Plugin %s uninstalled.', $pluginName);
                break;
            case 'update':
                $msg = tr('Plugin %s updated.', $pluginName);
                break;
            case 'change':
                $msg = tr('Plugin %s reconfigured.', $pluginName);
                break;
            case 'enable':
                $msg = tr('Plugin %s activated.', $pluginName);
                break;
            case 'disable':
                $msg = tr('Plugin %s deactivated.', $pluginName);
                break;
            case 'delete':
                $msg = tr('Plugin %s deleted.', $pluginName);
                break;
            case 'protect':
                $msg = tr('Plugin %s protected.', $pluginName);
        }

        setPageMessage($msg, 'success');
    } catch (\Exception $e) {
        setPageMessage($e->getMessage(), 'error');
    }
}

/**
 * Do bulk action (activate|deactivate|protect)
 *
 * @param PluginManager $pluginManager
 * @return void
 */
function doBulkAction($pluginManager)
{
    $action = cleanInput($_POST['bulk_actions']);

    in_array($action, ['install', 'uninstall', 'enable', 'disable', 'delete', 'protect']) or View::showBadRequestErrorPage();

    if (!isset($_POST['checked']) || !is_array($_POST['checked']) || empty($_POST['checked'])) {
        setPageMessage(tr('You must select at least one plugin.'), 'error');
        return;
    }

    foreach ($_POST['checked'] as $pluginName) {
        doAction($pluginManager, cleanInput($pluginName), $action);
    }
}

/**
 * Update plugin list
 *
 * @param PluginManager $pluginManager
 * @return void
 */
function updatePluginList(PluginManager $pluginManager)
{
    $responses = $pluginManager->getEventManager()->trigger(Events::onBeforeUpdatePluginList, NULL, ['pluginManager' => $pluginManager]);
    if ($responses->stopped()) {
        return;
    }

    $updateInfo = $pluginManager->pluginUpdateList();
    $pluginManager->getEventManager()->trigger(Events::onAfterUpdatePluginList, NULL, ['pluginManager' => $pluginManager]);
    setPageMessage(
        tr(
            'Plugins list has been updated: %s new plugin(s) found, %s plugin(s) updated, %s plugin(s) reconfigured, and %s plugin(s) deleted.',
            $updateInfo['new'], $updateInfo['updated'], $updateInfo['changed'], $updateInfo['deleted']
        ),
        'success'
    );
}

require 'application.php';

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

$pluginManager = Application::getInstance()->getPluginManager();

if (!empty($_REQUEST)
    || !empty($_FILES)
) {
    if (isset($_GET['update_plugin_list'])) {
        updatePluginList($pluginManager);
    } elseif (isset($_GET['install'])) {
        doAction($pluginManager, cleanInput($_GET['install']), 'install');
    } elseif (isset($_GET['uninstall'])) {
        doAction($pluginManager, cleanInput($_GET['uninstall']), 'uninstall');
    } elseif (isset($_GET['enable'])) {
        doAction($pluginManager, cleanInput($_GET['enable']), 'enable');
    } elseif (isset($_GET['disable'])) {
        doAction($pluginManager, cleanInput($_GET['disable']), 'disable');
    } elseif (isset($_GET['delete'])) {
        doAction($pluginManager, cleanInput($_GET['delete']), 'delete');
    } elseif (isset($_GET['protect'])) {
        doAction($pluginManager, cleanInput($_GET['protect']), 'protect');
    } elseif (isset($_GET['retry'])) {
        $pluginName = cleanInput($_GET['retry']);

        if ($pluginManager->pluginIsKnown($pluginName)) {
            switch ($pluginManager->pluginGetStatus($pluginName)) {
                case 'toinstall':
                    $action = 'install';
                    break;
                case 'touninstall':
                    $action = 'uninstall';
                    break;
                case 'toupdate':
                    $action = 'update';
                    break;
                case 'tochange':
                    $action = 'change';
                    break;
                case 'toenable':
                    $action = 'enable';
                    break;
                case 'todisable':
                    $action = 'disable';
                    break;
                case 'todelete':
                    $action = 'delete';
                    break;
                default:
                    // Handle case where the error field is not NULL and status field is in unexpected state
                    // Should never occurs...
                    $pluginManager->pluginSetStatus($pluginName, 'todisable');
                    $action = 'disable';
            }

            doAction($pluginManager, $pluginName, $action);
        } else {
            View::showBadRequestErrorPage();
        }
    } elseif (isset($_POST['bulk_actions'])) {
        doBulkAction($pluginManager);
    } elseif (!empty($_FILES) && uploadPlugin($pluginManager)) {
        OpcodeCache::clearAllActive(); // Force newest files to be loaded on next run
        setPageMessage(tr('Plugin has been successfully uploaded.'), 'success');
        redirectTo('settings_plugins.php?update_plugin_list');
    }

    redirectTo('settings_plugins.php');
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                      => 'shared/layouts/ui.tpl',
    'page'                        => 'admin/settings_plugins.tpl',
    'page_message'                => 'layout',
    'plugins_block'               => 'page',
    'plugin_block'                => 'plugins_block',
    'plugin_status_details_block' => 'plugin_block',
    'plugin_activate_link'        => 'plugin_block',
    'plugin_deactivate_link'      => 'plugin_block',
    'plugin_protected_link'       => 'plugin_block'
]);
Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')['core'] = array_merge($e->getParam('translations')['core'], [
        'dataTable'     => View::getDataTablesPluginTranslations(false),
        'force_retry'   => tr('Force retry'),
        'close'         => tr('Close'),
        'error_details' => tr('Error details')
    ]);
});
$tpl->assign([
    'TR_PAGE_TITLE'             => toHtml(tr('Admin / Settings / Plugin Management')),
    'TR_BULK_ACTIONS'           => toHtml(tr('Bulk Actions')),
    'TR_PLUGIN'                 => toHtml(tr('Plugin')),
    'TR_DESCRIPTION'            => toHtml(tr('Description')),
    'TR_STATUS'                 => toHtml(tr('Status')),
    'TR_ACTIONS'                => toHtml(tr('Actions')),
    'TR_INSTALL'                => toHtml(tr('Install')),
    'TR_ACTIVATE'               => toHtml(tr('Activate')),
    'TR_DEACTIVATE_TOOLTIP'     => toHtml(tr('Deactivate this plugin'), 'htmlAttr'),
    'TR_DEACTIVATE'             => toHtml(tr('Deactivate')),
    'TR_UNINSTALL'              => toHtml(tr('Uninstall')),
    'TR_PROTECT'                => toHtml(tr('Protect')),
    'TR_DELETE'                 => toHtml(tr('Delete')),
    'TR_PROTECT_TOOLTIP'        => toHtml(tr('Protect this plugin')),
    'TR_VERSION'                => toHtml(tr('Version')),
    'TR_BY'                     => toHtml(tr('By')),
    'TR_VISIT_PLUGIN_SITE'      => toHtml(tr('Visit plugin site')),
    'TR_UPDATE_PLUGIN_LIST'     => toHtml(tr('Update Plugins')),
    'TR_APPLY'                  => toHtml(tr('Apply')),
    'TR_PLUGIN_UPLOAD'          => toHtml(tr('Plugins Upload')),
    'TR_UPLOAD'                 => toHtml(tr('Upload')),
    'TR_PLUGIN_ARCHIVE'         => toHtml(tr('Plugin archive')),
    'TR_PLUGIN_ARCHIVE_TOOLTIP' => toHtml(tr('Only tar.gz and tar.bz2 archives are supported.'), 'htmlAttr'),
    'TR_PLUGIN_HINT'            => tr('Plugins hook into i-MSCP to extend its functionality with custom features. Plugins are developed independently from the core i-MSCP application by thousands of developers all over the world. You can find new plugins to install by browsing the %s.', '<a style="text-decoration: underline" href="https://i-mscp.net/filebase/" target="_blank">' . tr('i-MSCP plugin store') . '</a></u>'),
    'TR_CLICK_FOR_MORE_DETAILS' => toHtml(tr('Click here for more details'))
]);
View::generateNavigation($tpl);
generatePage($tpl, $pluginManager);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
