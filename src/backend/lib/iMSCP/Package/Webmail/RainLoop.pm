=head1 NAME

 iMSCP::Package::Webmail::RainLoop - i-MSCP RainLoop package

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

package iMSCP::Package::Webmail::RainLoop;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ ALNUM randomStr /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::InputValidation qw/ isOneOfStringsInList isValidUsername isStringNotInList isValidPassword isAvailableSqlUser /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Package::Installer::FrontEnd;
use iMSCP::Rights 'setRights';
use iMSCP::Server::sqld;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use JSON;
use parent 'iMSCP::Package::Abstract';

our $VERSION = '0.2.0.*@dev';

my $dbInitialized = FALSE;

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 i-MSCP RainLoop package.

 RainLoop Webmail is a simple, modern and fast Web-based email client.

 Project homepage: http://http://rainloop.net/

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, sub { $self->_askForSqlUser( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = iMSCP::Composer->getInstance()->registerPackage( 'imscp/rainloop', $VERSION );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 iMSCP::Installer::AbstractActions:install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_installFiles();
    $rs ||= $self->_mergeConfig();
    $rs ||= $self->_setupDatabase();
    $rs ||= $self->_buildConfig();
    $rs ||= $self->_buildHttpdConfig();
    $rs ||= $self->_setVersion();
    $rs ||= $self->_removeOldVersionFiles();
    $rs ||= $self->_cleanup();
}

=item uninstall( )

 iMSCP::Uninstaller::AbstractActions::uninstall()

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

 iMSCP::Installer::AbstractActions::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    return 0 unless -d "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop";

    my $panelUserGroup = $::imscpConfig{'USER_PREFIX'} . $::imscpConfig{'USER_MIN_UID'};

    my $rs = setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/data", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item deleteMail( \%data )

 See iMSCP::Installer::AbstractActions::deleteMail()

=cut

sub deleteMail
{
    my ( $self, $data ) = @_;

    return 0 unless $data->{'MAIL_TYPE'} =~ /_mail/;

    {
        my $rdbh = $self->{'dbh'}->getRawDb();
        $rdbh->{'RaiseError'} = TRUE;

        unless ( $dbInitialized ) {
            my $quotedDbName = $rdbh->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_rainloop' );
            my $row = $rdbh->selectrow_hashref( "SHOW TABLES FROM $quotedDbName" );
            $dbInitialized = TRUE if $row;
        }

        if ( $dbInitialized ) {
            my $oldDbName = $self->{'dbh'}->useDatabase( $::imscpConfig{'DATABASE_NAME'} . '_rainloop' );
            $rdbh->do(
                '
                    DELETE u, c, p
                    FROM rainloop_users u
                    LEFT JOIN rainloop_ab_contacts c USING(id_user)
                    LEFT JOIN rainloop_ab_properties p USING(id_user)
                    WHERE rl_email = ?
                ',
                undef, $data->{'MAIL_ADDR'}
            );
            $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
        }
    }

    my $storageDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/data/_data_/_default_/storage";
    ( my $email = $data->{'MAIL_ADDR'} ) =~ s/[^a-z0-9\-\.@]+/_/;
    ( my $storagePath = substr( $email, 0, 2 ) ) =~ s/\@$//;

    for my $storageType ( qw/ cfg data files / ) {
        iMSCP::Dir->new( dirname => "$storageDir/$storageType/$storagePath/$email" )->remove();
        next unless -d "$storageDir/$storageType/$storagePath";
        my $dir = iMSCP::Dir->new( dirname => "$storageDir/$storageType/$storagePath" );
        next unless $dir->isEmpty();
        $dir->remove();
    }

    0;
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

    return 0 unless grep ( $_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx' );

    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . "    include imscp_rainloop.conf;\n"
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
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/packages/RainLoop";

    if ( -f "$self->{'cfgDir'}/rainloop.data" ) {
        tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rainloop.data", readonly => TRUE;
    } else {
        $self->{'config'} = {};
        $self->{'skip_uninstall'} = TRUE;
    }

    $self;
}

=item _askForSqlUser( $dialog )

 Ask for Rainloop SQL user

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlUser
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'RAINLOOP_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || 'imscp_srv_user' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'RAINLOOP_SQL_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'}
    );
    $iMSCP::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all' ] ) || !isValidUsername( $dbUser )
        || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' ) || !isValidPassword( $dbPass )
        || !isAvailableSqlUser( $dbUser )
    ) {
        Q1:
        do {
            ( my $rs, $dbUser ) = $dialog->string( <<"EOF", $dbUser );
$iMSCP::InputValidation::lastValidationError
Please enter a username for the RainLoop SQL user:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidUsername( $dbUser ) || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser );

        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            do {
                ( my $rs, $dbPass ) = $dialog->string( <<"EOF", $dbPass || randomStr( 16, ALNUM ));
$iMSCP::InputValidation::lastValidationError
Please enter a password for the RainLoop SQL user:
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

    ::setupSetQuestion( 'RAINLOOP_SQL_USER', $dbUser );
    ::setupSetQuestion( 'RAINLOOP_SQL_PASSWORD', $dbPass );
    0;
}

=item _installFiles( )

 Install files

 Return int 0 on success, other on failure

=cut

sub _installFiles
{
    my ( $self ) = @_;

    my $srcDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/rainloop";

    unless ( -d $srcDir ) {
        error( "Couldn't find the imscp/rainloop package in the packages cache directory" );
        return 1;
    }

    my $destDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop";

    # Remove unwanted file to avoid hash naming convention for data directory
    if ( -f "$destDir/data/DATA.php" ) {
        my $rs = iMSCP::File->new( filename => "$destDir/data/DATA.php" )->delFile();
        return $rs if $rs;
    }

    # Handle upgrade from old rainloop data structure
    if ( -d "$destDir/data/_data_11c052c218cd2a2febbfb268624efdc1" ) {
        iMSCP::Dir->new( dirname => "$destDir/data/_data_11c052c218cd2a2febbfb268624efdc1" )->move( "$destDir/data/_data_" );
    }

    # Install new files
    iMSCP::Dir->new( dirname => "$srcDir/src" )->copy( $destDir );
    iMSCP::Dir->new( dirname => "$srcDir/iMSCP/src" )->copy( $destDir );
    iMSCP::Dir->new( dirname => "$srcDir/iMSCP/config" )->copy( $self->{'cfgDir'} );
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
        tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rainloop.data", nodeferring => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $self->{'config'}->{$key};
            $self->{'config'}->{$key} = $value;
        }

        return 0;
    }

    tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rainloop.data", nodeferring => TRUE;
    0;
}

