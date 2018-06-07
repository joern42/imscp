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
use iMSCP\Authentication\Adapter\Events as AuthEventAdapter;
use iMSCP\Authentication\AuthenticationService;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Config\DbConfig;
use iMSCP\Container\Registry;
use iMSCP\Exception;
use iMSCP\Functions\View;
use iMSCP\Model\SuIdentityInterface;
use iMSCP\Plugin\PluginManager;
use iMSCP\Session\SaveHandler\SessionHandler;
use Zend\Authentication\Storage as AuthenticationStorage;
use Zend\Cache;
use Zend\Config;
use Zend\Db\Adapter\Adapter as DbAdapter;
use Zend\EventManager;
use Zend\Http\PhpEnvironment\Request;
use Zend\I18n\Translator\Translator;
use Zend\Session\Config\SessionConfig;
use Zend\Session\Container as SessionContainer;
use Zend\Session\SessionManager;
use Zend\Session\Storage\SessionStorage;
use Zend\Session\Validator\HttpUserAgent;
use Zend\Session\Validator\RemoteAddr;

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
     * @var DbConfig
     */
    protected $dbConfig;

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
     * @var SessionContainer
     */
    protected $sessionContainer;

    /**
     * @var FlashMessenger
     */
    protected $flashMessenger;

    /**
     * @var Request
     */
    protected $request;

    /**
     * Get application
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
     * Make clone unavailable
     */
    private function __clone()
    {
    }

    /**
     * Bootstrap application
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
        $this->setupSession();
        $this->setUserGuiProps();
        $this->initLayout();
        $this->loadPlugins();
        $this->getEventManager()->trigger(Events::onAfterApplicationBootstrap, $this);

        $this->bootstrapped = true;
        return $this;
    }

    /**
     * Setup session
     *
     * @return void
     */
    protected function setupSession(): void
    {
        if (PHP_SAPI == 'cli') {
            return;
        }

        // Setup default session manager
        $isSecureRequest = isSecureRequest();
        $config = $this->getConfig();
        $sessionConfig = new SessionConfig();
        $sessionConfig->setOptions([
            // We cannot use same session name (cookie name) for both HTTP and
            // HTTPS because once the secure cookie is set, it will not longer
            // be send via HTTP and users won't be able to login via HTTP.
            // There is a similar problem with PMA: https://github.com/phpmyadmin/phpmyadmin/issues/14184
            'name'                   => 'iMSCP_Session' . ($isSecureRequest ? '_Secure' : ''),
            'use_cookies'            => true,
            'use_only_cookies'       => true,
            'cookie_domain'          => $config['BASE_SERVER_VHOST'],
            'cookie_secure'          => $isSecureRequest,
            'cookie_httponly'        => true,
            'cookie_path'            => '/',
            'cookie_lifetime'        => 0,
            'use_trans_sid'          => false,
            'gc_probability'         => $config['PHP_SESSION_GC_PROBABILITY'] ?? 2,
            'gc_divisor'             => $config['PHP_SESSION_GC_DIVISOR'] ?? 100,
            'gc_maxlifetime'         => $config['PHP_SESSION_GC_MAXLIFETIME'] ?? 1440,
            'save_path'              => FRONTEND_ROOT_DIR . '/data/sessions',
            'use_strict_mode'        => true,
            'sid_bits_per_character' => 5
        ]);

        SessionContainer::setDefaultManager(
            new SessionManager($sessionConfig, new SessionStorage(), new SessionHandler(), [RemoteAddr::class, HttpUserAgent::class])
        );
    }

    /**
     * Set user GUI properties
     *
     * @return void
     */
    public function setUserGuiProps(): void
    {
        if (PHP_SAPI == 'cli') {
            return;
        }

        $identity = $this->getAuthService()->getIdentity();
        $session = $this->getSession();

        if (NULL == $identity || $identity instanceof SuIdentityInterface || (isset($session['user_def_lang']) && isset($session['user_theme']))) {
            return;
        }

        $config = $this->getConfig();
        $stmt = execQuery('SELECT lang, layout FROM user_gui_props WHERE user_id = ?', [$identity->getUserId()]);

        if ($stmt->rowCount()) {
            $row = $stmt->fetch();
            if ((empty($row['lang']) && empty($row['layout']))) {
                list($lang, $theme) = [$config['USER_INITIAL_LANG'], $config['USER_INITIAL_THEME']];
            } elseif (empty($row['lang'])) {
                list($lang, $theme) = [$config['USER_INITIAL_LANG'], $row['layout']];
            } elseif (empty($row['layout'])) {
                list($lang, $theme) = [$row['lang'], $config['USER_INITIAL_THEME']];
            } else {
                list($lang, $theme) = [$row['lang'], $row['layout']];
            }
        } else {
            list($lang, $theme) = [$config['USER_INITIAL_LANG'], $config['USER_INITIAL_THEME']];
        }

        $session['user_def_lang'] = $lang;
        $session['user_theme'] = $theme;
    }

    /**
     * Initialize layout
     *
     * @return void
     */
    public function initLayout(): void
    {
        if (PHP_SAPI == 'cli' || isXhr()) {
            return;
        }

        // Set layout color for the current environment (Must be donne as late as possible)
        if (!$this->getAuthService()->hasIdentity()) {
            $this->getEventManager()->attach(Events::onLoginScriptEnd, 'initLayout');
            $this->getEventManager()->attach(Events::onLostPasswordScriptEnd, 'initLayout');
            return;
        }

        $identity = $this->getAuthService()->getIdentity();

        switch ($identity->getUserType()) {
            case 'admin':
                $this->getEventManager()->attach(Events::onAdminScriptEnd, 'initLayout');
                break;
            case 'reseller':
                $this->getEventManager()->attach(Events::onResellerScriptEnd, 'initLayout');
                break;
            case 'user':
                $this->getEventManager()->attach(Events::onClientScriptEnd, 'initLayout');
                break;
            default:
                throw  new \RuntimeException('Unknown user type');
        }

        if ($identity instanceof SuIdentityInterface) {
            $this->getEventManager()->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, function () {
                unset($this->getSession()['user_theme_color']);
            });
        }
    }

    /**
     * Get authentication service
     *
     * @return AuthenticationService
     */
    public function getAuthService(): AuthenticationService
    {
        if (NULL === $this->authService) {
            $this->authService = new AuthenticationService(
                new AuthenticationStorage\Session('iMSCP_Session', NULL, SessionContainer::getDefaultManager()),
                new AuthEventAdapter($this->getEventManager())
            );
        }

        return $this->authService;
    }

    public function getRequest()
    {
        if (NULL === $this->request) {
            $this->request = new Request();
        }

        return $this->request;
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

            if ($adapter == 'Apcu') {
                $this->cache = new Cache\Storage\Adapter\Apcu(['namespace' => 'iMSCPcache']);
                $this->cache->addPlugin(Cache\StorageFactory::pluginFactory('ExceptionHandler', ['throw_exceptions' => false]));
                $this->cache->addPlugin(Cache\StorageFactory::pluginFactory('IgnoreUserAbort', ['exit_on_abort' => false]));
                return $this->cache;
            }

            $this->cache = new Cache\Storage\Adapter\BlackHole();

            if (PHP_SAPI != 'cli') {
                $this->getEventManager()->attach(Events::onGeneratePageMessages, function () {
                    $identity = $this->getAuthService()->getIdentity();

                    if (NULL !== $identity
                        && !isXhr()
                        && ($identity->getUserType() == 'admin'
                            || ($identity instanceof SuIdentityInterface && $identity->getSuUserType() == 'admin'
                                || $identity->getSuIdentity() instanceof SuIdentityInterface
                            )
                        )
                    ) {
                        View::setPageMessage(tr('The APCu extension is not enabled on your system. This can lead to performance issues.'), 'static_warning');
                    }
                });
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

        // Setup reader for Java .properties configuration file
        #Config\Factory::registerReader('conf', Config\Reader\JavaProperties::class);
        Config\Factory::registerReader('data', Config\Reader\JavaProperties::class);
        $reader = new Config\Reader\JavaProperties('=', Config\Reader\JavaProperties::WHITESPACE_TRIM);

        // Load settings from the master i-MSCP configuration file (imscp.conf).
        $this->config = new Config\Config($reader->fromFile(normalizePath(IMSCP_CONF_DIR . '/imscp.conf')), true);
        // Load and merge settings from the FrontEnd configuration file (frontend.data)
        $this->config->merge(new Config\Config($reader->fromFile(normalizePath(IMSCP_CONF_DIR . '/frontend/frontend.data'))));
        // Load and merge additional settings
        $this->config->merge(new Config\Config(include_once(normalizePath(LIBRARY_PATH . '/include/asettings.php')), true));
        // Load and merge settings that were overridden
        $this->config->merge(new Config\Config($this->getDbConfig()->getArrayCopy()));

        // Set default root template directory according current theme
        $this->config['ROOT_TEMPLATE_PATH'] = FRONTEND_ROOT_DIR . '/themes/' . $this->config['USER_INITIAL_THEME'];

        // Make config object readonly
        $this->config->setReadOnly();

        // Cache the resulting merged configuration into cache, unless debug mode is enabled
        if (!$this->config['DEBUG']) {
            $this->getCache()->setItem('merged_config', $this->config);
            return $this->config;
        }

        $this->getCache()->getOptions()->setWritable(false);
        $this->getCache()->getOptions()->setReadable(false);

        // If the debug mode is enabled, and if logged user is of 'admin'
        // type, we display a warning as having the debug mode enabled in
        // a production environment is not a good thing for performances
        // reasons (cache disabled)
        $this->getEventManager()->attach(Events::onGeneratePageMessages, function () {
            $identity = $this->getAuthService()->getIdentity();
            if (NULL !== $identity && !isXhr() && ($identity->getUserType() == 'admin'
                    || ($identity instanceof SuIdentityInterface && $identity->getSuUserType() == 'admin')
                    || $identity->getSuIdentity() instanceof SuIdentityInterface
                )
            ) {
                View::setPageMessage(tr('The debug mode is currently enabled meaning that the cache is also disabled.'), 'static_warning');
                View::setPageMessage(
                    tr(
                        'For better performances, you should consider disabling it through the %s configuration file.',
                        normalizePath(IMSCP_CONF_DIR . '/imscp.conf')
                    ),
                    'static_warning'
                );
            }
        });


        return $this->config;
    }

    /**
     * Get configuration from database
     *
     * @return DbConfig
     */
    public function getDbConfig()
    {
        if (NULL === $this->dbConfig) {
            $this->dbConfig = new DbConfig($this->getDb());
        }

        return $this->dbConfig;
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
     * Set application environment
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
            \Locale::setDefault(\Locale::acceptFromHttp($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? 'en_GB'));
            $this->translator = Translator::factory([
                'locale'                    => [
                    (include_once 'flocales.php')[\Locale::getDefault()] ?? \Locale::getDefault(),
                    'en_GB'
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
     * @return SessionContainer
     */
    public function getSession(): SessionContainer
    {
        if (NULL === $this->sessionContainer) {
            $this->sessionContainer = new SessionContainer('iMSCP');
            $this->getEventManager()->trigger(Events::onAfterSessionStart, $this);
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
     * Get application flash messenger
     *
     * @return FlashMessenger
     */
    public function getFlashMessenger(): FlashMessenger
    {
        if (NULL === $this->flashMessenger) {
            $this->flashMessenger = new FlashMessenger();
        }

        return $this->flashMessenger;
    }

    /**
     * Load application functions
     *
     * @return void
     */
    public function loadFunctions()
    {
        // TODO Replace by classes with static methods and with better separation concerns
        require_once 'functions.php';
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
     * FIXME: Should it be safe to cache key/iv and decrypted password for faster processing?
     * FIXME: Acpu cache is not shared accross multiple user here.
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
                // FIXME: Provide a tool for regenerating key file without having to trigger full i-MSCP reconfiguration
                throw new \RuntimeException(sprintf(
                    'Missing or invalid key file. Delete the %s key file if any and run the imscp-reconfigure script.', $keyFile
                ));
            }

            $this->db = new DbAdapter([
                'driver'         => 'Pdo_Mysql',
                'driver_options' => [
                    \PDO::ATTR_EMULATE_PREPARES         => false,
                    \PDO::ATTR_STRINGIFY_FETCHES        => false,
                    \PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => true,
                    \PDO::ATTR_CASE                     => \PDO::CASE_NATURAL,
                    \PDO::ATTR_DEFAULT_FETCH_MODE       => \PDO::FETCH_ASSOC,
                    \PDO::MYSQL_ATTR_INIT_COMMAND       => "SET @@session.sql_mode = 'NO_AUTO_CREATE_USER', @@session.group_concat_max_len = 4294967295",
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
