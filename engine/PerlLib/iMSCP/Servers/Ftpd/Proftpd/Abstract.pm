=head1 NAME

 iMSCP::Servers::Ftpd::Proftpd - i-MSCP ProFTPd Server abstract implementation

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

package iMSCP::Servers::Ftpd::Proftpd::Abstract;

use strict;
use warnings;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Crypt' => qw/ ALNUM randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isAvailableSqlUser isNumberInRange isOneOfStringsInList isStringNotInList isValidNumberRange
        isValidPassword isValidUsername /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use autouse 'iMSCP::TemplateParser' => qw/ processByRef /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Database iMSCP::File iMSCP::Getopt iMSCP::Servers::Sqld /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use parent 'iMSCP::Servers::Ftpd';

%main::sqlUsers = () unless %main::sqlUsers;

=head1 DESCRIPTION

 i-MSCP ProFTPd Server abstract implementation.

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
            push @{$_[0]}, sub { $self->sqlUserDialog( @_ ); }, sub { $self->passivePortRangeDialog( @_ ); },
                sub { $self->maxClientsDialog( @_ ); }, sub { $self->maxCLientsPerIpDialog( @_ ); };
            0;
        },
        $self->getPriority()
    );
}

=item sqlUserDialog( \%dialog )

 Ask for ProFTPd SQL user

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub sqlUserDialog
{
    my ($self, $dialog) = @_;

    my $masterSqlUser = main::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = main::setupGetQuestion( 'FTPD_SQL_USER', $self->{'config'}->{'FTPD_SQL_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' ));
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion(
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
            if ( $dbUser eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $dbUser = 'imscp_srv_user';
            }

            ( $rs, $dbUser ) = $dialog->inputbox( <<"EOF", $dbUser );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the ProFTPd SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'FTPD_SQL_USER', $dbUser );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] ) || !isValidPassword( $dbPass ) ) {
        unless ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            my $rs = 0;

            do {
                if ( $dbPass eq '' ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $dbPass = randomStr( 16, ALNUM );
                }

                ( $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the ProFTPd SQL user (leave empty for autogeneration):
\\Z \\Zn
EOF
            } while $rs < 30 && !isValidPassword( $dbPass );

            return $rs unless $rs < 30;

            $main::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $main::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $main::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $main::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    main::setupSetQuestion( 'FTPD_SQL_PASSWORD', $dbPass );
    0;
}

=item passivePortRangeDialog( \%dialog )

 Ask for ProFTPd port range to use for passive data transfers

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub passivePortRangeDialog
{
    my ($self, $dialog) = @_;

    my $passivePortRange = main::setupGetQuestion(
        'FTPD_PASSIVE_PORT_RANGE', $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} || ( iMSCP::Getopt->preseed ? '32768 60999' : '' )
    );
    my ($startOfRange, $endOfRange);

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || !isValidNumberRange( $passivePortRange, \$startOfRange, \$endOfRange )
        || !isNumberInRange( $startOfRange, 32768, 60999 )
        || !isNumberInRange( $endOfRange, $startOfRange, 60999 )
    ) {
        my $rs = 0;

        do {
            if ( $passivePortRange eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $passivePortRange = '32768 60999';
            }

            ( $rs, $passivePortRange ) = $dialog->inputbox( <<"EOF", $passivePortRange );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPd passive port range\\Zn

Please enter the passive port range for ProFTPd (leave empty for default).

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

    main::setupSetQuestion( 'FTPD_PASSIVE_PORT_RANGE', $passivePortRange );
    $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} = $passivePortRange;
    0;
}