=item _setupDatabase( )

 Setup database

 Return int 0 on success, other on failure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $imscpDbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $rainLoopDbName = $imscpDbName . '_rainloop';
    my $dbUser = ::setupGetQuestion( 'RAINLOOP_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'RAINLOOP_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $rdbh = $self->{'dbh'};
    $rdbh->{'RaiseError'} = TRUE;

    my $quotedDbName = $rdbh->quote_identifier( $rainLoopDbName );

    $rdbh->do( "CREATE DATABASE IF NOT EXISTS $quotedDbName CHARACTER SET utf8 COLLATE utf8_unicode_ci" );

    my $sqlServer = iMSCP::Server::sqld->factory();

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

    $quotedDbName =~ s/([%_])/\\$1/g;
    $rdbh->do( "GRANT ALL PRIVILEGES ON $quotedDbName.* TO ?\@?", undef, $dbUser, $dbUserHost );

    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    $quotedDbName = $rdbh->quote_identifier( $imscpDbName );
    $rdbh->do( "GRANT SELECT (mail_addr, mail_pass), UPDATE (mail_pass) ON $quotedDbName.mail_users TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
    0;
}

=item _buildConfig( )

 Build RainLoop configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConfig
{
    my ( $self ) = @_;

    my $confDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/data/_data_/_default_/configs";

    for my $confFile ( 'application.ini', 'plugin-imscp-change-password.ini' ) {
        my $data = {
            DATABASE_NAME     => $confFile eq 'application.ini'
                ? ::setupGetQuestion( 'DATABASE_NAME' ) . '_rainloop' : ::setupGetQuestion( 'DATABASE_NAME' ),
            DATABASE_HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
            DATATABASE_PORT   => ::setupGetQuestion( 'DATABASE_PORT' ),
            DATABASE_USER     => ::setupGetQuestion( 'RAINLOOP_SQL_USER' ),
            DATABASE_PASSWORD => ::setupGetQuestion( 'RAINLOOP_SQL_PASSWORD' ),
            CA_BUNDLE         => ::setupGetQuestion( 'CA_BUNDLE' ),
            CA_PATH           => ::setupGetQuestion( 'CA_PATH' )
        };

        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'rainloop', $confFile, \my $cfgTpl, $data );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $cfgTpl = iMSCP::File->new( filename => "$confDir/$confFile" )->get();
            return 1 unless defined $cfgTpl;
        }

        processByRef( $data, \$cfgTpl );

        my $panelUserGroup = $::imscpConfig{'USER_PREFIX'} . $::imscpConfig{'USER_MIN_UID'};
        my $file = iMSCP::File->new( filename => "$confDir/$confFile" );
        $file->set( $cfgTpl );
        $rs = $file->save();
        $rs ||= $file->owner( $panelUserGroup, $panelUserGroup );
        $rs ||= $file->mode( 0640 );
        return $rs if $rs;
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

    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/rainloop";
    my $json = iMSCP::File->new( filename => "$packageDir/composer.json" )->get();
    return 1 unless defined $json;

    $json = decode_json( $json );
    debug( sprintf( 'Set new rainloop version to %s', $json->{'version'} ));
    $self->{'config'}->{'RAINLOOP_VERSION'} = $json->{'version'};
    0;
}

