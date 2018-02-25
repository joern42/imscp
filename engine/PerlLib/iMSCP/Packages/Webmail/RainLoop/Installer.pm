=head1 NAME

 iMSCP::Packages::Webmail::RainLoop::Installer - i-MSCP RainLoop package installer

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

package iMSCP::Packages::Webmail::RainLoop::Installer;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ randomStr /;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dialog::InputValidation qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use JSON;
use iMSCP::Packages::FrontEnd;
use iMSCP::Servers::Sqld;
use parent 'iMSCP::Common::Singleton';

our $VERSION = '0.2.0.*@dev';

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 This is the installer for the i-MSCP RainLoop package.

 See iMSCP::Packages::Webmail::RainLoop::RainLoop for more information.

=head1 PUBLIC METHODS

=over 4

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
    my ($self, $dialog) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'RAINLOOP_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' ));
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'RAINLOOP_SQL_PASSWORD', ( iMSCP::Getopt->preseed ? randomStr( 16, iMSCP::Crypt::ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'} )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all', 'forced' ] )
        || !isValidUsername( $dbUser )
        || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
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
Please enter a username for the RainLoop SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'RAINLOOP_SQL_USER', $dbUser );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all', 'forced' ] ) || !isValidPassword( $dbPass ) ) {
        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            my $rs = 0;
            do {
                unless ( length $dbPass ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $dbPass = randomStr( 16, iMSCP::Crypt::ALNUM );
                }

                ( $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the RainLoop SQL user (leave empty for autogeneration):
\\Z \\Zn
EOF
            } while $rs < 30 && !isValidPassword( $dbPass );

            return $rs unless $rs < 30;

            $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    ::setupSetQuestion( 'RAINLOOP_SQL_PASSWORD', $dbPass );
    0;
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ($self) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/rainloop', $VERSION );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( 

 Process install tasks

 Return void, die on failure

=cut

sub install
{
    my ($self) = @_;

    $self->_installFiles();
    $self->_mergeConfig();
    $self->_setupDatabase();
    $self->_buildConfig();
    $self->_buildHttpdConfig();
    $self->_setVersion();
    $self->_removeOldVersionFiles();
    $self->_cleanup();
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
    my ($tplContent, $tplName) = @_;

    return unless ( $tplName eq '00_master.nginx' && ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) ne 'https://' )
        || $tplName eq '00_master_ssl.nginx';

    replaceBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", <<"EOF", $tplContent );
    # SECTION custom BEGIN.
@{ [ getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent ) ] }
    include imscp_rainloop.conf;
    # SECTION custom END.
EOF
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Webmail::RainLoop::Installer

=cut

sub _init
{
    my ($self) = @_;

    $self->{'rainloop'} = iMSCP::Packages::Webmail::RainLoop::RainLoop->getInstance();
    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self->{'cfgDir'} = $self->{'rainloop'}->{'cfgDir'};
    $self->{'config'} = $self->{'rainloop'}->{'config'};
    $self;
}

=item _installFiles( )

 Install files

 Return void, die on failure

=cut

sub _installFiles
{
    my ($self) = @_;

    my $srcDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/rainloop";
    -d $srcDir or die( "Couldn't find the imscp/rainloop package in the packages cache directory" );
    my $destDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop";

    # Remove unwanted file to avoid hash naming convention for data directory
    iMSCP::File->new( filename => "$destDir/data/DATA.php" )->remove();

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

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ($self) = @_;

    if ( %{$self->{'config'}} ) {
        my %oldConfig = %{$self->{'config'}};

        tie %{$self->{'config'}}, 'iMSCP::Config', filename => "$self->{'cfgDir'}/rainloop.data", nodeferring => 1;

        debug( 'Merging old configuration with new configuration...' );

        while ( my ($key, $value) = each( %oldConfig ) ) {
            next unless exists $self->{'config'}->{$key};
            $self->{'config'}->{$key} = $value;
        }

        return;
    }

    tie %{$self->{'config'}}, 'iMSCP::Config', filename => "$self->{'cfgDir'}/rainloop.data", nodeferring => 1;
}

=item _setupDatabase( )

 Setup database

 Return void, die on failure

=cut

