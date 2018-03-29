=head1 NAME

 iMSCP::Servers::Server::Local::Abstract - i-MSCP Local server implementation

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

package iMSCP::Servers::Server::Local::Abstract;

use strict;
use warnings;
use autouse 'iMSCP::Debug' => qw/ debug error /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList isValidIpAddr isValidHostname isValidTimezone /;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'Net::LibIDN' => qw/ idn_to_ascii idn_to_unicode /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat DateTime::TimeZone iMSCP::Database iMSCP::File iMSCP::Getopt iMSCP::Net iMSCP::Providers::Networking
    iMSCP::Servers::Sqld /;
use iMSCP::Boolean;
use LWP::Simple qw/ $ua get /;
use parent 'iMSCP::Servers::Server';

=head1 DESCRIPTION

 i-MSCP Local server abstract implementation.

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
            push @{ $_[0] }, sub { $self->hostnameDialog( @_ ); }, sub { $self->askIPv6Support( @_ ) }, sub { $self->primaryIpDialog( @_ ); },
                sub { $self->timezoneDialog( @_ ); };
        },
        # We want show these dialog before the sqld server dialogs (sqld priority + 10)
        iMSCP::Servers::Sqld->getPriority()+10
    );
}

=item hostnameDialog( \%dialog )

 Ask for server hostname

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub hostnameDialog
{
    my ( undef, $dialog ) = @_;

    my $hostname = ::setupGetQuestion( 'SERVER_HOSTNAME', iMSCP::Getopt->preseed ? `hostname --fqdn 2>/dev/null` || '' : '' );
    chomp( $hostname );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'system_hostname', 'hostnames', 'servers', 'all', 'forced' ] )
        || !isValidHostname( $hostname )
    ) {
        my $rs = 0;

        do {
            unless ( length $hostname ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                chomp( $hostname = `hostname --fqdn 2>/dev/null` || '' );
            }

            $hostname = idn_to_unicode( $hostname, 'utf-8' ) // '';

            ( $rs, $hostname ) = $dialog->inputbox( <<"EOF", $hostname );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your server fully qualified hostname (leave empty for autodetection):
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidHostname( $hostname );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'SERVER_HOSTNAME', idn_to_ascii( $hostname, 'utf-8' ) // '' );
    0;
}

=item askIPv6Support(\%dialog)

 Ask for IPv6 support

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub askIPv6Support
{
    my ( $self, $dialog ) = @_;

    unless ( -f '/proc/net/if_inet6' ) {
        ::setupSetQuestion( 'IPV6_SUPPORT', 'no' );
        return 0;
    }

    my $value = ::setupGetQuestion( 'IPV6_SUPPORT', iMSCP::Getopt->preseed ? 'yes' : '' );
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'ipv6', 'servers', 'all', 'forced' ] )
        || !isStringInList( $value, keys %choices )
    ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'yes' );
Do you want to enable IPv6 support?

If you select the 'No' option, IPv6 support will be disabled globally. You'll not be able to add new IPv6 addresses and services will be configured to listen on IPv4 only.

\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'IPV6_SUPPORT', $value );
    0;
}

