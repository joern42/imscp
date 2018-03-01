=head1 NAME

 iMSCP::Packages::Webmail::Roundcube::Installer - i-MSCP Roundcube package installer

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

package iMSCP::Packages::Webmail::Roundcube::Installer;

use strict;
use warnings;
use File::Basename;
use Fcntl qw/ S_IMODE S_ISLNK S_IXUSR /;
use File::Find qw/ find /;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ randomStr /;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Rights;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use JSON;
use iMSCP::Packages::FrontEnd;
use iMSCP::Servers::Sqld;
use version;
use parent 'iMSCP::Common::Singleton';

our $VERSION = '~1.0.0';

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 This is the installer for the i-MSCP Roundcube package.

 See iMSCP::Packages::Webmail::Roundcube::Roundcube for more information.

=head1 PUBLIC METHODS

=over 4

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion(
        'ROUNDCUBE_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' )
    );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'ROUNDCUBE_SQL_PASSWORD',
        ( ( iMSCP::Getopt->preseed ) ? randomStr( 16, iMSCP::Crypt::ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'} )
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
Please enter a username for the Roundcube SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'ROUNDCUBE_SQL_USER', $dbUser );

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
Please enter a password for the Roundcube SQL user (leave empty for autogeneration):
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

    ::setupSetQuestion( 'ROUNDCUBE_SQL_PASSWORD', $dbPass );
    0;
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure 

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/roundcube', $VERSION );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 Process install tasks

 Return void, die on failure 

=cut

sub install
{
    my ( $self ) = @_;

    $self->_backupConfigFile( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail/config/config.inc.php" );
    $self->_installFiles();
    $self->_mergeConfig();
    $self->_buildRoundcubeConfig();
    $self->_setupDatabase();
    $self->_buildHttpdConfig();
    $self->_cleanup();
}

=item setGuiPermissions( )

 Set gui permissions

 Return void, die on failure 

=cut

sub setGuiPermissions
{
    return unless -d "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";

    # Set executable bit on *.sh scripts
    local $SIG{'__WARN__'} = sub { die @_ };

    find(
        {
            wanted   => sub {
                return unless substr( $_, -3 ) eq '.sh';

                my ( @st ) = lstat( $_ ) or die( sprintf( "Failed to stat '%s': %s", $_, $! ));
                return if S_ISLNK( $st[2] );

                chmod( S_IMODE( $st[2] | S_IXUSR ), $_ ) or die( sprintf( "Failed to set executable bit on '%s': %s", $_, $! ));
            },
            no_chdir => 1
        },
        "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail"
    );
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

    replaceBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", <<"EOF", $tplContent );
    # SECTION custom BEGIN.
@{ [ getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent ) ] } 
    include imscp_roundcube.conf;
    # SECTION custom END.
EOF
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Webmail::Roundcube::Installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'roundcube'} = iMSCP::Packages::Webmail::Roundcube::Roundcube->getInstance();
    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self->{'cfgDir'} = $self->{'roundcube'}->{'cfgDir'};
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->{'config'} = $self->{'roundcube'}->{'config'};
    $self;
}

=item _backupConfigFile( $cfgFile )

 Backup the given configuration file

 Param string $cfgFile Path of file to backup
 Return void, die on failure 

=cut

sub _backupConfigFile
{
    my ( $self, $cfgFile ) = @_;

    return unless -f $cfgFile && -d $self->{'bkpDir'};

    iMSCP::File->new( filename => $cfgFile )->copy( $self->{'bkpDir'} . '/' . fileparse( $cfgFile ) . '.' . time );
}

=item _installFiles( )

 Install files

 Return void, die on failure 

=cut

sub _installFiles
{
    my ( $self ) = @_;

    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/roundcube";
    -d $packageDir or die( "Couldn't find the imscp/roundcube package into the packages cache directory" );
    my $destDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";

    iMSCP::Dir->new( dirname => $destDir )->clear( qr/^logs$/, 'inverseMatching' ) if -d $destDir;
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/config" )->copy( $self->{'cfgDir'} );
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( $destDir );

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    for my $dir ( 'cron.d', 'logrotate.d' ) {
        next unless -f "$packageDir/iMSCP/$dir/imscp_roundcube";

        my $fileContentRef = iMSCP::File->new( filename => "$packageDir/iMSCP/$dir/imscp_roundcube" )->getAsRef();

        processByRef(
            {
                GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'},
                PANEL_USER     => $usergroup,
                PANEL_GROUP    => $usergroup
            },
            $fileContentRef
        );

        iMSCP::File->new( filename => "/etc/$dir/imscp_roundcube" )->set( ${ $fileContentRef } )->save();
    }

    # Set permissions -- Needed at this stage to make scripts from the bin/
    # directory executable
    $self->setGuiPermissions();
}

=item _mergeConfig( )

 Merge old config if any

 Return void, die on failure 

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( %{ $self->{'config'} } ) {
        my %oldConfig = %{ $self->{'config'} };
        tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", nodeferring => 1;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $self->{'config'}->{$key};
            $self->{'config'}->{$key} = $value;
        }

        return;
    }

    tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", nodeferring => 1;
}

