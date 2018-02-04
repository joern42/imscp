=head1 NAME

 iMSCP::Servers::Ftpd::vsftpd - i-MSCP VsFTPd Server abstract implementation

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

package iMSCP::Servers::Ftpd::Vsftpd::Abstract;

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
use iMSCP::File;
use parent 'iMSCP::Servers::Ftpd';

%main::sqlUsers = () unless %main::sqlUsers;

=head1 DESCRIPTION

 i-MSCP VsFTPd Server abstract implementation.

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
            push @{$_[0]}, sub { $self->sqlUserDialog( @_ ); }, sub { $self->passivePortRangeDialog( @_ ); }, sub { $self->maxClientsDialog( @_ ); },
                sub { $self->maxCLientsPerIpDialog( @_ ); };
        },
        $self->getPriority()
    );
}

=item sqlUserDialog( \%dialog )

 Show dialog

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
Please enter a username for the VsFTPd SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
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
Please enter a password for the VsFTPd SQL user (leave empty for autogeneration):
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

 Ask for VsFTPd port range to use for passive data transfers

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
\\Z4\\Zb\\ZuVsFTPd passive port range\\Zn

Please enter the passive port range for VsFTPd.

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

 Ask for VsFTPd max clients

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub maxClientsDialog
{
    my ($self, $dialog) = @_;

    my $maxClients = main::setupGetQuestion( 'FTPD_MAX_CLIENTS', $self->{'config'}->{'FTPD_MAX_CLIENTS'} // ( iMSCP::Getopt->preseed ? 100 : '' ));

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'servers', 'all', 'forced' ] )
        || !isNumberInRange( $maxClients, 0, 1000 )
    ) {
        my $rs = 0;

        do {
            if ( $maxClients eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $maxClients = 100;
            }

            ( $rs, $maxClients ) = $dialog->inputbox( <<"EOF", $maxClients );
$iMSCP::Dialog::InputValidation::lastValidationError
\\Z4\\Zb\\ZuVsFTPd max clients\\Zn

Please set the maximum number of VsFTPd clients (leave empty for default).

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

 Ask for VsFTPd max clients per IP

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
\\Z4\\Zb\\ZuVsFTPd max client per IP\\Zn

Please set the maximum number of clients allowed to connect to VsFTPd per IP (leave empty for default).

Allowed value: A number in range 0..1000, 0 for no limit.
\\Z \\Zn
EOF
        } while $rs < 30 && !isNumberInRange( $maxClientsPerIp, 0, 1000 );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'FTPD_MAX_CLIENTS_PER_IP', $maxClientsPerIp );
    $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'} = $maxClientsPerIp;
    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    $self->_setVersion();
    $self->_configure();
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

    setRights( "$self->{'config'}->{'FTPD_USER_CONF_DIR'}",
        {
            user      => $main::imscpConfig{'ROOT_USER'},
            group     => $main::imscpConfig{'ROOT_GROUP'},
            dirmode   => '0750',
            filemode  => '0640',
            recursive => 1
        }
    );
    setRights( "$self->{'config'}->{'FTPD_CONF_DIR'}/vsftpd.conf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ($self) = @_;

    'Vsftpd';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'VsFTPd %s', $self->getVersion());
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

    return if $moduleData->{'STATUS'} eq 'tochangepwd';

    $self->{'eventManager'}->trigger( 'beforeVsftpdAddUser', $moduleData );

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

    $self->{'eventManager'}->trigger( 'AfterVsftpdAddUser', $moduleData );
}

=item addFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::addFtpUser()

=cut

sub addFtpUser
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforeVsftpdAddFtpUser', $moduleData );
    $self->_createFtpUserConffile( $moduleData );
    $self->{'eventManager'}->trigger( 'afterVsftpdAddFtpUser', $moduleData );
}

=item disableFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::disableFtpUser()

=cut

sub disableFtpUser
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforeVsftpdDisableFtpUser', $moduleData );
    $self->_deleteFtpUserConffile( $moduleData );
    $self->{'eventManager'}->trigger( 'afterVsftpdDisableFtpUser', $moduleData );
}

=item deleteFtpUser( \%moduleData )

 See iMSCP::Servers::Ftpd::deleteFtpUser()

=cut

sub deleteFtpUser
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforeVsftpdDeleteFtpUser', $moduleData );
    $self->_deleteFtpUserConffile( $moduleData );
    $self->{'eventManager'}->trigger( 'afterVsftpdDeleteFtpUser', $moduleData );
}

