=head1 NAME

 iMSCP::Package::Webmail::Roundcube - i-MSCP Roundcube package

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

package iMSCP::Package::Webmail::Roundcube;

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

 Roundcube package for i-MSCP.

 RoundCube Webmail is a browser-based multilingual IMAP client with an
 application-like user interface. It provides full functionality expected from
 an email client, including MIME support, address book, folder manipulation and
 message filters.

 The user interface is fully skinnable using XHTML and CSS 2.

 Project homepage: http://www.roundcube.net/

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, sub { $self->_askForSqlUser( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = iMSCP::Composer->getInstance()->registerPackage( 'imscp/roundcube', '1.2.x' );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_backupConfigFile( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail/config/config.inc.php" );
    $rs ||= $self->_installFiles();
    $rs ||= $self->_mergeConfig();
    $rs ||= $self->_setupDatabase();
    $rs ||= $self->_buildRoundcubeConfig();
    $rs ||= $self->_updateDatabase() unless $self->{'newInstall'};
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

    return 0 unless -d "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";

    my $panelUserGroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    my $rs = setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail/logs", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item deleteMail( \%data )

 See iMSCP::AbstractInstallerActions::deleteMail()

=cut

sub deleteMail
{
    my ( $self, $data ) = @_;

    return 0 unless $data->{'MAIL_TYPE'} =~ /_mail/;

    my $oldDbName = $self->{'dbh'}->useDatabase( $::imscpConfig{'DATABASE_NAME'} . '_roundcube' );
    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( 'DELETE FROM users WHERE username = ?', undef, $data->{'MAIL_ADDR'} );
    $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
    0
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

    return 0 unless grep ( $tplName eq $_, '00_master.nginx', '00_master_ssl.nginx' );

    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . "    include imscp_roundcube.conf;\n"
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
    $self->{'frontend'} = iMSCP::Package::Installer::FrontEnd->getInstance();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/roundcube";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";

    if ( -f "$self->{'cfgDir'}/roundcube.data" ) {
        tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/roundcube.data", readonly => TRUE;
    } else {
        $self->{'config'} = {};
        $self->{'skip_uninstall'} = TRUE;
    }

    $self;
}

=item _askForSqlUser( $dialog )

 Ask for Roundcube SQL user

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlUser
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'ROUNDCUBE_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || 'imscp_srv_user' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'ROUNDCUBE_SQL_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'}
    );
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all' ] ) || !isValidUsername( $dbUser )
        || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' ) || !isValidPassword( $dbPass )
        || !isAvailableSqlUser( $dbUser )
    ) {
        Q1:
        do {
            ( my $rs, $dbUser ) = $dialog->inputbox( <<"EOF", $dbUser );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the RoundCube SQL user:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidUsername( $dbUser ) || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser );

        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            do {
                ( my $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass || randomStr( 16, ALNUM ));
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the RoundCube SQL user:
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

    ::setupSetQuestion( 'ROUNDCUBE_SQL_USER', $dbUser );
    ::setupSetQuestion( 'ROUNDCUBE_SQL_PASSWORD', $dbPass );
    0;
}

=item _backupConfigFile( $cfgFile )

 Backup the given configuration file

 Param string $cfgFile Path of file to backup
 Return int 0, other on failure

=cut

sub _backupConfigFile
{
    my ( $self, $cfgFile ) = @_;

    return 0 unless -f $cfgFile && -d $self->{'bkpDir'};

    iMSCP::File->new( filename => $cfgFile )->copyFile( $self->{'bkpDir'} . '/' . fileparse( $cfgFile ) . '.' . time, { preserve => 'no' } );
}

=item _installFiles( )

 Install files

 Return int 0 on success, other or die on failure

=cut

sub _installFiles
{
    my ( $self ) = @_;

    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/roundcube";

    unless ( -d $packageDir ) {
        error( "Couldn't find the imscp/roundcube package into the packages cache directory" );
        return 1;
    }

    my $destDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";

    iMSCP::Dir->new( dirname => $destDir )->remove();
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/config" )->rcopy( $self->{'cfgDir'}, { preserve => 'no' } );
    iMSCP::Dir->new( dirname => "$packageDir/src" )->rcopy( $destDir, { preserve => 'no' } );

}

=item _mergeConfig( )

 Merge old config if any

 Return int 0

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( %{ $self->{'config'} } ) {
        my %oldConfig = %{ $self->{'config'} };
        tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/roundcube.data", nodeferring => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $self->{'config'}->{$key};
            $self->{'config'}->{$key} = $value;
        }

        return 0;
    }

    tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/roundcube.data", nodeferring => TRUE;
    0;
}

