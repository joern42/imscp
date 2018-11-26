=head1 NAME

 iMSCP::Servers::Sqld::Mysql::Abstract - i-MSCP MySQL SQL server abstract implementation

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

package iMSCP::Servers::Sqld::Mysql::Abstract;

use strict;
use warnings;
use autouse 'iMSCP::Crypt' => qw/ ALNUM encryptRijndaelCBC decryptRijndaelCBC randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isNotEmpty isNumber isNumberInRange isOneOfStringsInList isStringInList isStringNotInList
    isValidHostname isValidIpAddr isValidPassword isValidUsername isValidDbName /;
use autouse 'iMSCP::Execute' => qw/ execute escapeShell /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use autouse 'Net::LibIDN' => qw/ idn_to_ascii idn_to_unicode /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt /;
use File::Basename;
use File::Spec;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use version;
use parent 'iMSCP::Servers::Sqld';

=head1 DESCRIPTION

 i-MSCP MySQL SQL server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub {
            push @{ $_[0] },
                sub { $self->masterSqlUserDialog( @_ ) }, sub { $self->sqlUserHostDialog( @_ ) }, sub { $self->databaseNameDialog( @_ ) },
                sub { $self->databasePrefixDialog( @_ ) };
        },
        $self->getServerPriority()
    );
}

