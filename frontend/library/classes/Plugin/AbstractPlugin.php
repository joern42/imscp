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

namespace iMSCP\Plugin;

use iMSCP\Application;
use iMSCP\Functions\View;
use iMSCP\Plugin\PluginManager as PluginManager;
use iMSCP\Utility\OpcodeCache;
use Zend\EventManager\EventManagerInterface;
use Zend\EventManager\ListenerAggregateInterface;
use Zend\EventManager\ListenerAggregateTrait;

/**
 * Class AbstractPlugin
 * @package iMSCP\Plugin
 */
abstract class AbstractPlugin implements ListenerAggregateInterface
{
    /**
     * @var array Plugin configuration parameters
     */
    private $config = [];

    /**
     * @var array Plugin previous configuration parameters
     */
    private $configPrev = [];

    /**
     * @var bool TRUE if plugin configuration is loaded, FALSE otherwise
     */
    private $isLoadedConfig = false;

    /**
     * @var string Plugin name
     */
    private $pluginName;

    /**
     * @var string $Plungin name
     */
    private $pluginType;

    /**
     * @var PluginManager
     */
    private $pluginManager;

    use ListenerAggregateTrait;

    /**
     * Constructor
     *
     * @param PluginManager $pluginManager
     */
    public function __construct(PluginManager $pluginManager)
    {
        $this->pluginManager = $pluginManager;
        $this->init();
    }

    /**
     * Attach one or more listeners
     *
     * Implementors may add an optional $priority argument; the EventManager implementation will pass this to the aggregate.
     *
     * @param EventManagerInterface $events
     * @param int $priority
     * @return void
     */
    public function attach(EventManagerInterface $events, $priority = 1)
    {
    }

    /**
     * Allow plugin initialization
     *
     * This method allows to initialize a plugin. That is the best place for adding additional translation files, or operating on the autoloader.
     *
     * For instance:
     *
     * <code>
     * $loader = Application::getInstance()->getAutoloader();
     * $loader->addPsr4('Cron\\', __DIR__ . '/frontend/library/vendor/cron-expression-master/src');
     *
     * l10n_addTranslations(__DIR__ . '/l10n/mo', 'Gettext', 'CronJobs');
     * </code>
     *
     * @return void
     */
    protected function init()
    {
    }

    /**
     * Returns plugin general information
     *
     * Need return an associative array with the following info fields:
     *
     * author: Plugin author name(s)
     * email: Plugin author email
     * version: Plugin version
     * build: Last build of the plugin in YYYYMMDDNN format
     * date: Last modified date of the plugin in YYYY-MM-DD format
     * require_api: Required i-MSCP plugin API version
     * require_cache_flush: OPTIONAL info field allowing to trigger flush of
     *                      cache on plugin action (excepted run action).
     *                      Value must be one of 'opcache' for OPcode cache,
     *                      'userland' for userland cache, <userland_cache_id>
     *                      for a specific userland cache ID
     * name: Plugin name
     * desc: Plugin short description (text only)
     * url: Website in which it's possible to found more information about the
     *      plugin
     * priority: OPTIONAL priority which define priority for plugin backend
     *           processing
     *
     * A plugin can provides any other info for its own needs. However, the
     * following keywords are reserved for internal use:
     *
     *  __nversion__      : Contain the last available plugin version
     *  __installable__   : Tell that the plugin provides installation routine(s)
     *  __uninstallable__ : Tell that the plugin provide uninstallation routine(s)
     * __need_change__    : Tell that the plugin need change
     * db_schema_version  : Plugin database schema version
     *
     * @return array An array containing information about plugin
     */
    function getInfo()
    {
        $file = $this->getPluginManager()->pluginGetDirectory() . '/' . $this->getName() . '/info.php';
        $info = [];

        if (@is_readable($file)) {
            $info = include($file);
            OpcodeCache::clearAllActive($file); // Be sure to load newest version on next call
        } else {
            if (file_exists($file)) {
                throw new \Exception(tr("Unable to read the %s file.", $file));
            }

            View::setPageMessage(
                tr(
                    '%s::getInfo() not implemented and %s not found. This is a bug in the %s plugin which must be reported to the author(s).', get_class($this),
                    $file,
                    $this->getName()
                ),
                'warning'
            );

        }

        return array_merge(
            [
                'author'      => tr('Unknown'),
                'email'       => '',
                'version'     => '0.0.0',
                'build'       => '0000000000',
                'date'        => '0000-00-00',
                'require_api' => '99.0.0',
                'name'        => $this->getName(),
                'desc'        => tr('Not provided'),
                'url'         => ''
            ],
            $info
        );
    }

