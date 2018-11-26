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

/**
 * Class PHPini
 * @package iMSCP
 */
class PHPini
{
    /**
     * @var PHPini
     */
    static protected $instance;

    /**
     * @var array Reseller permissions (including limits for INI options)
     */
    protected $resellerPermissions = [];

    /**
     * @var array Client permissions
     */
    protected $clientPermissions = [];

    /**
     * @var array INI options
     */
    protected $iniOptions = [];

    /**
     * @var bool Tells whether or not INI options are set with defaults
     */
    protected $isDefaultIniOptions = true;

    /**
     * @var bool Whether or not a backend request is needed for change of INI options in client production files
     */
    protected $isBackendRequestNeeded = false;

    /**
     * Singleton object - Make new unavailable
     */
    private function __construct()
    {
        set_time_limit(0);
        ignore_user_abort(true);
    }

    /**
     * Implements singleton design pattern
     *
     * @return PHPini
     */
    static public function getInstance()
    {
        if (NULL === static::$instance) {
            static::$instance = new self();
        }

        return static::$instance;
    }

    /**
     * Destructor
     */
    public function __destruct()
    {
        if ($this->isBackendRequestNeeded) {
            Daemon::sendRequest();
        }
    }

    /**
     * Sets reseller permission
     *
     * New permission value is set only if valid.
     *
     * @param string $permission Permission name
     * @param string $value Permission value
     * @return void
     */
    public function setResellerPermission(string $permission, $value)
    {
        switch ($permission) {
            case 'php_ini':
            case 'php_ini_allow_url_fopen':
            case 'php_ini_display_errors':
            case 'php_ini_mail_function':
            case 'php_ini_disable_functions':
                if ($this->validatePermission($permission, $value)) {
                    $this->resellerPermissions[$permission] = $value;
                }
                break;
            case 'php_ini_memory_limit':
            case 'php_ini_max_input_time':
            case 'php_ini_max_execution_time':
            case 'php_ini_post_max_size':
                if (isNumber($value) && $value >= 1 && $value <= 10000) {
                    $this->resellerPermissions[$permission] = $value;
                }
                break;
            case 'php_ini_upload_max_file_size':
                if (isNumber($value) && $value <= $this->resellerPermissions['php_ini_post_max_size'] && $value >= 1 && $value <= 10000) {
                    $this->resellerPermissions[$permission] = $value;
                }
                break;
            case 'php_ini_config_level':
                if ($this->validatePermission($permission, $value) && $value != $this->resellerPermissions[$permission]) {
                    $this->resellerPermissions[$permission] = $value;
                }
                break;
            default:
                throw new \InvalidArgumentException(sprintf('Unknown reseller PHP permission: %s', $permission));
        }
    }

    /**
     * Validate the given permission
     *
     * @param string $permission Permission name
     * @param string $value Permission value
     * @return bool TRUE if $permission is valid, FALSE otherwise
     *
     */
    protected function validatePermission($permission, $value)
    {
        switch ($permission) {
            case 'php_ini':
            case 'php_ini_allow_url_fopen':
            case 'php_ini_display_errors':
            case 'php_ini_mail_function':
                return in_array($value, [0, 1]);
            case 'php_ini_disable_functions':
                return in_array($value, ['yes', 'no', 'exec'], true);
            case 'php_ini_config_level':
                return in_array($value, ['per_domain', 'per_site', 'per_user'], true);
            default:
                throw new \InvalidArgumentException(sprintf('Unknown PHP permission: %s', $permission));
        }
    }

