=head1 NAME

 Servers::sqld::mysql::installer - i-MSCP MySQL server installer implementation

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package Servers::sqld::mysql::installer;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Crypt qw/ ALNUM encryptRijndaelCBC decryptRijndaelCBC randomStr /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dialog::InputValidation qw/
    isOneOfStringsInList isNotEmpty isStringInList isStringNotInList isValidUsername isValidPassword isValidHostname isValidIpAddr
    isNumber isValidDbName isNumberInRange
/;
use iMSCP::Dir;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use iMSCP::TemplateParser qw/ processByRef /;
use iMSCP::Umask;
use Net::LibIDN qw/ idn_to_ascii idn_to_unicode /;
use Servers::sqld::mysql;
use version;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP MySQL server installer implementation.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialog )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs },
        sub { $self->_askForMasterSqlUser( @_ ) },
        sub { $self->_askForSqlUserHost( @_ ) },
        sub { $self->_askForSqlDatabaseName( @_ ) },
        sub { $self->_askForSqlPrefixOrSuffix( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = $self->_setTypeAndVersion();
    $rs ||= $self->_buildConf();
    $rs ||= $self->_updateServerConfig();
    $rs ||= $self->_setupMasterSqlUser();
    $rs ||= $self->_setupSecureInstallation();
    $rs ||= $self->_setupDatbase();
    $rs ||= $self->_oldEngineCompatibility();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Servers::sqld::mysql:installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'sqld'} = Servers::sqld::mysql->getInstance();
    $self->{'eventManager'} = $self->{'sqld'}->{'eventManager'};
    $self->{'dbh'} = $self->{'sqld'}->{'dbh'};
    $self->{'cfgDir'} = $self->{'sqld'}->{'cfgDir'};
    $self->{'config'} = $self->{'sqld'}->{'config'};
    $self;
}

=item _askForMasterSqlUser( $dialog )

 Ask for i-MSCP master SQL user

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForMasterSqlUser
{
    my ( $self, $dialog ) = @_;

    my $hostname = ::setupGetQuestion( 'DATABASE_HOST' );
    my $port = ::setupGetQuestion( 'DATABASE_PORT' );
    my $user = ::setupGetQuestion( 'DATABASE_USER', 'imscp_user' );

    if ( lc $user eq 'root' ) {
        # Handle upgrade case
        $user = 'imscp_user';
        ::setupSetQuestion( 'DATABASE_USER', $user );
    }

    my $pwd = ::setupGetQuestion( 'DATABASE_PASSWORD', ( iMSCP::Getopt->preseed ) ? randomStr( 16, ALNUM ) : '' );
    $pwd = decryptRijndaelCBC( $::imscpDBKey, $::imscpDBiv, $pwd ) if length $pwd && !iMSCP::Getopt->preseed;

    my $rs = 0;
    $rs = $self->_askSqlRootUser( $dialog ) if iMSCP::Getopt->preseed;
    return $rs unless $rs < 30;

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'alternatives', 'all' ] ) || !isNotEmpty( $hostname )
        || !isNotEmpty( $port ) || !isNotEmpty( $user )
        || isStringInList( $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' )
        || !isNotEmpty( $pwd ) || ( !iMSCP::Getopt->preseed && $self->_tryDbConnect( $hostname, $port, $user, $pwd ) )
    ) {
        Q1:
        unless ( iMSCP::Getopt->preseed ) {
            my $prs = $rs;
            $rs = $self->_askSqlRootUser( $dialog );
            return 30 if $rs == 20 && $prs == 30;
            return $rs unless $rs < 30;
        }

        Q2:
        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        do {
            ( $rs, $user ) = $dialog->inputbox( <<"EOF", $user );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the master i-MSCP SQL user:
\\Z \\Zn
EOF
            goto Q1 if $rs == 30;
            return $rs if $rs == 50;
        } while !isValidUsername( $user ) || isStringInList( $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' );

        $pwd = isValidPassword( $pwd ) ? $pwd : '';
        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        do {
            ( $rs, $pwd ) = $dialog->inputbox( <<"EOF", $pwd || randomStr( 16, ALNUM ));
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the master i-MSCP SQL user:
\\Z \\Zn
EOF
            goto Q2 if $rs == 30;
            return $rs if $rs == 50;
        } while !isValidPassword( $pwd );
    }

    ::setupSetQuestion( 'DATABASE_USER', $user );
    ::setupSetQuestion( 'DATABASE_PASSWORD', encryptRijndaelCBC( $::imscpDBKey, $::imscpDBiv, $pwd ));
    # Substitute SQL root user data with i-MSCP master user data if needed
    #::setupSetQuestion( 'SQL_ROOT_USER', ::setupGetQuestion( 'SQL_ROOT_USER', $user ));
    #::setupSetQuestion( 'SQL_ROOT_PASSWORD', ::setupGetQuestion( 'SQL_ROOT_PASSWORD', $pwd ));
    0;
}

