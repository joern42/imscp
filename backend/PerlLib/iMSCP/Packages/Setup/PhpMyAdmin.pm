=head1 NAME

 iMSCP::Packages::Setup::PhpMyAdmin - i-MSCP PhpMyAdmin package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Packages::Setup::PhpMyAdmin;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ decryptRijndaelCBC randomStr ALNUM /;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Packages::Setup::FrontEnd;
use iMSCP::Servers::Sqld;
use iMSCP::Template::Processor qw/ processBlocByRef processVarsByRef /;
use JSON;
use version;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 PhpMyAdmin package for i-MSCP.

 PhpMyAdmin allows administering of MySQL with a web interface.

 It allows administrators to:
 * browse through databases and tables;
 * create, copy, rename, alter and drop databases;
 * create, copy, rename, alter and drop tables;
 * perform table maintenance;
 * add, edit and drop fields;
 * execute any SQL-statement, even multiple queries;
 * create, alter and drop indexes;
 * load text files into tables;
 * create and read dumps of tables or databases;
 * export data to SQL, CSV, XML, Word, Excel, PDF and LaTeX formats;
 * administer multiple servers;
 * manage MySQL users and privileges;
 * check server settings and runtime information with configuration hints;
 * check referential integrity in MyISAM tables;
 * create complex queries using Query-by-example (QBE), automatically connecting required tables;
 * create PDF graphics of database layout;
 * search globally in a database or a subset of it;
 * transform stored data into any format using a set of predefined functions, such as displaying BLOB-data as image or download-link;
 * manage InnoDB tables and foreign keys;
 and is fully internationalized and localized in dozens of languages.

 Project homepage: http://www.phpmyadmin.net/

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( \%eventManager )

 See iMSCP::Packages::Abstract::registerSetupListeners()

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->showDialog( @_ ) }; } );
}

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion(
        'PHPMYADMIN_SQL_USER', ( $self->{'config'}->{'DATABASE_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' ) )
    );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'PHPMYADMIN_SQL_PASSWORD', ( iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'} )
    );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqlmanager', 'all', 'forced' ] )
        || !isValidUsername( $dbUser ) || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
        || !isAvailableSqlUser( $dbUser )
    ) {
        my $rs = 0;

        do {
            unless ( length $dbUser ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $dbUser = 'imscp_srv_user';
            }

            ( $rs, $dbUser ) = $dialog->inputbox( <<"EOF", $dbUser );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the PhpMyAdmin SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'PHPMYADMIN_SQL_USER', $dbUser );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqlmanager', 'all', 'forced' ] ) || !isValidPassword( $dbPass ) ) {
        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            my $rs = 0;

            do {
                unless ( length $dbPass ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $dbPass = randomStr( 16, ALNUM );
                }

                ( $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the PhpMyAdmin SQL user (leave empty for autogeneration):
\\Z \\Zn
EOF
            } while $rs < 30 && !isValidPassword( $dbPass );

            return $rs if $rs >= 30;

            $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    ::setupSetQuestion( 'PHPMYADMIN_SQL_PASSWORD', $dbPass );
    0;
}

=item preinstall( )

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/phpmyadmin', '0.4.7.*@dev' );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_backupConfigFile( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/$self->{'config'}->{'PHPMYADMIN_CONF_DIR'}/config.inc.php" );
    $self->_installFiles();
    $self->_setupDatabase();
    $self->_setupSqlUser();
    $self->_generateBlowfishSecret();
    $self->_buildConfig();
    $self->_buildHttpdConfig();
    $self->_setVersion();
    $self->_cleanup();
}

=item uninstall( )

 See iMSCP::Packages::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    return if $self->{'skip_uninstall'} || !%{ $self->{'config'} };

    $self->_removeSqlUser();
    $self->_removeSqlDatabase();
    $self->_unregisterConfig();
    $self->_removeFiles();
}

=item getPackagePriority( )

 See iMSCP::Packages::Abstract::getPackagePriority()

=cut

sub getPackagePriority
{
    0;
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'AWStats';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'AWStats (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $::imscpConfig{'Version'};
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Setup::PhpMyAdmin

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontend'} = iMSCP::Packages::Setup::FrontEnd->getInstance();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/pma";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/phpmyadmin.data.dist";

    eval {
        tie %{ $self->{'config'} },
            'iMSCP::Config',
            filename    => "$self->{'cfgDir'}/phpmyadmin.data",
            readonly    => iMSCP::Getopt->context() ne 'installer',
            nodeferring => iMSCP::Getopt->context() eq 'installer';
    };
    if ( $@ ) {
        die unless iMSCP::Getopt->context() eq 'uninstaller';
        $self->{'skip_uninstall'} = TRUE;
    }

    $self->SUPER::_init();
}

