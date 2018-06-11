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
use iMSCP\Form\UserLoginDataFieldset;
use iMSCP\Form\UserPersonalDataFieldset;
use iMSCP\Functions\Mail;
use iMSCP\Functions\Statistics;
use iMSCP\Functions\View;
use Zend\EventManager\Event;
use Zend\Form\Element;
use Zend\Form\Form;

/**
 * Retrieve form data
 *
 * @param int $resellerId Domain unique identifier
 * @param bool $forUpdate Tell whether or not data are fetched for update
 * @return array Reference to array of data
 */
function &getFormData($resellerId, $forUpdate = false)
{
    static $data = NULL;

    if (NULL !== $data) {
        return $data;
    }

    $stmt = execQuery(
        'SELECT t1.*, t2.* FROM admin AS t1 JOIN reseller_props AS t2 ON(t2.reseller_id = t1.admin_id) WHERE t1.admin_id = ?', [$resellerId]
    );

    if (!$stmt->rowCount()) {
        View::showBadRequestErrorPage();
    }

    $data = $stmt->fetch();
    $data['admin_pass'] = '';

    // Getting total of consumed items for the given reseller.
    list($data['nbDomains'], $data['nbSubdomains'], $data['nbDomainAliases'], $data['nbMailAccounts'],
        $data['nbFtpAccounts'], $data['nbSqlDatabases'], $data['nbSqlUsers'], $data['totalTraffic'],
        $data['totalDiskspace']) = Statistics::getResellerStats($resellerId);

    // IP addresses

    // Retrieve list of all server IP addresses
    $stmt = execQuery("SELECT ip_id, ip_number FROM server_ips WHERE ip_status <> 'todelete' ORDER BY ip_number");
    if (!$stmt->rowCount()) {
        View::setPageMessage(tr('Unable to get the IP address list. Please fix this problem.'), 'error');
        redirectTo('users.php');
    }

    $data['server_ips'] = $stmt->fetchAll(\PDO::FETCH_KEY_PAIR);
    $data['reseller_ips'] = explode(',', $data['reseller_ips']);

    // Retrieve all IP addresses assigned to clients of the reseller being edited
    $stmt = execQuery('SELECT DISTINCT domain_client_ips FROM domain JOIN admin ON(admin_id = domain_admin_id) WHERE created_by = ?', [$resellerId]);
    $data['client_ips'] = [];
    while ($row = $stmt->fetch()) {
        $data['client_ips'] = array_merge(
            array_diff(explode(',', $row['domain_client_ips']), $data['client_ips']), $data['client_ips']
        );
    }

    $fallbackData = [];
    foreach ($data as $key => $value) {
        $fallbackData["fallback_$key"] = $value;
    }

    $data = array_merge($data, $fallbackData);

    $phpini = PHPini::getInstance();

    $data['php_ini_system'] = $phpini->getResellerPermission('phpiniSystem');
    $data['php_ini_al_config_level'] = $phpini->getResellerPermission('phpiniConfigLevel');
    $data['php_ini_al_disable_functions'] = $phpini->getResellerPermission('phpiniDisableFunctions');
    $data['php_ini_al_mail_function'] = $phpini->getResellerPermission('phpiniMailFunction');
    $data['php_ini_al_allow_url_fopen'] = $phpini->getResellerPermission('phpiniAllowUrlFopen');
    $data['php_ini_al_display_errors'] = $phpini->getResellerPermission('phpiniDisplayErrors');
    $data['post_max_size'] = $phpini->getResellerPermission('phpiniPostMaxSize');
    $data['upload_max_filesize'] = $phpini->getResellerPermission('phpiniUploadMaxFileSize');
    $data['max_execution_time'] = $phpini->getResellerPermission('phpiniMaxExecutionTime');
    $data['max_input_time'] = $phpini->getResellerPermission('phpiniMaxInputTime');
    $data['memory_limit'] = $phpini->getResellerPermission('phpiniMemoryLimit');

    if (!$forUpdate) {
        return $data;
    }

    foreach (
        [
            'max_dmn_cnt', 'max_sub_cnt', 'max_als_cnt', 'max_mail_cnt', 'max_ftp_cnt', 'max_sql_db_cnt', 'max_sql_user_cnt', 'max_traff_amnt',
            'max_disk_amnt', 'support_system'
        ] as $key
    ) {
        if (isset($_POST[$key])) {
            $data[$key] = cleanInput($_POST[$key]);
        }
    }

    if (isset($_POST['reseller_ips']) && is_array($data['reseller_ips'])) {
        foreach ($_POST['reseller_ips'] as $key => $value) {
            $_POST['reseller_ips'][$key] = cleanInput($value);
        }

        $data['reseller_ips'] = $_POST['reseller_ips'];
    } else { // We are safe here
        $data['reseller_ips'] = [];
    }

    if (isset($_POST['php_ini_system'])) {
        $data['php_ini_system'] = cleanInput($_POST['php_ini_system']);
    }

    if (isset($_POST['php_ini_al_config_level'])) {
        $data['php_ini_al_config_level'] = cleanInput($_POST['php_ini_al_config_level']);
    }

    if (isset($_POST['php_ini_al_disable_functions'])) {
        $data['php_ini_al_disable_functions'] = cleanInput($_POST['php_ini_al_disable_functions']);
    }

    if (isset($_POST['php_ini_al_mail_function'])) {
        $data['php_ini_al_mail_function'] = cleanInput($_POST['php_ini_al_mail_function']);
    }

    if (isset($_POST['php_ini_al_allow_url_fopen'])) {
        $data['php_ini_al_allow_url_fopen'] = cleanInput($_POST['php_ini_al_allow_url_fopen']);
    }

    if (isset($_POST['php_ini_al_display_errors'])) {
        $data['php_ini_al_display_errors'] = cleanInput($_POST['php_ini_al_display_errors']);
    }

    if (isset($_POST['post_max_size'])) {
        $data['post_max_size'] = cleanInput($_POST['post_max_size']);
    }

    if (isset($_POST['upload_max_filesize'])) {
        $data['upload_max_filesize'] = cleanInput($_POST['upload_max_filesize']);
    }

    if (isset($_POST['max_execution_time'])) {
        $data['max_execution_time'] = cleanInput($_POST['max_execution_time']);
    }

    if (isset($_POST['max_input_time'])) {
        $data['max_input_time'] = cleanInput($_POST['max_input_time']);
    }

    if (isset($_POST['memory_limit'])) {
        $data['memory_limit'] = cleanInput($_POST['memory_limit']);
    }

    return $data;
}