=item masterSqlUserDialog( \%dialog )

 Ask for i-MSCP master SQL user

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub masterSqlUserDialog
{
    my ( $self, $dialog ) = @_;

    my $rs = 0;
    $rs = $self->_askSqlRootUser( $dialog ) if iMSCP::Getopt->preseed;
    return $rs if $rs;

    my $hostname = ::setupGetQuestion( 'DATABASE_HOST' );
    my $port = ::setupGetQuestion( 'DATABASE_PORT' );
    my $user = ::setupGetQuestion( 'DATABASE_USER', iMSCP::Getopt->preseed ? 'imscp_user' : '' );
    $user = 'imscp_user' if lc( $user ) eq 'root'; # Handle upgrade case
    my $pwd = ::setupGetQuestion( 'DATABASE_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : '' );

    if ( length $pwd && !iMSCP::Getopt->preseed ) {
        $pwd = decryptRijndaelCBC( $::imscpKEY, $::imscpIV, $pwd );
        $pwd = '' unless isValidPassword( $pwd ); # Handle case of badly decrypted password
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || !isNotEmpty( $hostname )
        || !isNotEmpty( $port )
        || !isNotEmpty( $user )
        || !isStringNotInList( lc $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' )
        || !isNotEmpty( $pwd )
        || ( !iMSCP::Getopt->preseed && !eval { $self->_tryDbConnect( $hostname, $port, $user, $pwd ); } )
    ) {
        $rs = $self->_askSqlRootUser( $dialog ) unless iMSCP::Getopt->preseed;
        return $rs unless $rs < 30;

        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        do {
            unless ( length $user ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $user = 'imscp_user';
            }

            ( $rs, $user ) = $dialog->inputbox( <<"EOF", $user );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the i-MSCP master SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isValidUsername( $user )
            || !isStringNotInList( lc $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' )
        );

        return $rs unless $rs < 30;

        do {
            unless ( length $pwd ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $pwd = randomStr( 16, ALNUM );
            }

            ( $rs, $pwd ) = $dialog->inputbox( <<"EOF", $pwd );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the master i-MSCP SQL user (leave empty for autogeneration):
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidPassword( $pwd );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'DATABASE_USER', $user );
    ::setupSetQuestion( 'DATABASE_PASSWORD', encryptRijndaelCBC( $::imscpKEY, $::imscpIV, $pwd ));
    0;
}

=item sqlUserHostDialog( \%dialog )

 Ask for SQL user hostname

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub sqlUserHostDialog
{
    my ( undef, $dialog ) = @_;

    if ( index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ) {
        ::setupSetQuestion( 'DATABASE_USER_HOST', 'localhost' );
        return 0;
    }

    my $hostname = ::setupGetQuestion( 'DATABASE_USER_HOST', ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' ));

    if ( grep ($hostname eq $_, ( 'localhost', '127.0.0.1', '::1' )) ) {
        # Handle switch case (default value). Host cannot be one of above value
        # when using remote SQL server 
        $hostname = ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || ( $hostname ne '%' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname) )
    ) {
        my $rs = 0;

        do {
            ( $rs, $hostname ) = $dialog->inputbox( <<"EOF", idn_to_unicode( $hostname, 'utf-8' ) // '' );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the host from which SQL users created by i-MSCP must be allowed to connect:
\\Z \\Zn
EOF
        } while $rs < 30 && ( $hostname ne '%' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname ) );

        return unless $rs < 30;
    }

    ::setupSetQuestion( 'DATABASE_USER_HOST', idn_to_ascii( $hostname, 'utf-8' ));
    0;
}

=item databaseNameDialog( \%dialog )

 Ask for i-MSCP database name

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub databaseNameDialog
{
    my ( $self, $dialog ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME', iMSCP::Getopt->preseed ? 'imscp' : '' );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || ( !$self->_setupIsImscpDb( $dbName ) && !iMSCP::Getopt->preseed )
    ) {
        my $rs = 0;

        do {
            unless ( length $dbName ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $dbName = 'imscp';
            }

            ( $rs, $dbName ) = $dialog->inputbox( <<"EOF", $dbName );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a database name for i-MSCP:
\\Z \\Zn
EOF
            if ( $rs < 30 && isValidDbName( $dbName ) ) {
                
                if ( eval { $self->{'dbh'}->useDatabase( $dbName ); TRUE } && !$self->_setupIsImscpDb( $dbName ) ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = <<"EOF";
\\Z1Database '$dbName' exists but doesn't look like an i-MSCP database.\\Zn
EOF
                }
            }
        } while $rs < 30 && $iMSCP::Dialog::InputValidation::lastValidationError;

        return $rs unless $rs < 30;

        my $oldDbName = ::setupGetQuestion( 'DATABASE_NAME' );

        if ( $oldDbName && $dbName ne $oldDbName && $self->setupIsImscpDb( $oldDbName ) ) {
            if ( $rs = $dialog->yesno( <<"EOF", TRUE, TRUE ) ) {

A database '$::imscpConfig{'DATABASE_NAME'}' for i-MSCP already exists.

Are you sure you want to create a new database for i-MSCP?
Keep in mind that the new database will be free of any reseller and customer data.

\\Z4Note:\\Zn If the database you want to create already exists, nothing will happen.
EOF
                return $rs unless $rs < 30;
                goto &{ databaseNameDialog };
            }
        }
    }

    ::setupSetQuestion( 'DATABASE_NAME', $dbName );
    0;
}

=item databasePrefixDialog( \%dialog )

 Ask for database prefix

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub databasePrefixDialog
{
    my ( undef, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'MYSQL_PREFIX', iMSCP::Getopt->preseed ? 'none' : '' );
    my %choices = ( 'behind', 'Behind', 'infront', 'Infront', 'none', 'None' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'none' );

\\Z4\\Zb\\ZuMySQL Database Prefix/Suffix\\Zn

Do you want to use a prefix or suffix for customer's SQL databases?

\\Z4Infront:\\Zn A numeric prefix such as '1_' is added to each SQL user and database name.
 \\Z4Behind:\\Zn A numeric suffix such as '_1' is added to each SQL user and database name.
   \\Z4None\\Zn: Choice is left to the customer.
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'MYSQL_PREFIX', $value );
    0;
}

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->_setVendor();
    $self->_setVersion();
    $self->_buildConf();
    $self->_setupMasterSqlUser();
    $self->_updateServerConfig();
    $self->_secureInstallation();
    $self->_setupDatabase();
}

=item setBackendPermissions( )

 See iMSCP::Servers::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0644'
    } );
    setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0644'
    } );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Mysql';
}

=item getServerHumanName( )

 See iMSCP::Servers::Abstract::getServerHumanName()

=cut

sub getServerHumanName
{
    my ( $self ) = @_;

    sprintf( 'MySQL %s', $self->getServerVersion());
}

=item createUser( $user, $host, $password )

 See iMSCP::Servers::Sqld::createUser();

=cut

