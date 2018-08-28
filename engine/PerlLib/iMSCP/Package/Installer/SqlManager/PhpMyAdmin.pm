=head1 NAME

 iMSCP::Package::Installer::SqlManager::PhpMyAdmin - i-MSCP PhpMyAdmin package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package iMSCP::Package::Installer::SqlManager::PhpMyAdmin;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ ALNUM randomStr /;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isValidUsername isStringNotInList isValidPassword isAvailableSqlUser /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Rights qw/ setRights /;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use JSON;
use Installer::FrontEnd;
use Servers::sqld;
use version;
use parent 'iMSCP::Package::Abstract';

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

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, sub { $self->_askForPhpMyAdminCredentials( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = iMSCP::Composer->getInstance()->registerPackage( 'imscp/phpmyadmin', '0.4.7.*@dev' );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_backupConfigFile( "$::imscpConfig{'GUI_PUBLIC_DIR'}/$self->{'config'}->{'PHPMYADMIN_CONF_DIR'}/config.inc.php" );
    $rs ||= $self->_installFiles();
    $rs ||= $self->_setupDatabase();
    $rs ||= $self->_setupSqlUser();
    $rs ||= $self->_generateBlowfishSecret();
    $rs ||= $self->_buildConfig();
    $rs ||= $self->_buildHttpdConfig();
    $rs ||= $self->_setVersion();
    $rs ||= $self->_cleanup();
}

=item uninstall( )

 See iMSCP::AbstractUninstallerActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    return 0 if $self->{'skip_uninstall'} || !%{ $self->{'config'} };

    my $rs = $self->_removeSqlUser();
    $rs ||= $self->_removeSqlDatabase();
    $rs ||= $self->_unregisterConfig();
    $rs ||= $self->_removeFiles();
}

=item setGuiPermissions( )

 See iMSCP::AbstractInstallerActions::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpMyAdminSetGuiPermissions' );
    return $rs if $rs || !-d "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma";

    debug( "Setting permissions (event listener)" );
    my $panelUName = my $panelGName = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    $rs ||= setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma", {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpMyAdminSetGuiPermissions' );
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterFrontEndBuildConfFile( \$tplContent, $filename )

 Include httpd configuration into frontEnd vhost files

 Param string \$tplContent Template file tplContent
 Param string $tplName Template name
 Return int 0 on success, other on failure

=cut

sub afterFrontEndBuildConfFile
{
    my ( $tplContent, $tplName ) = @_;

    return 0 unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . "    include imscp_pma.conf;\n"
            . "    # SECTION custom END.\n",
        $tplContent
    );
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Package::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/pma";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";

    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/phpmyadmin.data.dist";
    eval {
        tie %{ $self->{'config'} },
            'iMSCP::Config',
            fileName    => "$self->{'cfgDir'}/phpmyadmin.data",
            readonly    => iMSCP::Getopt->context() ne 'installer',
            nodeferring => iMSCP::Getopt->context() eq 'installer';
    };
    if ( $@ ) {
        die unless iMSCP::Getopt->context() eq 'uninstaller';
        $self->{'skip_uninstall'} = TRUE;
    }

    $self;
}

=item _mergeConfig

 Merge distribution configuration with production configuration

 Die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/phpmyadmin.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/phpmyadmin.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/phpmyadmin.data", readonly => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/phpmyadmin.data.dist" )->moveFile( "$self->{'cfgDir'}/phpmyadmin.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item _askForPhpMyAdminCredentials( $dialog )

 Ask for PhpMyAdmin credentials

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForPhpMyAdminCredentials
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'PHPMYADMIN_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || 'imscp_srv_user' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'PHPMYADMIN_SQL_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'}
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqlmanager', 'all' ] ) || !isValidUsername( $dbUser )
        || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' ) || !isValidPassword( $dbPass )
        || !isAvailableSqlUser( $dbUser )
    ) {
        Q1:
        do {
            ( my $rs, $dbUser ) = $dialog->inputbox( <<"EOF", $dbUser );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the PhpMyAdmin SQL user:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidUsername( $dbUser ) || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser );

        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            $iMSCP::Dialog::InputValidation::lastValidationError = '';

            do {
                ( my $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass || randomStr( 16, ALNUM ));
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the PhpMyAdmin SQL user:
\\Z \\Zn
EOF
                goto Q1 if $rs == 30;
                return $rs if $rs == 50;
            } while !isValidPassword( $dbPass );

            $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    ::setupSetQuestion( 'PHPMYADMIN_SQL_USER', $dbUser );
    ::setupSetQuestion( 'PHPMYADMIN_SQL_PASSWORD', $dbPass );
    0;
}

=item _backupConfigFile( )

 Backup the given configuration file

 Return int 0

=cut

sub _backupConfigFile
{
    my ( $self, $cfgFile ) = @_;

    return 0 unless -f $cfgFile && -d $self->{'bkpDir'};
    iMSCP::File->new( filename => $cfgFile )->copyFile( $self->{'bkpDir'} . '/' . fileparse( $cfgFile ) . '.' . time, { preserve => 'no' } );
}

=item _installFiles( )

 Install files in production directory

 Return int 0 on success, other or die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/phpmyadmin";

    unless ( -d $packageDir ) {
        error( "Couldn't find the imscp/phpmyadmin package into the packages cache directory" );
        return 1;
    }

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir" )->rcopy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma", { preserve => 'no' } );

}