=item primaryIpDialog( \%dialog )

 Ask for server primary IP

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub primaryIpDialog
{
    my ( undef, $dialog ) = @_;

    my @ipList = ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes'
        ? grep (isValidIpAddr( $_, qr/(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)/ ), iMSCP::Net->getInstance()->getAddresses())
        : grep (isValidIpAddr( $_, qr/(?:PRIVATE|PUBLIC)/ ), iMSCP::Net->getInstance()->getAddresses())
        ,
        'None'
    );
    @ipList = sort @ipList;
    unless ( @ipList ) {
        error( "Couldn't get list of server IP addresses. At least one IP address must be configured." );
        return 1;
    }

    my $lanIP = ::setupGetQuestion( 'BASE_SERVER_IP', iMSCP::Getopt->preseed ? 'None' : '' );
    $lanIP = 'None' if $lanIP eq '0.0.0.0';

    my $wanIP = ::setupGetQuestion(
        'BASE_SERVER_PUBLIC_IP',
        ( iMSCP::Getopt->preseed
            ? do {
            chomp( my $wanIP = get( 'https://api.ipify.org/' ) || get( 'https://ipinfo.io/ip/' ) || $lanIP );
            $wanIP;
        }
            : ''
        )
    );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'primary_ip', 'servers', 'all', 'forced' ] )
        || !grep ( $_ eq $lanIP, @ipList )
    ) {
        my $rs = 0;

        do {
            my %choices;
            @choices{@ipList} = @ipList;
            ( $rs, $lanIP ) = $dialog->radiolist( <<"EOF", \%choices, grep ( $_ eq $lanIP, @ipList ) ? $lanIP : $ipList[0] );
Please select your server primary IP address:

The \\Zb`None'\\ZB option means that i-MSCP will configure the services to listen on all interfaces.
This option is more suitable for Cloud computing services such as Scaleway and Amazon EC2, or when using a Vagrant box where the IP that is set through DHCP can changes over the time.
\\Z \\Zn
EOF
            $lanIP = '0.0.0.0' if $lanIP eq 'None';
        } while $rs < 30 && !isValidIpAddr( $lanIP );

        return $rs unless $rs < 30;
    } elsif ( $lanIP eq 'None' ) {
        $lanIP = '0.0.0.0';
    }

    ::setupSetQuestion( 'BASE_SERVER_IP', $lanIP );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'primary_ip', 'servers', 'all', 'forced' ] )
        || !isValidIpAddr( $wanIP )
    ) {
        my $rs = 0;

        do {
            if ( !length $wanIP || $wanIP eq 'None' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                chomp( $wanIP = get( 'https://api.ipify.org/' ) || get( 'https://ipinfo.io/ip/' ) || $lanIP );
                $wanIP = '' if $wanIP eq '0.0.0.0';
            }

            ( $rs, $wanIP ) = $dialog->inputbox( <<"EOF", $wanIP );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your public IP address (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidIpAddr( $wanIP );

        return $rs unless $rs < 30;
    }

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'primary_ip', 'all', 'forced' ] ) ) {
        if ( ( my $rs = $dialog->yesno( <<"EOF", TRUE, TRUE ) ) == 0 ) {
Do you want to replace the IP address of all clients with the new primary IP address?
EOF
            return $rs unless $rs < 30;

            ::setupSetQuestion( 'REPLACE_CLIENTS_IP_WITH_BASE_SERVER_IP', TRUE );
        } else {
            ::setupSetQuestion( 'REPLACE_CLIENTS_IP_WITH_BASE_SERVER_IP', FALSE );
        }
    } else {
        ::setupSetQuestion( 'REPLACE_CLIENTS_IP_WITH_BASE_SERVER_IP', FALSE );
    }

    ::setupSetQuestion( 'BASE_SERVER_PUBLIC_IP', $wanIP );
    0;
}

=item timezoneDialog( \%dialog )

 Ask for server timezone

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub timezoneDialog
{
    my ( undef, $dialog ) = @_;

    my $timezone = ::setupGetQuestion( 'TIMEZONE', iMSCP::Getopt->preseed ? DateTime::TimeZone->new( name => 'local' )->name() : '' );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'local_server', 'timezone', 'servers', 'all', 'forced' ] )
        || !isValidTimezone( $timezone )
    ) {
        my $rs = 0;

        do {
            unless ( length $timezone ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $timezone = DateTime::TimeZone->new( name => 'local' )->name();
            }

            ( $rs, $timezone ) = $dialog->inputbox( <<"EOF", $timezone );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter your timezone (leave empty for autodetection):
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidTimezone( $timezone );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'TIMEZONE', $timezone );
    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setupHostname();
    $self->_setupSysctl();
    $self->_setupPrimaryIP();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'config'}->{'SYSCTL_CONF_DIR'}/imscp.conf" )->remove();
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'LocalServer';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( '%s %s (%s)', $self->{'config'}->{'DISTRO_ID'}, $self->{'config'}->{'DISTRO_RELEASE'}, $self->{'config'}->{'DISTRO_CODENAME'} );
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'DISTRO_RELEASE'};
}

=item addIpAddr( \%moduleData )

 See iMSCP::Servers::Server::addIpAddr()

=cut

sub addIpAddr
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeLocalServerAddIpAddr', $moduleData );

    if ( $moduleData->{'ip_card'} ne 'any' && $moduleData->{'ip_address'} ne '0.0.0.0' ) {
        iMSCP::Providers::Networking->getInstance()->addIpAddr( $moduleData );
        iMSCP::Net->getInstance()->resetInstance();
    }

    $self->{'eventManager'}->trigger( 'afterLocalServerAddIpAddr', $moduleData );
}

=item deleteIpAddr( \%moduleData )

 See iMSCP::Servers::Server::deleteIpAddr()

=cut

sub deleteIpAddr
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeLocalServerDeleteIpAddr', $moduleData );

    if ( $moduleData->{'ip_card'} ne 'any' && $moduleData->{'ip_address'} ne '0.0.0.0' ) {
        iMSCP::Providers::Networking->getInstance()->removeIpAddr( $moduleData );
        iMSCP::Net->getInstance()->resetInstance();
    }

    $self->{'eventManager'}->trigger( 'afterLocalServerDeleteIpAddr', $moduleData );
}

=item addUser( \%moduleData )

 See iMSCP::Servers::Server::addUser()

=cut

sub addUser
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeLocalServerAddUser', $moduleData );
    $self->{'eventManager'}->trigger( 'afterLocalServerAddUser', $moduleData );
}

=item deleteUser( \%moduleData )

 See iMSCP::Servers::Server::deleteUser()

=cut

sub deleteUser
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeLocalServerDeleteUser', $moduleData );
    $self->{'eventManager'}->trigger( 'afterLocalServerDeleteUser', $moduleData );
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Server::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $ua->timeout( 5 );
    $ua->agent( 'i-MSCP/1.6 (+https://i-mscp.net/)' );
    $ua->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );
    $self->SUPER::_init();
}

=item _loadConfig( [ $filename = lc( $self->getServerName() . 'data ) ] )

 See iMSCP::Servers::Abstract::_loadConfig()

=cut

sub _loadConfig
{
    my ( $self ) = @_;

    $self->{'config'} = \%::imscpConfig;
    $self->{'cfgDir'} = $self->{'config'}->{'CONF_DIR'};
}

=item _setupHostname( )

 Setup server hostname

 Return void, die on failure

=cut

sub _setupHostname
{
    my ( $self ) = @_;

    my $hostname = ::setupGetQuestion( 'SERVER_HOSTNAME' );
    my $lanIP = ::setupGetQuestion( 'BASE_SERVER_IP' );

    my @labels = split /\./, $hostname;
    my $host = shift @labels;
    my $hostnameLocal = "$hostname.local";

    # Build hosts configuration file
    $self->buildConfFile( iMSCP::File->new( filename => '/etc/hosts' )->set( <<"EOF" ));
127.0.0.1   $hostnameLocal   localhost
$lanIP  $hostname   $host

# The following lines are desirable for IPv6 capable hosts
::1 localhost  ip6-localhost   ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

    # Build hostname configuration file
    $self->buildConfFile( iMSCP::File->new( filename => '/etc/hostname' )->set( <<"EOF" ));
$host
EOF

    # Build mailname configuration file
    $self->buildConfFile( iMSCP::File->new( filename => '/etc/mailname' )->set( <<"EOF" ));
$hostname
EOF

    # Make new hostname effective
    my $rs = execute( 'hostname --file /etc/hostname', \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || "Couldn't set server hostname" );
}

=item _setupSysctl()

 Setup SYSCTL(8)

 Return void, die on failure

=cut

sub _setupSysctl
{
    my ( $self ) = @_;

    $self->buildConfFile( iMSCP::File->new( filename => "$self->{'config'}->{'SYSCTL_CONF_DIR'}/imscp.conf" )->set( <<"EOF" ),
# SYSCTL(8) configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN

# Promote secondaries IPs when primary is removed
net.ipv4.conf.all.promote_secondaries=1

# Set swappiness to lower value than default (60)
# for better memory management
vm.swappiness=10
EOF
        undef, undef, undef,
        { srcname => 'sysctl_imscp.conf' }
    );

    # Don't catch any error here to avoid permission denied error on some vps due to restrictions set by provider
    execute( [ $self->{'config'}->{'CMD_SYSCTL'}, '-p', "$self->{'config'}->{'SYSCTL_CONF_DIR'}/imscp.conf" ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    debug( $stderr ) if length $stderr;
}

=item _setupPrimaryIP( )

 Setup server primary IP

 Return void, die on failure

=cut

sub _setupPrimaryIP
{
    my ( $self ) = @_;

    my $primaryIP = ::setupGetQuestion( 'BASE_SERVER_IP' );
    $self->{'eventManager'}->trigger( 'beforeLocalServerSetupPrimaryIP', $primaryIP );

    my $netCard = ( $primaryIP eq '0.0.0.0' ) ? 'any' : iMSCP::Net->getInstance()->getAddrDevice( $primaryIP );
    defined $netCard or die( sprintf( "Couldn't find network card for the %s IP address", $primaryIP ));

    my $db = iMSCP::Database->getInstance();
    my $oldDbName = $db->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));

    $db->selectrow_hashref( 'SELECT 1 FROM server_ips WHERE ip_number = ?', undef, $primaryIP )
        ? $db->do( 'UPDATE server_ips SET ip_card = ? WHERE ip_number = ?', undef, $netCard, $primaryIP )
        : $db->do(
        'INSERT INTO server_ips (ip_number, ip_card, ip_config_mode, ip_status) VALUES(?, ?, ?, ?)', undef, $primaryIP, $netCard, 'manual', 'ok'
    );

    if ( ::setupGetQuestion( 'REPLACE_CLIENTS_IP_WITH_BASE_SERVER_IP' ) ) {
        my $resellers = $db->selectall_arrayref( 'SELECT reseller_id, reseller_ips FROM reseller_props', { Slice => {} } );
        if ( @{ $resellers } ) {
            my $primaryIpID = $db->selectrow_array( 'SELECT ip_id FROM server_ips WHERE ip_number = ?', undef, $primaryIP );

            for my $reseller ( @{ $resellers } ) {
                my @ipIDS = split( ';', $reseller->{'reseller_ips'} );
                next if grep ($_ eq $primaryIpID, @ipIDS );
                push @ipIDS, $primaryIpID;
                $db->do( 'UPDATE reseller_props SET reseller_ips = ? WHERE reseller_id = ?', undef, join( ';', @ipIDS ) . ';' );
            }

            $db->do( 'UPDATE domain SET domain_ip_id = ?', undef, $primaryIpID );
            $db->do( 'UPDATE domain_aliasses SET alias_ip_id = ?', undef, $primaryIpID );
        }
    }

    $db->useDatabase( $oldDbName ) if length $oldDbName;
    $self->{'eventManager'}->trigger( 'afterLocalServerSetupPrimaryIP', $primaryIP );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
