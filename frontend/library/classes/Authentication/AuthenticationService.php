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
use iMSCP\Authentication\Listener\CheckCustomerAccount;
use iMSCP\Authentication\Listener\CheckMaintenanceMode;
use iMSCP\Functions\View;
use iMSCP\Model\SuIdentity;
use iMSCP\Model\SuIdentityInterface;
use iMSCP\Model\UserIdentity;
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
    use ListenerAggregateTrait;

    /**
     * Attach default authentication listeners
     *
     * @param EventManagerInterface $events
     * @param int $priority
     * @return void
     */
    public function attach(EventManagerInterface $events, $priority = 1)
    {
        if (Application::getInstance()->getConfig()['BRUTEFORCE']) {
            $bruteforce = new Bruteforce(Application::getInstance()->getPluginManager());
            $bruteforce->attach($events, $priority);
        }

        // Attach default credentials authentication listener
        $this->listeners[] = $events->attach(AuthEvent::EVENT_AUTHENTICATION, new CheckCredentials(), $priority);
        // Attach listener that is responsible to check customer account
        $this->listeners[] = $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, new CheckCustomerAccount(), $priority);
        // Attach listener that is responsible to check for maintenance mode
        $this->listeners[] = $events->attach(AuthEvent::EVENT_AFTER_AUTHENTICATION, new CheckMaintenanceMode(), $priority);
    }

    /**
     * Check authentication
     *
     * @param string $userLevel User level (admin|reseller|user)
     * @param bool $preventExternalLogin If TRUE, external login is disallowed
     * @return void
     */
    public function checkAuthentication(string $userLevel, bool $preventExternalLogin = true): void
    {
        if (!$this->hasIdentity()) {
            !isXhr() or View::showForbiddenErrorPage();
            redirectTo('/index.php');
        }

        $identity = $this->getIdentity();

        // When the panel is in maintenance mode, only administrators can access the interface
        if (Application::getInstance()->getConfig()['MAINTENANCEMODE'] && $identity->getUserType() != 'admin'
            && ((!($identity instanceof SuIdentityInterface)
                || ($identity->getSuUserType() != 'admin' && !($identity->getSuIdentity() instanceof SuIdentityInterface))))
        ) {
            $this->clearIdentity();
            setPageMessage(tr('You have been automatically disconnected due to maintenance task.'), 'info');
            redirectTo('/index.php');
        }

        // Check user level
        if (empty($userLevel) || ($userLevel !== 'all' && $identity->getUserType() != $userLevel)) {
            $this->clearIdentity();
            redirectTo('/index.php');
        }

        // prevent external login / check for referer
        if ($preventExternalLogin && !empty($_SERVER['HTTP_REFERER']) && ($fromHost = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST))
            && $fromHost !== getRequestHost()
        ) {
            $this->clearIdentity();
            View::showForbiddenErrorPage();
        }

        // If all condition are meet, update session and last access
        // FIXME: Shouldn't be done while session write-close?
        execQuery('UPDATE login SET lastaccess = ? WHERE session_id = ? AND ipaddr = ?', [
            time(), Application::getInstance()->getSession()->getManager()->getId(), getIpAddr()
        ]);
    }

    /**
     * Returns the identity from storage or null if no identity is available
     *
     * Note: Only for type hinting
     *
     * @return UserIdentityInterface|SuIdentityInterface|null
     */
    public function getIdentity()
    {
        return parent::getIdentity();
    }

    /**
     * Become another user or switch back to previous user during a login session.
     *
     * @param int|null $userId Unique identifier of user to become, NULL to switch back to previous user
     * @return void
     */
    public function su(int $userId = NULL): void
    {
        if (!$this->hasIdentity()) {
            // Guest users cannot become another user
            View::showBadRequestErrorPage();
        }

        $identity = $this->getIdentity();

        if (NULL != $userId && $identity->getUserId() == $userId) {
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
                if ($identity->getSuUserType() == 'admin') {
                    if ($identity->getUserType() == 'reseller') { // Administrator logged-in as 'reseller'
                        if (NULL !== $userId) { // and that want become a 'user' of that 'reseller'
                            $newIdentity = new SuIdentity($identity, $this->getIdentityFromDb($userId));
                        } else { // and that wants become himself
                            $newIdentity = $identity->getSuIdentity();
                        }
                    } elseif ($identity->getUserType() == 'user') { // Administrator logged-in as 'user'
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
            }/**/
        } elseif (NULL === $userId || $identity->getUserType() == 'user') {
            // Unsupported use case: A non SU identity cannot become back to himself and an 'user' identity cannot become another user
            View::showBadRequestErrorPage();
        } else { // Administrator or Reseller that wants become another user
            $newIdentity = new SuIdentity($identity, $this->getIdentityFromDb($userId));

            if ($identity->getUserType() == 'reseller' && $newIdentity->getUserCreatedBy() != $identity->getUserId()) {
                // A reseller cannot become an user that have not been created by himself
                View::showBadRequestErrorPage();
            }
        }

        $this->setIdentity($newIdentity);
        //$this->>redirectToUserUi()
    }

    /**
     * Get an identity from the database
     *
     * @param int $identityId Identity unique identifier
     * @return UserIdentityInterface
     */
    protected function getIdentityFromDb(int $identityId): UserIdentityInterface
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

    /**
     * Set the identity
     *
     * @param UserIdentityInterface $identity
     */
    public function setIdentity(UserIdentityInterface $identity)
    {
        /**
         * Prevent multiple successive calls from storing inconsistent results
         * Ensure storage has clean state
         */
        if ($this->hasIdentity()) {
            $this->clearIdentity();
        }

        $this->getStorage()->write($identity);
    }

    /**
     * Redirect to user UI, that is, the interface of the logged-in user, out of any SU identity consideration
     *
     * Redirect the current logged-in user onto his interface, out of any SU
     * identity consideration. If no identity is found, redirect to login page.
     *
     * @return void
     */
    public function redirectToUserUi(): void
    {
        $authService = Application::getInstance()->getAuthService();
        if (!$authService->hasIdentity()) {
            View::showBadRequestErrorPage();
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
                View::showBadRequestErrorPage();
                exit;
        }

        redirectTo('/' . $userType . '/index.php');
    }
}