=item _askForSqlUserHost( $dialog )

 Ask for SQL user host

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlUserHost
{
    my ( $self, $dialog ) = @_;

    if ( $::imscpConfig{'SQLD_PACKAGE'} ne 'Servers::sqld::remote' ) {
        ::setupSetQuestion( 'DATABASE_USER_HOST', 'localhost' );
        return 20;
    }

    my $hostname = ::setupGetQuestion( 'DATABASE_USER_HOST', ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' ));

    if ( grep ( $hostname eq $_, ( 'localhost', '127.0.0.1', '::1' ) ) ) {
        # Handle switch case (default value). Host cannot be one of above value
        # when using remote SQL server 
        $hostname = ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );
    }

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'alternatives', 'all' ] )
        || ( $hostname ne '%' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname ) )
    ) {
        do {
            ( my $rs, $hostname ) = $dialog->inputbox( <<"EOF", idn_to_unicode( $hostname, 'utf-8' ));
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the host from which SQL users created by i-MSCP must be allowed to connect:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while $hostname ne '%' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname );
    }

    ::setupSetQuestion( 'DATABASE_USER_HOST', idn_to_ascii( $hostname, 'utf-8' ));
    0;
}

=item _askForSqlDatabaseName( $dialog )

 Ask for i-MSCP database name

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlDatabaseName
{
    my ( $self, $dialog ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME', 'imscp' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'alternatives', 'all' ] )
        || ( !$self->_setupIsImscpDb( $dbName ) && !iMSCP::Getopt->preseed )
    ) {
        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        do {
            ( my $rs, $dbName ) = $dialog->inputbox( <<"EOF", $dbName );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a database name for i-MSCP:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;

            if ( isValidDbName( $dbName ) ) {
                eval { $self->{'dbh'}->useDatabase( $dbName ); };
                if ( !$@ && !$self->_setupIsImscpDb( $dbName ) ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = <<"EOF";

\\Z1Database '$dbName' exists but doesn't looks like an i-MSCP database.\\Zn
EOF
                }
            }
        } while length $iMSCP::Dialog::InputValidation::lastValidationError;

        my $oldDbName = ::setupGetQuestion( 'DATABASE_NAME' );
        if ( $oldDbName && $dbName ne $oldDbName && $self->setupIsImscpDb( $oldDbName ) ) {
            my $rs = $dialog->yesno( <<"EOF", TRUE );
A database '$::imscpConfig{'DATABASE_NAME'}' for i-MSCP already exists.

Are you sure you want to create a new database for i-MSCP?
Keep in mind that the new database will be free of any reseller and client data.

If the database you want to create already exists, nothing will happen.
EOF
            goto &{ askForSqlDatabaseName } if $rs == 0 || $rs == 30;
            return $rs if $rs == 50;
        }
    }

    ::setupSetQuestion( 'DATABASE_NAME', $dbName );
    0;
}

=item _askForSqlPrefixOrSuffix( $dialog )

 Ask for SQL users and databases prefix or suffix

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlPrefixOrSuffix
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'MYSQL_PREFIX' );
    my %choices = ( 'behind', 'Behind', 'infront', 'Infront', 'none', 'None' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'alternatives', 'all' ] )
        || isStringNotInList( $value, 'behind', 'infront', 'none' )
    ) {
        ( my $rs, $value ) = $dialog->radiolist( <<'EOF', \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'none' );

Do you want to use a prefix or suffix for client SQL users databases?

\Z4Infront :\Zn A prefix such as \Zb1_\ZB will be added before each SQL user and database name.
\Z4Behind  :\Zn A suffix such as \Zb_1\ZB will be added after each SQL user and database name.
\Z4None    :\Zn Choice is left to the client.
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'MYSQL_PREFIX', $value );
    0;
}