=item getTraffic( $trafficDb [, $logFile, $trafficIndexDb ] )

 See iMSCP::Servers::Ftpd::getTraffic()

=cut

sub getTraffic
{
    my ($self, $trafficDb, $logFile, $trafficIndexDb) = @_;
    $logFile ||= $self->{'config'}->{'FTPD_TRAFFIC_LOG_FILE'};

    unless ( -f $logFile ) {
        debug( sprintf( "VsFTPd traffic %s log file doesn't exist. Skipping...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing VsFTPd traffic %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or tie %{$trafficIndexDb}, 'iMSCP::Config', fileName => "$main::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ($idx, $idxContent) = ( $trafficIndexDb->{'vsftpd_lineNo'} || 0, $trafficIndexDb->{'vsftpd_lineContent'} );

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or die( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    # Retain index of the last log (log file can continue growing)
    my $lastLogIdx = $#logs;

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping VsFTPd traffic logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( $idxContent ne '' && substr( $logFile, -2 ) ne '.1' ) {
        debug( 'Log rotation has been detected. Processing last rotated log file first' );
        $self->getTraffic( $trafficDb, $logFile . '.1', $trafficIndexDb );
        $idx = 0;
    }

    if ( $lastLogIdx < $idx ) {
        debug( 'No new VsFTPd traffic logs found for processing' );
        return;
    }

    debug( sprintf( 'Processing VsFTPd traffic logs (lines %d to %d)', $idx+1, $lastLogIdx+1 ));

    my $regexp = qr/^(?:[^\s]+\s){7}(?<bytes>\d+)\s(?:[^\s]+\s){5}[^\s]+\@(?<domain>[^\s]+)/;

    # In term of memory usage, C-Style loop provide better results than using 
    # range operator in Perl-Style loop: for( @logs[$idx .. $lastLogIdx] ) ...
    for ( my $i = $idx; $i <= $lastLogIdx; $i++ ) {
        next unless $logs[$i] =~ /$regexp/ && exists $trafficDb->{$+{'domain'}};
        $trafficDb->{$+{'domain'}} += $+{'bytes'};
    }

    return if substr( $logFile, -2 ) eq '.1';

    $trafficIndexDb->{'vsftpd_lineNo'} = $lastLogIdx;
    $trafficIndexDb->{'vsftpd_lineContent'} = $logs[$lastLogIdx];
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 See iMSCP::Servers::Ftpd::_init()

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ restart reload cfgDir /} = ( 0, 0, "$main::imscpConfig{'CONF_DIR'}/vsftpd" );
    $self->SUPER::_init();
}

=item _setVersion

 Set VsFTPd version

 Return void, die on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    # Version is print through STDIN (see: strace vsftpd -v)
    my $rs = execute( "$self->{'config'}->{'FTPD_BIN'} -v 0>&1", \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /([\d.]+)/ or die( "Couldn't find VsFTPd version from the `$self->{'config'}->{'FTPD_BIN'} -v 0>&1` command output" );
    $self->{'config'}->{'FTPD_VERSION'} = $1;
    debug( sprintf( 'VsFTPd version set to: %s', $1 ));
}

=item _configure()

 Configure VsFTPd configuration file

 Return void, die on failure

=cut

sub _configure
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'beforeVsftpdConfigure' );
    $self->_setupSqlUser();

    # Make sure to start with clean user configuration directory
    unlink glob "/etc/vsftpd/imscp/*";

    my ($passvMinPort, $passvMaxPort) = split( /\s+/, $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} );
    # VsFTPd main configuration file

    $self->{'eventManager'}->registerOne(
        'beforeProftpdBuildConfFile',
        sub {
            my ($cfgTpl) = @_;

            if ( $main::imscpConfig{'SYSTEM_VIRTUALIZER'} ne 'physical' ) {
                $cfgTpl .= <<'EOF';

# VsFTPd run inside unprivileged VE
# See http://youtrack.i-mscp.net/issue/IP-1503
seccomp_sandbox=NO
EOF
            }

            my $baseServerPublicIp = main::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );
            if ( $main::imscpConfig{'BASE_SERVER_IP'} ne $baseServerPublicIp ) {
                $cfgTpl .= <<"EOF";

# Server behind NAT - Advertise public IP address
pasv_address=$baseServerPublicIp
pasv_promiscuous=YES
EOF
            }

            if ( main::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ) {
                $cfgTpl .= <<"EOF";

# SSL support
ssl_enable=YES
force_local_data_ssl=NO
force_local_logins_ssl=NO
ssl_sslv2=NO
ssl_sslv3=NO
ssl_tlsv1=YES
require_ssl_reuse=NO
ssl_ciphers=HIGH
rsa_cert_file=$main::imscpConfig{'CONF_DIR'}/imscp_services.pem
rsa_private_key_file=$main::imscpConfig{'CONF_DIR'}/imscp_services.pem
EOF
            }
        }
    );

    $self->buildConfFile( 'vsftpd.conf', "$self->{'config'}->{'FTPD_CONF_DIR'}/vsftpd.conf", undef,
        {
            FTPD_BANNER             => $self->{'config'}->{'FTPD_BANNER'},
            FTPD_GUEST_USERNAME     => $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'},
            FTPD_IPV4_ONLY          => main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'NO' : 'YES',
            FTPD_IPV6_SUPPORT       => main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'YES' : 'NO',
            FTPD_LOCAL_ROOT         => $main::imscpConfig{'USER_WEB_DIR'},
            FTPD_PASSV_MIN_PORT     => $passvMinPort,
            FTPD_PASSV_MAX_PORT     => $passvMaxPort,
            FTPD_MAX_CLIENTS        => $self->{'config'}->{'FTPD_MAX_CLIENTS'},
            FTPD_MAX_CLIENTS_PER_IP => $self->{'config'}->{'FTPD_MAX_CLIENTS_PER_IP'},
            FTPD_PAM_SERVICE_NAME   => $self->{'config'}->{'FTPD_PAM_SERVICE_NAME'},
            FTPD_USER_CONF_DIR      => $self->{'config'}->{'FTPD_USER_CONF_DIR'}
        },
        {
            umask => 0027,
            mode  => 0640
        }
    );
    $self->buildConfFile( 'vsftpd_pam.conf', "$self->{'config'}->{'FTPD_PAM_CONF_DIR'}/vsftpd", undef,
        {
            FTPD_DATABASE_HOST => main::setupGetQuestion( 'DATABASE_HOST' ),
            FTPD_DATABASE_NAME => main::setupGetQuestion( 'DATABASE_NAME' ),
            FTPD_DATABASE_PORT => main::setupGetQuestion( 'DATABASE_PORT' ),
            FTPD_SQL_PASSWORD  => $self->{'config'}->{'FTPD_SQL_PASSWORD'},
            FTPD_SQL_USER      => $self->{'config'}->{'FTPD_SQL_USER'}
        },
        {
            umask => 0027,
            mode  => 0640
        }
    );
    $self->{'eventManager'}->trigger( 'afterVsftpdConfigure' );
}

