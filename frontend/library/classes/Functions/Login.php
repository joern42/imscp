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

namespace iMSCP\Functions;

use iMSCP\Application;
use iMSCP\Authentication\AuthEvent;
use iMSCP\Authentication\Handler\Credentials;
use iMSCP\Plugin\Bruteforce;
use Zend\EventManager\Event;

/**
 * Class Login
 * @package iMSCP\Functions
 */
class Login
{
    /**
     * Initialize login
     *
     * @return void
     */
    public static function initLogin(): void
    {
        static::doSessionTimeout();

        $events = Application::getInstance()->getEventManager();

        if (Application::getInstance()->getConfig()['BRUTEFORCE']) {
            $bruteforce = new Bruteforce(Application::getInstance()->getPluginManager());
            $bruteforce->attach($events);
        }

        // Register default authentication handler with high-priority
        $events->attach(AuthEvent::EVENT_AUTHENTICATION, [Credentials::class, 'authenticate'], 99);

        // Register listener that is responsible to check domain status and expire date
        //$events->attach(Events::onBeforeSetIdentity, [Login::class, 'checkDomainAccountHandler']);
    }

    /**
     * Check domain account state (status and expires date)
     *
     * Note: Listen to the onBeforeSetIdentity event triggered in the Auth component.
     *
     * @param Event $event
     * @return void
     */
    public static function checkDomainAccountHandler(Event $event): void
    {
        /** @var $identity \stdClass */
        $identity = $event->getParam('identity');

        if ($identity->admin_type != 'user') {
            return;
        }

        $stmt = execQuery(
            'SELECT domain_expires, domain_status, admin_status FROM domain JOIN admin ON(domain_admin_id = admin_id) WHERE domain_admin_id = ?',
            [$identity->admin_id]
        );

        $event->stopPropagation();

        if (!$stmt->rowCount()) {
            writeLog(sprintf('Account data not found in database for the %s user', $identity->admin_name), E_USER_ERROR);
            setPageMessage(tr('An unexpected error occurred. Please contact your reseller.'), 'error');
            return;
        }

        $row = $stmt->fetch();

        if ($row['admin_status'] == 'disabled' || $row['domain_status'] == 'disabled') {
            setPageMessage(tr('Your account has been disabled. Please, contact your reseller.'), 'error');
            return;
        }

        if ($row['domain_expires'] > 0 && $row['domain_expires'] < time()) {
            setPageMessage(tr('Your account has expired. Please, contact your reseller.'), 'error');
            return;
        }

        $event->stopPropagation(false);
    }

    /**
     * Remove data that belong to expired sessions
     *
     * FIXME: Shouldn't be run on every requests.
     * 
     * @return void
     */
    public static function doSessionTimeout(): void
    {
        // We must not remove bruteforce plugin data (AND `user_name` IS NOT NULL)
        execQuery(
            'DELETE FROM login WHERE lastaccess < ? AND user_name IS NOT NULL', [
                time() - Application::getInstance()->getConfig()['SESSION_TIMEOUT'] * 60
        ]);
    }

    /**
     * Check login
     *
     * @param string $userLevel User level (admin|reseller|user)
     * @param bool $preventExternalLogin If TRUE, external login is disallowed
     * @return void
     */
    public static function checkLogin(string $userLevel, bool $preventExternalLogin = true): void
    {
        static::doSessionTimeout();
        $authService = Application::getInstance()->getAuthService();

        if (!$authService->hasIdentity()) {
            $authService->clearIdentity(); // Ensure deletion of all identity data
            !isXhr() or View::showForbiddenErrorPage();
            redirectTo('/index.php');
        }

        $identity = $authService->getIdentity();
        $session = Application::getInstance()->getSession();

        // When the panel is in maintenance mode, only administrators can access the interface
        if (Application::getInstance()->getConfig()['MAINTENANCEMODE'] && $identity->admin_type != 'admin'
            && (!isset($session['logged_from_type']) || $session['logged_from_type'] != 'admin')
        ) {
            $authService->clearIdentity();
            redirectTo('/index.php');
        }

        // Check user level
        if (empty($userLevel) || ($userLevel !== 'all' && $identity->admin_type != $userLevel)) {
            $authService->clearIdentity();
            redirectTo('/index.php');
        }

        // prevent external login / check for referer
        if ($preventExternalLogin && !empty($_SERVER['HTTP_REFERER']) && ($fromHost = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST))
            && $fromHost !== getRequestHost()
        ) {
            $authService->clearIdentity();
            View::showForbiddenErrorPage();
        }