=item _askSqlRootUser( )

 Ask for SQL root user

 Return int 0 (NEXT), 20 (SKIP) 30 (BACK), 50 (ESC)

=cut

sub _askSqlRootUser
{
    my ( $self, $dialog ) = @_;

    my $hostname = ::setupGetQuestion( 'DATABASE_HOST', $::imscpConfig{'SQLD_PACKAGE'} eq 'Servers::sqld::remote' ? '' : 'localhost' );

    if ( $::imscpConfig{'SQLD_PACKAGE'} eq 'Servers::sqld::remote' && isStringInList( $hostname, 'localhost', '127.0.0.1', '::1' ) ) {
        # Handle switch case (default value). Host cannot be one of above value
        # when using remote SQL server
        $hostname = '';
    }

    my $port = ::setupGetQuestion( 'DATABASE_PORT', 3306 );
    my $user = ::setupGetQuestion( 'SQL_ROOT_USER', 'root' );
    my $pwd = ::setupGetQuestion( 'SQL_ROOT_PASSWORD' );

    if ( $hostname eq 'localhost' ) {
        # If authentication is made through unix socket, password is normally not required.
        # We try a connect without password with 'root' as user and we return on success
        for ( 'localhost', '127.0.0.1' ) {
            next if $self->_tryDbConnect( $_, $port, $user, $pwd );
            ::setupSetQuestion( 'DATABASE_TYPE', 'mysql' );
            ::setupSetQuestion( 'DATABASE_HOST', $_ );
            ::setupSetQuestion( 'DATABASE_PORT', $port );
            ::setupSetQuestion( 'SQL_ROOT_USER', $user );
            ::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
            return 20;
        }
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    Q1:
    do {
        ( my $rs, $hostname ) = $dialog->inputbox( <<"EOF", $hostname );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL server hostname or IP address:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    } while $hostname ne 'localhost' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    Q2:
    do {
        ( my $rs, $port ) = $dialog->inputbox( <<"EOF", $port );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL server port:
\\Z \\Zn
EOF
        goto Q1 if $rs == 30;
        return $rs if $rs == 50;
    } while !isNumber( $port ) || !isNumberInRange( $port, 1025, 65535 );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    Q3:
    do {
        ( my $rs, $user ) = $dialog->inputbox( <<"EOF", $user );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL root username:

Note that this user must have full privileges on the SQL server.
i-MSCP only uses that user while installation or reconfiguration.
EOF
        goto Q2 if $rs == 30;
        return $rs if $rs == 50;
    } while !isNotEmpty( $user );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    do {
        ( my $rs, $pwd ) = $dialog->passwordbox( <<"EOF" );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL root user password:
EOF
        goto Q3 if $rs == 30;
        return $rs if $rs == 50;
    } while !isNotEmpty( $pwd );

    if ( my $connectError = $self->_tryDbConnect( idn_to_ascii( $hostname, 'utf-8' ), $port, $user, $pwd ) ) {
        chomp( $connectError );

        my $rs = $dialog->msgbox( <<"EOF" );

\\Z1Connection to SQL server failed\\Zn

i-MSCP installer couldn't connect to SQL server using the following data:

\\Z4Host:\\Zn $hostname
\\Z4Port:\\Zn $port
\\Z4Username:\\Zn $user
\\Z4Password:\\Zn $pwd

Error was: \\Z1$connectError\\Zn

Please try again.
EOF
        return $rs if $rs == 50;
        goto Q1;
    }

    ::setupSetQuestion( 'DATABASE_TYPE', 'mysql' );
    ::setupSetQuestion( 'DATABASE_HOST', idn_to_ascii( $hostname, 'utf-8' ));
    ::setupSetQuestion( 'DATABASE_PORT', $port );
    ::setupSetQuestion( 'SQL_ROOT_USER', $user );
    ::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
    0;
}

=item _setTypeAndVersion( )

 Set SQL server type and version

 Return 0 on success, other or die on failure

=cut

sub _setTypeAndVersion
{
    my ( $self ) = @_;

    my $rdbh = $self->{'dbh'}->getRawDb();

    local $rdbh->{'RaiseError'} = TRUE;
    my $row = $rdbh->selectrow_hashref( 'SELECT @@version, @@version_comment' ) or die( "Could't find SQL server type and version" );

    my $type = 'mysql';
    if ( index( lc $row->{'@@version'}, 'mariadb' ) != -1 ) {
        $type = 'mariadb';
    } elsif ( index( lc $row->{'@@version_comment'}, 'percona' ) != -1 ) {
        $type = 'percona';
    }

    my ( $version ) = $row->{'@@version'} =~ /^([0-9]+(?:\.[0-9]+){1,2})/;
    unless ( defined $version ) {
        error( "Couldn't find SQL server version" );
        return 1;
    }

    debug( sprintf( 'SQL server type set to: %s', $type ));
    $self->{'config'}->{'SQLD_TYPE'} = $type;
    debug( sprintf( 'SQL server version set to: %s', $version ));
    $self->{'config'}->{'SQLD_VERSION'} = $version;
    0;
}

=item _buildConf( )

 Build configuration file

 Return int 0 on success, other or die on failure

=cut

sub _buildConf
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeSqldBuildConf' );
    return $rs if $rs;


    # Make sure that the conf.d directory exists
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d" )->make( {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => 0755
    } );

    # Create the /etc/mysql/my.cnf file if missing
    unless ( -f "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" ) {
        $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'mysql', 'my.cnf', \my $cfgTpl, {} );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $cfgTpl = "!includedir $self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/\n";
        } elsif ( $cfgTpl !~ m%^!includedir\s+$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/\n%m ) {
            $cfgTpl .= "!includedir $self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/\n";
        }

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" );
        $file->set( $cfgTpl );

        $rs = $file->save();
        $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;
    }

    $rs ||= $self->{'eventManager'}->trigger( 'onLoadTemplate', 'mysql', 'imscp.cnf', \my $cfgTpl, {} );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $cfgTpl = iMSCP::File->new( filename => "$self->{'cfgDir'}/imscp.cnf" )->get();
        return 1 unless defined $cfgTpl;
    }

    $cfgTpl .= <<'EOF';
