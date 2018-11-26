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

namespace iMSCP\FacFactory;

use iMSCP\Crypt;
use Interop\Container\ContainerInterface;
use Zend\ServiceManager\Factory\FactoryInterface;

/**
 * Class PDOFactory
 * @package iMSCP\Frontend\Common\Factory
 */
class PDOFactory implements FactoryInterface
{
    /**
     * @inheritdoc
     */
    public function __invoke(ContainerInterface $container, $requestedName, array $options = NULL)
    {
        $config = $container->get('config')['imscp'];
        $host = $config['DATABASE_HOST'];
        $port = $config['DATABASE_PORT'];
        $dbName = $config['DATABASE_NAME'];
        $keyFile = $config['CONF_DIR'] . '/imscp-db-keys.php';
        $imscpKEY = $imscpIV = '';

        if (!(@include_once $keyFile) || empty($imscpKEY) || empty($imscpIV)) {
            throw new \InvalidArgumentException(sprintf(
                'Missing or invalid key file. Delete the %s key file if any and run the imscp-reconfigure script.', $keyFile
            ));
        }

        $pdo = new \PDO(
            "mysql:host=$host;port=$port;dbname=$dbName;charset=utf8mb4",
            $config['DATABASE_USER'],
            Crypt::decryptRijndaelCBC($imscpKEY, $imscpIV, $config['DATABASE_PASSWORD'])
            /*
            ,
            [
                \PDO::MYSQL_ATTR_INIT_COMMAND => "SET @@session.sql_mode = 'NO_AUTO_CREATE_USER', @@session.group_concat_max_len = 4294967295"
            ]
            */
        );

        return $pdo;
    }
}