/**
 * Generates IP list form
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generateIpListForm(TemplateEngine $tpl)
{
    global $resellerId;

    $data = getFormData($resellerId);
    $tpl->assign('TR_IPS', toHtml(tr('IP addresses')));

    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations(false);
        $e->getParam('translations')->core['available'] = tr('Available');
        $e->getParam('translations')->core['assigned'] = tr('Assigned');
    });

    foreach ($data['server_ips'] as $ipId => $ipAddr) {
        $tpl->assign([
            'IP_VALUE'    => toHtml($ipId),
            'IP_NUM'      => toHtml($ipAddr == '0.0.0.0' ? tr('Any') : $ipAddr),
            'IP_SELECTED' => in_array($ipId, $data['reseller_ips']) ? ' selected' : '',
            'IP_DISABLED' => !in_array($ipId, $data['client_ips'])
                ? ' title="' . toHtml(tr('You cannot un-assign an IP address already used by customers.'), 'htmlAttr') . '" disabled' : ''
        ]);
        $tpl->parse('IP_ENTRY', '.ip_entry');
    }
}

/**
 * Generates features form
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generateLimitsForm(TemplateEngine $tpl)
{
    global $resellerId;

    $data = getFormData($resellerId);
    $tpl->assign([
        'TR_ACCOUNT_LIMITS'   => toHtml(tr('Account limits')),
        'TR_MAX_DMN_CNT'      => toHtml(tr('Domains limit')) . '<br><i>(0 ∞)</i>',
        'MAX_DMN_CNT'         => toHtml($data['max_dmn_cnt']),
        'TR_MAX_SUB_CNT'      => toHtml(tr('Subdomains limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_SUB_CNT'         => toHtml($data['max_sub_cnt']),
        'TR_MAX_ALS_CNT'      => toHtml(tr('Domain aliases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_ALS_CNT'         => toHtml($data['max_als_cnt']),
        'TR_MAX_MAIL_CNT'     => toHtml(tr('Mail accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_MAIL_CNT'        => toHtml($data['max_mail_cnt']),
        'TR_MAX_FTP_CNT'      => toHtml(tr('FTP accounts limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_FTP_CNT'         => toHtml($data['max_ftp_cnt']),
        'TR_MAX_SQL_DB_CNT'   => toHtml(tr('SQL databases limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_SQL_DB_CNT'      => toHtml($data['max_sql_db_cnt']),
        'TR_MAX_SQL_USER_CNT' => toHtml(tr('SQL users limit')) . '<br><i>(-1 ' . toHtml(tr('disabled')) . ', 0 ∞)</i>',
        'MAX_SQL_USER_CNT'    => toHtml($data['max_sql_user_cnt']),
        'TR_MAX_TRAFF_AMNT'   => toHtml(tr('Monthly traffic limit [MiB]')) . '<br><i>(0 ∞)</i>',
        'MAX_TRAFF_AMNT'      => toHtml($data['max_traff_amnt']),
        'TR_MAX_DISK_AMNT'    => toHtml(tr('Disk space limit [MiB]')) . '<br><i>(0 ∞)</i>',
        'MAX_DISK_AMNT'       => toHtml($data['max_disk_amnt'])
    ]);
}

/**
 * Generates features form
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function generateFeaturesForm(TemplateEngine $tpl)
{
    global $resellerId;

    $data = getFormData($resellerId);

    $tpl->assign([
        'TR_FEATURES'                        => toHtml(tr('Features')),
        'TR_SETTINGS'                        => toHtml(tr('PHP Settings')),
        'TR_PHP_EDITOR'                      => toHtml(tr('PHP Editor')),
        'TR_PHP_EDITOR_SETTINGS'             => toHtml(tr('PHP Settings')),
        'TR_PERMISSIONS'                     => toHtml(tr('PHP Permissions')),
        'TR_DIRECTIVES_VALUES'               => toHtml(tr('PHP directives values')),
        'TR_FIELDS_OK'                       => toHtml(tr('All fields are valid.')),
        'PHP_INI_SYSTEM_YES'                 => $data['php_ini_system'] == 'yes' ? ' checked' : '',
        'PHP_INI_SYSTEM_NO'                  => $data['php_ini_system'] != 'yes' ? ' checked' : '',
        'TR_PHP_INI_AL_CONFIG_LEVEL'         => toHtml(tr('PHP configuration level')),
        'TR_PHP_INI_AL_CONFIG_LEVEL_HELP'    => toHtml(tr('Per site: Different PHP configuration for each customer domain, including subdomains<br>Per domain: Identical PHP configuration for each customer domain, including subdomains<br>Per user: Identical PHP configuration for all customer domains, including subdomains'), 'htmlAttr'),
        'TR_PER_DOMAIN'                      => toHtml(tr('Per domain')),
        'TR_PER_SITE'                        => toHtml(tr('Per site')),
        'TR_PER_USER'                        => toHtml(tr('Per user')),
        'PHP_INI_AL_CONFIG_LEVEL_PER_DOMAIN' => $data['php_ini_al_config_level'] == 'per_domain' ? ' checked' : '',
        'PHP_INI_AL_CONFIG_LEVEL_PER_SITE'   => $data['php_ini_al_config_level'] == 'per_site' ? ' checked' : '',
        'PHP_INI_AL_CONFIG_LEVEL_PER_USER'   => $data['php_ini_al_config_level'] == 'per_user' ? ' checked' : '',
        'TR_PHP_INI_AL_ALLOW_URL_FOPEN'      => tr('Can edit the PHP %s configuration option', '<strong>allow_url_fopen</strong>'),
        'PHP_INI_AL_ALLOW_URL_FOPEN_YES'     => $data['php_ini_al_allow_url_fopen'] == 'yes' ? ' checked' : '',
        'PHP_INI_AL_ALLOW_URL_FOPEN_NO'      => $data['php_ini_al_allow_url_fopen'] != 'yes' ? ' checked' : '',
        'TR_PHP_INI_AL_DISPLAY_ERRORS'       => tr('Can edit the PHP %s configuration option', '<strong>display_errors</strong>'),
        'PHP_INI_AL_DISPLAY_ERRORS_YES'      => $data['php_ini_al_display_errors'] == 'yes' ? ' checked' : '',
        'PHP_INI_AL_DISPLAY_ERRORS_NO'       => $data['php_ini_al_display_errors'] != 'yes' ? ' checked' : '',
        'TR_PHP_INI_AL_DISABLE_FUNCTIONS'    => tr('Can edit the PHP %s configuration option', '<strong>disable_functions</strong>'),
        'PHP_INI_AL_DISABLE_FUNCTIONS_YES'   => $data['php_ini_al_disable_functions'] == 'yes' ? ' checked' : '',
        'PHP_INI_AL_DISABLE_FUNCTIONS_NO'    => $data['php_ini_al_disable_functions'] != 'yes' ? ' checked' : '',
        'TR_MEMORY_LIMIT'                    => tr('PHP %s configuration option', '<strong>memory_limit</strong>'),
        'MEMORY_LIMIT'                       => toHtml($data['memory_limit']),
        'TR_UPLOAD_MAX_FILESIZE'             => tr('PHP %s configuration option', '<strong>upload_max_filesize</strong>'),
        'UPLOAD_MAX_FILESIZE'                => toHtml($data['upload_max_filesize']),
        'TR_POST_MAX_SIZE'                   => tr('PHP %s configuration option', '<strong>post_max_size</strong>'),
        'POST_MAX_SIZE'                      => toHtml($data['post_max_size']),
        'TR_MAX_EXECUTION_TIME'              => tr('PHP %s configuration option', '<strong>max_execution_time</strong>'),
        'MAX_EXECUTION_TIME'                 => toHtml($data['max_execution_time']),
        'TR_MAX_INPUT_TIME'                  => tr('PHP %s configuration option', '<strong>max_input_time</strong>'),
        'MAX_INPUT_TIME'                     => toHtml($data['max_input_time']),
        'TR_SUPPORT_SYSTEM'                  => toHtml(tr('Support system')),
        'SUPPORT_SYSTEM_YES'                 => $data['support_system'] == 'yes' ? ' checked' : '',
        'SUPPORT_SYSTEM_NO'                  => $data['support_system'] != 'yes' ? ' checked' : '',
        'TR_PHP_INI_PERMISSION_HELP'         => toHtml(tr('If set to `yes`, the reseller can allows his customers to edit this PHP configuration option.'), 'htmlAttr'),
        'TR_PHP_INI_AL_MAIL_FUNCTION_HELP'   => toHtml(tr('If set to `yes`, the reseller can enable/disable the PHP mail function for his customers, else, the PHP mail function is disabled.'), 'htmlAttr'),
        'TR_YES'                             => toHtml(tr('Yes')),
        'TR_NO'                              => toHtml(tr('No')),
        'TR_MIB'                             => toHtml(tr('MiB')),
        'TR_SEC'                             => toHtml(tr('Sec.'))
    ]);

    Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
        $translations = $e->getParam('translations');
        $translations['core']['close'] = tr('Close');
        $translations['core']['fields_ok'] = tr('All fields are valid.');
        $translations['core']['out_of_range_value_error'] = tr('Value for the PHP %%s directive must be in range %%d to %%d.');
        $translations['core']['lower_value_expected_error'] = tr('%%s cannot be greater than %%s.');
        $translations['core']['error_field_stack'] = Application::getInstance()->getRegistry()->has('errFieldsStack')
            ? Application::getInstance()->getRegistry()->get('errFieldsStack') : [];
    });

    if (strpos(Application::getInstance()->getConfig()['iMSCP::Servers::Httpd'], '::Apache2::') !== false) {
        $apacheConfig = loadServiceConfigFile(Application::getInstance()->getConfig()['CONF_DIR'] . '/apache/apache.data');
        $isApacheItk = $apacheConfig['HTTPD_MPM'] == 'itk';
    } else {
        $isApacheItk = false;
    }

    if ($isApacheItk) {
        $tpl->assign([
            'TR_PHP_INI_AL_DISABLE_FUNCTIONS'  => tr('Can edit the PHP %s configuration option', '<strong>disable_functions</strong>'),
            'PHP_INI_AL_DISABLE_FUNCTIONS_YES' => $data['php_ini_al_disable_functions'] == 'yes' ? ' checked' : '',
            'PHP_INI_AL_DISABLE_FUNCTIONS_NO'  => $data['php_ini_al_disable_functions'] != 'yes' ? ' checked' : '',
            'TR_PHP_INI_AL_MAIL_FUNCTION'      => tr('Can use the PHP %s function', '<strong>mail</strong>'),
            'PHP_INI_AL_MAIL_FUNCTION_YES'     => $data['php_ini_al_mail_function'] == 'yes' ? ' checked' : '',
            'PHP_INI_AL_MAIL_FUNCTION_NO'      => $data['php_ini_al_mail_function'] != 'yes' ? ' checked' : '',
        ]);
        return;
    }

    $tpl->assign('PHP_EDITOR_DISABLE_FUNCTIONS_BLOCK', '');
    $tpl->assign('PHP_EDITOR_MAIL_FUNCTION_BLOCK', '');
}

/**
 * Update reseller user
 *
 * @param Form $form
 * @return void
 */
