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

use Composer\Autoload\ClassLoader as Autoloader;
use iMSCP\Authentication\Adapter\Event as AuthEventAdapter;
use iMSCP\Config\Reader\JavaProperties;
use iMSCP\Config\StandaloneReaderPluginManager;
use iMSCP\Exception;
use iMSCP\Plugin\PluginManager;
use Zend\Authentication\AuthenticationService;
use Zend\Cache;
use Zend\Config;
use Zend\Db\Adapter\Adapter as DbAdapter;
use Zend\EventManager;
use Zend\I18n\Translator\Translator;
use Zend\Session\Config\SessionConfig;
use Zend\Session\Container;
use Zend\Session\SessionManager;

/**
 * Class Application
 * @package iMSCP
 */
class Application implements EventManager\EventsCapableInterface, EventManager\SharedEventsCapableInterface
{
    /**
     * @var Application
     */
    static protected $application;

    /**
     * @var string Application environment
     */
    protected $environment;

    /**
     * @var Autoloader
     */
    protected $autoloader;

    /**
     * @var EventManager\EventManagerInterface
     */
    protected $events;

    /**
     * @var PluginManager
     */
    protected $pluginManager;

    /**
     * @var array Merged configuration
     */
    protected $config;

    /**
     * @var Cache\Storage\Adapter\BlackHole|Cache\Storage\Adapter\Apcu
     */
    protected $cache;

    /**
     * @var DbAdapter
     */
    protected $db;

    /**
     * @var Translator
     */
    protected $translator;

    /**
     * @var AuthenticationService
     */
    protected $authService;

    /**
     * @var Registry
     */
    protected $registry;

    /**
     * @static boolean Flag indicating whether application has been bootstrapped
     */
    protected $bootstrapped = false;

    /**
     * @var Container
     */
    protected $sessionContainer;

    /**
     * Get application instance
     *
     * @return Application
     */
    static public function getInstance(): Application
    {
        if (NULL === static::$application) {
            static::$application = new static();
        }

        return static::$application;
    }

    /**
     * Make new unavailable (singleton)
     */
    private function __construct()
    {
    }

    /**
     * Bootstrap the application
     *
     * @return Application
     */
    public function bootstrap(): Application
    {
        if ($this->bootstrapped) {
            throw new \LogicException('Already bootstrapped.');
        }

        $this->loadFunctions();
        $this->setErrorHandling();
        $this->setEncoding();
        $this->setTimezone();
        $this->loadPlugins();

        $this->getEventManager()->trigger(Events::onAfterApplicationBootstrap, $this);
        $this->bootstrapped = true;
        return $this;
    }

    /**
     * Get application authentication service
     *
     * @return AuthenticationService
     */
    public function getAuthService(): AuthenticationService
    {
        if (NULL === $this->authService) {
            $this->authService = new AuthenticationService(
                NULL, new AuthEventAdapter($this->getEventManager())
            );
        }

        return $this->authService;
    }

    /**
     * Get application autoloader
     *
     * @return Autoloader
     */
    public function getAutoloader(): Autoloader
    {
        return $this->autoloader;
    }

    /**
     * Set application autoloader
     *
     * @param Autoloader $autoloader
     * @return Application
     */
    public function setAutoLoader(Autoloader $autoloader): Application
    {
        $this->autoloader = $autoloader;
        return $this;
    }

    /**
     * Get application cache
     *
     * @return Cache\Storage\Adapter\BlackHole|Cache\Storage\Adapter\Apcu
     */
    public function getCache(): Cache\Storage\StorageInterface
    {
        if (NULL === $this->cache) {
            $adapter = PHP_SAPI != 'cli' && version_compare(phpversion('apcu'), '5.1.0', '>=') && ini_get('apc.enabled') ? 'Apcu' : 'BlackHole';
            $this->cache = Cache\StorageFactory::factory([
                'adapter' => [
                    'name'    => $adapter,
                    'options' => [
                        'namespace' => 'iMSCPcache'
                    ]
                ]
            ]);

            if ($adapter == 'Apcu') {
                $this->cache->addPlugin(Cache\StorageFactory::pluginFactory('ExceptionHandler', ['throw_exceptions' => false]));
                $this->cache->addPlugin(Cache\StorageFactory::pluginFactory('IgnoreUserAbort', ['exit_on_abort' => false]));
            }
        }

        return $this->cache;
    }