    /**
     * Get plugin manager
     *
     * @return PluginManager
     */
    public function getPluginManager()
    {
        return $this->pluginManager;
    }

    /**
     * Returns plugin name
     *
     * @return string
     */
    final public function getName()
    {
        if (NULL === $this->pluginName) {
            $class = get_class($this);

            if ((false !== $pos = strrpos($class, '\\'))
                || (false !== $pos = strrpos($class, '_'))
            ) {
                $this->pluginName = substr($class, $pos + 1);
            } else {
                throw new \Exception(tr("Couldn't retrieve plugin name from the plugin class name."));
            }
        }

        return $this->pluginName;
    }

    /**
     * Returns plugin type
     *
     * @return string
     */
    final public function getType()
    {
        if (NULL === $this->pluginType) {
            $class = get_parent_class($this);

            if ($class == self::class) {
                $this->pluginType = 'Standard';
            } elseif ((false !== $pos = strrpos($class, '_'))) {
                $this->pluginType = substr($class, $pos + 1);
            } else {
                throw new \Exception(tr("Couldn't retrieve plugin type from the plugin parent class name."));
            }
        }

        return $this->pluginType;
    }

    /**
     * Return plugin configuration
     *
     * @return array An associative array which contain plugin configuration
     */
    final public function getConfig()
    {
        if (!$this->isLoadedConfig) {
            $this->loadConfig();
        }

        return $this->config;
    }

    /**
     * Load plugin configuration from database
     *
     * @return void
     */
    final protected function loadConfig()
    {
        $stmt = execQuery('SELECT plugin_config, plugin_config_prev FROM plugin WHERE plugin_name = ?', [
            $this->getName()
        ]);

        if ($stmt->rowCount()) {
            $row = $stmt->fetch();
            $this->config = json_decode($row['plugin_config'], true);
            $this->configPrev = json_decode($row['plugin_config_prev'], true);
            $this->isLoadedConfig = true;
            return;
        }

        $this->config = [];
        $this->configPrev = [];
    }

    /**
     * Return previous plugin configuration
     *
     * @return array An associative array which contain plugin previous configuration
     */
    final public function getConfigPrev()
    {
        if (!$this->isLoadedConfig) {
            $this->loadConfig();
        }

        return $this->configPrev;
    }

    /**
     * Return plugin configuration from file
     *
     * @return array
     */
    final public function getConfigFromFile()
    {
        $this->isLoadedConfig = false;
        $pluginName = $this->getName();
        $file = $this->getPluginManager()->pluginGetDirectory() . "/$pluginName/config.php";
        $config = [];

        if (!file_exists($file)) {
            return $config;
        }

        $config = include($file);
        OpcodeCache::clearAllActive($file); // Be sure to load newest version on next call

        # See https://wiki.i-mscp.net/doku.php?id=plugins:configuration

        $file = PERSISTENT_PATH . "/plugins/$pluginName.php";

        if (file_exists($file)) {
            $localConfig = include($file);
            OpcodeCache::clearAllActive($file); // Be sure to load newest version on next call

            // Remove item(s) first (if needed)
            if (array_key_exists('__REMOVE__', $localConfig)) {
                if (is_array($localConfig['__REMOVE__'])) {
                    $config = arrayDiffRecursive($config, $localConfig['__REMOVE__']);
                }

                unset($localConfig['__REMOVE__']);
            }

            $config = arrayMergeRecursive($config, $localConfig);
        }

        return $config;
    }