=item _setupDatabase( )

 Setup database

 Return int 0 on success, other or die on failure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $roundcubeDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";
    my $imscpDbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $roundcubeDbName = $imscpDbName . '_roundcube';
    my $dbUser = ::setupGetQuestion( 'ROUNDCUBE_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'ROUNDCUBE_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;

    my $quotedDbName = $rdbh->quote_identifier( $roundcubeDbName );

    if ( !$rdbh->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $roundcubeDbName )
        || !$rdbh->selectrow_hashref( "SHOW TABLES FROM $quotedDbName" )
    ) {
        $rdbh->do( "CREATE DATABASE IF NOT EXISTS $quotedDbName CHARACTER SET utf8 COLLATE utf8_unicode_ci" );

        my $oldDbName = $self->{'dbh'}->useDatabase( $roundcubeDbName );
        ::setupImportSqlSchema( $self->{'dbh'}, "$roundcubeDir/SQL/mysql.initial.sql" ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
        );
        $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
    } else {
        $self->{'newInstall'} = FALSE;
    }

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

    # Give required privileges to this SQL user
    $quotedDbName =~ s/([%_])/\\$1/g;
    $rdbh->do( "GRANT ALL PRIVILEGES ON $quotedDbName.* TO ?\@?", undef, $dbUser, $dbUserHost );

    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    $quotedDbName = $rdbh->quote_identifier( $imscpDbName );
    $rdbh->do( "GRANT SELECT (mail_addr, mail_pass), UPDATE (mail_pass) ON $quotedDbName.mail_users TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
    0;
}

=item _buildRoundcubeConfig( )

 Build roundcube configuration file

 Return int 0 on success, other on failure

=cut

sub _buildRoundcubeConfig
{
    my ( $self ) = @_;

    my $panelUName =
        my $panelGName = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_roundcube';
    my $dbHost = ::setupGetQuestion( 'DATABASE_HOST' );
    my $dbPort = ::setupGetQuestion( 'DATABASE_PORT' );
    ( my $dbUser = ::setupGetQuestion( 'ROUNDCUBE_SQL_USER' ) ) =~ s%(')%\\$1%g;
    ( my $dbPass = ::setupGetQuestion( 'ROUNDCUBE_SQL_PASSWORD' ) ) =~ s%(')%\\$1%g;

    my $data = {
        BASE_SERVER_VHOST => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        DB_NAME           => $dbName,
        DB_HOST           => $dbHost,
        DB_PORT           => $dbPort,
        DB_USER           => $dbUser,
        DB_PASS           => $dbPass,
        TMP_PATH          => "$::imscpConfig{'GUI_ROOT_DIR'}/data/tmp",
        DES_KEY           => randomStr( 24, ALNUM )
    };

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'roundcube', 'config.inc.php', \my $cfgTpl, $data );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $cfgTpl = iMSCP::File->new( filename => "$self->{'cfgDir'}/config.inc.php" )->get();
        return 1 unless defined $cfgTpl;
    }

    processByRef( $data, \$cfgTpl );

    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/config.inc.php" );
    $file->set( $cfgTpl );
    $rs = $file->save();
    $rs ||= $file->owner( $panelUName, $panelGName );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail/config/config.inc.php" );
}

=item _updateDatabase( )

 Update database

 Return int 0 on success other or die on failure

=cut

