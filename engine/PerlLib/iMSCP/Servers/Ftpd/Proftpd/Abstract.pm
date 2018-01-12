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
                sub { $self->maxInstancesDialog( @_ ); }, sub { $self->maxCLientsPerHostDialog( @_ ); };
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
Please enter a password for the ProFTPD SQL user (leave empty for autogeneration):
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

    $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} = $passivePortRange;
    0;
}

=item maxInstancesDialog( \%dialog )

 Ask for ProFTPd max instances

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxInstancesDialog
{
    my ($self, $dialog) = @_;

    my $maxInstances = main::setupGetQuestion(
        'FTPD_MAX_INSTANCES', $self->{'config'}->{'FTPD_MAX_INSTANCES'} || ( iMSCP::Getopt->preseed ? '100' : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || ( $maxInstances ne 'none' && !isNumberInRange( $maxInstances, 1, 1000 ) )
    ) {
        my $rs = 0;

        do {
            if ( $maxInstances eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxInstances = 100;
            }

            ( $rs, $maxInstances ) = $dialog->inputbox( <<"EOF", $maxInstances );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPd max instances\\Zn

Please set maximum number of ProFTPd child processes to be spawned (leave empty for default).

Allowed value: 'none' or a number in range 1..1000
The 'none' value means no limit.

See http://www.proftpd.org/docs/directives/linked/config_ref_MaxInstances.html for more details.
\\Z \\Zn
EOF
        } while $rs < 30 || ( $maxInstances ne 'none' && !isNumberInRange( $maxInstances, 1, 1000 ) );

        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'FTPD_MAX_INSTANCES'} = $maxInstances;
    0;
}

=item maxClientPerHostDialog( \%dialog )

 Ask for ProFTPd max clients per host

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxClientPerHostDialog
{
    my ($self, $dialog) = @_;

    my $maxClients = main::setupGetQuestion(
        'FTPD_MAX_CLIENTS_PER_HOST', $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_HOST'} || ( iMSCP::Getopt->preseed ? '20' : '' )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || ( $maxClients ne 'none' && !isNumberInRange( $maxClients, 1, 1000 ) )
    ) {
        my $rs = 0;

        do {
            if ( $maxClients eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClients = 20;
            }

            ( $rs, $maxClients ) = $dialog->inputbox( <<"EOF", $maxClients );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuProFTPd max client per host\\Zn

Please set the maximum number of clients allowed to connect to ProFTPd per host (leave empty for default).

Allowed value: none or a number in range 1..1000
The 'none' value means no limit.

http://www.proftpd.org/docs/directives/linked/config_ref_MaxClientsPerHost.html
\\Z \\Zn
EOF
        } while $rs < 30 || ( $maxClients ne 'none' && !isNumberInRange( $maxClients, 1, 1000 ) );

        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_HOST'} = $maxClients;
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

    sprintf( 'ProFTPDd %s', $self->getVersion());
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
        debug( sprintf( "ProFTPD traffic %s log file doesn't exist. Skipping ...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing ProFTPD traffic %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or tie %{$trafficIndexDb}, 'iMSCP::Config', fileName => "$main::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ($idx, $idxContent) = ( $trafficIndexDb->{'proftpd_lineNo'} || 0, $trafficIndexDb->{'proftpd_lineContent'} );

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or croak( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    # Retain index of the last log (log file can continue growing)
    my $lastLogIdx = $#logs;

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping ProFTPD traffic logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( $idxContent ne '' && substr( $logFile, -2 ) ne '.1' ) {
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

    croak ( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _configure( )

 Configure ProFTPd

 return int 0 on succes, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeProftpdConfigure' );
    $rs ||= $self->_setupDatabase();
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
            FTPD_CERTIFICATE          => "$main::imscpConfig{'CONF_DIR'}/imscp_services.pem",
            FTPD_DATABASE_HOST        => main::setupGetQuestion( 'DATABASE_HOST' ),
            FTPD_DATABASE_NAME        => main::setupGetQuestion( 'DATABASE_NAME' ),
            FTPD_DATABASE_PORT        => main::setupGetQuestion( 'DATABASE_PORT' ),
            FTPD_HOSTNAME             => main::setupGetQuestion( 'SERVER_HOSTNAME' ),
            FTPD_IPV6_SUPPORT         => main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'on' : 'off',
            FTPD_MAX_INSTANCES        => $self->{'config'}->{'FTPD_MAX_INSTANCES'},
            FTPD_MAX_CLIENTS_PER_HOST => $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_HOST'},
            FTPD_MIN_UID              => $self->{'config'}->{'FTPD_MIN_UID'},
            FTPD_MIN_GID              => $self->{'config'}->{'FTPD_MIN_GID'},
            FTPD_PASSIVE_PORT_RANGE   => $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'},
            FTPD_BANNER               => $self->{'config'}->{'FTPD_BANNER'},
            FTPD_SSL_LOG_FILE         => $self->{'config'}->{'FTP_SSL_LOG_FILE'},
            # Escape any double-quotes and backslash (see #IP-1330)
            FTPD_SQL_PASSWORD         => '"' . $self->{'config'}->{'FTPD_SQL_PASSWORD'} =~ s%("|\\)%\\$1%gr . '"',
            # Escape any double-quotes and backslash (see #IP-1330)
            FTPD_SQL_USER             => '"' . $self->{'config'}->{'FTPD_SQL_USER'} =~ s%("|\\)%\\$1%gr . '"',
            FTPD_TLSOPTIONS           => 'NoCertRequest NoSessionReuseRequired'
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
        $rs = $self->buildConfFile(
            "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf",
            "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf",
            undef,
            undef,
            {
                mode => 0644
            }
        );
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterProftpdConfigure' );
}

=item _setupDatabase( )

 Setup database

 Return int 0 on success, other on failure

=cut

sub _setupDatabase
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = main::setupGetQuestion( 'FTPD_SQL_USER' );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion( 'FTPD_SQL_PASSWORD' );

    eval {
        my $sqlServer = iMSCP::Servers::Sqld->factory();

        # Drop old SQL user if required
        for my $sqlUser ( $self->{'config'}->{'FTPD_SQL_USER'}, $dbUser ) {
            next unless $sqlUser;

            for my $host( $dbUserHost, $main::imscpOldConfig{'DATABASE_USER_HOST'} ) {
                next if !$host || exists $main::sqlUsers{$sqlUser . '@' . $host} && !defined $main::sqlUsers{$sqlUser . '@' . $host};
                $sqlServer->dropUser( $sqlUser, $host );
            }
        }

        # Create SQL user if required
        if ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
            $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
            $main::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
        }

        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'} = 1;

        # Give required privileges to this SQL user
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
    my $dbUserHost = ( $main::execmode eq 'setup' ) ? $main::imscpOldConfig{'DATABASE_USER_HOST'} : $main::imscpConfig{'DATABASE_USER_HOST'};

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