=item maxClientsDialog( \%dialog )

 Ask for ProFTPd max clients

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxClientsDialog
{
    my ($self, $dialog) = @_;

    my $maxClients = main::setupGetQuestion(
        'FTPD_MAX_CLIENTS', $self->{'config'}->{'FTPD_MAX_CLIENTS'} // ( iMSCP::Getopt->preseed ? 100 : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] ) || !isNumberInRange( $maxClients, 0, 1000 ) ) {
        my $rs = 0;

        do {
            if ( $maxClients eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClients = 100;
            }

            ( $rs, $maxClients ) = $dialog->inputbox( <<"EOF", $maxClients );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPd max clients\\Zn

Please set the maximum number of ProFTPd clients (leave empty for default).

Allowed value: A number in range 0..1000, 0 for no limit.
\\Z \\Zn
EOF
        } while $rs < 30 && !isNumberInRange( $maxClients, 0, 1000 );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'FTPD_MAX_CLIENTS', $maxClients );
    $self->{'config'}->{'FTPD_MAX_CLIENTS'} = $maxClients;
    0;
}

=item maxCLientsPerIpDialog( \%dialog )

 Ask for ProFTPd max clients per IP

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxCLientsPerIpDialog
{
    my ($self, $dialog) = @_;

    my $maxClientsPerIp = main::setupGetQuestion(
        'FTPD_MAX_CLIENTS_PER_IP', $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} // ( iMSCP::Getopt->preseed ? 5 : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || !isNumberInRange( $maxClientsPerIp, 0, 1000 )
    ) {
        my $rs = 0;

        do {
            if ( $maxClientsPerIp eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClientsPerIp = 5;
            }

            ( $rs, $maxClientsPerIp ) = $dialog->inputbox( <<"EOF", $maxClientsPerIp );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPd max client per IP\\Zn

Please set the maximum number of clients allowed to connect to ProFTPd per IP (leave empty for default).

Allowed value: A number in range 0..1000, 0 for no limit.
\\Z \\Zn
EOF
        } while $rs < 30 && !isNumberInRange( $maxClientsPerIp, 1, 1000 );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'FTPD_MAX_CLIENTS_PER_IP', ${$maxClientsPerIp} );
    $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} = $maxClientsPerIp;
    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->_setVersion();
    $rs ||= $self->_configure();
}

=item uninstall( )

 iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    $self->_dropSqlUser();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    setRights( "$self->{'config'}->{'FTPD_CONF_DIR'}/proftpd.conf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
}

=item getEventServerName( )

 See iMSCP::Servers::Abstract::getEventServerName()

=cut

sub getEventServerName
{
    my ($self) = @_;

    'Proftpd';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'ProFTPd %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

    $self->{'config'}->{'FTPD_VERSION'};
}

=item addUser( \%moduleData )

 See iMSCP::Servers::Ftpd::addUser()

=cut

sub addUser
{
    my ($self, $moduleData) = @_;

    return 0 if $moduleData->{'STATUS'} eq 'tochangepwd';

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdAddUser', $moduleData );
    return $rs if $rs;

    my $dbh = iMSCP::Database->getInstance()->getRawDb();

    eval {
        local $dbh->{'RaiseError'} = 1;
        $dbh->begin_work();
        $dbh->do(
            'UPDATE ftp_users SET uid = ?, gid = ? WHERE admin_id = ?',
            undef, $moduleData->{'USER_SYS_UID'}, $moduleData->{'USER_SYS_GID'}, $moduleData->{'USER_ID'}
        );
        $dbh->do( 'UPDATE ftp_group SET gid = ? WHERE groupname = ?',
            undef, $moduleData->{'USER_SYS_GID'}, $moduleData->{'USERNAME'} );
        $dbh->commit();
    };
    if ( $@ ) {
        $dbh->rollback();
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'AfterProftpdAddUser', $moduleData );
}

=item addFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::addFtpUser()

=cut

sub addFtpUser
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdAddFtpUser', $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterProftpdAddFtpUser', $moduleData );
}

=item disableFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::disableFtpUser()

=cut

sub disableFtpUser
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdDisableFtpUser', $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterProftpdDisableFtpUser', $moduleData );
}

=item deleteFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::deleteFtpUser()

=cut