[mysqld]
performance_schema = 0
max_connections = 500
max_allowed_packet = 500M
EOF

    ( my $user = ::setupGetQuestion( 'DATABASE_USER' ) ) =~ s/"/\\"/g;
    ( my $pwd = decryptRijndaelCBC( $::imscpDBKey, $::imscpDBiv, ::setupGetQuestion( 'DATABASE_PASSWORD' )) ) =~ s/"/\\"/g;
    my $variables = {
        DATABASE_HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
        DATABASE_PORT     => ::setupGetQuestion( 'DATABASE_PORT' ),
        DATABASE_USER     => $user,
        DATABASE_PASSWORD => $pwd,
        SQLD_SOCK_DIR     => $self->{'config'}->{'SQLD_SOCK_DIR'}
    };

    if ( version->parse( "$self->{'config'}->{'SQLD_VERSION'}" ) >= version->parse( '5.5.0' ) ) {
        my $innoDbUseNativeAIO = $self->_isMysqldInsideCt() ? '0' : '1';
        $cfgTpl .= "innodb_use_native_aio = $innoDbUseNativeAIO\n";
    }

    # Fix For: The 'INFORMATION_SCHEMA.SESSION_VARIABLES' feature is disabled; see the documentation for
    # 'show_compatibility_56' (3167) - Occurs when executing mysqldump with Percona server 5.7.x
    if ( $::imscpConfig{'SQLD_PACKAGE'} eq 'Servers::sqld::percona'
        && version->parse( "$self->{'config'}->{'SQLD_VERSION'}" ) >= version->parse( '5.7.6' )
    ) {
        $cfgTpl .= "show_compatibility_56 = 1\n";
    }

    # For backward compatibility - We will review this in later version
    # TODO Handle mariadb case when ready. See https://mariadb.atlassian.net/browse/MDEV-7597
    if ( version->parse( "$self->{'config'}->{'SQLD_VERSION'}" ) >= version->parse( '5.7.4' )
        && $::imscpConfig{'SQLD_PACKAGE'} ne 'Servers::sqld::mariadb'
    ) {
        $cfgTpl .= "default_password_lifetime = 0\n";
    }

    $cfgTpl .= "event_scheduler = DISABLED\n";
    processByRef( $variables, \$cfgTpl );

    local $UMASK = 027; # imscp.cnf file must not be created world-readable
    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf" );
    $file->set( $cfgTpl );
    $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_GROUP'}, $self->{'config'}->{'SQLD_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $self->{'eventManager'}->trigger( 'afterSqldBuildConf' );
}

