=head1 NAME

 iMSCP::Servers::Sqld::Mysql::Debian - i-MSCP (Debian) MySQL SQL server implementation

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

package iMSCP::Servers::Sqld::Mysql::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Crypt' => qw/ ALNUM encryptRijndaelCBC decryptRijndaelCBC randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isNotEmpty isOneOfStringsInList isStringInList isStringNotInList isValidHostname isValidIpAddr
    isValidPassword isValidUsername isValidDbName/;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::TemplateParser' => qw/ processByRef /;
use autouse 'Net::LibIDN' => qw/ idn_to_ascii idn_to_unicode /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Dir iMSCP::File iMSCP::Getopt /;
use File::Temp;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Sqld::Mysql::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) MySQL SQL server implementation

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub {
            push @{$_[0]},
                sub { $self->masterSqlUserDialog( @_ ) }, # Should we move this in the local server?
                sub { $self->sqlUserHostDialog( @_ ) }, # Should we enforce localhost without further ask for local server?
                sub { $self->databaseNameDialog( @_ ) }, # Should we move this in the local server?
                sub { $self->databasePrefixDialog( @_ ) }; # Should we move this in specific feature package?
            0;
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
    my ($self, $dialog) = @_;

    my $rs = 0;
    $rs = $self->_askSqlRootUser( $dialog ) if iMSCP::Getopt->preseed;
    return $rs if $rs;

    my $hostname = main::setupGetQuestion( 'DATABASE_HOST' );
    my $port = main::setupGetQuestion( 'DATABASE_PORT' );
    my $user = main::setupGetQuestion( 'DATABASE_USER', iMSCP::Getopt->preseed ? 'imscp_user' : '' );
    $user = 'imscp_user' if lc( $user ) eq 'root'; # Handle upgrade case
    my $pwd = main::setupGetQuestion( 'DATABASE_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : '' );

    if ( $pwd ne '' && !iMSCP::Getopt->preseed ) {
        $pwd = decryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, $pwd );
        $pwd = '' unless isValidPassword( $pwd ); # Handle case of badly decrypted password
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || !isNotEmpty( $hostname )
        || !isNotEmpty( $port )
        || !isNotEmpty( $user )
        || !isStringNotInList( lc $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' )
        || !isNotEmpty( $pwd )
        || ( !iMSCP::Getopt->preseed && $self->_tryDbConnect( $hostname, $port, $user, $pwd ) )
    ) {
        $rs = $self->_askSqlRootUser( $dialog ) unless iMSCP::Getopt->preseed;
        return $rs unless $rs < 30;

        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        do {
            if ( $user eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $user = 'imscp_user';
            }

            ( $rs, $user ) = $dialog->inputbox( <<"EOF", $user );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the i-MSCP master SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidUsername( $user )
            || !isStringNotInList( lc $user, 'debian-sys-maint', 'imscp_srv_user', 'mysql.user', 'root', 'vlogger_user' )
        );

        return $rs unless $rs < 30;

        do {
            if ( $pwd eq '' ) {
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

    main::setupSetQuestion( 'DATABASE_USER', $user );
    main::setupSetQuestion( 'DATABASE_PASSWORD', encryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, $pwd ));
    0;
}

=item sqlUserHostDialog( \%dialog )

 Ask for SQL user hostname

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub sqlUserHostDialog
{
    my (undef, $dialog) = @_;

    if ( index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ) {
        main::setupSetQuestion( 'DATABASE_USER_HOST', 'localhost' );
        return 0;
    }

    my $hostname = main::setupGetQuestion( 'DATABASE_USER_HOST', main::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' ));

    if ( grep($hostname eq $_, ( 'localhost', '127.0.0.1', '::1' )) ) {
        $hostname = main::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );
    }

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || ( $hostname ne '%'
        && !isValidHostname( $hostname )
        && !isValidIpAddr( $hostname,
            ( main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' || index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 )
            ? qr/^(?:PUBLIC|GLOBAL-UNICAST)$/ : qr/^PUBLIC$/ ) )
    ) {
        my $rs = 0;

        do {
            ( $rs, $hostname ) = $dialog->inputbox( <<"EOF", idn_to_unicode( $hostname, 'utf-8' ) // '' );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the host from which SQL users created by i-MSCP must be allowed to connect:
\\Z \\Zn
EOF
        } while $rs < 30
            && ( $hostname ne '%'
            && !isValidHostname( $hostname )
            && !isValidIpAddr( $hostname,
                ( main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' || index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 )
                ? qr/^(?:PUBLIC|GLOBAL-UNICAST)$/ : qr/^PUBLIC$/ )
        );

        return unless $rs < 30;
    }

    main::setupSetQuestion( 'DATABASE_USER_HOST', idn_to_ascii( $hostname, 'utf-8' ));
    0;
}

=item databaseNameDialog( \%dialog )

 Ask for i-MSCP database name

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub databaseNameDialog
{
    my ($self, $dialog) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME', iMSCP::Getopt->preseed ? 'imscp' : '' );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] )
        || ( !$self->_setupIsImscpDb( $dbName ) && !iMSCP::Getopt->preseed )
    ) {
        my $rs = 0;

        do {
            if ( $dbName eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $dbName = 'imscp';
            }

            ( $rs, $dbName ) = $dialog->inputbox( <<"EOF", $dbName );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a database name for i-MSCP:
\\Z \\Zn
EOF
            if ( isValidDbName( $dbName ) ) {
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

        my $oldDbName = main::setupGetQuestion( 'DATABASE_NAME' );

        if ( $oldDbName && $dbName ne $oldDbName && $self->setupIsImscpDb( $oldDbName ) ) {
            if ( $dialog->yesno( <<"EOF", 1 ) ) {
A database '$main::imscpConfig{'DATABASE_NAME'}' for i-MSCP already exists.

Are you sure you want to create a new database for i-MSCP?
Keep in mind that the new database will be free of any reseller and customer data.

\\Z4Note:\\Zn If the database you want to create already exists, nothing will happen.
EOF
                goto &{databaseNameDialog};
            }
        }
    }

    main::setupSetQuestion( 'DATABASE_NAME', $dbName );
    0;
}

=item databasePrefixDialog( \%dialog )

 Ask for database prefix

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub databasePrefixDialog
{
    my (undef, $dialog) = @_;

    my $value = main::setupGetQuestion( 'MYSQL_PREFIX', iMSCP::Getopt->preseed ? 'none' : '' );
    my %choices = ( 'behind', 'Behind', 'infront', 'Infront', 'none', 'None' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'sqld', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep( $value eq $_, keys %choices ) )[0] || 'none' );
\\Z4\\Zb\\ZuMySQL Database Prefix/Suffix\\Zn

Do you want to use a prefix or suffix for customer's SQL databases?

\\Z4Infront:\\Zn A numeric prefix such as '1_' is added to each SQL user and database name.
 \\Z4Behind:\\Zn A numeric suffix such as '_1' is added to each SQL user and database name.
   \\Z4None\\Zn: Choice is left to the customer.
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'MYSQL_PREFIX', $value );
    0;
}

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    my $rs = $self->SUPER::preinstall();
    $rs ||= $self->_buildConf();
    $rs ||= $self->_setupMasterSqlUser();
    $rs ||= $self->_updateServerConfig();
    $rs ||= $self->_setupSecureInstallation();
    $rs ||= $self->_setupDatbase();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Sqld::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'mysql' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->_removeConfig();
    return $rs if $rs;

    eval {
        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->restart( 'mysql' ) if $serviceMngr->hasService( 'mysql' ) && $serviceMngr->isRunning( 'mysql' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'mysql' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'mysql' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'mysql' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'mysql' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _askSqlRootUser( )

 Ask for SQL root user

=cut

sub _askSqlRootUser
{
    my ($self, $dialog) = @_;

    my $hostname = main::setupGetQuestion(
        'DATABASE_HOST', index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == 0 ? '' : 'localhost'
    );

    if ( index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) != -1 && grep { $hostname eq $_ } ( 'localhost', '127.0.0.1', '::1' ) ) {
        $hostname = '';
    }

    my $port = main::setupGetQuestion( 'DATABASE_PORT', 3306 );
    my $user = main::setupGetQuestion( 'SQL_ROOT_USER', 'root' );
    my $pwd = main::setupGetQuestion( 'SQL_ROOT_PASSWORD' );

    if ( $hostname eq 'localhost' ) {
        for ( 'localhost', '127.0.0.1' ) {
            next if $self->_tryDbConnect( $_, $port, $user, $pwd );
            main::setupSetQuestion( 'DATABASE_HOST', $_ );
            main::setupSetQuestion( 'DATABASE_PORT', $port );
            main::setupSetQuestion( 'SQL_ROOT_USER', $user );
            main::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
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

    main::setupSetQuestion( 'DATABASE_HOST', idn_to_ascii( $hostname, 'utf-8' ) // '' );
    return $rs if $rs >= 30;

    do {
        ( $rs, $port ) = $dialog->inputbox( <<"EOF", $port );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL server port:
\\Z \\Zn
EOF
    } while $rs < 30 && !isNumber( $port ) || !isNumberInRange( $port, 1025, 65535 );

    main::setupSetQuestion( 'DATABASE_PORT', $port );
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

    main::setupSetQuestion( 'SQL_ROOT_USER', $user );
    return $rs if $rs >= 30;

    do {
        ( $rs, $pwd ) = $dialog->passwordbox( <<"EOF" );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your SQL root user password:
\\Z \\Zn
EOF
    } while $rs < 30 && !isNotEmpty( $pwd );

    main::setupSetQuestion( 'SQL_ROOT_PASSWORD', $pwd );
    return $rs if $rs >= 30;

    if ( my $connectError = $self->_tryDbConnect( $hostname, $port, $user, $pwd ) ) {
        chomp( $connectError );

        $rs = $dialog->msgbox( <<"EOF" );
\\Z1Connection to SQL server failed\\Zn

i-MSCP installer couldn't connect to SQL server using the following data:

\\Z4Host:\\Zn $hostname
\\Z4Port:\\Zn $port
\\Z4Username:\\Zn $user
\\Z4Password:\\Zn $pwd

Error was: \\Z1$connectError\\Zn
EOF
        goto &{_askSqlRootUser};
    }

    0;
}

=item _buildConf( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConf
{
    my ($self) = @_;

    eval {
        # Make sure that the conf.d directory exists
        iMSCP::Dir->new( dirname => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d" )->make( {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => 0755
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    # Build the my.cnf file
    my $rs = $self->{'eventManager'}->registerOne(
        'beforeMysqlBuildConfFile',
        sub {
            unless ( defined ${$_[0]} ) {
                ${$_[0]} = "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            } elsif ( ${$_[0]} !~ m%^!includedir\s+$_[5]->{'SQLD_CONF_DIR'}/conf.d/\n%m ) {
                ${$_[0]} .= "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            }

            0;
        }
    );
    $rs ||= $self->buildConfFile(
        ( -f "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" ? "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" : File::Temp->new() ),
        "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf",
        undef,
        undef,
        {
            srcname => 'my.cnf'
        }
    );
    return $rs if $rs;

    # Build the imscp.cnf file
    my $conffile = File::Temp->new();
    print $conffile <<'EOF';
# Configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
[mysql]
max_allowed_packet = {MAX_ALLOWED_PACKET}
[mysqld]
event_scheduler = {EVENT_SCHEDULER}
innodb_use_native_aio = {INNODB_USE_NATIVE_AIO}
max_connections = {MAX_CONNECTIONS}
max_allowed_packet = MAX_ALLOWED_PACKET}
performance_schema = {PERFORMANCE_SCHEMA}
sql_mode = {SQL_MODE}
EOF
    $conffile->close();
    $rs ||= $self->{'eventManager'}->registerOne(
        'beforeMysqlBuildConfFile',
        sub {
            return 0 unless version->parse( $self->getVersion()) >= version->parse( '5.7.4' );

            # For backward compatibility - We will review this in later version
            ${$_[0]} .= "default_password_lifetime = {DEFAULT_PASSWORD_LIFETIME}\n";
            $_[4]->{'DEFAULT_PASSWORD_LIFETIME'} = 0;
            0;
        }
    );
    $rs ||= $self->buildConfFile( $conffile, "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf", undef,
        {
            EVENT_SCHEDULER       => 'DISABLED',
            INNODB_USE_NATIVE_AIO => $main::imscpConfig{'SYSTEM_VIRTUALIZER'} ne 'physical' ? 0 : 1,
            MAX_CONNECTIONS       => 500,
            MAX_ALLOWED_PACKET    => '500M',
            PERFORMANCE_SCHEMA    => 0,
            SQL_MODE              => 0,
            SQLD_SOCK_DIR         => $self->{'config'}->{'SQLD_SOCK_DIR'}
        },
        {
            srcname => 'imscp.cnf'
        }
    );
}

=item _setupMasterSqlUser( )

 Setup master SQL user
 
 Return 0 on success, other on failure

=cut

sub _setupMasterSqlUser
{
    my ($self) = @_;

    my $user = main::setupGetQuestion( 'DATABASE_USER' );
    my $userHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldUserHost = $main::imscpOldConfig{'DATABASE_USER_HOST'};
    my $pwd = decryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, main::setupGetQuestion( 'DATABASE_PASSWORD' ));
    my $oldUser = $main::imscpOldConfig{'DATABASE_USER'};

    # Remove old user if any
    for my $sqlUser ( $oldUser, $user ) {
        next unless $sqlUser;

        for my $host( $userHost, $oldUserHost ) {
            next unless $host;
            $self->dropUser( $sqlUser, $host );
        }
    }

    # Create user
    $self->createUser( $user, $userHost, $pwd );

    # Grant all privileges to that user (including GRANT otpion)
    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'};
        $dbh->do( 'GRANT ALL PRIVILEGES ON *.* TO ?@? WITH GRANT OPTION', undef, $user, $userHost );
    };
    if ( $@ ) {
        error( sprintf( "Couldn't grant privileges to master i-MSCP SQL user: %s", $@ ));
        return 1;
    }

    0;
}

=item _updateServerConfig( )

 Update server configuration

  - Upgrade MySQL system tables if necessary
  - Disable unwanted plugins

 Return 0 on success, other on failure

=cut

sub _updateServerConfig
{
    my ($self) = @_;

    # Upgrade MySQL tables if necessary

    my $defaultExtraFile = File::Temp->new();
    print <<'EOF';
[mysql_upgrade]
host = {HOST}
port = {PORT}
user = {USER}
password = {PASSWORD}
EOF
    $defaultExtraFile->close();
    $self->buildConfFile( $defaultExtraFile, $defaultExtraFile, undef,
        {
            HOST     => main::setupGetQuestion( 'DATABASE_HOST' ),
            PORT     => main::setupGetQuestion( 'DATABASE_PORT' ),
            USER     => main::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
            PASSWORD => decryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, main::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
        },
        {
            srcname => 'default-extra-file'
        }
    );
    return $rs if $rs;

    $rs = execute( "/usr/bin/mysql_upgrade --defaults-extra-file=$defaultExtraFile", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( sprintf( "Couldn't upgrade SQL server system tables: %s", $stderr || 'Unknown error' )) if $rs;
    return $rs if $rs;

    # Disable unwanted plugins

    return 0 if version->parse( $self->getVersion()) < version->parse( '5.6.6' );

    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'};

        # Disable unwanted plugins (bc reasons)
        for ( qw/ cracklib_password_check simple_password_check validate_password / ) {
            $dbh->do( "UNINSTALL PLUGIN $_" ) if $dbh->selectrow_hashref( "SELECT name FROM mysql.plugin WHERE name = '$_'" );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _setupSecureInstallation( )

 Secure Installation
 
 Basically, this method do same job as the mysql_secure_installation script
  - Remove anonymous users
  - Remove remote sql root user (only for local server)
  - Remove test database if any
  - Reload privileges tables
  
  Return 0 on success, other on failure

=cut

sub _setupSecureInstallation
{
    my ($self) = @_;

    eval {
        my $db = iMSCP::Database->getInstance();
        my $oldDbName = $db->useDatabase( 'mysql' );

        my $dbh = $db->getRawDb();
        local $dbh->{'RaiseError'};

        $dbh->do( "DELETE FROM user WHERE User = ''" ); # Remove anonymous users
        $dbh->do( 'DROP DATABASE IF EXISTS `test`' ); # Remove test database if any
        $dbh->do( "DELETE FROM db WHERE Db = 'test' OR Db = 'test\\_%'" ); # Remove privileges on test database

        # Disallow remote root login
        if ( index( $main::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ) {
            $dbh->do( "DELETE FROM user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" );
        }

        $dbh->do( 'FLUSH PRIVILEGES' );
        $db->useDatabase( $oldDbName ) if $oldDbName;
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _setupDatbase( )

 Setup database
 
 Return 0 on success, other on failure

=cut

sub _setupDatbase
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );

    unless ( $self->_setupIsImscpDb( $dbName ) ) {
        # Buils database schema file
        my $dbSchemaFile = File::Temp->new();
        my $rs = $self->buildConfFile( "$main::imscpConfig{'CONF_DIR'}/database/database.sql", $dbSchemaFile, undef, { DATABASE_NAME => $dbName } );
        return $rs if $rs;

        # Build MySQL temporary conffile
        my $defaultExtraFile = File::Temp->new();
        print $defaultExtraFile <<'EOF';
[mysql]
host = {HOST}
port = {PORT}
user = {USER}
password = {PASSWORD}
EOF
        $conffile->close();
        $rs ||= $self->buildConfFile( $defaultExtraFile, $defaultExtraFile, undef,
            {
                HOST     => main::setupGetQuestion( 'DATABASE_HOST' ),
                PORT     => main::setupGetQuestion( 'DATABASE_PORT' ),
                USER     => main::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
                PASSWORD => decryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, main::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
            },
            {
                srcname => 'default-extra-file'
            }
        );
        return $rs if $rs;

        $rs = execute( "cat $dbSchemaFile | /usr/bin/mysql --defaults-extra-file=$defaultExtraFile", \ my $stdout, \ my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    # In all cases, we process database update. This is important because sometime developers forget to update the
    # database revision in the database.sql schema file.
    my $rs = execute( "/usr/bin/php7.1 -d date.timezone=UTC $main::imscpConfig{'ROOT_DIR'}/engine/setup/updDB.php", \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs
}

=item _setupIsImscpDb( $dbName )

 Is the given database an i-MSCP database?

 Return bool TRUE if database exists and look like an i-MSCP database, FALSE otherwise, croak on failure

=cut

sub _setupIsImscpDb
{
    my (undef, $dbName) = @_;

    return 0 unless defined $dbName && $dbName ne '';

    my $db = iMSCP::Database->getInstance();
    my $dbh = $db->getRawDb();

    local $dbh->{'RaiseError'} = 1;
    return 0 unless $dbh->selectrow_hashref( 'SHOW DATABASES LIKE ?', undef, $dbName );

    my $tables = $db->getDbTables( $dbName );
    ref $tables eq 'ARRAY' or croak( $tables );

    for my $table( qw/ server_ips user_gui_props reseller_props / ) {
        return 0 unless grep( $_ eq $table, @{$tables} );
    }

    1;
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/imscp.cnf" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/imscp.cnf" )->delFile();
        return $rs if $rs;
    }

    return 0 unless -f "$self->{'cfgDir'}/mysql.old.data";

    iMSCP::File->new( filename => "$self->{'cfgDir'}/mysql.old.data" )->delFile();
}

=item _removeConfig( )

 Remove imscp configuration file

 Return int 0 on success, other on failure

=cut

sub _removeConfig
{
    my ($self) = @_;

    return 0 unless -f "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf";

    iMSCP::File->new( filename => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf" )->delFile();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