function updateResellerUser(Form $form)
{
    global $resellerId;

    $error = false;
    $db = Application::getInstance()->getDb();

    try {
        $stmt = execQuery(
            '
                SELECT IFNULL(SUM(t1.domain_subd_limit), 0) AS subdomains,
                    IFNULL(SUM(t1.domain_alias_limit), 0) AS domainAliases,
                    IFNULL(SUM(t1.domain_mailacc_limit), 0) AS mailAccounts,
                    IFNULL(SUM(t1.domain_ftpacc_limit), 0) AS ftpAccounts,
                    IFNULL(SUM(t1.domain_sqld_limit), 0) AS sqlDatabases,
                    IFNULL(SUM(t1.domain_sqlu_limit), 0) AS sqlUsers,
                    IFNULL(SUM(t1.domain_traffic_limit), 0) AS traffic,
                    IFNULL(SUM(t1.domain_disk_limit), 0) AS diskspace
                FROM domain AS t1
                JOIN admin AS t2 ON(t2.admin_id = t1.domain_admin_id)
                WHERE t2.created_by = ?
            ',
            [$resellerId]
        );

        $unlimitedItems = array_map(
            function ($element) {
                return $element == -1 ? false : $element == 0;
            },
            $stmt->fetch()
        );

        //
        // Check for login and personal data
        //

        $form->setData(Application::getInstance()->getRequest()->getPost());

        // We do not want validate username in edit mode
        $form->getInputFilter()->get('loginData')->remove('admin_name');
        // Password is optional in edit mode
        $form->getInputFilter()->get('loginData')->get('admin_pass')->setRequired(false);
        if ($form->get('loginData')->get('admin_pass')->getValue() == ''
            && $form->get('loginData')->get('admin_pass_confirmation')->getValue() == ''
        ) {
            $form->getInputFilter()->get('loginData')->get('admin_pass_confirmation')->setRequired(false);
        }
        if (!$form->isValid()) {
            $error = true;
            View::setPageMessage(View::formatPageMessages($form->getMessages()), 'error');
        }

        $data =& getFormData($resellerId, true);

        //
        // Check for IP addresses
        //

        // Make sure that all assigned IP addresses (client IP addresses are still listed
        $data['reseller_ips'] = array_unique(array_merge($data['reseller_ips'], $data['client_ips']));

        // Dicard unknown IP addresses
        $data['reseller_ips'] = array_intersect($data['reseller_ips'], array_keys($data['server_ips']));

        if (empty($data['reseller_ips'])) {
            View::setPageMessage(tr('You must assign at least one IP to this reseller.'), 'error');
            $error = true;
        } else {
            sort($data['reseller_ips'], SORT_NUMERIC);
        }

        // Check for max domains limit
        if (validateLimit($data['max_dmn_cnt'], NULL)) {
            if (!checkResellerLimit($data['max_dmn_cnt'], $data['current_dmn_cnt'], $data['nbDomains'], false, tr('domains'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('domain')), 'error');
            $error = true;
        }

        // Check for max subdomains limit
        if (validateLimit($data['max_sub_cnt'])) {
            if (!checkResellerLimit($data['max_sub_cnt'], $data['current_sub_cnt'], $data['nbSubdomains'], $unlimitedItems['subdomains'], tr('subdomains'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('subdomains')), 'error');
            $error = true;
        }

        // check for max domain aliases limit
        if (validateLimit($data['max_als_cnt'])) {
            if (!checkResellerLimit($data['max_als_cnt'], $data['current_als_cnt'], $data['nbDomainAliases'], $unlimitedItems['domainAliases'], tr('domain aliases'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('domain aliases')), 'error');
            $error = true;
        }

        // Check for max mail accounts limit
        if (validateLimit($data['max_mail_cnt'])) {
            if (!checkResellerLimit($data['max_mail_cnt'], $data['current_mail_cnt'], $data['nbMailAccounts'], $unlimitedItems['mailAccounts'], tr('mail'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('mail accounts')), 'error');
            $error = true;
        }

        // Check for max FTP accounts limit
        if (validateLimit($data['max_ftp_cnt'])) {
            if (!checkResellerLimit($data['max_ftp_cnt'], $data['current_ftp_cnt'], $data['nbFtpAccounts'], $unlimitedItems['ftpAccounts'], tr('Ftp'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('Ftp accounts')), 'error');
            $error = true;
        }

        // Check for max SQL databases limit
        if (!$rs = validateLimit($data['max_sql_db_cnt'])) {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('SQL databases')), 'error');
            $error = true;
        } elseif ($data['max_sql_db_cnt'] == -1 && $data['max_sql_user_cnt'] != -1) {
            View::setPageMessage(tr('SQL database limit is disabled but SQL user limit is not.'), 'error');
            $error = true;
        } else {
            if (!checkResellerLimit($data['max_sql_db_cnt'], $data['current_sql_db_cnt'], $data['nbSqlDatabases'], $unlimitedItems['sqlDatabases'], tr('SQL databases'))) {
                $error = true;
            }
        }

        // Check for max SQL users limit
        if (!$rs = validateLimit($data['max_sql_user_cnt'])) {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('SQL users')), 'error');
            $error = true;
        } elseif ($data['max_sql_db_cnt'] != -1 && $data['max_sql_user_cnt'] == -1) {
            View::setPageMessage(tr('SQL user limit is disabled but SQL database limit is not.'), 'error');
            $error = true;
        } else {
            if (!checkResellerLimit($data['max_sql_user_cnt'], $data['current_sql_user_cnt'], $data['nbSqlUsers'], $unlimitedItems['sqlUsers'], tr('SQL users'))) {
                $error = true;
            }
        }

        // Check for max monthly traffic limit
        if (validateLimit($data['max_traff_amnt'], NULL)) {
            if (!checkResellerLimit($data['max_traff_amnt'], $data['current_traff_amnt'], $data['totalTraffic'] / 1048576, $unlimitedItems['traffic'], tr('traffic'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('traffic')), 'error');
        }

        // Check for max disk space limit
        if (validateLimit($data['max_disk_amnt'], NULL)) {
            if (!checkResellerLimit($data['max_disk_amnt'], $data['current_disk_amnt'], $data['totalDiskspace'] / 1048576, $unlimitedItems['diskspace'], tr('disk space'))) {
                $error = true;
            }
        } else {
            View::setPageMessage(tr('Incorrect limit for %s.', tr('disk space')), 'error');
        }

        $db->getDriver()->getConnection()->beginTransaction();

        // Check for PHP settings
        $phpini = PHPini::getInstance();
        $phpini->setResellerPermission('phpiniSystem', $data['php_ini_system']);

        if ($phpini->resellerHasPermission('phpiniSystem')) {
            $phpini->setResellerPermission('phpiniConfigLevel', $data['php_ini_al_config_level']);
            $phpini->setResellerPermission('phpiniDisableFunctions', $data['php_ini_al_disable_functions']);
            $phpini->setResellerPermission('phpiniMailFunction', $data['php_ini_al_mail_function']);
            $phpini->setResellerPermission('phpiniAllowUrlFopen', $data['php_ini_al_allow_url_fopen']);
            $phpini->setResellerPermission('phpiniDisplayErrors', $data['php_ini_al_display_errors']);

            // Must be set before phpiniPostMaxSize
            $phpini->setResellerPermission('phpiniMemoryLimit', $data['memory_limit']);
            // Must be set before phpiniUploadMaxFileSize
            $phpini->setResellerPermission('phpiniPostMaxSize', $data['post_max_size']);
            $phpini->setResellerPermission('phpiniUploadMaxFileSize', $data['upload_max_filesize']);
            $phpini->setResellerPermission('phpiniMaxExecutionTime', $data['max_execution_time']);
            $phpini->setResellerPermission('phpiniMaxInputTime', $data['max_input_time']);
        } else {
            // Reset reseller permissions to their default values
            $phpini->loadResellerPermissions();
        }

        if (!$error) {
            $ldata = $form->getData()['loginData'];
            $pdata = $form->getData()['personalData'];

            Application::getInstance()->getEventManager()->trigger(Events::onBeforeEditUser, NULL, [
                'userId'       => $resellerId,
                'loginData'    => $ldata,
                'personalData' => $pdata
            ]);

            // Update reseller personal data (including password if needed)

            $bindParams = [
                $pdata['fname'], $pdata['lname'], $pdata['gender'], $pdata['firm'], $pdata['zip'], $pdata['city'], $pdata['state'], $pdata['country'],
                encodeIdna($pdata['email']), $pdata['phone'], $pdata['fax'], $pdata['street1'], $pdata['street2'], $resellerId
            ];

            if ($ldata['admin_pass'] != '') {
                $setPassword = 'admin_pass = ?,';
                array_unshift($bindParams, Crypt::bcrypt($ldata['admin_pass']));
            } else {
                $setPassword = '';
            }

            execQuery(
                "
                    UPDATE admin SET {$setPassword} fname = ?, lname = ?, gender = ?, firm = ?, zip = ?, city = ?, state = ?, country = ?, email = ?,
                        phone = ?, fax = ?, street1 = ?, street2 = ?
                    WHERE admin_id = ?
                ",
                $bindParams
            );

            // Update limits and permissions

            execQuery(
                '
                    UPDATE reseller_props
                    SET max_dmn_cnt = ?, max_sub_cnt = ?, max_als_cnt = ?, max_mail_cnt = ?, max_ftp_cnt = ?, max_sql_db_cnt = ?,
                        max_sql_user_cnt = ?, max_traff_amnt = ?, max_disk_amnt = ?, reseller_ips = ?, support_system = ?
                    WHERE reseller_id = ?
                ',
                [
                    $data['max_dmn_cnt'], $data['max_sub_cnt'], $data['max_als_cnt'], $data['max_mail_cnt'], $data['max_ftp_cnt'],
                    $data['max_sql_db_cnt'], $data['max_sql_user_cnt'], $data['max_traff_amnt'], $data['max_disk_amnt'],
                    implode(',', $data['reseller_ips']), $data['support_system'], $resellerId
                ]
            );

            $phpini->saveResellerPermissions($resellerId);
            $phpini->syncClientPermissionsAndIniOptions($resellerId);

            // Force user to login again (needed due to possible password or email change)
            execQuery('DELETE FROM login WHERE user_name = ?', [$data['fallback_admin_name']]);

            Application::getInstance()->getEventManager()->trigger(Events::onAfterEditUser, NULL, [
                'userId'       => $resellerId,
                'loginData'    => $ldata,
                'personalData' => $pdata
            ]);

            $db->getDriver()->getConnection()->commit();

            // Send mail to reseller for new password
            if ($ldata['admin_pass'] != '') {
                Mail::sendWelcomeMail(
                    Application::getInstance()->getAuthService()->getIdentity()->getUserId(), $data['admin_name'], $ldata['admin_pass'],
                    $pdata['email'], $pdata['fname'], $pdata['lname'], tr('Reseller')
                );
            }

            writeLog(sprintf(
                'The %s reseller has been updated by %s', $data['admin_name'], Application::getInstance()->getAuthService()->getIdentity()->getUsername()),
                E_USER_NOTICE
            );
            View::setPageMessage('Reseller has been updated.', 'success');
            redirectTo('users.php');
        }
    } catch (\Exception $e) {
        $db->getDriver()->getConnection()->rollBack();
        throw $e;
    }
}

/**
 * Check reseller limit
 *
 * @param int $newLimit New limit (-1 for deactivation, 0 for ∞, $newLimit > 0 to limit items quantity)
 * @param int $assignedByReseller How many items are already assigned to reseller's customers
 * @param int $consumedByCustomers How many items are already consumed by reseller's customers.
 * @param bool $unlimitedService Tells whether or not the service is set as unlimited for a reseller's customer
 * @param String $serviceName Service name for which new limit is verified
 * @return bool TRUE if new limit is valid, FALSE otherwise
 */
function checkResellerLimit($newLimit, $assignedByReseller, $consumedByCustomers, $unlimitedService, $serviceName)
{
    $retVal = true;

    // We process only if the new limit value is not equal to 0 (unlimited)
    if ($newLimit == 0) {
        return $retVal;
    }

    // The service is limited for all customers
    if ($unlimitedService == false) {
        // If the new limit is lower than the already consomed item by customer
        if ($newLimit < $consumedByCustomers && $newLimit != -1) {
            View::setPageMessage(
                tr(
                    "%s: The clients consumption (%s) for this reseller is greater than the new limit.",
                    '<strong>' . ucfirst($serviceName) . '</strong>', $consumedByCustomers),
                'error'
            );
            $retVal = false;
            // If the new limit is lower than the items already assigned by the reseller
        } elseif ($newLimit < $assignedByReseller && $newLimit != -1) {
            View::setPageMessage(
                tr('%s: The total of items (%s) already assigned by the reseller is greater than the new limit.',
                    '<strong>' . ucfirst($serviceName) . '</strong>', $assignedByReseller
                ),
                'error'
            );
            $retVal = false;
            // If the new limit is -1 (disabled) and assigned items are already consumed by customer
        } elseif ($newLimit == -1 && $consumedByCustomers > 0) {
            View::setPageMessage(
                tr("%s: You cannot disable a service already consumed by reseller's customers.", '<strong>' . ucfirst($serviceName) . '</strong>'),
                'error'
            );
            $retVal = false;
            // If the new limit is -1 (disabled) and the already assigned accounts/limits by reseller is greater 0
        } elseif ($newLimit == -1 && $assignedByReseller > 0) {
            View::setPageMessage(
                tr("%s: You cannot disable a service already sold to reseller's customers.", '<strong>' . ucfirst($serviceName) . '</strong>'),
                'error'
            );
            $retVal = false;
        }
        // One or more reseller's customers have unlimited items
    } elseif ($newLimit != 0) {
        View::setPageMessage(tr('%s: This reseller has customer(s) with unlimited items.', '<strong>' . ucfirst($serviceName) . '</strong>'), 'error');
        View::setPageMessage(tr('If you want to limit the reseller, you must first limit its customers.'), 'error');
        $retVal = false;
    }

    return $retVal;
}

/**
 * Generate page
 *
 * @param TemplateEngine $tpl Template engine instance
 * @param Form $form
 * @return void
 */
function generatePage(TemplateEngine $tpl, Form $form)
{
    global $resellerId;

    /** @noinspection PhpUndefinedFieldInspection */
    $tpl->form = $form;

    if (!Application::getInstance()->getRequest()->isPost()) {
        $data = getFormData($resellerId);
        $form->get('loginData')->populateValues($data);
        $form->get('personalData')->populateValues($data);
    }

    generateIpListForm($tpl);
    generateLimitsForm($tpl);
    generateFeaturesForm($tpl);
}

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::ADMIN_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

global $resellerId;
($resellerId = Application::getInstance()->getRequest()->getQuery('edit_id')) !== NULL or View::showBadRequestErrorPage();
$phpini = PHPini::getInstance();
$phpini->loadResellerPermissions($resellerId);

($form = new Form('ResellerEditForm'))
    ->add([
        'type' => UserLoginDataFieldset::class,
        'name' => 'loginData'
    ])
    ->add([
        'type' => UserPersonalDataFieldset::class,
        'name' => 'personalData'
    ])
    ->add([
        'type'    => Element\Csrf::class,
        'name'    => 'csrf',
        'options' => [
            'csrf_options' => [
                'timeout' => 300,
                'message' => tr('Validation token (CSRF) was expired. Please try again.')
            ]
        ]
    ])
    ->add([
        'type'    => Element\Submit::class,
        'name'    => 'submit',
        'options' => ['label' => tr('Update')]
    ]);

if (Application::getInstance()->getRequest()->isPost()) {
    updateResellerUser($form);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                             => 'shared/layouts/ui.tpl',
    'page'                               => 'admin/reseller_edit.phtml',
    'page_message'                       => 'layout',
    'ip_entry'                           => 'page',
    'php_editor_disable_functions_block' => 'page',
    'php_editor_mail_function_block'     => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE' => toHtml(tr('Admin / Users / Edit Reseller')),
    'EDIT_ID'       => toUrl($resellerId)
]);
View::generateNavigation($tpl);
generatePage($tpl, $form);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