    /**
     * Returns the given plugin configuration
     *
     * @param string $paramName Configuration parameter name
     * @param mixed $default Default value returned
     * @return mixed Configuration parameter value
     */
    final public function getConfigParam($paramName, $default = NULL)
    {
        if (!$this->isLoadedConfig) {
            $this->loadConfig();
        }

        return isset($this->config[$paramName]) ? $this->config[$paramName] : $default;
    }

    /**
     * Returns the given previous plugin configuration
     *
     * @param string $paramName Configuration parameter name
     * @param mixed $default Default value returned
     * @return mixed Configuration parameter value
     */
    final public function getConfigPrevParam($paramName, $default = NULL)
    {
        if (!$this->isLoadedConfig) {
            $this->loadConfig();
        }

        return isset($this->configPrev[$paramName]) ? $this->configPrev[$paramName] : $default;
    }

    /**
     * Plugin installation
     *
     * This method is automatically called by the plugin manager when the
     * plugin is being installed.
     * @param PluginManager $pluginManager
     * @return void
     */
    public function install(PluginManager $pluginManager)
    {
    }

    /**
     * Plugin activation
     *
     * This method is automatically called by the plugin manager when the
     * plugin is being enabled (activated).
     *
     * @param PluginManager $pluginManager
     * @return void
     */
    public function enable(PluginManager $pluginManager)
    {
    }

    /**
     * Plugin deactivation
     *
     * This method is automatically called by the plugin manager when the
     * plugin is being disabled (deactivated).
     *
     * @param PluginManager $pluginManager
     * @return void
     */
    public function disable(PluginManager $pluginManager)
    {
    }

    /**
     * Plugin update
     *
     * This method is automatically called by the plugin manager when
     * the plugin is being updated.
     *
     * @param PluginManager $pluginManager
     * @param string $fromVersion Version from which plugin update is initiated
     * @param string $toVersion Version to which plugin is updated
     * @return void
     */
    public function update(PluginManager $pluginManager, $fromVersion, $toVersion)
    {
    }

    /**
     * Plugin uninstallation
     *
     * This method is automatically called by the plugin manager when the
     * plugin is being uninstalled.
     *
     * @param PluginManager $pluginManager
     * @return void
     */
    public function uninstall(PluginManager $pluginManager)
    {
    }

    /**
     * Plugin deletion
     *
     * This method is automatically called by the plugin manager when the
     * plugin is being deleted.
     *
     * @param PluginManager $pluginManager
     * @return void
     */
    public function delete(PluginManager $pluginManager)
    {
    }

    /**
     * Get routes
     *
     * This method allow the plugin to provide its routes. For instance:
     *
     * <code>
     * $pluginDir = $this->getPluginManager()->pluginGetDirectory() . '/' . $this->getName();
     *
     * return [
     *     '/admin/mailgraph.php'    => $pluginDir . '/frontend/mailgraph.php',
     *     '/admin/mailgraphics.php' => $pluginDir . '/frontend/mailgraphics.php'
     * ];
     * </code>
     *
     * @return array An array containing action script paths
     * @TODO merge this method with the route() method
     */
    public function getRoutes()
    {
        return [];
    }

    /**
     * Route an URL
     *
     * This method allows a plugin to provide its own routing logic. If a route
     * matches the given URL, this method MUST return a string representing
     * the action script to load, else, NULL must be returned. For instance:
     *
     * <code>
     * if (strpos($urlComponents['path'], '/mydns/api/') === 0) {
     *     return $this->getPluginManager()->pluginGetDirectory() . '/' . $this->getName() . '/api.php';
     * }
     *
     * return null;
     * </code>
     *
     * @param array $urlComponents Associative array containing URL components
     * @return string|null Action script path or null if not route match the URL
     * @noinspection PhpUnusedParameterInspection
     */
    public function route(
        /** @noinspection PhpUnusedParameterInspection */
        $urlComponents)
    {
        return NULL;
    }