=item _buildRoundcubeConfig( )

 Build roundcube configuration file

 Return void, die on failure 

=cut

sub _buildRoundcubeConfig
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
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
        DES_KEY           => randomStr( 24, iMSCP::Crypt::ALNUM )
    };

    my $file = iMSCP::File->new( filename => "$self->{'cfgDir'}/config.inc.php" )->get();
    my $cfgTpl = $file->getAsRef( TRUE );

    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'roundcube', 'config.inc.php', $cfgTpl, $data );
    $file->getAsRef() unless length ${ $cfgTpl };

    processByRef( $data, $cfgTpl );

    $file->{'filename'} = "$self->{'wrkDir'}/config.inc.php";
    $file
        ->save()
        ->owner( $usergroup, $usergroup )
        ->mode( 0640 )
        ->copy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail/config/config.inc.php", { preserve => 1 } );
}

=item _setupDatabase( )

 Setup database

 Return void, die on failure 

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $rcDir = "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/webmail";
    my $imscpDbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $rcDbName = $imscpDbName . '_roundcube';
    my $dbUser = ::setupGetQuestion( 'ROUNDCUBE_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'ROUNDCUBE_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $sqlServer = iMSCP::Servers::Sqld->factory();

    # Drop old SQL user if needed
    for my $sqlUser ( $dbOldUser, $dbUser ) {
        next unless $sqlUser;

        for my $host ( $dbUserHost, $oldDbUserHost ) {
            next if !$host || ( exists $::sqlUsers{$sqlUser . '@' . $host} && !defined $::sqlUsers{$sqlUser . '@' . $host} );
            $sqlServer->dropUser( $sqlUser, $host );
        }
    }

    # Create SQL user if required
    if ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
    }

    my $db = iMSCP::Database->getInstance();

    # Give required privileges on Roundcube database to SQL user
    # According https://dev.mysql.com/doc/refman/5.7/en/grant.html,
    # we can grant privileges on databases that doesn't exist yet.
    my $quotedRcDbName = $db->quote_identifier( $rcDbName );
    $db->do( "GRANT ALL PRIVILEGES ON @{ [ $quotedRcDbName =~ s/([%_])/\\$1/gr ] }.* TO ?\@?", undef, $dbUser, $dbUserHost );

    # Give required privileges on the imscp.mail table
    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    $db->do(
        "GRANT SELECT (mail_addr, mail_pass), UPDATE (mail_pass) ON @{ [ $db->quote_identifier( $imscpDbName ) ] }.mail_users TO ?\@?",
        undef, $dbUser, $dbUserHost
    );

    # Create/Update Roundcube database

    if ( !$db->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $rcDbName )
        || !$db->selectrow_hashref( "SHOW TABLES FROM $quotedRcDbName" )
    ) {
        $db->do( "CREATE DATABASE IF NOT EXISTS $quotedRcDbName CHARACTER SET utf8 COLLATE utf8_unicode_ci" );

        # Create Roundcube database
        my $rs = execute( [ "$rcDir/bin/initdb.sh", '--dir', "$rcDir/SQL", '--package', 'roundcube' ], \my $stdout, \my $stderr );
        debug( $stdout ) if $stdout;
        !$rs or die( $stderr || 'Unknown error' );
    } else {
        # Update Roundcube database
        my $rs = execute( [ "$rcDir/bin/updatedb.sh", '--dir', "$rcDir/SQL", '--package', 'roundcube' ], \my $stdout, \my $stderr );
        debug( $stdout ) if $stdout;
        !$rs or die( $stderr || 'Unknown error' );

        # Ensure tha users.mail_host entries are set with expected hostname (default to 'localhost')
        my $hostname = 'localhost';
        $self->{'eventManager'}->trigger( 'beforeUpdateRoundCubeMailHostEntries', \$hostname );

        my $oldDbName = $db->useDatabase( $rcDbName );
        $db->do( 'UPDATE IGNORE users SET mail_host = ?', undef, $hostname );
        $db->do( 'DELETE FROM users WHERE mail_host <> ?', undef, $hostname );
        $db->useDatabase( $oldDbName ) if $oldDbName;
    }

    $self->{'config'}->{'DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return void, die on failure 

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'wrkDir'}/imscp_roundcube.conf" ) {
        iMSCP::File->new( filename => "$self->{'wrkDir'}/imscp_roundcube.conf" )->copy( "$self->{'bkpDir'}/imscp_roundcube.conf." . time );
    }

    my $frontEnd = iMSCP::Packages::FrontEnd->getInstance();
    $frontEnd->buildConfFile(
        "$self->{'cfgDir'}/nginx/imscp_roundcube.conf",
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
        { destination => "$self->{'wrkDir'}/imscp_roundcube.conf" }
    );

    iMSCP::File->new( filename => "$self->{'wrkDir'}/imscp_roundcube.conf" )->copy(
        "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_roundcube.conf"
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure 

=cut

sub _cleanup
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'cfgDir'}/roundcube.old.data" )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