=item _setupSqlUser( )

 Setup SQL user for VsFTPd

 Return void, die on failure

=cut

sub _setupSqlUser
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = main::setupGetQuestion( 'FTPD_SQL_USER' );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion( 'FTPD_SQL_PASSWORD' );

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

    my $dbh = iMSCP::Database->getInstance();

    # GRANT privileges to the SQL user
    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    my $quotedDbName = $dbh->quote_identifier( $dbName );
    $dbh->do( "GRANT SELECT ON $quotedDbName.ftp_users TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'FTPD_SQL_USER'} = $dbUser;
    $self->{'config'}->{'FTPD_SQL_PASSWORD'} = $dbPass;
}

=item _createFtpUserConffile( \%moduleData )

 Create VsFTPd user configuration file

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::FtpUser module
 Return void, die on failure

=cut

sub _createFtpUserConffile
{
    my ($self, $moduleData) = @_;

    $self->buildConfFile( 'vsftpd_user.conf', "$self->{'config'}->{'FTPD_USER_CONF_DIR'}/$moduleData->{'USERNAME'}", $moduleData, undef,
        {
            umask => 0027,
            mode  => 0640
        }
    );
}

=item _deleteFtpUserConffile(\%moduleData)

 Delete VsFTPd user configuration file

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::FtpUser module
 Return void, die on failure

=cut

sub _deleteFtpUserConffile
{
    my ($self, $moduleData) = @_;

    iMSCP::File->new( filename => "$self->{'config'}->{'FTPD_USER_CONF_DIR'}/$moduleData->{'USERNAME'}" )->remove();
}

=item _dropSqlUser( )

 Drop SQL user

 Return void, die on failure

=cut

sub _dropSqlUser
{
    my ($self) = @_;

    # In installer context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer' ? $main::imscpOldConfig{'DATABASE_USER_HOST'} : $main::imscpConfig{'DATABASE_USER_HOST'};

    return unless $self->{'config'}->{'FTPD_SQL_USER'} && $dbUserHost;

    iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'FTPD_SQL_USER'}, $dbUserHost );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
