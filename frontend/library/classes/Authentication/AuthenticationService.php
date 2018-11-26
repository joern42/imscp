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

namespace iMSCP\Authentication;

use iMSCP\Application;
use iMSCP\Authentication\Listener\CheckCredentials;
use iMSCP\Authentication\Listener\checkUserAccount;
use iMSCP\Authentication\Listener\CheckMaintenanceMode;
use iMSCP\Authentication\Listener\PasswordRecovery;
use iMSCP\Functions\View;
use iMSCP\Model\CpSuIdentity;
use iMSCP\Model\CpSuIdentityInterface;
use iMSCP\Model\CpUserIdentity;
use iMSCP\Model\UserIdentityInterface;
use iMSCP\Plugin\Bruteforce;
use Zend\Db\Adapter\Driver\ResultInterface;
use Zend\Db\ResultSet\HydratingResultSet;
use Zend\EventManager\EventManagerInterface;
use Zend\EventManager\ListenerAggregateInterface;
use Zend\EventManager\ListenerAggregateTrait;
use Zend\Hydrator\Reflection as ReflectionHydrator;

/**
 * Class AuthenticationService
 *
 * @package iMSCP\Authentication
 */
class AuthenticationService extends \Zend\Authentication\AuthenticationService implements ListenerAggregateInterface
{
    public const EVENT_BEFORE_SIGN_IN = 'onBeforeSignIn';
    public const EVENT_AFTER_SIGN_IN = 'onAfterSignIn';
    public const EVENT_BEFORE_SIGN_OUT = 'onBeforeSignOut';
    public const EVENT_AFTER_SIGN_OUT = 'onAfterSignOut';

    public const ANY_IDENTITY_TYPE = 'any';
    public const ADMIN_IDENTITY_TYPE = 'admin';
    public const RESELLER_IDENTITY_TYPE = 'reseller';
    public const USER_IDENTITY_TYPE = 'user';

    use ListenerAggregateTrait;

    /**
     * @inheritdoc
     */
    public function attach(EventManagerInterface $events, $priority = 99)
    {
        if (Application::getInstance()->getConfig()['BRUTEFORCE']) {
            $bruteforce = new Bruteforce(Application::getInstance()->getPluginManager(), Bruteforce::LOGIN_TARGET);
            $bruteforce->attach($events, $priority);
        }

        // Attach default credentials authentication listener
        $events->attach(AuthEvent::EVENT_AUTHENTICATION, new CheckCredentials(), $priority);

        // Attach listener that is responsible to check for maintenance mode
        $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, new CheckMaintenanceMode(), $priority);