sub createUser
{
    my ( $self, $user, $host, $password ) = @_;

    defined $user or croak( '$user parameter is not defined' );
    defined $host or croak( '$host parameter is not defined' );
    defined $password or croak( '$password parameter is not defined' );

    unless ( $self->{'dbh'}->selectrow_array( 'SELECT EXISTS(SELECT 1 FROM mysql.user WHERE User = ? AND Host = ?)', undef, $user, $host ) ) {
        # User doesn't already exist. We create it
        $self->{'dbh'}->do(
            'CREATE USER ?@? IDENTIFIED BY ?'
                . ( version->parse( $self->getServerVersion()) >= version->parse( '5.7.6' ) ? ' PASSWORD EXPIRE NEVER' : '' ),
            undef, $user, $host, $password
        );
        return;
    }

    # User does already exists. We update his password
    if ( version->parse( $self->getServerVersion()) < version->parse( '5.7.6' ) ) {
        $self->{'dbh'}->do( 'SET PASSWORD FOR ?@? = PASSWORD(?)', undef, $user, $host, $password );
        return;
    }

    $self->{'dbh'}->do( 'ALTER USER ?@? IDENTIFIED BY ? PASSWORD EXPIRE NEVER', undef, $user, $host, $password )
}

=item dropUser( $user, $host )

 See iMSCP::Servers::Sqld::dropUser();

=cut

sub dropUser
{
    my ( $self, $user, $host ) = @_;

    defined $user or croak( '$user parameter not defined' );
    defined $host or croak( '$host parameter not defined' );

    # Prevent deletion of system SQL users
    return if grep ($_ eq lc $user, 'debian-sys-maint', 'mysql.sys', 'root');
    return unless $self->{'dbh'}->selectrow_hashref( 'SELECT 1 FROM mysql.user WHERE user = ? AND host = ?', undef, $user, $host );

    $self->{'dbh'}->do( 'DROP USER ?@?', undef, $user, $host );
    !$@ or die( sprintf( "Couldn't drop the %s\@%s SQL user: %s", $user, $host, $@ ));
}

=item restoreDomain ( \%moduleData )

 See iMSCP::Servers::Sqld::restoreDomain()

=cut

sub restoreDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'before' . $self->getServerName . 'RestoreDomain' );

    # Restore known databases only
    my $rows = $self->{'dbh'}->selectall_arrayref( 
        'SELECT sqld_name FROM sql_database WHERE domain_id = ?', { Slice => {} }, $moduleData->{'DOMAIN_ID'}
    );

    for my $row ( @{ $rows } ) {
        # Encode slashes as SOLIDUS unicode character
        # Encode dots as Full stop unicode character
        ( my $encodedDbName = $row->{'sqld_name'} ) =~ s%([./])%{ '/', '@002f', '.', '@002e' }->{$1}%ge;

        for my $ext ( qw/ .sql .sql.bz2 .sql.gz .sql.lzma .sql.xz / ) {
            my $dbDumpFilePath = File::Spec->catfile( "$moduleData->{'HOME_DIR'}/backups", $encodedDbName . $ext );
            next unless -f $dbDumpFilePath;
            debug( $dbDumpFilePath );
            $self->_restoreDatabase( $row->{'sqld_name'}, $dbDumpFilePath );
        }
    }

    $self->{'eventManager'}->trigger( 'after' . $self->getServerName . 'RestoreDomain' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Sqld::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/mysql";
    $self->SUPER::_init();
}

