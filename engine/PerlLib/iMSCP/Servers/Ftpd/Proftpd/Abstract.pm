=head1 NAME

 iMSCP::Servers::Ftpd::Proftpd - i-MSCP ProFTPD Server abstract implementation

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

package iMSCP::Servers::Ftpd::Proftpd::Abstract;

use strict;
use warnings;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Crypt' => qw/ ALNUM randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isAvailableSqlUser isNumberInRange isOneOfStringsInList isStringNotInList isValidNumberRange
    isValidPassword isValidUsername /;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Database iMSCP::Getopt iMSCP::Servers::Sqld /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug /;
use parent 'iMSCP::Servers::Ftpd';

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 i-MSCP ProFTPD Server abstract implementation.

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
            push @{ $_[0] }, sub { $self->sqlUserDialog( @_ ); }, sub { $self->passivePortRangeDialog( @_ ); }, sub { $self->maxClientsDialog( @_ ); },
                sub { $self->maxCLientsPerIpDialog( @_ ); };
        },
        $self->getPriority()
    );
}

=item sqlUserDialog( \%dialog )

 Ask for ProFTPD SQL user

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub sqlUserDialog
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'FTPD_SQL_USER', $self->{'config'}->{'FTPD_SQL_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' ));
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'FTPD_SQL_PASSWORD', ( iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'FTPD_SQL_PASSWORD'} )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
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
Please enter a username for the ProFTPD SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'FTPD_SQL_USER', $dbUser );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] ) || !isValidPassword( $dbPass ) ) {
        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            my $rs = 0;

            do {
                unless ( length $dbPass ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $dbPass = randomStr( 16, ALNUM );
                }

                ( $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the ProFTPD SQL user (leave empty for autogeneration):
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

    ::setupSetQuestion( 'FTPD_SQL_PASSWORD', $dbPass );
    0;
}

=item passivePortRangeDialog( \%dialog )

 Ask for ProFTPD port range to use for passive data transfers

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub passivePortRangeDialog
{
    my ( $self, $dialog ) = @_;

    my $passivePortRange = ::setupGetQuestion(
        'FTPD_PASSIVE_PORT_RANGE', $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} || ( iMSCP::Getopt->preseed ? '32768 60999' : '' )
    );
    my ( $startOfRange, $endOfRange );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || !isValidNumberRange( $passivePortRange, \$startOfRange, \$endOfRange )
        || !isNumberInRange( $startOfRange, 32768, 60999 )
        || !isNumberInRange( $endOfRange, $startOfRange, 60999 )
    ) {
        my $rs = 0;

        do {
            unless ( length $passivePortRange ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $passivePortRange = '32768 60999';
            }

            ( $rs, $passivePortRange ) = $dialog->inputbox( <<"EOF", $passivePortRange );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPD passive port range\\Zn

Please enter the passive port range for ProFTPD (leave empty for default).

Note that if you're behind a NAT, you must forward those ports to this server.
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidNumberRange( $passivePortRange, \$startOfRange, \$endOfRange )
            || !isNumberInRange( $startOfRange, 32768, 60999 )
            || !isNumberInRange( $endOfRange, $startOfRange, 60999 )
        );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'FTPD_PASSIVE_PORT_RANGE', $passivePortRange );
    $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} = $passivePortRange;
    0;
}

=item maxClientsDialog( \%dialog )

 Ask for ProFTPD max clients

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxClientsDialog
{
    my ( $self, $dialog ) = @_;

    my $maxClients = ::setupGetQuestion(
        'FTPD_MAX_CLIENTS',
        length $self->{'config'}->{'FTPD_MAX_CLIENTS'} ? $self->{'config'}->{'FTPD_MAX_CLIENTS'} : ( iMSCP::Getopt->preseed ? 100 : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] ) || !isNumberInRange( $maxClients, 0, 1000 ) ) {
        my $rs = 0;

        do {
            unless ( length $maxClients ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClients = 100;
            }

            ( $rs, $maxClients ) = $dialog->inputbox( <<"EOF", $maxClients );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPD max clients\\Zn

Please set the maximum number of ProFTPD clients (leave empty for default).

Allowed value: A number in range 1..1000, 0 for no limit.
\\Z \\Zn
EOF
        } while $rs < 30 && !isNumberInRange( $maxClients, 0, 1000 );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'FTPD_MAX_CLIENTS', $maxClients );
    $self->{'config'}->{'FTPD_MAX_CLIENTS'} = $maxClients;
    0;
}

