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
use iMSCP\Authentication\AuthResult;
use iMSCP\Authentication\Handler\Credentials;
use iMSCP\Model\SuIdentity;
use iMSCP\Model\SuIdentityInterface;
use iMSCP\Model\UserIdentity;
use iMSCP\Model\UserIdentityInterface;
use iMSCP\Plugin\Bruteforce;
use Zend\Db\Adapter\Driver\ResultInterface;
use Zend\Db\ResultSet\HydratingResultSet;
use Zend\Hydrator\Reflection as ReflectionHydrator;

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
        $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, [Login::class, 'checkDomainAccountListener']);
    }

    /**
     * Event listener that check domain account (status and expires date)
     *
     * Listen on the AuthEvent::EVENT_AFTER_AUTHENTICATION
     *
     * @param AuthEvent $event
     * @return void
     */
    public static function checkDomainAccountListener(AuthEvent $event): void
    {
        $authResult = $event->getAuthenticationResult();
        if (!$authResult->isValid()) {
            return;
        }

        $identity = $authResult->getIdentity();
        if ($identity->getUserType() !== 'user') {
            return;
        }

        $stmt = execQuery(
            '
                SELECT t1.domain_expires, t1.domain_status, t2.admin_status
                FROM domain AS t1
                JOIN admin AS t2. ON(t2.admin_id = t2.domain_admin_id)
                WHERE domain_admin_id = ?
            ',
            [$identity->getUserId()]
        );

        if (!$stmt->rowCount()) {
            writeLog(sprintf('Account data not found in database for the %s user', $identity->getUsername()), E_USER_ERROR);
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [
                tr('An unexpected error occurred. Please contact your reseller.')
            ]);
            $event->setAuthenticationResult($authResult);
            return;
        }

        $row = $stmt->fetch();

        if ($row['admin_status'] == 'disabled' || $row['domain_status'] == 'disabled') {
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [
                tr('Your account has been disabled. Please, contact your reseller.')
            ]);
            $event->setAuthenticationResult($authResult);
            return;
        }

        // We prevent login for accounts which are already expired or which will expire in less than one hour
        if ($row['domain_expires'] > 0 && ($row['domain_expires'] - 3599) < time()) {
            setPageMessage(tr('Your account is expired or will expire in less than one hour. Please contact your reseller.'), 'error');
            $authResult = new AuthResult(AuthResult::FAILURE_UNCATEGORIZED, $identity, [
                tr('Your account has expired. Please, contact your reseller.')
            ]);
            $event->setAuthenticationResult($authResult);
        }
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

        // When the panel is in maintenance mode, only administrators can access the interface
        if (Application::getInstance()->getConfig()['MAINTENANCEMODE'] && $identity->getUserType() != 'admin'
            && ((!($identity instanceof SuIdentityInterface)
                || ($identity->getSuUserType() != 'admin' && !($identity->getSuIdentity() instanceof SuIdentityInterface))))
        ) {
            $authService->clearIdentity();
            redirectTo('/index.php');
        }

        // Check user level
        if (empty($userLevel) || ($userLevel !== 'all' && $identity->getUserType() != $userLevel)) {
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

        // If all condition are meet, update session and last access
        $session = Application::getInstance()->getSession();
        $session['user_login_time'] = time();
        execQuery('UPDATE login SET lastaccess = ? WHERE session_id = ?', [$session['user_login_time'], session_id()]);
    }

    /**
     * Become another user or switch back to previous user
     *
     * @param int|null $userId Unique identifier of user to become, NULL to switch back to previous user
     * @return void
     */
    public static function su(int $userId = NULL): void
    {
        $authService = Application::getInstance()->getAuthService();
        if (!$authService->hasIdentity()) {
            // Guest users cannot become another user
            View::showBadRequestErrorPage();
        }

        $identity = $authService->getIdentity();

        if (NULL != $userId && $identity->getUserId() === $userId) {
            // An user cannot become himself
            View::showBadRequestErrorPage();
        }

        $newIdentity = NULL;

        if ($identity instanceof SuIdentityInterface) { // Administrator or Reseller logged-in as another user
            if ($identity->getSuIdentity() instanceof SuIdentityInterface) { // Administrator logged-in as 'reseller', then logged-in as 'user'
                if (NULL !== $userId) {
                    // When logged-in as 'reseller', then logged-in as 'user', an administrator
                    // can only become the previous user, that is, a 'reseller'.
                    View::showBadRequestErrorPage();
                }

                # and that wants become back the previous user
                $newIdentity = $identity->getSuIdentity();
            } else { // Administrator logged-in as 'reseller' or 'user', Or Reseller logged-in as 'user'
                if ($identity->getSuUserType() === 'admin') {
                    if ($identity->getUserType() === 'reseller') { // Administrator logged-in as 'reseller'
                        if (NULL !== $userId) { // and that want become a 'user' of that 'reseller'
                            $newIdentity = new SuIdentity($identity, static::getIdentityFromDb($userId));
                        } else { // and that wants become himself
                            $newIdentity = $identity->getSuIdentity();
                        }
                    } elseif ($identity->getUserType() === 'user') { // Administrator logged-in as 'user'
                        if (NULL !== $userId) {
                            // Unsupported use case: An administrator logged-in as 'user' can only become himself
                            View::showBadRequestErrorPage();
                        }

                        // and that wants become back to himself
                        $newIdentity = $identity->getSuIdentity();
                    } else {
                        // Unsupported use case: Unknown user identity type
                        View::showBadRequestErrorPage();
                    }
                } elseif ($identity->getSuUserType() == 'reseller') { // Reseller logged-in as user
                    if (NULL !== $userId) {
                        // Unsupported use case: A reseller logged-in as user can only become himself
                        View::showBadRequestErrorPage();
                    }

                    // and that wants become back to himself
                    $newIdentity = $identity->getSuIdentity();
                } else {
                    // Unsupported use case: Unknown SU identity type; A SU identity can be only of type 'admin' or 'reseller'
                    View::showBadRequestErrorPage();
                }
            }
        } elseif (NULL === $userId || $identity->getUserType() == 'user') {
            // Unsupported use case: A non SU identity cannot become back to himself and an 'user' identity cannot become another user
            View::showBadRequestErrorPage();
        } else { // Administrator or Reseller that wants become another user
            $newIdentity = new SuIdentity($identity, static::getIdentityFromDb($userId));

            if ($identity->getUserType() === 'reseller' && $newIdentity->getUserCreatedBy() !== $identity->getUserId()) {
                // A reseller cannot become an user that have not been created by himself
                View::showBadRequestErrorPage();
            }
        }

        $authService->setIdentity($newIdentity);
        static::redirectToUiLevel();
    }

    /**
     * Redirects to user UI level
     *
     * @return void
     */
    public static function redirectToUiLevel(): void
    {
        $authService = Application::getInstance()->getAuthService();
        if (!$authService->hasIdentity()) {
            return;
        }

        switch ($authService->getIdentity()->getUserType()) {
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

        redirectTo('/' . $userType . '/index.php');
    }

    /**
     * Get an identity from the database
     *
     * @param int $identityId Identity unique identifier
     * @return UserIdentityInterface
     */
    protected static function getIdentityFromDb(int $identityId): UserIdentityInterface
    {
        $stmt = Application::getInstance()->getDb()->createStatement(
            'SELECT admin_id, admin_name, admin_pass, admin_type, email, created_by FROM admin WHERE admin_id = ?'
        );
        $stmt->prepare();
        $result = $stmt->execute([$identityId]);

        if ($result instanceof ResultInterface && $result->isQueryResult()) {
            $resultSet = new HydratingResultSet(new ReflectionHydrator, new UserIdentity());
            $resultSet->initialize($result);

            if (count($resultSet) < 1) {
                View::showBadRequestErrorPage();
            }

            /** @var UserIdentityInterface $identity */
            $identity = $resultSet->current();
            return $identity;
        }

        // Something else went wrong...
        View::showInternalServerError();
        exit;
    }
}