=item _askSqlRootUser( \%dialog )

 Ask for SQL root user

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub _askSqlRootUser
{
    my ( $self, $dialog ) = @_;

    my $hostname = ::setupGetQuestion(
        'DATABASE_HOST', index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 ? '' : 'localhost'
    );

    if ( index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 && grep { $hostname eq $_ } ( 'localhost', '127.0.0.1', '::1' ) ) {
        # Handle switch case (default value). Host cannot be one of above value
        # when using remote SQL server
        $hostname = '';
    }

    my $port = ::setupGetQuestion( 'DATABASE_PORT', 3306 );
    my $user = ::setupGetQuestion( 'SQL_ROOT_USER', 'root' );
    my $pwd = ::setupGetQuestion( 'SQL_ROOT_PASSWORD' );

    if ( $hostname eq 'localhost' ) {
        for my $host ( 'localhost', '127.0.0.1' ) {
            eval { $self->_tryDbConnect( $host, $port, $user, $pwd ); };
            next if $@;

            ::setupSetQuestion( 'DATABASE_HOST', $host );
            ::setupSetQuestion( 'DATABASE_PORT', $port );
            ::setupSetQuestion( 'SQL_ROOT_USER', $user );
            ::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
            return 0;
        }
    }

    my $rs = 0;
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    do {
        ( $rs, $hostname ) = $dialog->inputbox( <<"EOF", $hostname );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL server hostname or IP address:
\\Z \\Zn
EOF
    } while $rs < 30 && ( $hostname ne 'localhost' && !isValidHostname( $hostname ) && !isValidIpAddr( $hostname ) );

    ::setupSetQuestion( 'DATABASE_HOST', idn_to_ascii( $hostname, 'utf-8' ) // '' );
    return $rs if $rs >= 30;

    do {
        ( $rs, $port ) = $dialog->inputbox( <<"EOF", $port );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL server port:
\\Z \\Zn
EOF
    } while $rs < 30 && !isNumber( $port ) || !isNumberInRange( $port, 1025, 65535 );

    ::setupSetQuestion( 'DATABASE_PORT', $port );
    return $rs if $rs >= 30;

    do {
        ( $rs, $user ) = $dialog->inputbox( <<"EOF", $user );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL root username:

Note that this user must have full privileges on the SQL server.
i-MSCP only uses that user while installation or reconfiguration.
\\Z \\Zn
EOF
    } while $rs < 30 && !isNotEmpty( $user );

    ::setupSetQuestion( 'SQL_ROOT_USER', $user );
    return $rs if $rs >= 30;

    do {
        ( $rs, $pwd ) = $dialog->passwordbox( <<"EOF" );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL root user password:
\\Z \\Zn
EOF
    } while $rs < 30 && !isNotEmpty( $pwd );

    ::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
    return $rs if $rs >= 30;

    unless ( eval { $self->_tryDbConnect( $hostname, $port, $user, $pwd ); } ) {
        chomp( $@ );
        local $dialog->{'opts'}->{'ok-label'} = 'Retry';
        local $dialog->{'opts'}->{'extra-button'} = '';
        local $dialog->{'opts'}->{'extra-label'} = 'Abort';
        local $ENV{'DIALOG_EXTRA'} = 1;
        exit if $dialog->msgbox( <<"EOF" );

\\Z1Connection to SQL server failed\\Zn

i-MSCP installer couldn't connect to SQL server using the following data:

\\Z4Host:\\Zn $hostname
\\Z4Port:\\Zn $port
\\Z4Username:\\Zn $user
\\Z4Password:\\Zn $pwd

Error was: \\Z1$@\\Zn
EOF
        goto &{ _askSqlRootUser };
    }

    0;
}

=item _setVendor( )

 Set SQL server vendor

 Return 0 on success, other on failure

=cut

sub _setVendor
{
    my ( $self ) = @_;

    debug( sprintf( 'SQL server vendor set to: %s', 'MySQL' ));
    $self->{'config'}->{'SQLD_VENDOR'} = 'MySQL';
}

=item _setVersion( )

 Set SQL server version

 Return 0 on success, other on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $row = $self->{'dbh'}->selectrow_hashref( 'SELECT @@version' ) or die( "Could't find SQL server version" );
    my ( $version ) = $row->{'@@version'} =~ /^([0-9]+(?:\.[0-9]+){1,2})/;
    defined $version or die( "Couldn't guess SQL server version with the `SELECT \@\@version` SQL query" );
    debug( sprintf( 'SQL server version set to: %s', $version ));
    $self->{'config'}->{'SQLD_VERSION'} = $version;

}

=item _buildConf( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConf
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the _buildConf() method ', ref $self ));
}

=item _setupMasterSqlUser( )

 Setup master SQL user
 
 Return void, die on faimure

=cut

sub _setupMasterSqlUser
{
    my ( $self ) = @_;

    my $user = ::setupGetQuestion( 'DATABASE_USER' );
    my $userHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $pwd = decryptRijndaelCBC( $::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' ));

    # Remove old user if any
    for my $sqlUser ( $::imscpOldConfig{'DATABASE_USER'}, $user ) {
        next unless length $sqlUser;

        for my $host ( $userHost, $::imscpOldConfig{'DATABASE_USER_HOST'} ) {
            next unless length $host;
            $self->dropUser( $sqlUser, $host );
        }
    }

    # Create user
    $self->createUser( $user, $userHost, $pwd );

    # Grant all privileges to that user, including GRANT OPTION
    $self->{'dbh'}->do( 'GRANT ALL PRIVILEGES ON *.* TO ?@? WITH GRANT OPTION', undef, $user, $userHost );
}

=item _updateServerConfig( )

 Update server configuration

  - Upgrade MySQL system tables if necessary
  - Disable unwanted plugins

 Return void, die on faimure

=cut

sub _updateServerConfig
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the _updateServerConfig() method ', ref $self ));
}