sub _updateDatabase
{
    my ( $self ) = @_;

    my $rCubeDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";
    my $rCubeDbName = ::setupGetQuestion( 'DATABASE_NAME' ) . '_roundcube';
    my $fromVersion = $self->{'config'}->{'ROUNDCUBE_VERSION'} || '0.8.4';

    my $rs = execute( "php $rCubeDir/bin/updatedb.sh --version=$fromVersion --dir=$rCubeDir/SQL --package=roundcube", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    my $rdbh = $self->{'dbh'}->getRawDb();

    local $@;
    eval {
        # Ensure tha users.mail_host entries are set with expected hostname (default to 'localhost')
        my $hostname = 'localhost';
        $self->{'eventManager'}->trigger( 'beforeUpdateRoundCubeMailHostEntries', \$hostname ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
        );

        my $oldDbName = $self->{'dbh'}->useDatabase( $rCubeDbName );

        {
            local $rdbh->{'RaiseError'} = TRUE;
            $rdbh->begin_work();
            $rdbh->do( 'UPDATE IGNORE users SET mail_host = ?', undef, $hostname );
            $rdbh->do( 'DELETE FROM users WHERE mail_host <> ?', undef, $hostname );
            $rdbh->commit();
        }

        $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
    };
    if ( $@ ) {
        $rdbh->rollback();
        die
    }

    0;
}

=item _setVersion( )

 Set version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $repoDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/roundcube";
    my $json = iMSCP::File->new( filename => "$repoDir/composer.json" )->get();
    return 1 unless defined $json;

    $json = decode_json( $json );
    debug( sprintf( 'Set new roundcube version to %s', $json->{'version'} ));
    $self->{'config'}->{'ROUNDCUBE_VERSION'} = $json->{'version'};
    0;
}

=item _buildHttpdConfig( )

 Build Httpd configuration

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'wrkDir'}/imscp_roundcube.conf" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'wrkDir'}/imscp_roundcube.conf" )->copyFile(
            "$self->{'bkpDir'}/imscp_roundcube.conf." . time,, { preserve => 'no' }
        );
        return $rs if $rs;
    }

    my $frontEnd = iMSCP::Package::Installer::FrontEnd->getInstance();
    my $rs = $frontEnd->buildConfFile(
        "$self->{'cfgDir'}/nginx/imscp_roundcube.conf",
        { WEB_DIR => $::imscpConfig{'GUI_ROOT_DIR'} },
        { destination => "$self->{'wrkDir'}/imscp_roundcube.conf" }
    );
    $rs ||= iMSCP::File->new( filename => "$self->{'wrkDir'}/imscp_roundcube.conf" )->copyFile(
        "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_roundcube.conf", { preserve => 'no' }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return 0 unless -f "$self->{'cfgDir'}/roundcube.old.data";

    iMSCP::File->new( filename => "$self->{'cfgDir'}/roundcube.old.data" )->delFile();
}

=item _removeSqlUser( )

 Remove SQL user

 Return int 0 on success, other on failure

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    return 0 if $self->{'config'}->{'DATABASE_USER'} eq '';

    my $sqlServer = Servers::sqld->factory();
    for my $host ( $::imscpConfig{'DATABASE_USER_HOST'}, $::imscpConfig{'BASE_SERVER_IP'}, 'localhost', '127.0.0.1', '%' ) {
        next if $host eq '';
        $sqlServer->dropUser( $self->{'config'}->{'DATABASE_USER'}, $_ );
    }

    0;
}

=item _removeSqlDatabase( )

 Remove database

 Return int 0 on success, die on failure

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    my $rdbh = $self->{'dbh'}->getRawDb();
    $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( 'DROP DATABASE IF EXISTS ' . $rdbh->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_roundcube' ));
    0;
}

=item _unregisterConfig( )

 Remove include directive from frontEnd vhost files

 Return int 0 on success, other on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return 0 unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/[\t ]*include imscp_roundcube.conf;\n//;

    my $rs = $file->save();
    return $rs if $rs;

    $self->{'frontend'}->{'reload'} = TRUE;
    0;
}

=item _removeFiles( )

 Remove files

 Return int 0 on success, other or die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail" )->remove();

    if ( -f "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_roundcube.conf" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_roundcube.conf" )->delFile();
        return $rs if $rs;
    };

    iMSCP::Dir->new( dirname => $self->{'cfgDir'} )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
