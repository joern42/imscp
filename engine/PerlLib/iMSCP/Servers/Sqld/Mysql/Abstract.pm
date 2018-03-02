=head1 NAME

 iMSCP::Servers::Sqld::Mysql::Abstract::Abstract - i-MSCP MySQL SQL server abstract implementation

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
use File::Spec;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Database;
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
        $self->getPriority()
    );
}

=item masterSqlUserDialog( \%dialog )

 Ask for i-MSCP master SQL user

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

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
 Return int 0 on success, other on failure

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
        $hostname = ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || ( $hostname ne '%' && !isValidHostname( $hostname )
        && !isValidIpAddr( $hostname,
        ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' || index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 )
            ? qr/^(?:PUBLIC|GLOBAL-UNICAST)$/ : qr/^PUBLIC$/ ) )
    ) {
        my $rs = 0;

        do {
            ( $rs, $hostname ) = $dialog->inputbox( <<"EOF", idn_to_unicode( $hostname, 'utf-8' ) // '' );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the host from which SQL users created by i-MSCP must be allowed to connect:
\\Z \\Zn
EOF
        } while $rs < 30 && ( $hostname ne '%' && !isValidHostname( $hostname )
            && !isValidIpAddr( $hostname,
            ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' || index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 )
                ? qr/^(?:PUBLIC|GLOBAL-UNICAST)$/ : qr/^PUBLIC$/ )
        );

        return unless $rs < 30;
    }

    ::setupSetQuestion( 'DATABASE_USER_HOST', idn_to_ascii( $hostname, 'utf-8' ));
    0;
}