        // If all goes fine update session and last access
        $session['user_login_time'] = time();
        execQuery('UPDATE login SET lastaccess = ? WHERE session_id = ?', [$session['user_login_time'], session_id()]);
    }

    /**
     * Switch between user's interfaces
     *
     * @param int $fromId User ID to switch from
     * @param int $toId User ID to switch on
     * @return void
     */
    public static function changeUserInterface(int $fromId, int $toId): void
    {
        $toActionScript = false;

        while (1) { // We loop over nothing here, it's just a way to avoid code repetition
            $stmt = execQuery(
                'SELECT admin_id, admin_name, admin_type, email, created_by FROM admin WHERE admin_id IN(?, ?) ORDER BY FIELD(admin_id, ?, ?) LIMIT 2',
                [$fromId, $toId, $fromId, $toId]
            );

            if ($stmt->rowCount() < 2) {
                setPageMessage(tr('Bad request.'), 'error');
            }

            list($from, $to) = $stmt->fetchAll(\PDO::FETCH_OBJ);

            $fromToMap = [];
            $fromToMap['admin']['BACK'] = 'users.php';
            $fromToMap['admin']['reseller'] = 'index.php';
            $fromToMap['admin']['user'] = 'index.php';
            $fromToMap['reseller']['user'] = 'index.php';
            $fromToMap['reseller']['BACK'] = 'users.php';

            $session = Application::getInstance()->getSession();

            if (!isset($fromToMap[$from->admin_type][$to->admin_type]) || ($from->admin_type == $to->admin_type)) {
                if (!isset($session['logged_from_id']) || $session['logged_from_id'] != $to->admin_id) {
                    setPageMessage(tr('Bad request.'), 'error');
                    writeLog(sprintf("%s tried to switch onto %s's interface", $from->admin_name, decodeIdna($to->admin_name)), E_USER_WARNING);
                    break;
                }

                $toActionScript = $fromToMap[$to->admin_type]['BACK'];
            }

            $toActionScript = $toActionScript ?: $fromToMap[$from->admin_type][$to->admin_type];

            // Set new identity
            $authService = Application::getInstance()->getAuthService();
            $authService->clearIdentity();

            if ($from->admin_type != 'user' && $to->admin_type != 'admin') {
                $session = Application::getInstance()->getSession();
                // Set additional data about user from which we are logged from
                $session['logged_from_type'] = $from->admin_type;
                $session['logged_from'] = $from->admin_name;
                $session['logged_from_id'] = $from->admin_id;
                writeLog(sprintf("%s switched onto %s's interface", $from->admin_name, decodeIdna($to->admin_name)), E_USER_NOTICE);
            } else {
                writeLog(sprintf("%s switched back from %s's interface", $to->admin_name, decodeIdna($from->admin_name)), E_USER_NOTICE);
            }

            $authService->setIdentity($to);
            break;
        }

        static::redirectToUiLevel($toActionScript);
    }

    /**
     * Redirects to user ui level
     *
     * @param string $actionScript Action script on which user should be redirected
     * @return void
     */
    public static function redirectToUiLevel(string $actionScript = 'index.php'): void
    {
        $authService = Application::getInstance()->getAuthService();

        if (!$authService->hasIdentity()) {
            return;
        }

        switch ($authService->getIdentity()->admin_type) {
            case 'user':
                $userType = 'client';
                break;
            case 'admin':
                $userType = 'admin';
                break;
            case 'reseller':
                $userType = 'reseller';
                break;
            default:
                throw new \Exception('Unknown UI level');
        }

        redirectTo('/' . $userType . '/' . $actionScript);
    }
}