=item maxCLientsPerIpDialog( \%dialog )

 Ask for ProFTPD max clients per IP

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxCLientsPerIpDialog
{
    my ( $self, $dialog ) = @_;

    my $maxClientsPerIp = ::setupGetQuestion(
        'FTPD_MAX_CLIENTS_PER_IP',
        length $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} ? $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} :  ( iMSCP::Getopt->preseed ? 20 : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || !isNumberInRange( $maxClientsPerIp, 0, 1000 )
    ) {
        my $rs = 0;

        do {
            unless ( length $maxClientsPerIp ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClientsPerIp = 20;
            }

            ( $rs, $maxClientsPerIp ) = $dialog->inputbox( <<"EOF", $maxClientsPerIp );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPD max client per IP\\Zn

Please set the maximum number of clients allowed to connect to ProFTPD per IP (leave empty for default).

Allowed value: A number in range 0..1000, 0 for no limit.
\\Z \\Zn
EOF
        } while $rs < 30 && !isNumberInRange( $maxClientsPerIp, 0, 1000 );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'FTPD_MAX_CLIENTS_PER_IP', $maxClientsPerIp );
    $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} = $maxClientsPerIp;
    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setVersion();
    $self->_configure();
}

=item uninstall( )

 iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_dropSqlUser();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( "$self->{'config'}->{'FTPD_CONF_DIR'}/proftpd.conf",
        {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Proftpd';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'ProFTPD %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'FTPD_VERSION'};
}

=item addUser( \%moduleData )

 See iMSCP::Servers::Ftpd::addUser()

=cut

sub addUser
{
    my ( $self, $moduleData ) = @_;

    return if $moduleData->{'STATUS'} eq 'tochangepwd';

    $self->{'eventManager'}->trigger( 'beforeProftpdAddUser', $moduleData );

    my $dbh = iMSCP::Database->getInstance();

    eval {
        $dbh->begin_work();
        $dbh->do(
            'UPDATE ftp_users SET uid = ?, gid = ? WHERE admin_id = ?',
            undef, $moduleData->{'USER_SYS_UID'}, $moduleData->{'USER_SYS_GID'}, $moduleData->{'USER_ID'}
        );
        $dbh->do( 'UPDATE ftp_group SET gid = ? WHERE groupname = ?', undef, $moduleData->{'USER_SYS_GID'}, $moduleData->{'USERNAME'} );
        $dbh->commit();
    };
    if ( $@ ) {
        $dbh->rollback();
        die;
    }

    $self->{'eventManager'}->trigger( 'AfterProftpdAddUser', $moduleData );
}

=item addFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::addFtpUser()

=cut

sub addFtpUser
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeProftpdAddFtpUser', $moduleData );
    $self->{'eventManager'}->trigger( 'afterProftpdAddFtpUser', $moduleData );
}

=item disableFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::disableFtpUser()

=cut

sub disableFtpUser
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeProftpdDisableFtpUser', $moduleData );
    $self->{'eventManager'}->trigger( 'afterProftpdDisableFtpUser', $moduleData );
}

=item deleteFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::deleteFtpUser()

=cut

sub deleteFtpUser
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeProftpdDeleteFtpUser', $moduleData );
    $self->{'eventManager'}->trigger( 'afterProftpdDeleteFtpUser', $moduleData );
}

=item getTraffic( $trafficDb [, $logFile, $trafficIndexDb ] )

 See iMSCP::Servers::Abstract::getTraffic()

=cut