=item databaseNameDialog( \%dialog )

 Ask for i-MSCP database name

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

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
            if ($rs < 30 && isValidDbName( $dbName ) ) {
                my $db = iMSCP::Database->getInstance();
                eval { $db->useDatabase( $dbName ); };
                if ( !$@ && !$self->_setupIsImscpDb( $dbName ) ) {
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
 Return int 0 on success, other on failure

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

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf",
        {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
    setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf",
        {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Mysql';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'MySQL %s', $self->getVersion());
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

    my $dbh = iMSCP::Database->getInstance();

    unless ( $dbh->selectrow_array( 'SELECT EXISTS(SELECT 1 FROM mysql.user WHERE User = ? AND Host = ?)', undef, $user, $host ) ) {
        # User doesn't already exist. We create it
        $dbh->do(
            'CREATE USER ?@? IDENTIFIED BY ?' . ( version->parse( $self->getVersion()) >= version->parse( '5.7.6' ) ? ' PASSWORD EXPIRE NEVER' : '' ),
            undef, $user, $host, $password
        );
        return;
    }

    # User does already exists. We update his password
    if ( version->parse( $self->getVersion()) < version->parse( '5.7.6' ) ) {
        $dbh->do( 'SET PASSWORD FOR ?@? = PASSWORD(?)', undef, $user, $host, $password );
        return;
    }

    $dbh->do( 'ALTER USER ?@? IDENTIFIED BY ? PASSWORD EXPIRE NEVER', undef, $user, $host, $password )
}

=item dropUser( $user, $host )

 See iMSCP::Servers::Sqld::dropUser();

=cut

sub dropUser
{
    my ( undef, $user, $host ) = @_;

    defined $user or croak( '$user parameter not defined' );
    defined $host or croak( '$host parameter not defined' );

    # Prevent deletion of system SQL users
    return if grep ($_ eq lc $user, 'debian-sys-maint', 'mysql.sys', 'root');

    my $dbh = iMSCP::Database->getInstance();
    return unless $dbh->selectrow_hashref( 'SELECT 1 FROM mysql.user WHERE user = ? AND host = ?', undef, $user, $host );
    $dbh->do( 'DROP USER ?@?', undef, $user, $host );
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
    my $rows = iMSCP::Database->getInstance()->selectall_arrayref(
        'SELECT sqld_name FROM sql_database WHERE domain_id = ?', { Slice => {} }, $moduleData->{'DOMAIN_ID'}
    );

    for my $row ( @{ $rows } ) {
        # Encode slashes as SOLIDUS unicode character
        # Encode dots as Full stop unicode character
        ( my $encodedDbName = $row->{'sqld_name'} ) =~ s%([./])%{ '/', '@002f', '.', '@002e' }->{$1}%ge;

        for my $ext ( '.sql', '.sql.bz2', '.sql.gz', '.sql.lzma', '.sql.xz' ) {
            my $dbDumpFilePath = File::Spec->catfile( "$moduleData->{'HOME_DIR'}/backups", $encodedDbName . $ext );
            debug( $dbDumpFilePath );
            next unless -f $dbDumpFilePath;
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

=item _askSqlRootUser( )

 Ask for SQL root user

=cut

sub _askSqlRootUser
{
    my ( $self, $dialog ) = @_;

    my $hostname = ::setupGetQuestion(
        'DATABASE_HOST', index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 ? '' : 'localhost'
    );

    if ( index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 && grep { $hostname eq $_ } ( 'localhost', '127.0.0.1', '::1' ) ) {
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

    my $row = iMSCP::Database->getInstance()->selectrow_hashref( 'SELECT @@version' ) or die( "Could't find SQL server version" );
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
        next unless $sqlUser;

        for my $host ( $userHost, $::imscpOldConfig{'DATABASE_USER_HOST'} ) {
            next unless $host;
            $self->dropUser( $sqlUser, $host );
        }
    }

    # Create user
    $self->createUser( $user, $userHost, $pwd );

    # Grant all privileges to that user, including GRANT OPTION
    iMSCP::Database->getInstance()->do( 'GRANT ALL PRIVILEGES ON *.* TO ?@? WITH GRANT OPTION', undef, $user, $userHost );
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

    my $db = iMSCP::Database->getInstance();
    my $oldDbName = $db->useDatabase( 'mysql' );
    $db->do( "DELETE FROM user WHERE User = ''" ); # Remove anonymous users
    $db->do( 'DROP DATABASE IF EXISTS `test`' ); # Remove test database if any
    $db->do( "DELETE FROM db WHERE Db = 'test' OR Db = 'test\\_%'" ); # Remove privileges on test database

    # Disallow remote root login
    if ( index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ) {
        $db->do( "DELETE FROM user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" );
    }

    $db->do( 'FLUSH PRIVILEGES' );
    $db->useDatabase( $oldDbName ) if $oldDbName;
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

        my $defaultsExtraFile = File::Temp->new();
        print $defaultsExtraFile <<'EOF';
[mysql]
host = {HOST}
port = {PORT}
user = "{USER}"
password = "{PASSWORD}"
EOF
        $defaultsExtraFile->close();
        $self->buildConfFile( $defaultsExtraFile, $defaultsExtraFile, undef,
            {
                HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
                PORT     => ::setupGetQuestion( 'DATABASE_PORT' ),
                USER     => ::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
                PASSWORD => decryptRijndaelCBC( $::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
            },
            { srcname => 'defaults-extra-file' }
        );

        my $rs = execute( "mysql --defaults-extra-file=$defaultsExtraFile < $dbSchemaFile", \my $stdout, \my $stderr );
        debug( $stdout ) if $stdout;
        !$rs or die( $stderr || 'Unknown error' );
    }

    # In all cases, we process database update. This is important because sometime developers forget to update the
    # database revision in the database.sql schema file.
    my $rs = execute(
        [
            ( iMSCP::ProgramFinder::find( 'php' ) or die( "Couldn't find php executable in \$PATH" ) )
            , '-d', 'date.timezone=UTC', "$::imscpConfig{'ROOT_DIR'}/engine/setup/updDB.php"
        ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if $stdout;
    die( $stderr || 'Unknown error' ) if $rs;
}

=item _setupIsImscpDb( $dbName )

 Is the given database an i-MSCP database?

 Return bool TRUE if the database exists and look like an i-MSCP database, FALSE otherwise, die on failure

=cut

sub _setupIsImscpDb
{
    my ( undef, $dbName ) = @_;

    return 0 unless length $dbName;

    my $db = iMSCP::Database->getInstance();

    return 0 unless $db->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $dbName );

    my $tables = $db->getDbTables( $dbName );
    ref $tables eq 'ARRAY' or die( $tables );

    for my $table ( qw/ server_ips user_gui_props reseller_props / ) {
        return 0 unless grep ( $_ eq $table, @{ $tables } );
    }

    1;
}

=item _tryDbConnect

 Try database connection

 Return void, die on failure

=cut

sub _tryDbConnect
{
    my ( undef, $host, $port, $user, $pwd ) = @_;

    defined $host or croak( '$host parameter is not defined' );
    defined $port or croak( '$port parameter is not defined' );
    defined $user or croak( '$user parameter is not defined' );
    defined $pwd or croak( '$pwd parameter is not defined' );

    my $db = iMSCP::Database->getInstance();
    $db->set( 'DATABASE_HOST', idn_to_ascii( $host, 'utf-8' ) // '' );
    $db->set( 'DATABASE_PORT', $port );
    $db->set( 'DATABASE_USER', $user );
    $db->set( 'DATABASE_PASSWORD', $pwd );
    $db->connect();
}

=item _restoreDatabase( $dbName, $dbDumpFilePath )

 Restore a database from the given database dump file
 
 Param string $dbName Database name
 Param string $dbDumpFilePath Path to database dump file
 Return void, die on faimure

=cut

sub _restoreDatabase
{
    my ( $self, $dbName, $dbDumpFilePath ) = @_;

    my ( undef, undef, $archFormat ) = fileparse( $dbDumpFilePath, qr/\.(?:bz2|gz|lzma|xz)/ );
    my $cmd;

    if ( $archFormat eq '.bz2' ) {
        $cmd = 'bzcat -d ';
    } elsif ( $archFormat eq '.gz' ) {
        $cmd = 'zcat -d ';
    } elsif ( $archFormat eq '.lzma' ) {
        $cmd = 'lzma -dc ';
    } elsif ( $archFormat eq '.xz' ) {
        $cmd = 'xz -dc ';
    } else {
        $cmd = 'cat ';
    }

    # We need to create an user that will be able to act on the target
    # database only. Making use of an user with full privileges, such as
    # the i-MSCP master SQL user, would create a security breach as the
    # $dbDumpFilePath dump is provided by the customer

    my $tmpUser = randomStr( 16, ALNUM );
    my $tmpPassword = randomStr( 16, ALNUM );
    $self->createUser( $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'}, $tmpPassword );
    my $dbh = iMSCP::Database->getInstance();

    # According MySQL documentation (http://dev.mysql.com/doc/refman/5.5/en/grant.html#grant-accounts-passwords)
    # The “_” and “%” wildcards are permitted when specifying database names in GRANT statements that grant privileges
    # at the global or database levels. This means, for example, that if you want to use a “_” character as part of a
    # database name, you should specify it as “\_” in the GRANT statement, to prevent the user from being able to
    # access additional databases matching the wildcard pattern; for example, GRANT ... ON `foo\_bar`.* TO ....
    #
    # In practice, without escaping, an user added for db `a_c` would also have access to a db `abc`.
    $dbh->do( "GRANT ALL PRIVILEGES ON @{ [ $dbh->quote_identifier( $dbName ) =~ s/([%_])/\\$1/gr ] }.* TO ?\@?", undef, $tmpUser, $tmpPassword );

    # Avoid error such as 'MySQL error 1449: The user specified as a definer does not exist' by updating definer if any
    # FIXME: Need flush privileges?
    # FIXME: Should we STAMP that statement?
    # TODO: TO BE TESTED FIRST
    #$dbh->do( "UPDATE mysql.proc SET definer = ?@? WHERE db = ?", undef, $tmpUser, $tmpPassword, $dbName );

    my $defaultsExtraFile = File::Temp->new();
    print $defaultsExtraFile <<"EOF";
[mysql]
host = $::imscpConfig{'DATABASE_HOST'}
port = $::imscpConfig{'DATABASE_PORT'}
user = @{ [ $tmpUser =~ s/"/\\"/gr ] }
password = @{ [ $tmpPassword =~ s/"/\\"/gr ] }
max_allowed_packet = 500M
EOF
    $defaultsExtraFile->close();

    my @cmd = ( $cmd, escapeShell( $dbDumpFilePath ), '|', "mysql --defaults-extra-file=$defaultsExtraFile", escapeShell( $dbName ) );
    my $rs = execute( "@cmd", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf( "Couldn't restore SQL database: %s", $stderr || 'Unknown error' ));
    $self->dropUser( $tmpUser, $::imscpConfig{'DATABASE_USER_HOST'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
