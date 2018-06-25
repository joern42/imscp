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

use Doctrine\DBAL\Migrations\Configuration\Configuration;
use Doctrine\DBAL\Migrations\Tools\Console as DoctrineMigrationsConsole;
use Doctrine\DBAL\Tools\Console as DoctrinDBALConsole;
use Doctrine\ORM\Tools\Console as DoctrineORMConsole;
use Symfony\Component\Console\Helper\HelperSet;

chdir(dirname(__DIR__));

// Bootstrap i-MSCP application
require_once 'library/include/application.php';

$DBALConnection = Application::getInstance()->getEntityManager()->getConnection();
$ORMEntityManager = Application::getInstance()->getEntityManager();

// Migration config
$doctrineMigrationsConfiguration = new Configuration($DBALConnection);
$doctrineMigrationsConfiguration->setMigrationsTableName('imscp_migration');
$doctrineMigrationsConfiguration->setMigrationsDirectory('data/db_migrations');
$doctrineMigrationsConfiguration->setMigrationsNamespace('iMSCP\\Database\\Migration');

// Create and run console application
$cli = new \Symfony\Component\Console\Application(
    'i-MSCP management tool', '1.0.0-DEV'
);
$cli->setCatchExceptions(true);
$cli->setHelperSet(new HelperSet([
    'db'            => new DoctrinDBALConsole\Helper\ConnectionHelper($DBALConnection),
    'em'            => new DoctrineORMConsole\Helper\EntityManagerHelper($ORMEntityManager),
    'question'      => new \Symfony\Component\Console\Helper\QuestionHelper(),
    'configuration' => new DoctrineMigrationsConsole\Helper\ConfigurationHelper($DBALConnection, $doctrineMigrationsConfiguration)
]));
$cli->addCommands(
    [
        // Doctrine DBAL Commands
        new DoctrinDBALConsole\Command\ImportCommand(),
        new DoctrinDBALConsole\Command\ReservedWordsCommand(),
        new DoctrinDBALConsole\Command\RunSqlCommand(),

        // Doctrine ORM Commands
        new DoctrineORMConsole\Command\ClearCache\CollectionRegionCommand(),
        new DoctrineORMConsole\Command\ClearCache\EntityRegionCommand(),
        new DoctrineORMConsole\Command\ClearCache\MetadataCommand(),
        new DoctrineORMConsole\Command\ClearCache\QueryCommand(),
        new DoctrineORMConsole\Command\ClearCache\QueryRegionCommand(),
        new DoctrineORMConsole\Command\ClearCache\ResultCommand(),
        new DoctrineORMConsole\Command\SchemaTool\CreateCommand(),
        new DoctrineORMConsole\Command\SchemaTool\UpdateCommand(),
        new DoctrineORMConsole\Command\SchemaTool\DropCommand(),
        new DoctrineORMConsole\Command\EnsureProductionSettingsCommand(),
        new DoctrineORMConsole\Command\ConvertDoctrine1SchemaCommand(),
        new DoctrineORMConsole\Command\GenerateRepositoriesCommand(),
        new DoctrineORMConsole\Command\GenerateEntitiesCommand(),
        new DoctrineORMConsole\Command\GenerateProxiesCommand(),
        new DoctrineORMConsole\Command\ConvertMappingCommand(),
        new DoctrineORMConsole\Command\RunDqlCommand(),
        new DoctrineORMConsole\Command\ValidateSchemaCommand(),
        new DoctrineORMConsole\Command\InfoCommand(),
        new DoctrineORMConsole\Command\MappingDescribeCommand(),

        // Doctrine Migrations commands
        new DoctrineMigrationsConsole\Command\DiffCommand(),
        new DoctrineMigrationsConsole\Command\ExecuteCommand(),
        new DoctrineMigrationsConsole\Command\GenerateCommand(),
        new DoctrineMigrationsConsole\Command\LatestCommand(),
        new DoctrineMigrationsConsole\Command\MigrateCommand(),
        new DoctrineMigrationsConsole\Command\StatusCommand(),
        new DoctrineMigrationsConsole\Command\UpToDateCommand(),
        new DoctrineMigrationsConsole\Command\VersionCommand(),
    ]
);
$cli->run();