        // Attach listener that is responsible to check customer account
        $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, new checkUserAccount(), $priority);

        // Attach listener that is responsible to show link for password recovery
        $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, new PasswordRecovery(), -99);
    }

    /**
     * Sign in user
     *
     * @return boolean TRUE on success, FALSE on failure
     */
    public function signIn(): bool
    {
        $events = Application::getInstance()->getEventManager();
        $this->attach($events);
        $events->trigger(self::EVENT_BEFORE_SIGN_IN, $this);
        $ret = true;
        $authResult = $this->authenticate();

        if ($authResult->isValid()) {
            writeLog(sprintf('%s signed in.', $this->getIdentity()->getUsername()), E_USER_NOTICE);
        } elseif ($messages = $authResult->getMessages()) {
            // AuthResult::FAILURE_UNCATEGORIZED is used to denote failures that we do not want log
            if ($authResult->getCode() != AuthResult::FAILURE_UNCATEGORIZED) {
                writeLog(sprintf('Authentication failed. Reason: %s', View::FormatPageMessages($messages)), E_USER_NOTICE);
            }

            View::setPageMessage(View::FormatPageMessages($messages), 'static_error');
            $ret = false;
        }

        $events->trigger(self::EVENT_AFTER_SIGN_IN, $this);
        return $ret;
    }

    /**
     * Sign out user
     * 
     * @return void
     */
    public function signOut(): void
    {
        if (!$this->hasIdentity()) {
            return;
        }

        $events = Application::getInstance()->getEventManager();
        $events->trigger(self::EVENT_BEFORE_SIGN_OUT, $this);
        $adminName = $this->getIdentity()->getUsername();
        $this->clearIdentityFromDb();
        $this->clearIdentity();
        $events->trigger(self::EVENT_AFTER_SIGN_OUT, $this);
        View::setPageMessage(tr('You have been successfully signed out.'), 'success');
        writeLog(sprintf('%s signed out.', decodeIdna($adminName)), E_USER_NOTICE);
        redirectTo('/index.php');
    }

    /**
     * Check if current identity is allowed to access the current page
     *
     * @param string $userType User type
     * @param bool $preventExternalLogin If TRUE, external login is disallowed
     * @return void
     */
    public function checkIdentity(string $userType = self::ANY_IDENTITY_TYPE, bool $preventExternalLogin = true): void
    {
        if (!$this->hasIdentity()) {
            !isXhr() or View::showForbiddenErrorPage();
            redirectTo('/index.php');
        }

        $identity = $this->getIdentity();

        // When the panel is in maintenance mode, only administrators can access the interface
        if (Application::getInstance()->getConfig()['MAINTENANCEMODE'] && $identity->getUserType() != self::ADMIN_IDENTITY_TYPE
            && ((!($identity instanceof CpSuIdentityInterface)
                || ($identity->getSuUserType() != self::ADMIN_IDENTITY_TYPE && !($identity->getSuIdentity() instanceof CpSuIdentityInterface))))
        ) {
            $this->clearIdentity();
            View::setPageMessage(tr('You have been automatically signed out due to maintenance tasks.'), 'info');
            redirectTo('/index.php');
        }

        // Check user type
        if (empty($userType) || ($userType != self::ANY_IDENTITY_TYPE && $identity->getUserType() != $userType)) {
            $this->clearIdentity();
            redirectTo('/index.php');
        }

        // Prevent external login if needed
        if ($preventExternalLogin && !empty($_SERVER['HTTP_REFERER']) && ($fromHost = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST))
            && $fromHost !== getRequestHost()
        ) {
            $this->clearIdentity();
            View::showForbiddenErrorPage();
        }
    }

    /**
     * Become another identity or switch back to previous identity during a login session.
     *
     * @param int|null $userId Unique identifier of identity to become, NULL to switch back to previous identity
     * @return void
     */
    public function su(int $userId = NULL): void
    {
        if (!$this->hasIdentity()) {
            // Guests cannot become another identity
            View::showBadRequestErrorPage();
        }

        $identity = $this->getIdentity();
        if (NULL != $userId && $identity->getUserId() == $userId) {
            // An user cannot become himself
            View::showBadRequestErrorPage();
        }

        $newIdentity = NULL;
        // Administrator or reseller signed in as another user identity
        if ($identity instanceof CpSuIdentityInterface) {
            // Administrator signed in as 'reseller' identity then signed in as 'user' identity
            if ($identity->getSuIdentity() instanceof CpSuIdentityInterface) {
                if (NULL !== $userId) {
                    // Unsupported use case: An administrator signed in as 'reseller' identity, then signed in as 'user' identity can only become back
                    // to himself
                    View::showBadRequestErrorPage();
                }
                // and that wants become back the previous identity
                $newIdentity = $identity->getSuIdentity();
            } else { // Administrator signed in as 'reseller' identity  or 'user' identity, or reseller signed in as 'user' identity
                if ($identity->getSuUserType() == 'admin') {
                    if ($identity->getUserType() == 'reseller') { // Administrator signed in as 'reseller' identity
                        if (NULL !== $userId) { // and that want become a 'user' identity of that 'reseller' identity
                            $newIdentity = new CpSuIdentity($identity, $this->getIdentityFromDb($userId));
                        } else { // and that wants become back to himself
                            $newIdentity = $identity->getSuIdentity();
                        }
                    } elseif ($identity->getUserType() == 'user') { // Administrator signed in as 'user' identity
                        if (NULL !== $userId) {
                            // Unsupported use case: An administrator signed in as 'user' identity can only become back to himself
                            View::showBadRequestErrorPage();
                        }
                        // and that wants become back to himself
                        $newIdentity = $identity->getSuIdentity();
                    } else {
                        // Unsupported use case: Unknown user identity type
                        View::showBadRequestErrorPage();
                    }
                } elseif ($identity->getSuUserType() == 'reseller') { // Reseller signed in as 'user' identity
                    if (NULL !== $userId) {
                        // Unsupported use case: A reseller signed in as user identity can only become back to himself
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
            // Unsupported use case: A non SU identity cannot become back to himself and an 'user' identity cannot become another user identity
            View::showBadRequestErrorPage();
        } else { // Administrator or reseller that wants become another user identity
            $newIdentity = new CpSuIdentity($identity, $this->getIdentityFromDb($userId));
            if ($identity->getUserType() == 'reseller' && $newIdentity->getUserCreatedBy() != $identity->getUserId()) {
                // A reseller cannot become an user identity that have not been created by himself
                View::showBadRequestErrorPage();
            }
        }

        // Prevent multiple successive calls from storing inconsistent results
        // Ensure storage has clean state
        if ($this->hasIdentity()) {
            $this->clearIdentity();
        }

        $this->getStorage()->write($newIdentity);
    }

    /**
     * Returns the identity from storage or null if no identity is available
     *
     * Note: Only for IDE type hinting
     *
     * @return UserIdentityInterface|CpSuIdentityInterface|null
     */
    public function getIdentity()
    {
        return parent::getIdentity();
    }

    /**
     * Redirect to user UI
     *
     * Redirect the current logged-in user onto his interface, out of any SU
     * identity consideration. Return early if no identity is found.
     *
     * @param string $location Location to which redirect, relative to current user's interface
     * @return void
     */
    public function redirectToUserUi(string $location = 'index.php'): void
    {
        if (!$this->hasIdentity()) {
            return;
        }

        switch ($this->getIdentity()->getUserType()) {
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
                View::showBadRequestErrorPage();
                exit;
        }

        redirectTo('/' . $userType . '/' . $location);
    }

    /**
     * Return hydrated UserIdentityInterface object using data from the database
     *
     * @param int $identityId Identity unique identifier
     * @return UserIdentityInterface
     */
    protected function getIdentityFromDb(int $identityId): UserIdentityInterface
    {
        $stmt = Application::getInstance()->getDb()->createStatement(
            'SELECT admin_id, admin_name, admin_type, email, created_by FROM admin WHERE admin_id = ?'
        );
        $stmt->prepare();
        $result = $stmt->execute([$identityId]);

        if ($result instanceof ResultInterface && $result->isQueryResult()) {
            $resultSet = new HydratingResultSet(new ReflectionHydrator, new CpUserIdentity());
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

    /**
     * Clear identity data from login database table
     *
     * @return void
     */
    protected function clearIdentityFromDb(): void
    {
        Application::getInstance()->getDb()->createStatement('DELETE FROM login WHERE session_id = ?')->execute([
            Application::getInstance()->getSession()->getManager()->getId()
        ]);
    }
}