=item _setupSqlUser( )

 Setup restricted SQL user

 Return int 0 on success, other or die on failure

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
    my $sqlServer = Servers::sqld->factory();

    # Drop old SQL user if required
    for my $sqlUser ( $dbOldUser, $dbUser ) {
        next unless $sqlUser;
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

    my $rdbh = $self->{'dbh'};
    $rdbh->{'RaiseError'} = TRUE;

    # Give required privileges to this SQL user

    $rdbh->do( 'GRANT USAGE ON mysql.* TO ?@?', undef, $dbUser, $dbUserHost );
    $rdbh->do( 'GRANT SELECT ON mysql.db TO ?@?', undef, $dbUser, $dbUserHost );
    $rdbh->do(
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
    if ( $rdbh->selectrow_hashref( "SHOW tables FROM mysql LIKE 'host'" ) ) {
        $rdbh->do( 'GRANT SELECT ON mysql.user TO ?@?', undef, $dbUser, $dbUserHost );
        $rdbh->do( 'GRANT SELECT (Host, Db, User, Table_name, Table_priv, Column_priv) ON mysql.tables_priv TO?@?', undef, $dbUser, $dbUserHost );
    }

    ( my $quotedDbName = $rdbh->quote_identifier( $phpmyadminDbName ) ) =~ s/([%_])/\\$1/g;
    $rdbh->do( "GRANT ALL PRIVILEGES ON $quotedDbName.* TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
    0;
}

=item _setupDatabase( )

 Setup database

 Return int 0 on success, other or die on failure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $phpmyadminDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma";
    my $phpmyadminDbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_pma';

    {
        my $rdbh = $self->{'dbh'};
        local $rdbh->{'RaiseError'} = TRUE;
        # Drop previous database
        # FIXME: Find a better way to handle upgrade
        $rdbh->do( "DROP DATABASE IF EXISTS " . $rdbh->quote_identifier( $phpmyadminDbName ));
    }

    # Create database

    my $schemaFilePath = "$phpmyadminDir/sql/create_tables.sql";

    my $file = iMSCP::File->new( filename => $schemaFilePath );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/^(-- Database :) `phpmyadmin`/$1 `$phpmyadminDbName`/im;
    ${ $fileC } =~ s/^(CREATE DATABASE IF NOT EXISTS) `phpmyadmin`/$1 `$phpmyadminDbName`/im;
    ${ $fileC } =~ s/^(USE) phpmyadmin;/$1 `$phpmyadminDbName`;/im;

    my $rs = $file->save();
    return $rs if $rs;

    $rs = execute( "cat $schemaFilePath | mysql", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return int 0 on success, other on failure

=cut

sub _buildHttpdConfig
{
    my $frontEnd = iMSCP::Package::Installer::FrontEnd->getInstance();
    $frontEnd->buildConfFile(
        "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Installer/SqlManager/PhpMyAdmin/imscp_pma.nginx",
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
        { destination => "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pma.conf" }
    );
}

=item _setVersion( )

 Set version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $json = iMSCP::File->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma/composer.json" )->get();
    return 1 unless defined $json;

    $json = decode_json( $json );
    debug( sprintf( 'Set new phpMyAdmin version to %s', $json->{'version'} ));
    $self->{'config'}->{'PHPMYADMIN_VERSION'} = $json->{'version'};
    0;
}

=item _generateBlowfishSecret( )

 Generate blowfish secret

 Return int 0

=cut

sub _generateBlowfishSecret
{
    $_[0]->{'config'}->{'BLOWFISH_SECRET'} = randomStr( 32, ALNUM );
    0;
}

=item _buildConfig( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConfig
{
    my ( $self ) = @_;

    my $panelUName = my $panelGName = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my $confDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/$self->{'config'}->{'PHPMYADMIN_CONF_DIR'}";
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
        UPLOADS_DIR  => "$::imscpConfig{'GUI_ROOT_DIR'}/data/uploads",
        TMP_DIR      => "$::imscpConfig{'GUI_ROOT_DIR'}/data/tmp",
        BLOWFISH     => $blowfishSecret
    };

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'phpmyadmin', 'imscp.config.inc.php', \my $cfgTpl, $data );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $cfgTpl = iMSCP::File->new( filename => "$confDir/imscp.config.inc.php" )->get();
        return 1 unless defined $cfgTpl;
    }

    processByRef( $data, \$cfgTpl );

    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/config.inc.php" );
    $file->set( $cfgTpl );
    $rs = $file->save();
    $rs ||= $file->owner( $panelUName, $panelGName );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$confDir/config.inc.php" );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpMyAdminCleanup' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/phpmyadmin.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/phpmyadmin.old.data" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterPhpMyAdminCleanup' );
}

=item _removeSqlUser( )

 Remove SQL user

 Return int 0

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    return 0 unless $self->{'config'}->{'DATABASE_USER'} && $::imscpConfig{'DATABASE_USER_HOST'};
    Servers::sqld->factory()->dropUser( $self->{'config'}->{'DATABASE_USER'}, $::imscpConfig{'DATABASE_USER_HOST'} );
}

=item _removeSqlDatabase( )

 Remove database

 Return int 0, die on failure

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( "DROP DATABASE IF EXISTS " . $rdbh->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_pma' ));
    0;
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return int 0 on success, other on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    my $frontend = iMSCP::Package::Installer::FrontEnd->getInstance();

    return 0 unless -f "$frontend->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "$frontend->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/[\t ]*include imscp_pma.conf;\n//;

    my $rs = $file->save();
    return $rs if $rs;

    $frontend->{'reload'} = TRUE;
    0;
}

=item _removeFiles( )

 Remove files

 Return int 0, die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/pma" )->remove();

    my $frontend = iMSCP::Package::Installer::FrontEnd->getInstance();

    if ( -f "$frontend->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pma.conf" ) {
        my $rs = iMSCP::File->new( filename => "$frontend->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pma.conf" )->delFile();
        return $rs if $rs;
    }

    iMSCP::Dir->new( dirname => $self->{'cfgDir'} )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