    /**
     * Get application configuration (merged configuration)
     *
     * @return Config\Config
     */
    public function getConfig(): Config\Config
    {
        if (NULL !== $this->config || NULL !== $this->config = $this->getCache()->getItem('merged_config')) {
            return $this->config;
        }

        // Load settings from master i-MSCP configuration file.
        // We need set our own JavaProperties configuration file reader as
        // the one provided by ZF doesn't handle equal sign as separator
        Config\Factory::setReaderPluginManager(new StandaloneReaderPluginManager());
        Config\Factory::registerReader('conf', JavaProperties::class);
        $this->config = new Config\Config(Config\Factory::fromFile(CONFIG_FILE_PATH), true);

        // Load and merge overridable settings
        $this->config->merge(new Config\Config(include_once 'osettings.php', true));

        // Load and merge settings from database
        $this->config->merge(new Config\Config($this->getDb()
            ->createStatement('SELECT name, value FROM config')
            ->execute()
            ->getResource()
            ->fetchAll(\PDO::FETCH_KEY_PAIR)
        ));

        // Set default root template directory according current theme
        $this->config['ROOT_TEMPLATE_PATH'] = FRONTEND_ROOT_DIR . '/themes/' . $this->config['USER_INITIAL_THEME'];

        // Cache the resulting merged configuration into cache, unless debug mode is enabled
        if (!$this->config['DEBUG']) {
            $this->getCache()->addItem('merged_config', $this->config);
        } else {
            $session = $this->getSession();

            if (!isXhr() && ($session['user_type'] == 'admin' || (isset($session['logged_from_type']) && $session['logged_from_type'] == 'admin'))) {
                // If the debug mode is enabled, and if logged user is of 'admin'
                // type, we display a warning as having the debug mode enabled in
                // a production environment is not a good thing for performances
                // reasons (cache disabled)
                $this->getEventManager()->attach(Events::onGeneratePageMessages, function () {
                    setPageMessage(tr('The debug mode is currently enabled meaning that the cache is also disabled..'), 'static_warning');
                    setPageMessage(tr('For better performances, you should consider disabling it through the %s.', CONFIG_FILE_PATH), 'static_warning');
                });
            }
        }

        return $this->config;
    }

    /**
     * Get application environment
     *
     * @return string
     */
    public function getEnvironment(): string
    {
        return $this->environment;
    }

    /**
     * Set eapplication nvironment
     *
     * @param string $environment
     * @return Application
     */
    public function setEnvironment(string $environment = 'production'): Application
    {
        $this->environment = $environment;
        return $this;
    }

    /**
     * Get application event manager
     *
     * @inheritdoc
     */
    public function getEventManager(): EventManager\EventManagerInterface
    {
        if ($this->events === NULL) {
            $this->events = new EventManager\EventManager(new EventManager\SharedEventManager());
            $this->events->setIdentifiers([__CLASS__, get_class($this)]);
        }

        return $this->events;
    }

    /**
     * Get application shared event manager
     * @inheritdoc
     */
    public function getSharedManager(): EventManager\SharedEventManagerInterface
    {
        return $this->getEventManager()->getSharedManager();
    }

    /**
     * Get application plugin manager
     *
     * @return PluginManager
     */
    public function getPluginManager(): PluginManager
    {
        if (NULL === $this->pluginManager) {
            $this->pluginManager = new PluginManager(FRONTEND_ROOT_DIR . '/plugins', $this->getEventManager(), $this->getCache());
        }

        return $this->pluginManager;
    }

    /**
     * Get application translator
     *
     * @return Translator
     */
    public function getTranslator(): Translator
    {
        if (NULL === $this->translator) {
            $locale = new \Locale();

            if (PHP_SAPI == 'cli') {
                $locale->setDefault('en_GB');
            } else {
                $locale->setDefault($locale->acceptFromHttp($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? 'en_GB'));
            }

            $fallbackLocales = [
                'bg' => 'bg_BG',
                'ca' => 'ca_es',
                'cs' => 'cs_CZ',
                'da' => 'da_DK',
                'de' => 'de_DE',
                'en' => 'en_GB',
                'es' => 'es_ES',
                'eu' => 'eu_ES',
                'fa' => 'fa_IR',
                'fi' => 'fi_FI',
                'fr' => 'fr_FR',
                'gl' => 'gl_ES',
                'hu' => 'hu_HU',
                'it' => 'it_IT',
                'ja' => 'ja_JP',
                'lt' => 'lt_LT',
                'nb' => 'nb_NO',
                'nl' => 'nl_NL',
                'pl' => 'pl_PL',
                'pt' => 'pt_PT',
                'ro' => 'ro_RO',
                'ru' => 'ru_RU',
                'sk' => 'sk_SK',
                'sv' => 'sv_SE',
                'th' => 'th_TH',
                'tr' => 'tr_TR',
                'uk' => 'uk_UA',
                'zh' => 'zh_CN'
            ];

            $this->translator = Translator::factory([
                'locale'                    => [
                    $locale::getDefault(),
                    $fallbackLocales[$locale::getDefault()] ?? 'en_GB'
                ],
                'translation_file_patterns' => [
                    [
                        'type'        => 'gettext',
                        'base_dir'    => FRONTEND_ROOT_DIR . '/i18n/locales',
                        'pattern'     => '%1$s/LC_MESSAGES/%1$s.mo',
                        'text_domain' => 'default'
                    ]
                ],
                'cache'                     => $this->getCache()
            ]);
        }

        return $this->translator;
    }