sub getTraffic
{
    my ( $self, $trafficDb, $logFile, $trafficIndexDb ) = @_;
    $logFile ||= $self->{'config'}->{'FTPD_TRAFFIC_LOG_FILE'};

    unless ( -f $logFile ) {
        debug( sprintf( "ProFTPD traffic %s log file doesn't exist. Skipping...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing ProFTPD traffic %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or tie %{ $trafficIndexDb }, 'iMSCP::Config', filename => "$::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ( $idx, $idxContent ) = ( $trafficIndexDb->{'proftpd_lineNo'} || 0, $trafficIndexDb->{'proftpd_lineContent'} );

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or die( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    # Retain index of the last log (log file can continue growing)
    my $lastLogIdx = $#logs;

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping ProFTPD traffic logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( length $idxContent && substr( $logFile, -2 ) ne '.1' ) {
        debug( 'Log rotation has been detected. Processing last rotated log file first' );
        $self->getTraffic( $trafficDb, $logFile . '.1', $trafficIndexDb );
        $idx = 0;
    }

    if ( $lastLogIdx < $idx ) {
        debug( 'No new ProFTPD traffic logs found for processing' );
        return;
    }

    debug( sprintf( 'Processing ProFTPD traffic logs (lines %d to %d)', $idx+1, $lastLogIdx+1 ));

    my $regexp = qr/^(?:[^\s]+\s){7}(?<bytes>\d+)\s(?:[^\s]+\s){5}[^\s]+\@(?<domain>[^\s]+)/;

    # In term of memory usage, C-Style loop provide better results than using 
    # range operator in Perl-Style loop: for( @logs[$idx .. $lastLogIdx] ) ...
    for ( my $i = $idx; $i <= $lastLogIdx; $i++ ) {
        next unless $logs[$i] =~ /$regexp/ && exists $trafficDb->{$+{'domain'}};
        $trafficDb->{$+{'domain'}} += $+{'bytes'};
    }

    return if substr( $logFile, -2 ) eq '.1';

    $trafficIndexDb->{'proftpd_lineNo'} = $lastLogIdx;
    $trafficIndexDb->{'proftpd_lineContent'} = $logs[$lastLogIdx];
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Ftpd::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{ $self }{qw/ restart reload cfgDir /} = ( 0, 0, "$::imscpConfig{'CONF_DIR'}/proftpd" );
    $self->SUPER::_init();
}

=item _setVersion

 Set ProFTPD version

 Return void, die on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( [ $self->{'config'}->{'FTPD_BIN'}, '-v' ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /([\d.]+)/ or die( "Couldn't find ProFTPD version from the `$self->{'config'}->{'FTPD_BIN'} -v` command output" );
    $self->{'config'}->{'FTPD_VERSION'} = $1;
    debug( "ProFTPD version set to: $1" );
}

=item _configure( )

 Configure ProFTPD

 Return void, die on failure

=cut

sub _configure
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeProftpdConfigure' );
    $self->_setupSqlUser();
    $self->{'eventManager'}->registerOne(
        'beforeProftpdBuildConfFile',
        sub {
            if ( ::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ) {
                ${ $_[0] } .= <<'EOF';

# SSL configuration
<Global>
<IfModule mod_tls.c>
  TLSEngine                on
  TLSRequired              off
  TLSLog                   {FTPD_SSL_LOG_FILE}
  TLSOptions               {FTPD_TLSOPTIONS}
  TLSRSACertificateFile    {FTPD_CERTIFICATE}
  TLSRSACertificateKeyFile {FTPD_CERTIFICATE}
  TLSVerifyClient          off
</IfModule>
</Global>
<IfModule mod_tls.c>
  TLSProtocol TLSv1
</IfModule>
EOF
            }

            my $baseServerIp = ::setupGetQuestion( 'BASE_SERVER_IP' );
            my $baseServerPublicIp = ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );

            return unless $baseServerIp ne $baseServerPublicIp;

            my @virtualHostIps = grep (
                $_ ne '0.0.0.0', ( '127.0.0.1', ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? '::1' : () ), $baseServerIp )
            );

            ${ $_[0] } .= <<"EOF";

# Server behind NAT - Advertise public IP address
MasqueradeAddress $baseServerPublicIp

# VirtualHost for local access (No IP masquerading)
<VirtualHost @virtualHostIps>
    ServerName "{FTPD_HOSTNAME}.local"
</VirtualHost>
EOF

        }
    );
    $self->buildConfFile( 'proftpd.conf', "$self->{'config'}->{'FTPD_CONF_DIR'}/proftpd.conf", undef,
        {
            FTPD_BANNER             => $self->{'config'}->{'FTPD_BANNER'},
            FTPD_CERTIFICATE        => "$::imscpConfig{'CONF_DIR'}/imscp_services.pem",
            FTPD_DATABASE_HOST      => ::setupGetQuestion( 'DATABASE_HOST' ),
            FTPD_DATABASE_NAME      => ::setupGetQuestion( 'DATABASE_NAME' ),
            FTPD_DATABASE_PORT      => ::setupGetQuestion( 'DATABASE_PORT' ),
            FTPD_HOSTNAME           => ::setupGetQuestion( 'SERVER_HOSTNAME' ),
            FTPD_IPV6_SUPPORT       => ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'on' : 'off',
            FTPD_MAX_CLIENTS        => $self->{'config'}->{'FTPD_MAX_CLIENTS'} || 'none',
            FTPD_MAX_CLIENTS_PER_IP => $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} || 'none',
            FTPD_MIN_UID            => $self->{'config'}->{'FTPD_MIN_UID'},
            FTPD_MIN_GID            => $self->{'config'}->{'FTPD_MIN_GID'},
            FTPD_PASSIVE_PORT_RANGE => $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'},
            FTPD_SSL_LOG_FILE       => $self->{'config'}->{'FTPD_SSL_LOG_FILE'},
            # Escape any double-quotes and backslash (see #IP-1330)
            FTPD_SQL_PASSWORD       => '"' . $self->{'config'}->{'FTPD_SQL_PASSWORD'} =~ s%("|\\)%\\$1%gr . '"',
            # Escape any double-quotes and backslash (see #IP-1330)
            FTPD_SQL_USER           => '"' . $self->{'config'}->{'FTPD_SQL_USER'} =~ s%("|\\)%\\$1%gr . '"',
            FTPD_TLSOPTIONS         => 'NoCertRequest NoSessionReuseRequired'
        },
        {
            umask => 0027,
            mode  => 0640
        }
    );

    if ( -f "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf" ) {
        $self->{'eventManager'}->registerOne(
            'beforeProftpdBuildConfFile',
            sub {
                ${ $_[0] } =~ s/^(LoadModule\s+mod_tls_memcache.c)/#$1/m;
                0;
            }
        );
        $self->buildConfFile( "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf", "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf", undef,
            undef, { mode => 0644 }
        );
    }

    $self->{'eventManager'}->trigger( 'afterProftpdConfigure' );
}

=item _setupSqlUser( )

 Setup SQL user for ProFTPD

 Return void, die on failure

=cut

sub _setupSqlUser
{
    my ( $self ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = ::setupGetQuestion( 'FTPD_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion( 'FTPD_SQL_PASSWORD' );

    my $sqlServer = iMSCP::Servers::Sqld->factory();

    # Drop old SQL user if required
    if ( ( length $self->{'config'}->{'FTPD_SQL_USER'} && $self->{'config'}->{'FTPD_SQL_USER'} ne $dbUser )
        || ( length $::imscpOldConfig{'DATABASE_USER_HOST'} && $::imscpOldConfig{'DATABASE_USER_HOST'} ne $dbUserHost )
    ) {
        for my $host ( $dbUserHost, $::imscpOldConfig{'DATABASE_USER_HOST'} ) {
            next if !length $host || exists $::sqlUsers{$self->{'config'}->{'FTPD_SQL_USER'} . '@' . $host};
            $sqlServer->dropUser( $self->{'config'}->{'FTPD_SQL_USER'}, $host );
        }
    }

    # Create/update SQL user if needed
    if ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
    }

    my $dbh = iMSCP::Database->getInstance();

    # GRANT privileges to the SQL user
    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    my $quotedDbName = $dbh->quote_identifier( $dbName );

    $dbh->do( "GRANT SELECT ON $quotedDbName.$_ TO ?\@?", undef, $dbUser, $dbUserHost ) for qw/ ftp_users ftp_group /;
    $dbh->do( "GRANT SELECT, INSERT, UPDATE ON $quotedDbName.$_ TO ?\@?", undef, $dbUser, $dbUserHost ) for qw/ quotalimits quotatallies /;

    $self->{'config'}->{'FTPD_SQL_USER'} = $dbUser;
    $self->{'config'}->{'FTPD_SQL_PASSWORD'} = $dbPass;
}

=item _dropSqlUser( )

 Drop SQL user

 Return void, die on failure

=cut

sub _dropSqlUser
{
    my ( $self ) = @_;

    # In installer context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer' ? $::imscpOldConfig{'DATABASE_USER_HOST'} : $::imscpConfig{'DATABASE_USER_HOST'};

    return unless $self->{'config'}->{'FTPD_SQL_USER'} && $dbUserHost;

    iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'FTPD_SQL_USER'}, $dbUserHost );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