=item _updateServerConfig( )

 Update server configuration

  - Upgrade MySQL system tables if necessary
  - Disable unwanted plugins

 Return 0 on success, other or die on failure

=cut

sub _updateServerConfig
{
    my ( $self ) = @_;

    if ( iMSCP::ProgramFinder::find( 'dpkg' ) && iMSCP::ProgramFinder::find( 'mysql_upgrade' ) ) {
        my $rs = execute( "dpkg -l mysql-community* percona-server-* | cut -d' ' -f1 | grep -q 'ii'", \my $stdout, \my $stderr );
        debug( $stdout ) if $stdout;
        debug( $stderr ) if $stderr;

        # Upgrade server system tables
        # See #IP-1482 for further details.
        unless ( $rs ) {
            # Filter all "duplicate column", "duplicate key" and "unknown column"
            # errors as the command is designed to be idempotent.
            $rs = execute( "mysql_upgrade 2>&1 | egrep -v '^(1|\@had|ERROR (1054|1060|1061))'", \$stdout );
            error( sprintf( "Couldn't upgrade SQL server system tables: %s", $stdout )) if $rs;
            return $rs if $rs;
            debug( $stdout ) if $stdout;
        }
    }

    if ( !( $::imscpConfig{'SQLD_PACKAGE'} eq 'Servers::sqld::mariadb'
        && version->parse( "$self->{'config'}->{'SQLD_VERSION'}" ) >= version->parse( '10.0' ) )
        && !( version->parse( "$self->{'config'}->{'SQLD_VERSION'}" ) >= version->parse( '5.6.6' ) )
    ) {
        return 0;
    }

    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;

    # Disable unwanted plugins (bc reasons)
    for my $plugin ( qw/ cracklib_password_check simple_password_check validate_password / ) {
        $rdbh->do( "UNINSTALL PLUGIN $plugin" ) if $rdbh->selectrow_hashref( "SELECT name FROM mysql.plugin WHERE name = '$plugin'" );
    }

    0;
}

=item _setupMasterSqlUser( )

 Setup master SQL user
 
 Return 0 on success, other or die on failure

=cut

sub _setupMasterSqlUser
{
    my ( $self ) = @_;

    my $user = ::setupGetQuestion( 'DATABASE_USER' );
    my $userHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $pwd = decryptRijndaelCBC( $::imscpDBKey, $::imscpDBiv, ::setupGetQuestion( 'DATABASE_PASSWORD' ));
    my $oldUser = $::imscpOldConfig{'DATABASE_USER'};

    # Remove old user if any
    for my $sqlUser ( $oldUser, $user ) {
        next unless $sqlUser;
        for my $host ( $userHost, $oldUserHost ) {
            next unless $host;
            $self->{'sqld'}->dropUser( $sqlUser, $host );
        }
    }

    # Create user
    $self->{'sqld'}->createUser( $user, $userHost, $pwd );

    # Grant all privileges to that user (including GRANT otpion)
    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( 'GRANT ALL PRIVILEGES ON *.* TO ?@? WITH GRANT OPTION', undef, $user, $userHost );
    0;
}

=item _setupSecureInstallation( )

 Secure Installation
 
 Basically, this method do same job as the mysql_secure_installation script
  - Remove anonymous users
  - Remove remote sql root user (only for local server)
  - Remove test database if any
  - Reload privileges tables
  
  Return 0 on success, other or die on failure

=cut

sub _setupSecureInstallation
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->getInstance()->trigger( 'beforeSetupSecureSqlInstallation' );
    return $rs if $rs;

    my $oldDbName = $self->{'dbh'}->useDatabase( 'mysql' );

    my $rdbh = $self->{'dbh'}->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;

    # Remove anonymous users
    $rdbh->do( "DELETE FROM user WHERE User = ''" );
    # Remove test database if any
    $rdbh->do( 'DROP DATABASE IF EXISTS `test`' );
    # Remove privileges on test database
    $rdbh->do( "DELETE FROM db WHERE Db = 'test' OR Db = 'test\\_%'" );

    # Disallow remote root login
    if ( $::imscpConfig{'SQLD_PACKAGE'} ne 'Servers::sqld::remote' ) {
        $rdbh->do( "DELETE FROM user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" );
    }

    $rdbh->do( 'FLUSH PRIVILEGES' );
    $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
    $self->{'eventManager'}->getInstance()->trigger( 'afterSetupSecureSqlInstallation' );
}