=item _setVersion( )

 Remove old version files if any

 Return int 0 on success, other on failure

=cut

sub _removeOldVersionFiles
{
    my ( $self ) = @_;

    while ( my $dentry = <$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/rainloop/v/*> ) {
        next unless -d $dentry || basename( $dentry ) eq $self->{'config'}->{'RAINLOOP_VERSION'};
        iMSCP::Dir->new( dirname => $dentry )->remove();
    }

    0;
}

=item _buildHttpdConfig( )

 Build Httpd configuration

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    $self->{'frontend'}->buildConfFile(
        "$self->{'cfgDir'}/nginx/imscp_rainloop.conf",
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
        { destination => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_rainloop.conf" }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeRainloopCleanup' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/rainloop.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/rainloop.old.data" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterRainloopCleanup' );
}

=item _removeSqlUser( )

 Remove SQL user

 Return int 0 on success, other on failure

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    return 0 if $self->{'config'}->{'DATABASE_USER'} eq '';

    my $sqlServer = iMSCP::Server::sqld->factory();
    for my $host ( $::imscpConfig{'DATABASE_USER_HOST'}, $::imscpConfig{'BASE_SERVER_IP'}, 'localhost', '127.0.0.1', '%' ) {
        next if $host eq '';
        $sqlServer->dropUser( $self->{'config'}->{'DATABASE_USER'}, $host );
    }

    0;
}

=item _removeSqlDatabase( )

 Remove database

 Return int 0, die on failure

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    my $rdbh = $self->{'dbh'}->getRawDb();
    $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( 'DROP DATABASE IF EXISTS ' . $rdbh->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_rainloop' ));
    0;
}

=item _unregisterConfig

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

    ${ $fileC } =~ s/[\t ]*include imscp_rainloop.conf;\n//;

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

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop" )->remove();

    if ( -f "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_rainloop.conf" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_rainloop.conf" )->delFile();
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