=item _mergeConfig

 Merge distribution configuration with production configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/phpmyadmin.data" ) {
        tie my %newConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/phpmyadmin.data.dist";
        tie my %oldConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/phpmyadmin.data", readonly => 1;

        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/phpmyadmin.data.dist" )->move( "$self->{'cfgDir'}/phpmyadmin.data" );
}

=item _backupConfigFile( )

 Backup the given configuration file

 Return void, die on failure

=cut

sub _backupConfigFile
{
    my ( $self, $cfgFile ) = @_;

    return unless -f $cfgFile && -d $self->{'bkpDir'};

    iMSCP::File->new( filename => $cfgFile )->copy( $self->{'bkpDir'} . '/' . fileparse( $cfgFile ) . '.' . time );
}

=item _installFiles( )

 Install files in production directory

 Return void, die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/phpmyadmin";

    -d $packageDir or die( "Couldn't find the imscp/phpmyadmin package into the packages cache directory" );

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/pma" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir" )->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/pma" );
}

=item _setupSqlUser( )

 Setup restricted SQL user

 Return void, die on failure

=cut

sub _setupSqlUser
{
    my ( $self ) = @_;

    my $phpmyadminDbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_pma';
    my $dbUser = ::setupGetQuestion( 'PHPMYADMIN_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'PHPMYADMIN_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $sqlServer = iMSCP::Servers::Sqld->factory();

    # Drop old SQL user if required
    for my $sqlUser ( $dbOldUser, $dbUser ) {
        next unless length $sqlUser;

        for my $host ( $dbUserHost, $oldDbUserHost ) {
            next if !$host || exists $::sqlUsers{$sqlUser . '@' . $host} && !defined $::sqlUsers{$sqlUser . '@' . $host};
            $sqlServer->dropUser( $sqlUser, $host );
        }
    }

    # Create SQL user if required
    if ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
    }

    # Give required privileges to this SQL user

    $self->{'dbh'}->do( 'GRANT USAGE ON mysql.* TO ?@?', undef, $dbUser, $dbUserHost );
    $self->{'dbh'}->do( 'GRANT SELECT ON mysql.db TO ?@?', undef, $dbUser, $dbUserHost );
    $self->{'dbh'}->do(
        '
            GRANT SELECT (Host, User, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv,
                Reload_priv, Shutdown_priv, Process_priv, File_priv, Grant_priv, References_priv, Index_priv,
                Alter_priv, Show_db_priv, Super_priv, Create_tmp_table_priv, Lock_tables_priv, Execute_priv,
                Repl_slave_priv, Repl_client_priv)
            ON mysql.user
            TO ?@?
        ',
        undef, $dbUser, $dbUserHost
    );

    # Check for mysql.host table existence (as for MySQL >= 5.6.7, the mysql.host table is no longer provided)
    if ( $self->{'dbh'}->selectrow_hashref( "SHOW tables FROM mysql LIKE 'host'" ) ) {
        $self->{'dbh'}->do( 'GRANT SELECT ON mysql.user TO ?@?', undef, $dbUser, $dbUserHost );
        $self->{'dbh'}->do(
            'GRANT SELECT (Host, Db, User, Table_name, Table_priv, Column_priv) ON mysql.tables_priv TO?@?', undef, $dbUser, $dbUserHost
        );
    }

    ( my $quotedDbName = $self->{'dbh'}->quote_identifier( $phpmyadminDbName ) ) =~ s/([%_])/\\$1/g;
    $self->{'dbh'}->do( "GRANT ALL PRIVILEGES ON $quotedDbName.* TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
}

=item _setupDatabase( )

 Setup database

 Return void, die on failure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $phpmyadminDir = "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/pma";
    my $phpmyadminDbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_pma';

    # Drop previous database
    # FIXME: Find a better way to handle upgrade
    $self->{'dbh'}->do( "DROP DATABASE IF EXISTS " . $self->{'dbh'}->quote_identifier( $phpmyadminDbName ));

    # Create database

    my $schemaFilePath = "$phpmyadminDir/sql/create_tables.sql";

    my $file = iMSCP::File->new( filename => $schemaFilePath );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/^(-- Database :) `phpmyadmin`/$1 `$phpmyadminDbName`/im;
    ${ $fileContentRef } =~ s/^(CREATE DATABASE IF NOT EXISTS) `phpmyadmin`/$1 `$phpmyadminDbName`/im;
    ${ $fileContentRef } =~ s/^(USE) phpmyadmin;/$1 `$phpmyadminDbName`;/im;
    $file->save();

    my $mysqlConffile = File::Temp->new();
    print $mysqlConffile <<"EOF";
[mysql]
host = @{[ ::setupGetQuestion( 'DATABASE_HOST' ) ]}
port = @{[ ::setupGetQuestion( 'DATABASE_PORT' ) ]}
user = "@{ [ ::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr ] }"
password = "@{ [ decryptRijndaelCBC($::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr ] }"
EOF
    $mysqlConffile->close();

    my $rs = execute( "mysql --defaults-extra-file=$mysqlConffile < $schemaFilePath", \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' ) if $rs;
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return void, die on failure

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    $self->{'frontend'}->buildConfFile(
        "$::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Setup/PhpMyAdmin/config/nginx/imscp_pma.nginx",
        { FRONTEND_ROOT_DIR => $::imscpConfig{'FRONTEND_ROOT_DIR'} },
        { destination => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pma.conf" }
    );
}

=item _setVersion( )

 Set version

 Return void, die on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $json = JSON->new()->utf8()->decode(
        iMSCP::File->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/pma/composer.json" )->get()
    );
    debug( sprintf( 'Set new phpMyAdmin version to %s', $json->{'version'} ));
    $self->{'config'}->{'PHPMYADMIN_VERSION'} = $json->{'version'};
}

=item _generateBlowfishSecret( )

 Generate blowfish secret

 Return void, die on failure

=cut

sub _generateBlowfishSecret
{
    $_[0]->{'config'}->{'BLOWFISH_SECRET'} = randomStr( 32, ALNUM );
}

=item _buildConfig( )

 Build configuration file

 Return void, die on failure

=cut

sub _buildConfig
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my $confDir = "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/$self->{'config'}->{'PHPMYADMIN_CONF_DIR'}";
    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_pma';
    ( my $dbUser = ::setupGetQuestion( 'PHPMYADMIN_SQL_USER' ) ) =~ s%('|\\)%\\$1%g;
    my $dbHost = ::setupGetQuestion( 'DATABASE_HOST' );
    my $dbPort = ::setupGetQuestion( 'DATABASE_PORT' );
    ( my $dbPass = ::setupGetQuestion( 'PHPMYADMIN_SQL_PASSWORD' ) ) =~ s%('|\\)%\\$1%g;
    ( my $blowfishSecret = $self->{'config'}->{'BLOWFISH_SECRET'} ) =~ s%('|\\)%\\$1%g;

    my $data = {
        PMA_DATABASE => $dbName,
        PMA_USER     => $dbUser,
        PMA_PASS     => $dbPass,
        HOSTNAME     => $dbHost,
        PORT         => $dbPort,
        UPLOADS_DIR  => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/uploads",
        TMP_DIR      => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/tmp",
        BLOWFISH     => $blowfishSecret
    };

    my $file = iMSCP::File->new( filename => "$confDir/imscp.config.inc.php" );
    my $cfgTpl = $file->getAsRef( TRUE );

    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'phpmyadmin', 'imscp.config.inc.php', $cfgTpl, $data );
    $file->getAsRef() unless length ${ $cfgTpl };

    processVarsByRef( $cfgTpl, $data );

    $file->{'filename'} = "$self->{'wrkDir'}/config.inc.php";
    $file->save()->owner( $usergroup, $usergroup )->mode( 0640 )->copy( "$confDir/config.inc.php", { preserve => 1 } );
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'cfgDir'}/phpmyadmin.old.data" )->remove();
}

=item _removeSqlUser( )

 Remove SQL user

 Return void, die on failure

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    return unless $self->{'config'}->{'DATABASE_USER'} && $::imscpConfig{'DATABASE_USER_HOST'};
    iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'DATABASE_USER'}, $::imscpConfig{'DATABASE_USER_HOST'} );
}

=item _removeSqlDatabase( )

 Remove database

 Return void, die on failure

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    $self->{'dbh'}->do( "DROP DATABASE IF EXISTS " . $self->{'dbh'}->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_pma' ));
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return void, die on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/(^[\t ]+)?\Qinclude imscp_pma.conf;\E\n//m;
    $file->save();

    $self->{'frontend'}->{'reload'} ||= TRUE;
}

=item _removeFiles( )

 Remove files

 Return void, die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pma.conf" )->remove();
    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/pma" )->remove();
    iMSCP::Dir->new( dirname => $self->{'cfgDir'} )->remove();
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterFrontEndBuildConfFile( \$tplContent, $filename )

 Include httpd configuration into frontEnd vhost files

 Param string \$tplContent Reference to template file content
 Param string $tplName Template name
 Return void, die on failure

=cut

sub afterFrontEndBuildConfFile
{
    my ( $tplContent, $tplName ) = @_;

    return unless ( $tplName eq '00_master.nginx' && ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) ne 'https://' )
        || $tplName eq '00_master_ssl.nginx';

    processBlocByRef( $tplContent, '# SECTION custom BEGIN.', '# SECTION custom ENDING.', <<"EOF", TRUE );
    include imscp_pma.conf;
EOF
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