sub _setupDatabase
{
    my ($self) = @_;

    my $imscpDbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $rainLoopDbName = $imscpDbName . '_rainloop';
    my $dbUser = ::setupGetQuestion( 'RAINLOOP_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'RAINLOOP_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $dbh = iMSCP::Database->getInstance();
    my $quotedDbName = $dbh->quote_identifier( $rainLoopDbName );

    $dbh->do( "CREATE DATABASE IF NOT EXISTS $quotedDbName CHARACTER SET utf8 COLLATE utf8_unicode_ci" );

    my $sqlServer = iMSCP::Servers::Sqld->factory();

    # Drop old SQL user if required
    for my $sqlUser ( $dbOldUser, $dbUser ) {
        next unless $sqlUser;

        for my $host( $dbUserHost, $oldDbUserHost ) {
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
    $dbh->do( "GRANT ALL PRIVILEGES ON $quotedDbName.* TO ?\@?", undef, $dbUser, $dbUserHost );

    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    $quotedDbName = $dbh->quote_identifier( $imscpDbName );
    $dbh->do( "GRANT SELECT (mail_addr, mail_pass), UPDATE (mail_pass) ON $quotedDbName.mail_users TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
}

=item _buildConfig( )

 Build RainLoop configuration file

 Return void, die on failure

=cut

sub _buildConfig
{
    my ($self) = @_;

    my $confDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/data/_data_/_default_/configs";
    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    for my $confFile( 'application.ini', 'plugin-imscp-change-password.ini' ) {
        my $data = {
            DATABASE_NAME     => $confFile eq 'application.ini'
                ? ::setupGetQuestion( 'DATABASE_NAME' ) . '_rainloop' : ::setupGetQuestion( 'DATABASE_NAME' ),
            DATABASE_HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
            DATATABASE_PORT   => ::setupGetQuestion( 'DATABASE_PORT' ),
            DATABASE_USER     => ::setupGetQuestion( 'RAINLOOP_SQL_USER' ),
            DATABASE_PASSWORD => ::setupGetQuestion( 'RAINLOOP_SQL_PASSWORD' ),
            DISTRO_CA_BUNDLE  => ::setupGetQuestion( 'DISTRO_CA_BUNDLE' ),
            DISTRO_CA_PATH    => ::setupGetQuestion( 'DISTRO_CA_PATH' )
        };

        my $file = iMSCP::File->new( filename => "$confDir/$confFile" );
        my $cfgTpl = $file->getAsRef( TRUE );

        $self->{'eventManager'}->trigger( 'onLoadTemplate', 'rainloop', $confFile, $cfgTpl, $data );
        $file->getAsRef() unless length ${$cfgTpl};

        processByRef( $data, $cfgTpl );

        $file->save()->owner( $usergroup, $usergroup )->mode( 0640 )
    }

    0;
}

=item _setVersion( )

 Set version

 Return void, die on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    my $json = decode_json( iMSCP::File->new( filename => "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/rainloop/composer.json" )->get());
    debug( sprintf( 'Set new rainloop version to %s', $json->{'version'} ));
    $self->{'config'}->{'RAINLOOP_VERSION'} = $json->{'version'};
}

=item _setVersion( )

 Remove old version files if any

 Return void, die on failure

=cut

sub _removeOldVersionFiles
{
    my ($self) = @_;

    my $versionsDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop/rainloop/v";

    for my $versionDir( iMSCP::Dir->new( dirname => $versionsDir )->getDirs() ) {
        next if $versionDir eq $self->{'config'}->{'RAINLOOP_VERSION'};
        iMSCP::Dir->new( dirname => "$versionsDir/$versionDir" )->remove();
    }
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return void, die on failure

=cut

sub _buildHttpdConfig
{
    my ($self) = @_;

    $self->{'frontend'}->buildConfFile(
        "$self->{'cfgDir'}/nginx/imscp_rainloop.conf",
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
        { destination => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_rainloop.conf" }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'beforeRainloopCleanup' );
    iMSCP::File->new( filename => "$self->{'cfgDir'}/rainloop.old.data" )->remove();
    $self->{'eventManager'}->trigger( 'afterRainloopCleanup' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