    /**
     * Get plugin item with error status
     *
     * This method is called by the i-MSCP debugger component to retrieve plugin
     * items that are in error state.
     *
     * Basically, a plugin item is an item (entity) that belong to and managed
     * by a specific plugin. A plugin item can have different status, depending
     * on it current state. If a status reflect an error state, the plugin
     * should make the i-MSCP debugger component aware of this fact by
     * providing the following set of information:
     *
     *  table    : Name of the database table that belongs to the entity
     *  item_id  : The entity unique identifier in the database table
     *  item_name: An arbitrary string representing humanized item name
     *  status   : The status of the entity (generally an error string).
     *  field    : The name of the database field that holds item status
     *
     * For instance:
     *
     * <code>
     * return [
     *  [
     *      'table'     => 'cron_jobs',
     *      'item_id'   => 1,
     *      'item_name' => 'Cron job ID 1 -- domain.tld',
     *      'status'    => "Couldn't write cron table: Invalid syntax..."
     *      'field'     => 'cron_job_status'
     *  ],
     *  ...
     * ];
     * </code>
     *
     * @return array Array describing list of plugin items that are in error
     *               state
     */
    public function getItemWithErrorStatus()
    {
        return [];
    }

    /**
     * Change a plugin item status for a new attemps
     *
     * This method is called by the i-MSCP debugger component to recover items
     * that are in error state, those provided by the getItemWithErrorStatus()
     * method.
     *
     * Best practice: For any plugin item, you *SHOULD* implement one status
     * field and one error field. Then, when an item is in error state, the
     * status field should be left untouched and the error field updated with
     * error string. Doing this make it possible to repeat the task that has
     * failed instead of triggering a fixed action (setting status to
     * 'tochange' for change action)
     *
     * For instance:
     *
     * <code>
     * if ($table == 'cron_jobs' && $field == 'cron_job_status') {
     *      if($cron_job_status == 'todelete') {
     *        // Do something specific when item is being deleted...
     *      }
     *
     *     exec_query("UPDATE cron_jobs SET cron_job_error = NULL WHERE cron_job_id = ?", [$itemId]);
     * }
     * <code>
     *
     * @param string $table Table name
     * @param string $field Status field name
     * @param int $itemId item unique identifier
     * @return void
     */
    public function changeItemStatus($table, $field, $itemId)
    {
    }

    /**
     * Return count of backend requests being processed
     *
     * This method is called by the i-MSCP debugger component to get the count
     * of backend requests being processed for items that belong to the plugin.
     *
     * For instance:
     *
     * <code>
     * return execute_query(
     *     "
     *         SELECT COUNT(cron_job_id)
     *         FROM cron_jobs
     *         WHERE cron_job_status IN ('toadd','tochange','toenable','todisable','tosuspend','tounsuspend','todelete')
     *         AND cron_job_error IS NULL
     *     "
     * )->fetchColumn();
     * </code>
     *
     * @return int
     */
    public function getCountRequests()
    {
        return 0;
    }

