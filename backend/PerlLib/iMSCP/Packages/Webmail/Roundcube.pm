=head1 NAME

 iMSCP::Packages::Webmail::Roundcube - i-MSCP Roundcube package

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

package iMSCP::Packages::Webmail::Roundcube;

use strict;
use warnings;
use autouse 'Fcntl' => qw/ S_IMODE S_ISLNK S_IXUSR /;
use autouse 'File::Find' => qw/ find /;
use autouse 'iMSCP::Crypt' => qw/ randomStr ALNUM /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use autouse 'iMSCP::TemplateParser' => qw/ getBlocByRef processByRef replaceBlocByRef /;
use Class::Autouse qw/
    :nostat iMSCP::Composer iMSCP::Config iMSCP::Dir iMSCP::File iMSCP::Getopt iMSCP::Packages::Setup::FrontEnd iMSCP::Servers::Sqld;
/;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use version;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

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
        'ROUNDCUBE_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' )
    );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'ROUNDCUBE_SQL_PASSWORD', ( ( iMSCP::Getopt->preseed ) ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'} )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all', 'forced' ] ) || !isValidUsername( $dbUser ) ||
        !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
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
        } while $rs < 30 && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
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
                    $dbPass = randomStr( 16, ALNUM );
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

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::Packages::Setup::FrontEnd->getInstance()->getComposer()->requirePackage( 'imscp/roundcube', '~1.0.0' );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_backupConfigFile( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail/config/config.inc.php" );
    $self->_installFiles();
    $self->_mergeConfig();
    $self->_buildRoundcubeConfig();
    $self->_setupDatabase();
    $self->_buildHttpdConfig();
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

=item setFrontendPermissions( )

 See iMSCP::Packages::Abstract::setFrontendPermissions()

=cut

sub setFrontendPermissions
{
    return unless -d "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail";

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
        "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail"
    );
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Roundcube';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'Roundcube Webmail (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $::imscpConfig{'Version'};
}

=item deleteMail( \%moduleData )

 Process deleteMail tasks

 Param hashref \%moduleData Data as provided by the Mail module
 Return void, die on failure 

=cut

sub deleteMail
{
    my ( $self, $moduleData ) = @_;

    return unless $moduleData->{'MAIL_TYPE'} =~ /_mail/;

    my $oldDbName = $self->{'dbh'}->useDatabase( $::imscpConfig{'DATABASE_NAME'} . '_roundcube' );
    $self->{'dbh'}->do( 'DELETE FROM users WHERE username = ?', undef, $moduleData->{'MAIL_ADDR'} );
    $self->{'dbh'}->useDatabase( $oldDbName ) if length $oldDbName;
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

 Return iMSCP::Packages::Webmail::Roundcube::Roundcube

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/roundcube";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";

    if ( -f "$self->{'cfgDir'}/roundcube.data" ) {
        tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", readonly => TRUE;
    } else {
        $self->{'config'} = {};
        $self->{'skip_uninstall'} = TRUE;
    }

    $self->SUPER::_init();
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
    my $destDir = "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail";

    iMSCP::Dir->new( dirname => $destDir )->clear( qr/^logs$/, 'inverseMatching' ) if -d $destDir;
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/config" )->copy( $self->{'cfgDir'} );
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( $destDir );

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    for my $dir ( 'cron.d', 'logrotate.d' ) {
        next unless -f "$packageDir/iMSCP/$dir/imscp_roundcube";

        my $fileContentRef = iMSCP::File->new( filename => "$packageDir/iMSCP/$dir/imscp_roundcube" )->getAsRef();

        processByRef(
            {
                GUI_PUBLIC_DIR => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public",
                PANEL_USER     => $usergroup,
                PANEL_GROUP    => $usergroup
            },
            $fileContentRef
        );

        iMSCP::File->new( filename => "/etc/$dir/imscp_roundcube" )->set( ${ $fileContentRef } )->save();
    }

    # Set permissions -- Needed at this stage to make scripts from the bin/
    # directory executable
    $self->setFrontendPermissions();
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
        tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", nodeferring => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $self->{'config'}->{$key};
            $self->{'config'}->{$key} = $value;
        }

        return;
    }

    tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", nodeferring => TRUE;
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
        TMP_PATH          => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/tmp",
        DES_KEY           => randomStr( 24, ALNUM )
    };

    my $file = iMSCP::File->new( filename => "$self->{'cfgDir'}/config.inc.php" );
    my $cfgTpl = $file->getAsRef( TRUE );

    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'roundcube', 'config.inc.php', $cfgTpl, $data );
    $file->getAsRef() unless length ${ $cfgTpl };

    processByRef( $data, $cfgTpl );

    $file->{'filename'} = "$self->{'wrkDir'}/config.inc.php";
    $file
        ->save()
        ->owner( $usergroup, $usergroup )
        ->mode( 0640 )
        ->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail/config/config.inc.php", { preserve => TRUE } );
}