=item _setupDatbase( )

 Setup database
 
 Return 0 on success, other or die on failure

=cut

sub _setupDatbase
{
    my ( $self ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );

    unless ( $self->_setupIsImscpDb( $dbName ) ) {
        my $rs = $self->{'eventManager'}->getInstance()->trigger( 'beforeSetupDatabase', \$dbName );
        return $rs if $rs;

        my $rdbh = $self->{'dbh'}->getRawDb();
        local $rdbh->{'RaiseError'} = TRUE;
        my $qdbName = $rdbh->quote_identifier( $dbName );
        $rdbh->do( "CREATE DATABASE $qdbName CHARACTER SET utf8 COLLATE utf8_unicode_ci;" );

        $self->{'dbh'}->set( 'DATABASE_NAME', $dbName );

        if ( $self->{'dbh'}->connect() ) {
            error( "Couldn't connect to SQL server" );
            return 1;
        }

        $rs = ::setupImportSqlSchema( $self->{'dbh'}, "$::imscpConfig{'CONF_DIR'}/database/database.sql" );
        $rs ||= $self->{'eventManager'}->getInstance()->trigger( 'afterSetupDatabase', \$dbName );
        return $rs if $rs;
    }

    # In all cases, we process database update. This is important because sometime some developer forget to update the
    # database revision in the main database.sql file.
    my $rs = $self->{'eventManager'}->getInstance()->trigger( 'beforeSetupUpdateDatabase' );
    $rs ||= execute( "php -d date.timezone=UTC $::imscpConfig{'ROOT_DIR'}/engine/bin/imscp-update.php", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs ||= $self->{'eventManager'}->getInstance()->trigger( 'afterSetupUpdateDatabase' );
}

=item _isMysqldInsideCt( )

 Does the Mysql server is run inside an unprivileged VE (OpenVZ container)

 Return boolean TRUE if the Mysql server is run inside an OpenVZ container, FALSE

=cut

sub _isMysqldInsideCt
{
    return 0 unless -f '/proc/user_beancounters';

    my $rs = execute( 'cat /proc/1/status | grep --color=never envID', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    debug( $stderr ) if $rs && $stderr;
    return $rs if $rs;

    if ( $stdout =~ /envID:\s+(\d+)/ ) {
        return !!( $1 > 0 );
    }

    FALSE;
}

=item _setupIsImscpDb

 Is the given database an i-MSCP database?

 Return boolean TRUE if the given database exists and look like an i-MSCP database, FALSE otherwise, die on failure

=cut

sub _setupIsImscpDb
{
    my ( $self, $dbName ) = @_;

    my $rdbh = $self->{'dbh'}->getRawDb();

    local $rdbh->{'RaiseError'} = TRUE;
    return FALSE unless $rdbh->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $dbName );

    my $tables = $self->{'dbh'}->getDbTables( $dbName );
    return FALSE unless @{ $tables };

    for my $table ( qw/ server_ips user_gui_props reseller_props / ) {
        return FALSE unless grep ( $table eq $_, @{ $tables } );
    }

    TRUE;
}

=item _tryDbConnect

 Try database connection

=cut

sub _tryDbConnect
{
    my ( $self, $host, $port, $user, $pwd ) = @_;

    defined $host or die( '$host parameter is not defined' );
    defined $port or die( '$port parameter is not defined' );
    defined $user or die( '$user parameter is not defined' );
    defined $pwd or die( '$pwd parameter is not defined' );

    $self->{'dbh'}->set( 'DATABASE_HOST', idn_to_ascii( $host, 'utf-8' ));
    $self->{'dbh'}->set( 'DATABASE_PORT', $port );
    $self->{'dbh'}->set( 'DATABASE_USER', $user );
    $self->{'dbh'}->set( 'DATABASE_PASSWORD', $pwd );
    $self->{'dbh'}->connect();
}

=item _oldEngineCompatibility( )

 Remove old files

 Return int 0 on success, other on failure

=cut

sub _oldEngineCompatibility
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeSqldOldEngineCompatibility' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/mysql.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/mysql.old.data" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterSqldOldEngineCompatibility' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