sub deleteFtpUser
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdDeleteFtpUser', $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterProftpdDeleteFtpUser', $moduleData );
}

=item getTraffic( $trafficDb [, $logFile, $trafficIndexDb ] )

 See iMSCP::Servers::Abstract::getTraffic()

=cut

sub getTraffic
{
    my ($self, $trafficDb, $logFile, $trafficIndexDb) = @_;
    $logFile ||= $self->{'config'}->{'FTPD_TRAFFIC_LOG_FILE'};

    unless ( -f $logFile ) {
        debug( sprintf( "ProFTPd traffic %s log file doesn't exist. Skipping ...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing ProFTPd traffic %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or tie %{$trafficIndexDb}, 'iMSCP::Config', fileName => "$main::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ($idx, $idxContent) = ( $trafficIndexDb->{'proftpd_lineNo'} || 0, $trafficIndexDb->{'proftpd_lineContent'} );

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or croak( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    # Retain index of the last log (log file can continue growing)
    my $lastLogIdx = $#logs;

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping ProFTPd traffic logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( $idxContent ne '' && substr( $logFile, -2 ) ne '.1' ) {
        debug( 'Log rotation has been detected. Processing last rotated log file first' );
        $self->getTraffic( $trafficDb, $logFile . '.1', $trafficIndexDb );
        $idx = 0;
    }

    if ( $lastLogIdx < $idx ) {
        debug( 'No new ProFTPd traffic logs found for processing' );
        return;
    }

    debug( sprintf( 'Processing ProFTPd traffic logs (lines %d to %d)', $idx+1, $lastLogIdx+1 ));

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
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ restart reload cfgDir /} = ( 0, 0, "$main::imscpConfig{'CONF_DIR'}/proftpd" );
    $self->_loadConfig( 'proftpd.data' );
    $self->SUPER::_init();
}

=item _setVersion

 Set ProFTPd version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ $self->{'config'}->{'FTPD_BIN'}, '-v' ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /([\d.]+)/ ) {
        error( "Couldn't find ProFTPD version from the `$self->{'config'}->{'FTPD_BIN'} -v` command output" );
        return 1;
    }

    $self->{'config'}->{'FTPD_VERSION'} = $1;
    debug( "ProFTPD version set to: $1" );
    0;
}

=item _configure( )

 Configure ProFTPd

 return int 0 on succes, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdConfigure' );
    $rs ||= $self->_setupSqlUser();
    $rs ||= $self->{'eventManager'}->registerOne(
        'beforeProftpdBuildConfFile',
        sub {
            if ( main::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ) {
                ${$_[0]} .= <<'EOF';

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

            my $baseServerIp = main::setupGetQuestion( 'BASE_SERVER_IP' );
            my $baseServerPublicIp = main::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );

            if ( $baseServerIp ne $baseServerPublicIp ) {
                my @virtualHostIps = grep(
                    $_ ne '0.0.0.0', ( '127.0.0.1', ( main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? '::1' : () ), $baseServerIp )
                );

                ${$_[0]} .= <<"EOF";

# Server behind NAT - Advertise public IP address
MasqueradeAddress $baseServerPublicIp

 VirtualHost for local access (No IP masquerading)
<VirtualHost @virtualHostIps>
    ServerName "{HOSTNAME}.local"
</VirtualHost>
EOF
            }

            0;
        }
    );
    $rs ||= $self->buildConfFile( 'proftpd.conf', "$self->{'config'}->{'FTPD_CONF_DIR'}/proftpd.conf", undef,
        {
            FTPD_BANNER             => $self->{'config'}->{'FTPD_BANNER'},
            FTPD_CERTIFICATE        => "$main::imscpConfig{'CONF_DIR'}/imscp_services.pem",
            FTPD_DATABASE_HOST      => main::setupGetQuestion( 'DATABASE_HOST' ),
            FTPD_DATABASE_NAME      => main::setupGetQuestion( 'DATABASE_NAME' ),
            FTPD_DATABASE_PORT      => main::setupGetQuestion( 'DATABASE_PORT' ),
            FTPD_HOSTNAME           => main::setupGetQuestion( 'SERVER_HOSTNAME' ),
            FTPD_IPV6_SUPPORT       => main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'on' : 'off',
            FTPD_MAX_CLIENTS        => $self->{'config'}->{'FTPD_MAX_CLIENTS'} ? $self->{'config'}->{'FTPD_MAX_CLIENTS'} : 'none',
            FTPD_MAX_CLIENTS_PER_IP => $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} ? $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} : 'none',
            FTPD_MIN_UID            => $self->{'config'}->{'FTPD_MIN_UID'},
            FTPD_MIN_GID            => $self->{'config'}->{'FTPD_MIN_GID'},
            FTPD_PASSIVE_PORT_RANGE => $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'},
            FTPD_SSL_LOG_FILE       => $self->{'config'}->{'FTP_SSL_LOG_FILE'},
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
    return $rs if $rs;

    if ( -f "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf" ) {
        $rs = $self->{'eventManager'}->registerOne(
            'beforeProftpdBuildConfFile',
            sub {
                ${$_[0]} =~ s/^(LoadModule\s+mod_tls_memcache.c)/#$1/m;
                0;
            }
        );
        $rs = $self->buildConfFile( "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf", "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf", undef,
            undef, { mode => 0644 }
        );
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterProftpdConfigure' );
}

=item _setupSqlUser( )

 Setup SQL user for ProFTPd

 Return int 0 on success, other on failure

=cut

sub _setupSqlUser
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = main::setupGetQuestion( 'FTPD_SQL_USER' );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion( 'FTPD_SQL_PASSWORD' );

    eval {
        my $sqlServer = iMSCP::Servers::Sqld->factory();

        # Drop old SQL user if required
        if ( ( $self->{'config'}->{'FTPD_SQL_USER'} ne '' && $self->{'config'}->{'FTPD_SQL_USER'} ne $dbUser )
            || ( $main::imscpOldConfig{'DATABASE_USER_HOST'} ne '' && $main::imscpOldConfig{'DATABASE_USER_HOST'} ne $dbUserHost )
        ) {
            for ( $dbUserHost, $main::imscpOldConfig{'DATABASE_USER_HOST'} ) {
                next if $_ eq '' || exists $main::sqlUsers{$self->{'config'}->{'FTPD_SQL_USER'} . '@' . $_};
                $sqlServer->dropUser( $self->{'config'}->{'FTPD_SQL_USER'}, $_ );
            }
        }

        # Create/update SQL user if needed
        if ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
            $main::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
        }

        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'} = 1;

        # GRANT privileges to the SQL user
        # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
        my $quotedDbName = $dbh->quote_identifier( $dbName );

        $dbh->do( "GRANT SELECT ON $quotedDbName.$_ TO ?\@?", undef, $dbUser, $dbUserHost ) for qw / ftp_user ftp_group /;
        $dbh->do( "GRANT SELECT, INSERT, UPDATE ON $quotedDbName.$_ TO ?\@?", undef, $dbUser, $dbUserHost ) for qw/ quotalimits quotatallies /;

    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'config'}->{'FTPD_SQL_USER'} = $dbUser;
    $self->{'config'}->{'FTPD_SQL_PASSWORD'} = $dbPass;
    0;
}

=item _dropSqlUser( )

 Drop SQL user

 Return int 0 on success, 1 on failure

=cut

sub _dropSqlUser
{
    my ($self) = @_;

    # In setup context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer'
        ? $main::imscpOldConfig{'DATABASE_USER_HOST'} : $main::imscpConfig{'DATABASE_USER_HOST'};

    return 0 unless $self->{'config'}->{'FTPD_SQL_USER'} && $dbUserHost;

    eval { iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'FTPD_SQL_USER'}, $dbUserHost ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