=item _setupDatabase( )

 Setup database

 Return void, die on failure 

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $rcDir = "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail";
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
        next unless length $sqlUser;

        for my $host ( $dbUserHost, $oldDbUserHost ) {
            next if !length $host || ( exists $::sqlUsers{$sqlUser . '@' . $host} && !defined $::sqlUsers{$sqlUser . '@' . $host} );
            $sqlServer->dropUser( $sqlUser, $host );
        }
    }

    # Create SQL user if required
    if ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
    }

    # Give required privileges on Roundcube database to SQL user
    # According https://dev.mysql.com/doc/refman/5.7/en/grant.html,
    # we can grant privileges on databases that doesn't exist yet.
    my $quotedRcDbName = $self->{'dbh'}->quote_identifier( $rcDbName );
    $self->{'dbh'}->do( "GRANT ALL PRIVILEGES ON @{ [ $quotedRcDbName =~ s/([%_])/\\$1/gr ] }.* TO ?\@?", undef, $dbUser, $dbUserHost );

    # Give required privileges on the imscp.mail table
    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    $self->{'dbh'}->do(
        "GRANT SELECT (mail_addr, mail_pass), UPDATE (mail_pass) ON @{ [ $self->{'dbh'}->quote_identifier( $imscpDbName ) ] }.mail_users TO ?\@?",
        undef, $dbUser, $dbUserHost
    );

    # Create/Update Roundcube database

    if ( !$self->{'dbh'}->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $rcDbName )
        || !$self->{'dbh'}->selectrow_hashref( "SHOW TABLES FROM $quotedRcDbName" )
    ) {
        $self->{'dbh'}->do( "CREATE DATABASE IF NOT EXISTS $quotedRcDbName CHARACTER SET utf8 COLLATE utf8_unicode_ci" );

        # Create Roundcube database
        my $rs = execute( [ "$rcDir/bin/initdb.sh", '--dir', "$rcDir/SQL", '--package', 'roundcube' ], \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        $rs == 0 or die( $stderr || 'Unknown error' );
    } else {
        # Update Roundcube database
        my $rs = execute( [ "$rcDir/bin/updatedb.sh", '--dir', "$rcDir/SQL", '--package', 'roundcube' ], \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        $rs == 0 or die( $stderr || 'Unknown error' );

        # Ensure tha users.mail_host entries are set with expected hostname (default to 'localhost')
        my $hostname = 'localhost';
        $self->{'eventManager'}->trigger( 'beforeUpdateRoundCubeMailHostEntries', \$hostname );

        my $oldDbName = $self->{'dbh'}->useDatabase( $rcDbName );
        $self->{'dbh'}->do( 'UPDATE IGNORE users SET mail_host = ?', undef, $hostname );
        $self->{'dbh'}->do( 'DELETE FROM users WHERE mail_host <> ?', undef, $hostname );
        $self->{'dbh'}->useDatabase( $oldDbName ) if length $oldDbName;
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

    my $frontEnd = iMSCP::Packages::Setup::FrontEnd->getInstance();
    $frontEnd->buildConfFile(
        "$self->{'cfgDir'}/nginx/imscp_roundcube.conf",
        { GUI_PUBLIC_DIR => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public" },
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

=item _removeSqlUser( )

 Remove SQL user

 Return void, die on failure 

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    my $sqlServer = iMSCP::Servers::Sqld->factory();
    return unless $self->{'config'}->{'DATABASE_USER'};

    for my $host ( $::imscpConfig{'DATABASE_USER_HOST'}, $::imscpConfig{'BASE_SERVER_IP'}, 'localhost', '127.0.0.1', '%' ) {
        next unless length $host;
        $sqlServer->dropUser( $self->{'config'}->{'DATABASE_USER'}, $host );
    }
}

=item _removeSqlDatabase( )

 Remove database

 Return void, die on failure 

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    $self->{'dbh'}->do( 'DROP DATABASE IF EXISTS ' . $self->{'dbh'}->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_roundcube' ));
}

=item _unregisterConfig( )

 Remove include directive from frontEnd vhost files

 Return void, die on failure 

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    my $frontend = iMSCP::Packages::Setup::FrontEnd->getInstance();

    return unless -f "$frontend->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "my $frontend->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    $fileContentRef =~ s/[\t ]*include imscp_roundcube.conf;\n//;
    $file->save();

    $frontend->{'reload'} ||= TRUE;
}

=item _removeFiles( )

 Remove files

 Return void, die on failure 

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    my $frontend = iMSCP::Packages::Setup::FrontEnd->getInstance();

    iMSCP::File->new( filename => "$frontend->{'config'}->{'HTTPD_CONF_DIR'}/imscp_roundcube.conf" )->remove();
    iMSCP::File->new( filename => "/etc/$_/imscp_roundcube" )->remove() for 'cron.d', 'logrotate.d';
    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/webmail" )->remove();
    iMSCP::Dir->new( dirname => $self->{'cfgDir'} )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