    /**
     * Migrate plugin database schema
     *
     * Provide a convenient way to alter plugins's database schema over the
     * time in a consistent and easy way.
     *
     * Each migration is considered as being a new 'version' of the database
     * schema. A schema starts off with nothing in it, and each migation
     * modifies it to add or remove tables, columns, or entries. Each time a
     * new migration is applied, the 'db_schema_version' info field is updated.
     * This allow to keep track of the last applied database migration.
     *
     * USAGE:
     *
     * Any plugin which uses this method *MUST* provide a 'sql' directory a
     * the root of its directory, which contain all migration files.
     *
     * Migration file naming convention:
     *
     * Each migration file must be named using the following naming convention:
     *
     * <version>_<description>.php where:
     *
     *  - <version> migration version number such as 003
     *  - <description> migration description such as add_version_column
     *
     * Resulting to the following migration file:
     *
     *  003_add_version_confdir_path_prev.php
     *
     * Version of the first migration *MUST* start to 001 and not 000.
     *
     * Migration file structure:
     *
     * A migration file is a simple PHP file which return an associative array
     * containing exactly two pairs of key/value:
     *
     * - The 'up' key for which the value must be the SQL statement to be executed in the 'up' mode
     * - The 'down' key for which the value must be the SQL statement to be executed in the 'down' mode
     *
     * If one of these keys is missing, the migrateDb method won't complain and will simply continue its work normally.
     *
     * Sample:
     *
     * <code>
     * return array(
     *     'up' => '
     *         ALTER TABLE `php_switcher_version`
     *         ADD `version_confdir_path_prev` varchar(255) COLLATE utf8_unicode_ci NULL DEFAULT NULL
     *         AFTER `version_binary_path`;
     *      ',
     *      'down' => '
     *          ALTER TABLE `php_switcher_version` DROP COLUMN `version_confdir_path_prev`;
     *      '
     * );
     * </code>
     *
     * @param string $migrationMode Migration mode (up|down)
     * @return void
     */
    protected function migrateDb($migrationMode = 'up')
    {
        ignore_user_abort(true);

        $pluginName = $this->getName();
        $pluginManager = $this->getPluginManager();
        $sqlDir = $pluginManager->pluginGetDirectory() . '/' . $pluginName . '/sql';

        if (!@is_dir($sqlDir)) {
            throw new \Exception(tr("Directory %s doesn't exist.", $sqlDir));
        }

        $pluginInfo = $pluginManager->pluginGetInfo($pluginName);
        $dbSchemaVersion = isset($pluginInfo['db_schema_version']) ? $pluginInfo['db_schema_version'] : '000';
        $migrationFiles = [];

        /** @var $migrationFileInfo \DirectoryIterator */
        foreach (new \DirectoryIterator($sqlDir) as $migrationFileInfo) {
            if (!$migrationFileInfo->isDot()) {
                $migrationFiles[] = $migrationFileInfo->getRealPath();
            }
        }

        natsort($migrationFiles);

        if ($migrationMode == 'down') {
            $migrationFiles = array_reverse($migrationFiles);
        }

        $db = Application::getInstance()->getDb();

        try {
            foreach ($migrationFiles as $migrationFile) {
                if (!@is_readable($migrationFile)) {
                    throw new \Exception(tr('Migration file %s is not readable.', $migrationFile));
                }

                if (!preg_match('/(\d+)_[^\/]+\.php$/i', $migrationFile, $version)) {
                    throw new \Exception(tr("File %s doesn't look like a migration file.", $migrationFile));
                }

                if (($migrationMode == 'up' && $version[1] > $dbSchemaVersion)
                    || ($migrationMode == 'down' && $version[1] <= $dbSchemaVersion)
                ) {
                    $migrationFilesContent = include($migrationFile);
                    if (isset($migrationFilesContent[$migrationMode])) {
                        $stmt = $db->createStatement($migrationFilesContent[$migrationMode])->execute()->getResource();
                        /** @noinspection PhpStatementHasEmptyBodyInspection */
                        while ($stmt->nextRowset()) {
                            /* https://bugs.php.net/bug.php?id=61613 */
                        };
                    }

                    $dbSchemaVersion = $version[1];
                }
            }

            $pluginInfo['db_schema_version'] = ($migrationMode == 'up') ? $dbSchemaVersion : '000';
            $pluginManager->pluginUpdateInfo($pluginName, $pluginInfo->toArray());
        } catch (\Exception $e) {
            $pluginInfo['db_schema_version'] = $dbSchemaVersion;
            $pluginManager->pluginUpdateInfo($pluginName, $pluginInfo->toArray());
            throw new \Exception($e->getMessage(), $e->getCode(), $e);
        }
    }
}
