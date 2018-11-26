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

namespace iMSCP\Session\SaveHandler;

use iMSCP\Application;
use iMSCP\Model\CpUserLogin;
use iMSCP\Model\UserIdentityInterface;
use Zend\Session\SaveHandler\SaveHandlerInterface;

/**
 * Class SessionHandler
 *
 * This session handler class is meant to override default write(), destroy()
 * and gc() methods as we want be able to track sessions of logged-in users
 * by storing their identifiers in database.
 *
 * @package iMSCP\Session\SaveHandler
 */
class SessionHandler extends \SessionHandler implements SaveHandlerInterface
{
    /**
     * @inheritdoc
     */
    public function write($sessionId, $sessionData)
    {
        $identity = Application::getInstance()->getAuthService()->getIdentity();

        try {
            if ($identity instanceof UserIdentityInterface) {
                $em = Application::getInstance()->getEntityManager();
                $cpUserLogin = $em->find(CpUserLogin::class, $sessionId);

                if (NULL === $cpUserLogin) {
                    // New session
                    $cpUserLogin = new CpUserLogin($sessionId, $identity->getUsername(), getIpAddr());
                } else {
                    // Session last access time
                    $cpUserLogin->setLastAccessTime();
                }

                $em->persist($cpUserLogin);
                $em->flush();
            }
        } catch (\Throwable $e) {
            return false;
        }

        return parent::write($sessionId, $sessionData);
    }

    /**
     * @inheritdoc
     */
    public function destroy($sessionId)
    {
        try {
            $em = Application::getInstance()->getEntityManager();
            /** @var CpUserLogin $cpUserLogin */
            $cpUserLogin = $em->getReference(CpUserLogin::class, $sessionId);

            if (NULL !== $cpUserLogin) {
                $em->remove($cpUserLogin);
                $em->flush();
            }
        } catch (\Throwable $e) {
            return false;
        }

        return parent::destroy($sessionId);
    }

    /**
     * @inheritdoc
     */
    public function gc($maxlifetime)
    {
        try {
            $datetime = new \DateTime();
            $datetime->setTimestamp(time() - $maxlifetime);
            $qb = Application::getInstance()->getEntityManager()->createQueryBuilder();
            $qb
                ->delete(CpUserLogin::class, 'l')
                ->where($qb->expr()->lte('l.lastAccessTime', '?'))
                // We need ignore rows for which 'username' field is empty as this denote
                // data stored by 3rd-party components such as the Bruteforce plugin.
                ->andWhere($qb->expr()->isNotNull(':username'))
                ->setParameter(0, $datetime)
                ->getQuery()
                ->execute();
        } catch (\Throwable $e) {
            return false;
        }

        return parent::gc($maxlifetime);
    }
}