    /**
     * Set application errors handling
     *
     * Since 1.6.0:
     *  - error_reporting now set in pool conffile with value: E_ALL
     *  - error_log now set in pool conffile with value: {WEB_DIR}/data/logs/errors.log
     *  - log_errors now set in pool conffile with value: On
     *  - ignore_repeated_errors now set in pool conffile with value: On
     *  - display_errors now set in pool conffile with value: On (overridden below in production environment)
     *
     * @return void
     */
    protected function setErrorHandling(): void
    {
        if ($this->getEnvironment() == 'production') {
            ini_set('display_errors', 0);
        }

        set_exception_handler(new Exception\Handler());
    }

    /**
     * Set application internal encoding
     *
     * @return void
     */
    protected function setEncoding(): void
    {
        ini_set('default_charset', 'UTF-8');

        if (!extension_loaded('mbstring')) {
            throw new \RuntimeException('mbstring extension not available');
        }

        mb_internal_encoding('UTF-8');
        mb_regex_encoding('UTF-8');
    }

    /**
     * Get application session
     *
     * @return Container
     */
    public function getSession(): Container
    {
        if (NULL === $this->sessionContainer) {
            if (PHP_SAPI == 'cli') {
                return $this->sessionContainer = new Container('iMSCP');
            }

            if (!is_writable(FRONTEND_ROOT_DIR . '/data/sessions')) {
                throw new \RuntimeException('The frontend/data/sessions directory is not writable.');
            }

            $config = new SessionConfig();
            # FIXME: cookie_secure if scheme only https
            $config->setOptions([
                'name'                => 'iMSCP',
                'use_cookies'         => true,
                'use_only_cookies'    => true,
                'cookie_domain'       => $this->getConfig()['BASE_SERVER_VHOST'],
                'cookie_secure'       => $this->getConfig()['BASE_SERVER_VHOST_PREFIX'] == 'https://',
                'cookie_httponly'     => $this->getConfig()['BASE_SERVER_VHOST_PREFIX'] == 'https://',
                'use_trans_sid'       => false,
                'remember_me_seconds' => 1800,
                'gc_divisor'          => 100,
                'gc_maxlifetime'      => 1440,
                'gc_probability'      => 1,
                'save_path'           => FRONTEND_ROOT_DIR . '/data/sessions'
            ]);

            $manager = new SessionManager($config);
            Container::setDefaultManager($manager);

            $this->sessionContainer = new Container('iMSCP');
        }

        return $this->sessionContainer;
    }

    /**
     * Get appplication registry
     *
     * @return Registry
     */
    public function getRegistry()
    {
        if (NULL === $this->registry) {
            $this->registry = new Registry();
        }

        return $this->registry;
    }

    /**
     * Load application functions
     *
     * @return void
     */
    public function loadFunctions()
    {
        # TODO Replace by classes with static method, with better separation concerns
        require_once 'admin.php';
        require_once 'client.php';
        require_once 'counting.php';
        require_once 'email.php';
        require_once 'input.php';
        require_once 'i18n.php';
        require_once 'layout.php';
        require_once 'login.php';
        require_once 'reseller.php';
        require_once 'shared.php';
        require_once 'aps.php';
        require_once 'stats.php';
        require_once 'view.php';
    }

    /**
     * Set application timezone
     *
     * @return void
     */
    protected function setTimezone(): void
    {
        if (!@date_default_timezone_set($this->getConfig()['TIMEZONE'] ?? 'UTC')) {
            date_default_timezone_set('UTC');
        }
    }

    /**
     * Get application database handle
     *
     * @return DbAdapter
     */
    public function getDb(): DbAdapter
    {
        if (NULL === $this->db) {
            $config = $this->getConfig();
            $keyFile = $config['CONF_DIR'] . '/imscp-db-keys.php';
            $imscpKEY = $imscpIV = '';

            if (!(@include_once $keyFile) || empty($imscpKEY) || empty($imscpIV)) {
                throw new \RuntimeException(sprintf(
                    'Missing or invalid key file. Delete the %s key file if any and run the imscp-reconfigure script.', $keyFile
                ));
            }

            $this->db = new DbAdapter([
                'driver'         => 'Pdo_Mysql',
                'driver_options' => [
                    \PDO::ATTR_CASE               => \PDO::CASE_NATURAL,
                    \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
                    \PDO::MYSQL_ATTR_INIT_COMMAND => "SET @@session.sql_mode = 'NO_AUTO_CREATE_USER', @@session.group_concat_max_len = 4294967295",
                ],
                'hostname'       => $config['DATABASE_HOST'],
                'port'           => $config['DATABASE_PORT'],
                'database'       => $config['DATABASE_NAME'],
                'username'       => $config['DATABASE_USER'],
                'password'       => Crypt::decryptRijndaelCBC($imscpKEY, $imscpIV, $config['DATABASE_PASSWORD']),
                'charset'        => 'utf8'
            ]);
        }

        return $this->db;
    }

    /**
     * Load application plugins
     *
     * @return void
     */
    protected function loadPlugins(): void
    {
        if (PHP_SAPI == 'cli') {
            return;
        }

        $pluginManager = $this->getPluginManager();
        foreach ($pluginManager->pluginGetList() as $pluginName) {
            if ($pluginManager->pluginHasError($pluginName)) {
                continue;
            }

            $pluginManager->pluginLoad($pluginName);
        }
    }
}