=item _secureInstallation( )

 Secure Installation
 
 Basically, this method do same job as the mysql_secure_installation script
  - Remove anonymous users
  - Remove remote sql root user (only for local server)
  - Remove test database if any
  - Reload privileges tables
  
  Return void, die on faimure

=cut

sub _secureInstallation
{
    my ( $self ) = @_;

    my $oldDbName = $self->{'dbh'}->useDatabase( 'mysql' );
    $self->{'dbh'}->do( "DELETE FROM user WHERE User = ''" ); # Remove anonymous users
    $self->{'dbh'}->do( 'DROP DATABASE IF EXISTS `test`' ); # Remove test database if any
    $self->{'dbh'}->do( "DELETE FROM db WHERE Db = 'test' OR Db = 'test\\_%'" ); # Remove privileges on test database

    # Disallow remote root login
    if ( index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ) {
        $self->{'dbh'}->do( "DELETE FROM user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" );
    }

    $self->{'dbh'}->do( 'FLUSH PRIVILEGES' );
    $self->{'dbh'}->useDatabase( $oldDbName ) if length $oldDbName;
}

=item _setupDatabase( )

 Setup database
 
 Return void, die on faimure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );

    unless ( $self->_setupIsImscpDb( $dbName ) ) {
        my $dbSchemaFile = File::Temp->new();
        $self->buildConfFile( "$::imscpConfig{'CONF_DIR'}/database/database.sql", $dbSchemaFile, undef, { DATABASE_NAME => $dbName } );

        my $mysqlDefaultsFile = File::Temp->new();
        print $mysqlDefaultsFile <<'EOF';
[mysql]
host = {HOST}
port = {PORT}
user = "{USER}"
password = "{PASSWORD}"
EOF
        $mysqlDefaultsFile->close();
        $self->buildConfFile( $mysqlDefaultsFile, undef, undef,
            {
                HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
                PORT     => ::setupGetQuestion( 'DATABASE_PORT' ),
                USER     => ::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
                PASSWORD => decryptRijndaelCBC( $::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
            },
            {
                srcname => 'mysql-defaults-file'
            }
        );

        my $rs = execute( "mysql --defaults-file=$mysqlDefaultsFile < $dbSchemaFile", \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        $rs == 0 or die( $stderr || 'Unknown error' );
    }

    # In all cases, we process database update. This is important because sometime developers forget to update the
    # database revision in the database.sql schema file.
    my $rs = execute(
        [
            ( iMSCP::ProgramFinder::find( 'php' ) or die( "Couldn't find php executable in \$PATH" ) ), '-d', 'date.timezone=UTC',
            "$::imscpConfig{'BACKEND_ROOT_DIR'}/setup/updDB.php"
        ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if length $stdout;
    die( $stderr || 'Unknown error' ) if $rs;
}

=item _setupIsImscpDb( $dbName )

 Is the given database an i-MSCP database?

 Return bool TRUE if the database exists and look like an i-MSCP database, FALSE otherwise, die on failure

=cut

sub _setupIsImscpDb
{
    my ( $self, $dbName ) = @_;

    return FALSE unless length $dbName;
    return FALSE unless $self->{'dbh'}->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $dbName );

    my $tables = $self->{'dbh'}->getDbTables( $dbName );
    ref $tables eq 'ARRAY' or die( $tables );

    for my $table ( qw/ server_ips user_gui_props reseller_props / ) {
        return FALSE unless grep ( $_ eq $table, @{ $tables } );
    }

    TRUE;
}

=item _tryDbConnect( $host, $port, $user, $pwd )

 Try database connection

 Param string $host Server host
 Param string $port Server port
 Param string $user SQL user
 Param string $pwd SQL password
 Return void, die on failure

=cut

sub _tryDbConnect
{
    my ( $self, $host, $port, $user, $pwd ) = @_;

    defined $host or croak( '$host parameter is not defined' );
    defined $port or croak( '$port parameter is not defined' );
    defined $user or croak( '$user parameter is not defined' );
    defined $pwd or croak( '$pwd parameter is not defined' );

    $self->{'dbh'}->set( 'DATABASE_HOST', idn_to_ascii( $host, 'utf-8' ) // '' );
    $self->{'dbh'}->set( 'DATABASE_PORT', $port );
    $self->{'dbh'}->set( 'DATABASE_USER', $user );
    $self->{'dbh'}->set( 'DATABASE_PASSWORD', $pwd );
    $self->{'dbh'}->connect();
}

=item _restoreDatabase( $dbName, $dbDumpFilePath )

 Restore a database from the given database dump file
 
 # TODO: Verify the dump signature
 
 Param string $dbName Database name
 Param string $dbDumpFilePath Path to database dump file
 Return void, die on faimure

=cut

sub  _restoreDatabase
{
    my ( $self, $dbName, $dbDumpFilePath ) = @_;

    my ( undef, undef, $archFormat ) = fileparse( $dbDumpFilePath, qr/\.(?:bz2|gz|lzma|xz)/ );
    my $cmd;

    if ( $archFormat eq '.bz2' ) {
        $cmd = 'bzcat -d';
    } elsif ( $archFormat eq '.gz' ) {
        $cmd = 'zcat -d ';
    } elsif ( $archFormat eq '.lzma' ) {
        $cmd = 'lzma -dc';
    } elsif ( $archFormat eq '.xz' ) {
        $cmd = 'xz -dc';
    } else {
        $cmd = 'cat';
    }

    my $tmpUser = 'imscp_' . randomStr( 10, ALNUM );
    my $tmpPassword = randomStr( 16, ALNUM );
    $self->createUser( $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'}, $tmpPassword );

    eval {
        # According MySQL documentation (http://dev.mysql.com/doc/refman/5.5/en/grant.html#grant-accounts-passwords)
        # The '_' and '%' wildcards are permitted when specifying database names in GRANT statements that grant privileges
        # at the global or database levels. This means, for example, that if you want to use a '_' character as part of a
        # database name, you should specify it as '\_' in the GRANT statement, to prevent the user from being able to
        # access additional databases matching the wildcard pattern; for example, GRANT ... ON `foo\_bar`.* TO ....
        # In practice, without escaping, an user added for db `a_c` would also have access to a db `abc`.
        $self->{'dbh'}->do(
            "GRANT ALL PRIVILEGES ON @{ [ $self->{'dbh'}->quote_identifier( $dbName ) =~ s/([%_])/\\$1/gr ] }.* TO ?\@?",
            undef, $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'}
        );
        # The SUPER privilege is needed to restore objects such as the procedures, functions, triggers, events and views
        # for which the definer is not the CURRENT_USER(). Another way is to remove the definer statements in the dump
        # prior restoring but that is a non viable solution as the definer *MUST* remain the same, that is, the one which
        # has been used while objects creation.
        $self->{'dbh'}->do( "GRANT SUPER ON *.* TO ?\@?", undef, $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'} );

        my $mysqlDefaultsFile = File::Temp->new();
        print $mysqlDefaultsFile <<"EOF";
[mysql]
host = $::imscpConfig{'DATABASE_HOST'}
port = $::imscpConfig{'DATABASE_PORT'}
user = @{ [ $tmpUser =~ s/"/\\"/gr ] }
password = @{ [ $tmpPassword =~ s/"/\\"/gr ] }
max_allowed_packet = 500M
EOF
        $mysqlDefaultsFile->close();

        my @cmd = ( $cmd, escapeShell( $dbDumpFilePath ), '|', "mysql --defaults-file=$mysqlDefaultsFile", escapeShell( $dbName ) );
        my $rs = execute( "@cmd", \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        $rs == 0 or die( sprintf( "Couldn't restore SQL database: %s", $stderr || 'Unknown error' ));
    };

    # We need drop tmp SQL user even on error
    my $error = $@ || '';
    eval { $self->dropUser( $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'} ); };
    $error .= ( length $error ? "\n$@" : $@ ) if $@;
    die $error if length $error;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