    /**
     * Saves reseller permissions
     *
     * @param int $resellerId Reseller unique identifier
     * @return void
     */
    public function saveResellerPermissions($resellerId)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException('You must first load and set the new reseller PHP permissions');
        }

        execQuery(
            '
                UPDATE reseller_props
                SET
                    php_ini = ?,
                    php_ini_config_level = ?,
                    php_ini_disable_functions = ?,
                    php_ini_mail_function = ?,
                    php_ini_allow_url_fopen = ?,
                    php_ini_display_errors = ?,
                    php_ini_post_max_size = ?,
                    php_ini_upload_max_filesize = ?,
                    php_ini_max_execution_time = ?,
                    php_ini_max_input_time = ?,
                    php_ini_memory_limit = ?
                WHERE reseller_id = ?
            ',
            [
                $this->resellerPermissions['php_ini'],
                $this->resellerPermissions['php_ini_config_level'],
                $this->resellerPermissions['php_ini_disable_functions'],
                $this->resellerPermissions['php_ini_mail_function'],
                $this->resellerPermissions['php_ini_allow_url_fopen'],
                $this->resellerPermissions['php_ini_display_errors'],
                $this->resellerPermissions['php_ini_post_max_size'],
                $this->resellerPermissions['php_ini_upload_max_filesize'],
                $this->resellerPermissions['php_ini_max_execution_time'],
                $this->resellerPermissions['php_ini_max_input_time'],
                $this->resellerPermissions['php_ini_memory_limit'],
                $resellerId
            ]
        );
    }

    /**
     * Sets client permission
     *
     * New permission value is set only if valid.
     *
     * @param string $permission Permission name
     * @param string $value Permission value
     * @return void
     */
    public function setClientPermission($permission, $value)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException('You must first load the reseller PHP permissions');
        }

        if (!$this->validatePermission($permission, $value) || !$this->resellerHasPermission($permission)
            || ($permission == 'php_ini_config_level' && $this->getResellerPermission('php_ini_config_level') == 'per_domain'
                && !in_array($value, ['per_domain', 'per_user'], true)
            )
        ) {
            return;
        }

        $this->clientPermissions[$permission] = $value;

        if ($permission == 'php_ini_allow_url_fopen' && !$value) {
            $this->iniOptions['php_ini_allow_url_fopen'] = 0;
        }

        if ($permission == 'php_ini_display_error' && !$value) {
            $this->iniOptions['php_ini_display_error'] = 0;
        }

        if ($permission == 'php_ini_disable_functions' && !$value) {
            if ($value == 'no') {
                $this->iniOptions['php_ini_disable_functions'] = 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
            } elseif (in_array('exec', explode(',', $this->iniOptions['php_ini_disable_functions'], true))) {
                $this->iniOptions['php_ini_disable_functions'] = 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
            } else {
                $this->iniOptions['php_ini_disable_functions'] = 'passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
            }

            if (!$this->clientHasPermission('php_ini_mail_function')) {
                $this->iniOptions['php_ini_disable_functions'] .= ',mail';
            }
        }

        if ($permission == 'php_ini_mail_function' && !$value) {
            $disabledFunctions = explode(',', $this->getIniOption('php_ini_mail_function'));

            if (!in_array('mail', $disabledFunctions)) {
                $disabledFunctions[] = 'mail';
                $this->iniOptions['php_ini_disable_functions'] = $this->assembleDisableFunctions($disabledFunctions);
            }
        }
    }

    /**
     * Does the reseller as the given permission?
     *
     * @param string $permission Permission
     * @return bool TRUE if $key is a known and reseller has permission on it
     */
    public function resellerHasPermission($permission)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException('You must first load the reseller PHP permissions');
        }

        if (!$this->resellerPermissions['php_ini']) {
            return false;
        }

        switch ($permission) {
            case 'php_ini':
            case 'php_ini_allow_url_fopen':
            case 'php_ini_display_errors':
            case 'php_ini_disable_functions':
            case 'php_ini_mail_functions':
                return $this->resellerPermissions[$permission] == '1';
            case 'php_ini_config_level':
                return in_array($this->resellerPermissions[$permission], ['per_site', 'per_domain']);
            default;
                throw new \InvalidArgumentException(sprintf('Unknown reseller PHP permission: %s', $permission));
        }
    }

    /**
     * Gets the the given reseller permission or all reseller permissions if no permission is given
     *
     * @param string|null $permission Permission name or null for all permissions
     * @return mixed
     */
    public function getResellerPermission($permission = NULL)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException('You must first load the reseller PHP permissions');
        }

        if (NULL === $permission) {
            return $this->resellerPermissions;
        }

        if (!array_key_exists($permission, $this->resellerPermissions)) {
            throw new \InvalidArgumentException(sprintf('Unknown reseller PHP permission: %s', $permission));
        }

        return $this->resellerPermissions[$permission];
    }

    /**
     * Does the client as the given PHP permission?
     *
     * In case of the php_ini_disable_functions, true is returned as long as
     * the client has either 'exec' or 'full' permission.
     *
     * @param string $permission Permission
     * @return bool TRUE if $key is a known and client has permission on it
     */
    public function clientHasPermission($permission)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException('You must first load the reseller PHP permissions');
        }

        if ($this->resellerPermissions['php_ini'] != 'yes') {
            return false;
        }

        switch ($permission) {
            case 'php_ini':
            case 'php_ini_allow_url_fopen':
            case 'php_ini_display_errors':
            case 'php_ini_mail_functions':
                return $this->clientPermissions[$permission] == '1';
            case 'php_ini_disable_function':
                return $this->clientPermissions[$permission] == 'yes' || $this->clientPermissions[$permission] == 'exec';
            case 'php_ini_config_level':
                return true; // FIXME???
            default:
                throw new \InvalidArgumentException(sprintf('Unknown client PHP permission: %s', $permission));
        }
    }

    /**
     * Gets the the given INI option or all INI option if no INI option is given
     *
     * @param string|null OPTIONAL $varname INI option name
     * @return mixed
     */
    public function getIniOption($option = NULL)
    {
        if (empty($this->iniOptions)) {
            throw new \LogicException("You must first load the client domain INI options");
        }

        if (NULL === $option) {
            return $this->iniOptions;
        }

        if (!array_key_exists($option, $this->iniOptions)) {
            throw new \InvalidArgumentException(sprintf('Unknown domain INI option: %s', $option));
        }

        return $this->iniOptions[$option];
    }

    /**
     * Assemble disable_functions parameter from its parts
     *
     * @param array $disabledFunctions List of disabled function
     * @return string
     */
    public function assembleDisableFunctions(array $disabledFunctions)
    {
        return implode(',', array_unique($disabledFunctions));
    }

    /**
     * Whether or not INI options are set with default values
     *
     * @return boolean
     */
    public function isDefaultIniOptions()
    {
        return $this->isDefaultIniOptions;
    }

    /**
     * Sets value for the given INI option
     *
     * New INI option value is set only if valid.
     *
     * @param string $option Configuration option name
     * @param string $value Configuration option value
     */
    public function setIniOption($option, $value)
    {
        if (empty($this->clientPermissions)) {
            throw new \LogicException('You must first load the client PHP permissions.');
        }

        if (!$this->validateIniOption($option, $value)) {
            return;
        }

        switch ($option) {
            case 'php_ini_post_max_size':
            case 'php_ini_upload_max_file_size':
            case 'php_ini_max_execution_time':
            case 'php_ini_max_input_time':
            case 'php_ini_memory_limit':
                if ($value > $this->getResellerPermission($option)) {
                    return;
                }
                break;
            case 'php_ini_error_reporting':
                break; // FIXME ????
            default:
                if (!$this->clientHasPermission($option)) {
                    return;
                }
        }

        $this->iniOptions[$option] = $value;
        $this->isDefaultIniOptions = false;
    }

    /**
     * Validate the given INI option
     *
     * Unlimited values are not allowed for safety reasons.
     *
     * @param string $option Configuration option name
     * @param string $value Configuration option value
     * @return bool TRUE if $value is valid, FALSE otherwise
     */
    protected function validateIniOption($option, $value)
    {
        if (!is_scalar($option)) {
            return false;
        }

        switch ($option) {
            case 'php_ini_allow_url_fopen':
            case 'php_display_error':
                return in_array($value, [0, 1]);
            case 'php_ini_error_reporting':
                return is_scalar($option) && in_array(
                        $value,
                        [
                            // Default value
                            'E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED',
                            // All error (development value)
                            '-1',
                            // Production
                            'E_ALL & ~E_DEPRECATED & ~E_STRICT'
                        ]
                    );
            case 'php_ini_disable_functions':
                $allowedFunctionNames = [
                    'exec', 'mail', 'passthru', 'phpinfo', 'popen', 'proc_open', 'show_source', 'shell', 'shell_exec', 'symlink', 'system', ''
                ];

                return array_diff(explode(',', $value), $allowedFunctionNames) ? false : true;
            case 'php_ini_memory_limit':
            case 'php_ini_max_execution_time':
            case 'php_ini_max_input_time':
            case 'php_ini_post_max_size':
                return isNumber($value) && $value >= 1 && $value <= 10000;
            case 'php_ini_upload_max_file_size':
                return isNumber($value) && $value <= $this->iniOptions['php_ini_post_max_size'] && $value >= 1 && $value <= 10000;
            default:
                throw new \InvalidArgumentException(sprintf('Unknown INI option: %s', $option));
        }
    }

    /**
     * Synchronise client permissions and INI optiions according reseller permissions
     *
     * @param int $resellerId Reseller unique identifier
     * @param int $clientId OPTIONAL client unique identifier (Default: All reseller's clients)
     * @return void
     */
    public function syncClientPermissionsAndIniOptions($resellerId, $clientId = NULL)
    {
        if (empty($this->resellerPermissions)) {
            $this->loadResellerPermissions($resellerId);
        }

        $params = [];

        if (NULL !== $clientId) {
            $condition = 'WHERE admin_id = ? AND created_by = ?';
            $params[] = $clientId;
        } else {
            $condition = 'WHERE created_by = ?';
        }

        $params[] = $resellerId;
        $stmt = execQuery("SELECT admin_id FROM admin $condition", $params);

        while ($row = $stmt->fetch()) {
            $this->loadClientPermissions($row['admin_id']);
            $configLevel = $this->getClientPermission('php_ini_config_level');

            if (!$this->resellerHasPermission('php_ini')) {
                // Reset client's permissions to their default values based on the permissions of its reseller.
                $this->loadClientPermissions();
                $this->saveClientPermissions($row['admin_id']);
                $this->updateClientIniOptions($row['admin_id'], $configLevel != $this->getClientPermission('php_ini_config_level'), true);
                continue;
            }

            // Adjusts client's permissions based on permissions of its reseller.

            if (!$this->resellerHasPermission('php_ini_config_level') && $this->clientPermissions['php_ini_config_level'] != 'per_user') {
                $this->clientPermissions['php_ini_config_level'] = 'per_user';
                $this->isBackendRequestNeeded = true;
            } elseif ($this->getResellerPermission('php_ini_config_level') == 'per_domain'
                && !in_array($this->clientPermissions['php_ini_config_level'], ['per_user', 'per_domain'], true)
            ) {
                $this->clientPermissions['php_ini_config_level'] = 'per_domain';
                $this->isBackendRequestNeeded = true;
            }

            foreach (['php_ini_allow_url_fopen', 'php_ini_display_errors', 'php_ini_disable_functions', 'php_ini_mail_function'] as $permissions) {
                if (!$this->resellerHasPermission($permissions)) {
                    $this->clientPermissions[$permissions] = 'no';
                }
            }

            $this->saveClientPermissions($row['admin_id']);
            $this->updateClientIniOptions($row['admin_id'], $configLevel != $this->getClientPermission('php_ini_config_level'), true);
        }
    }

    /**
     * Loads reseller permissions
     *
     * If a reseller identifier is given, try to load current permissions for
     * that reseller, else, load default permissions for resellers.
     *
     * Reseller permissions also include limits for INI options.
     *
     * @param int|null $resellerId Reseller unique identifier
     * @return void
     */
    public function loadResellerPermissions($resellerId = NULL)
    {
        if (NULL !== $resellerId) {
            $stmt = execQuery(
                '
                    SELECT
                        php_ini,
                        php_ini_config_level,
                        php_ini_disable_functions,
                        php_ini_mail_function,
                        php_ini_mail_function,
                        php_ini_allow_url_fopen,
                        php_ini_display_errors,
                        php_ini_post_max_size,
                        php_ini_upload_max_filesize,
                        php_ini_max_execution_time,
                        php_ini_max_input_time,
                        php_ini_memory_limit
                    FROM reseller_props WHERE reseller_id = ?
                ',
                [$resellerId]
            );

            if ($stmt->rowCount()) {
                $row = $stmt->fetch();

                // PHP permissions
                $this->resellerPermissions['php_ini'] = $row['php_ini'];
                $this->resellerPermissions['php_ini_config_level'] = $row['php_ini_config_level'];
                $this->resellerPermissions['php_ini_allow_url_fopen'] = $row['php_ini_allow_url_fopen'];
                $this->resellerPermissions['php_ini_display_errors'] = $row['php_ini_display_errors'];
                $this->resellerPermissions['php_ini_disable_functions'] = $row['php_ini_disable_functions'];
                $this->resellerPermissions['php_ini_mail_function'] = $row['php_ini_mail_function'];

                // Limits for PHP INI options
                $this->resellerPermissions['php_ini_post_max_size'] = $row['php_ini_post_max_size'];
                $this->resellerPermissions['php_ini_upload_max_filesize'] = $row['php_ini_upload_max_filesize'];
                $this->resellerPermissions['php_ini_max_execution_time'] = $row['php_ini_max_execution_time'];
                $this->resellerPermissions['php_ini_max_input_time'] = $row['php_ini_max_input_time'];
                $this->resellerPermissions['php_ini_memory_limit'] = $row['php_ini_memory_limit'];
                return;
            }
        }

        // Default PHP permissions
        $this->resellerPermissions['php_ini'] = 0;
        $this->resellerPermissions['php_ini_config_level'] = 'per_site';
        $this->resellerPermissions['php_ini_allow_url_fopen'] = 0;
        $this->resellerPermissions['php_ini_display_errors'] = 0;
        $this->resellerPermissions['php_ini_disable_functions'] = 0;
        $this->resellerPermissions['php_ini_mail_function'] = 1;

        // Default limits for PHP INI options
        $this->resellerPermissions['php_ini_post_max_size'] = 8;
        $this->resellerPermissions['php_ini_upload_max_filesize'] = 2;
        $this->resellerPermissions['php_ini_max_execution_time'] = 30;
        $this->resellerPermissions['php_ini_max_input_time'] = 60;
        $this->resellerPermissions['php_ini_memory_limit'] = 128;
    }

    /**
     * Loads client permissions
     *
     * If a client identifier is given, try to load current permissions for
     * that client, else, load default permissions for clients, based on
     * reseller permissions.
     *
     * @param int|null $clientId Domain unique identifier
     */
    public function loadClientPermissions($clientId = NULL)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException("You must first load the PHPpermissions of the client's reseller");
        }

        if (NULL !== $clientId) {
            $stmt = execQuery(
                '
                    SELECT
                        php_ini,
                        php_ini_config_level,
                        php_ini_allow_url_fopen,
                        php_ini_display_errors,
                        php_ini_disable_functions,
                        php_ini_mail_function
                    FROM domain
                    WHERE domain_admin_id = ?
                ',
                [$clientId]
            );

            if ($stmt->rowCount()) {
                $row = $stmt->fetch();
                $this->clientPermissions['php_ini'] = $row['php_ini'];
                $this->clientPermissions['php_ini_config_level'] = $row['php_ini_config_level'];
                $this->clientPermissions['php_ini_allow_url_fopen'] = $row['php_ini_allow_url_fopen'];
                $this->clientPermissions['php_ini_display_errors'] = $row['php_ini_display_errors'];
                $this->clientPermissions['php_ini_disable_functions'] = $row['php_ini_disable_functions'];
                $this->clientPermissions['php_ini_mail_function'] = $row['php_ini_mail_function'];
                return;
            }
        }

        $this->clientPermissions['php_ini'] = 0;
        $this->clientPermissions['php_ini_allow_url_fopen'] = 0;
        $this->clientPermissions['php_ini_display_errors'] = 0;
        $this->clientPermissions['php_ini_disable_functions'] = 0;
        $this->clientPermissions['php_ini_config_level'] = $this->getResellerPermission('php_ini_config_level');
        $this->clientPermissions['php_ini_mail_function'] = $this->resellerHasPermission('php_ini_mail_function') ? 1 : 0;
    }

    /**
     * Gets the the given client permission or all client permissions if no permission is given
     *
     * @param string|null $permission Permission name or null for all permissions
     * @return mixed
     */
    public function getClientPermission($permission = NULL)
    {
        if (empty($this->resellerPermissions)) {
            throw new \LogicException("You must first load client permissions");
        }

        if (NULL === $permission) {
            return $this->clientPermissions;
        }

        if (!array_key_exists($permission, $this->clientPermissions)) {
            throw new \InvalidArgumentException(sprintf('Unknown client PHP permission: %s', $permission));
        }

        return $this->clientPermissions[$permission];
    }

    /**
     * Saves client permissions
     *
     * @param int $clientId Client unique identifier
     * @return void
     */
    public function saveClientPermissions($clientId)
    {
        if (empty($this->clientPermissions)) {
            throw new \LogicException("You must first load and set new client permissions");
        }

        execQuery(
            '
                UPDATE domain
                SET
                    php_ini = ?,
                    php_ini_config_level = ?,
                    php_ini_allow_url_fopen = ?,
                    php_ini_display_errors = ?,
                    php_ini_disable_functions = ?,
                    php_ini_mail_function = ?
                WHERE domain_admin_id = ?
            ',
            [
                $this->clientPermissions['php_ini'],
                $this->clientPermissions['php_ini_config_level'],
                $this->clientPermissions['php_ini_allow_url_fopen'],
                $this->clientPermissions['php_ini_display_errors'],
                $this->clientPermissions['php_ini_disable_functions'],
                $this->clientPermissions['php_ini_mail_function'],
                $clientId
            ]
        );
    }

    /**
     * Update client INI options for all its domains, including subdomains
     *
     * @param int $clientId Client unique identifier
     * @param bool $isBackendRequestNeeded OPTIONAL Is a request backend needed for the given client?
     * @param bool $loadIniOptions OPTIONAL Whether or not INI options must be loaded
     * @return void
     */
    public function updateClientIniOptions($clientId, $isBackendRequestNeeded = false, $loadIniOptions = false)
    {
        if (empty($this->clientPermissions)) {
            $this->loadClientPermissions($clientId);
        }

        $isBackendRequestNeededPrev = $this->isBackendRequestNeeded;
        $stmt = execQuery('SELECT id, domain_id, domain_type FROM php_ini WHERE admin_id = ?', [$clientId]);

        while ($row = $stmt->fetch()) {
            $this->isBackendRequestNeeded = $isBackendRequestNeeded ? true : false;

            if (!$this->clientHasPermission('php_ini')) {
                // Reset INI options to their default values
                $this->loadIniOptions();
                $this->saveIniOptions($clientId, $row['domain_id'], $row['domain_type']);
                $this->updateDomainStatuses($clientId, $row['domain_id'], $row['domain_type']);
                continue;
            }

            if ($loadIniOptions) {
                // Load current INI options
                $this->loadIniOptions($row['domain_id'], $row['domain_type']);
            }

            if (!$this->clientHasPermission('php_ini_allow_url_fopen')) {
                $this->iniOptions['php_ini_allow_url_fopen'] = 0;
            }

            if (!$this->clientHasPermission('php_ini_display_errors')) {
                $this->iniOptions['php_ini_display_errors'] = 0;
            }

            if (!$this->clientHasPermission('php_ini_disable_functions')) {
                if ($this->getClientPermission('php_ini_disable_functions') == 'no') {
                    $this->iniOptions['php_ini_disable_functions'] = 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
                } elseif (in_array('exec', explode(',', $this->iniOptions['php_ini_disable_functions']), true)) {
                    $this->iniOptions['php_ini_disable_functions'] = 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
                } else {
                    $this->iniOptions['php_ini_disable_functions'] = 'passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';
                }
            }

            if (!$this->clientHasPermission('php_ini_mail_function')) {
                if (!in_array('mail', explode(',', $this->iniOptions['php_ini_disable_functions']), true)) {
                    $this->iniOptions['php_ini_disable_functions'] .= ',mail';
                }
            }

            // Make sure that client INI options are not above reseller's limits
            foreach (
                [
                    'php_ini_memory_limit', 'php_ini_post_max_size', 'php_ini_upload_max_file_size', 'php_ini_max_execution_time',
                    'php_ini_max_input_time'
                ] as $iniOption
            ) {
                $resellerLimit = $this->resellerPermissions[$iniOption];

                if ($this->iniOptions[$iniOption] > $resellerLimit) {
                    $this->iniOptions[$iniOption] = $resellerLimit;
                }
            }

            $this->saveIniOptions($clientId, $row['domain_id'], $row['domain_type']);
            $this->updateDomainStatuses($clientId, $row['domain_id'], $row['domain_type']);
        }

        if ($isBackendRequestNeededPrev && !$this->isBackendRequestNeeded) {
            $this->isBackendRequestNeeded = $isBackendRequestNeededPrev;
        }
    }

    /**
     * Loads INI options
     *
     * If a client identifier, domain and and type are given, try to load
     * current INI options for that client and domain, else, load default
     * INI options, based on both client and reseller permissions.
     *
     * @param int|null $clientId OPTIONAL Client unique identifier
     * @param int|null $domainId OPTIONAL Domain unique identifier
     * @param string|null $domainType OPTIONAL Domain type (dmn|als|sub|subals)
     */
    public function loadIniOptions($clientId = NULL, $domainId = NULL, $domainType = NULL)
    {
        if (empty($this->clientPermissions)) {
            throw new \LogicException('You must first load client permissions.');
        }

        if (NULL !== $clientId) {
            if (NULL == $domainId && NULL == $domainType) {
                throw new \InvalidArgumentException('Both domain identifier and domain type are required');
            }

            $stmt = execQuery('SELECT * FROM php_ini WHERE admin_id = ? AND domain_id = ? AND domain_type = ?', [$clientId, $domainId, $domainType]);

            if ($stmt->rowCount()) {
                $row = $stmt->fetch();
                $this->iniOptions['php_ini_allow_url_fopen'] = $row['allow_url_fopen'];
                $this->iniOptions['php_ini_display_errors'] = $row['display_errors'];
                $this->iniOptions['php_ini_error_reporting'] = $row['error_reporting'];
                $this->iniOptions['php_ini_disable_functions'] = $row['disable_functions'];
                $this->iniOptions['php_ini_post_max_size'] = $row['post_max_size'];
                $this->iniOptions['php_ini_upload_max_file_size'] = $row['upload_max_filesize'];
                $this->iniOptions['php_ini_max_execution_time'] = $row['max_execution_time'];
                $this->iniOptions['php_ini_max_input_time'] = $row['max_input_time'];
                $this->iniOptions['php_ini_memory_limit'] = $row['memory_limit'];
                $this->isDefaultIniOptions = false;
                return;
            }
        }

        $this->iniOptions['php_ini_allow_url_fopen'] = 0;
        $this->iniOptions['php_ini_display_errors'] = 0;
        $this->iniOptions['php_ini_error_reporting'] = 'E_ALL & ~E_DEPRECATED & ~E_STRICT'; // Production value
        $this->iniOptions['php_ini_disable_functions'] = 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system';

        if (!$this->clientHasPermission('php_ini_mail_function')) {
            $this->iniOptions['php_ini_disable_functions'] .= ',mail';
        }

        // Value taken from Debian default php.ini file
        $this->iniOptions['php_ini_memory_limit'] = min($this->resellerPermissions['php_ini_memory_limit'], 128);
        $this->iniOptions['php_ini_post_max_size'] = min($this->resellerPermissions['php_ini_post_max_size'], 8);
        $this->iniOptions['php_ini_upload_max_file_size'] = min($this->resellerPermissions['php_ini_upload_max_file_size'], 2);
        $this->iniOptions['php_ini_max_execution_time'] = min($this->resellerPermissions['php_ini_max_execution_time'], 30);
        $this->iniOptions['php_ini_max_input_time'] = min($this->resellerPermissions['php_ini_max_input_time'], 60);
        $this->isDefaultIniOptions = true;
    }

    /**
     * Saves INI options for the given client and domain
     *
     * @param int $adminId Owner unique identifier
     * @param int $domainId Domain unique identifier
     * @param string $domainType Domain type (dmn|als|sub|subals)
     * @return void
     */
    public function saveIniOptions($adminId, $domainId, $domainType)
    {
        if (empty($this->iniOptions)) {
            throw new \LogicException('You must first load client domain INI options.');
        }

        $stmt = execQuery(
            '
                INSERT INTO php_ini (
                    admin_id, domain_id, domain_type, disable_functions, allow_url_fopen, display_errors, error_reporting, post_max_size,
                    upload_max_filesize, max_execution_time, max_input_time,memory_limit
                ) VALUES (
                    :admin_id, :domain_id, :domain_type, :disable_functions, :allow_url_fopen, :display_errors, :error_reporting, :post_max_size,
                    :upload_max_file_size, :max_execution_time, :max_input_time,:memory_limit
                ) ON DUPLICATE KEY UPDATE
                    disable_functions = :disable_functions, allow_url_fopen = :allow_url_fopen, display_errors = :display_errors,
                    error_reporting = :error_reporting, post_max_size = :post_max_size, upload_max_filesize = :upload_max_file_size,
                    max_execution_time = :max_execution_time, max_input_time = :max_input_time, memory_limit = :memory_limit
            ',
            [
                'admin_id'             => $adminId,
                'domain_id'            => $domainId,
                'domain_type'          => $domainType,
                'disable_functions'    => $this->iniOptions['php_ini_disable_functions'],
                'allow_url_fopen'      => $this->iniOptions['php_ini_allow_url_fopen'],
                'display_errors'       => $this->iniOptions['php_ini_display_errors'],
                'error_reporting'      => $this->iniOptions['php_ini_error_reporting'],
                'post_max_size'        => $this->iniOptions['php_ini_post_max_size'],
                'upload_max_file_size' => $this->iniOptions['php_ini_upload_max_file_size'],
                'max_execution_time'   => $this->iniOptions['php_ini_max_execution_time'],
                'max_input_time'       => $this->iniOptions['php_ini_max_input_time'],
                'memory_limit'         => $this->iniOptions['php_ini_memory_limit']
            ]
        );

        if ($stmt->rowCount() > 0) {
            $this->isBackendRequestNeeded = true;
        }
    }

    /**
     * Update domain statuses if needed
     *
     * @param int $clientId Client unique identifier
     * @param int $domainId Domain unique identifier
     * @param string $domainType Domain type (dmn|als|sub|subals)
     * @param bool $configLevelBased whether domains statuses must be updated based on client PHP configuration level
     * @return void
     */
    public function updateDomainStatuses($clientId, $domainId, $domainType, $configLevelBased = false)
    {
        if (!$this->isBackendRequestNeeded) {
            return;
        }

        if (empty($this->clientPermissions)) {
            throw new \LogicException('You must first load client permissions');
        }

        if ($configLevelBased) {
            switch ($this->clientPermissions['php_ini_config_level']) {
                case 'per_user':
                    // Identical PHP configuration for all domains, including subdomains.
                    $domainId = getCustomerMainDomainId($clientId);

                    // Update all domains
                    execQuery(
                        "
                            UPDATE domain AS t1
                            LEFT JOIN subdomain AS t2 ON(t1.domain_id = t2.domain_id AND t2.subdomain_status NOT IN('disabled', 'todelete'))
                            SET t1.domain_status = 'tochange', t2.subdomain_status = 'tochange'
                            WHERE t1.domain_id = ?
                            AND t1.domain_status <> 'disabled'
                        ",
                        [$domainId]
                    );
                    return;
                case 'per_domain':
                    // Identical PHP configuration for each domains, including subdomains.
                    switch ($domainType) {
                        case 'dmn':
                            // Update primary domain, including its subdomains, except those that are disabled, being disabled or deleted
                            execQuery(
                                "
                                    UPDATE domain AS t1
                                    LEFT JOIN subdomain AS t2 ON(
                                        t1.domain_id = t2.domain_id AND t2.subdomain_status NOT IN ('disabled', 'todisable', 'todelete')
                                    )
                                    SET t1.domain_status = 'tochange', t2.subdomain_status = 'tochange'
                                    WHERE t1.domain_id = ?
                                    AND t1.domain_admin_id = ?
                                    AND t1.domain_status NOT IN('disabled', 'todisable', 'todelete')
                                "
                                [$domainId]
                            );
                            break;
                        case 'als':
                            // Update domain aliases, including their subdomains, except those that are disabled, being disabled or deleted
                            execQuery(
                                "
                                    UPDATE domain_aliases AS t1
                                    LEFT JOIN subdomain_alias AS t2 ON(
                                        t1.alias_id = t2.alias_id AND t2.subdomain_alias_status NOT IN('disabled', 'todisable', 'todelete')
                                    )
                                    SET t1.alias_status = 'tochange', t2.subdomain_alias_status = 'tochange'
                                    WHERE t1.domain_id = ?
                                    AND t1.alias_status NOT IN('disabled', 'todisable', 'todelete')
                                "
                                [$domainId]
                            );
                            break;
                        default:
                            // Nothing to do here. Such request (sub, subals) should never occurs in per_domain level
                            return;
                    }

                    return;
                default:
                    // per_site = Different PHP configuration for each domains, including subdomains.
                    // We need update statuses of $domainId-$domainType only
            }
        }

        switch ($domainType) {
            case 'dmn':
                // Update primary domain, except if it is disabled, being disabled or deleted
                execQuery(
                    "
                        UPDATE domain
                        SET domain_status = 'tochange'
                        WHERE domain_id = ?
                        AND domain_admin_id = ?
                        AND domain_status NOT IN ('disabled', 'todisable', 'todelete')
                    ",
                    [$domainId, $clientId]
                );
                return;
            case 'sub':
                // Update subdomains except if it is disabled, being disabled or deleted
                $query = "
                    UPDATE subdomain AS t1
                    JOIN domain AS t2 USING(domain_id)
                    SET t1.subdomain_status = 'tochange'
                    WHERE t1.subdomain_id = ?
                    AND t2.domain_id = ?
                    AND t1.subdomain_status NOT IN ('disabled', 'todisable', 'todelete')
                ";
                break;
            case 'als';
                // Update domain alias except if it is disabled, being disabled or deleted
                $query = "
                    UPDATE domain_aliases AS t1
                    JOIN domain AS t2 USING(domain_id)
                    SET t1.alias_status = 'tochange'
                    WHERE t1.alias_id = ?
                    AND t2.domain_id = ?
                    AND t1.alias_status NOT IN ('disabled', 'todisable', 'todelete')
                 ";
                break;
            case 'subals':
                // Update subdomains of domain alias except if it is disabled, being disabled or deleted
                $query = "
                    UPDATE subdomain_alias AS t1
                    JOIN domain_aliases AS t2 USING(alias_id)
                    SET t1.subdomain_alias_status = 'tochange'
                    WHERE t1.subdomain_alias_id = ?
                    AND t2.domain_id = ?
                    AND t1.subdomain_alias_status NOT IN ('disabled', 'todisable', 'todelete')
                ";
                break;
            default:
                throw new \InvalidArgumentException('Unknown domain type');
        }

        execQuery($query, [$domainId, getCustomerMainDomainId($clientId)]);
    }
}
