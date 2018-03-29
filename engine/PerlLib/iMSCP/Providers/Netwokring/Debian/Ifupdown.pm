=head1 NAME

 iMSCP::Providers::Networking::Debian::Ifupdown - Ifupdown networking configuration provider implementation for Debian like distributions

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

package iMSCP::Providers::Networking::Debian::Ifupdown;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Boolean;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Net;
use iMSCP::TemplateParser qw/ process replaceBlocByRef /;
use parent qw/ iMSCP::Common::Object iMSCP::Providers::Networking::Interface /;

# Commands used in that package
my %COMMANDS = (
    ifup    => '/sbin/ifup',
    ifdown  => '/sbin/ifdown',
    ifquery => '/sbin/ifquery'
);

#  Network interface configuration file for ifup/ifdown
my $INTERFACES_FILE_PATH = '/etc/network/interfaces';
my $IFUP_STATE_DIR = '/run/network';

=head1 DESCRIPTION

 Ifupdown networking configuration provider implementation for Debian like distributions

=head1 PUBLIC METHODS

=over 4

=item addIpAddr( \%data )

 See iMSCP::Providers::Networking::Interface

=cut

sub addIpAddr
{
    my ( $self, $data ) = @_;

    defined $data && ref $data eq 'HASH' or croak( '$data parameter is not defined or invalid' );

    for my $param ( qw/ ip_id ip_card ip_address ip_config_mode / ) {
        defined $data->{$param} or croak( sprintf( 'The %s parameter is not defined', $param ));
    }

    $data->{'ip_id'} =~ /^\d+$/ or croak( 'ip_id parameter must be an integer' );

    # We localize the modification as we do not want propagate it to caller
    local $data->{'ip_id'} += 1000;

    $self->{'net'}->isKnownDevice( $data->{'ip_card'} ) or croak( sprintf( 'The %s network interface is unknown', $data->{'ip_card'} ));
    $self->{'net'}->isValidAddr( $data->{'ip_address'} ) or croak( sprintf( 'The %s IP address is not valid', $data->{'ip_address'} ));

    my $addrVersion = $self->{'net'}->getAddrVersion( $data->{'ip_address'} );

    $data->{'ip_netmask'} ||= ( $addrVersion eq 'ipv4' ) ? 24 : 64;

    $self->_updateInterfacesFile( 'add', $data );

    return $self unless $data->{'ip_config_mode'} eq 'auto';

    # Handle case where the IP netmask or NIC has been changed
    if ( $self->{'net'}->isKnownAddr( $data->{'ip_address'} )
        && ( $self->{'net'}->getAddrDevice( $data->{'ip_address'} ) ne $data->{'ip_card'}
        || $self->{'net'}->getAddrNetmask( $data->{'ip_address'} ) ne $data->{'ip_netmask'} )
    ) {
        $self->{'net'}->delAddr( $data->{'ip_address'} );
    }

    if ( $addrVersion eq 'ipv4' ) {
        my $nic = $self->_isDefinedInterface( "$data->{'ip_card'}:$data->{'ip_id'}" ) ? "$data->{'ip_card'}:$data->{'ip_id'}" : $data->{'ip_card'};

        my ( $stdout, $stderr );
        execute( [ $COMMANDS{'ifup'}, '--force', $nic ], \$stdout, \$stderr ) == 0 or die(
            sprintf( "Couldn't bring up the %s network interface: %s", "$data->{'ip_card'}:$data->{'ip_id'}", $stderr || 'Unknown error' )
        );
        return $self;
    }

    # IPv6 case: We do not have aliased interface
    $self->{'net'}->addAddr( $data->{'ip_address'}, $data->{'ip_netmask'}, $data->{'ip_card'} );
    $self;
}

=item removeIpAddr( \%data )

 See iMSCP::Providers::Networking::Interface

=cut

sub removeIpAddr
{
    my ( $self, $data ) = @_;

    defined $data && ref $data eq 'HASH' or croak( '$data parameter is not defined or invalid' );

    for my $param ( qw/ ip_id ip_card ip_address ip_config_mode / ) {
        defined $data->{$param} or croak( sprintf( 'The %s parameter is not defined', $param ));
    }

    $data->{'ip_id'} =~ /^\d+$/ or croak( 'ip_id parameter must be an integer' );

    # We localize the modification as we do not want propagate it to caller
    local $data->{'ip_id'} += 1000;

    if ( $data->{'ip_config_mode'} eq 'auto'
        && $self->{'net'}->getAddrVersion( $data->{'ip_address'} ) eq 'ipv4'
        && $self->_isDefinedInterface( "$data->{'ip_card'}:$data->{'ip_id'}" )
    ) {
        my ( $stdout, $stderr );
        execute( "$COMMANDS{'ifdown'} --force $data->{'ip_card'}:$data->{'ip_id'}", \$stdout, \$stderr ) == 0 or die(
            sprintf( "Couldn't bring down the %s network interface: %s", "$data->{'ip_card'}:$data->{'ip_id'}", $stderr || 'Unknown error' )
        );

        iMSCP::File->new( filename => $IFUP_STATE_DIR . "/ifup.$data->{'ip_card'}:$data->{'ip_id'}" )->remove();
    } elsif ( $data->{'ip_config_mode'} eq 'auto' ) {
        # Cover not aliased interface (IPv6) case
        # Cover undefined interface case
        $self->{'net'}->delAddr( $data->{'ip_address'} );
    }

    $self->_updateInterfacesFile( 'remove', $data );
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::Object

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'net'} = iMSCP::Net->getInstance();
    $self;
}

=item _updateInterfacesFile( $action, \%data )

 Add or remove IP address in the interfaces configuration file

 Param string $action Action to perform (add|remove)
 Param string $data Template data
 Return void, die on failure

=cut

sub _updateInterfacesFile
{
    my ( $self, $action, $data ) = @_;

    my $file = iMSCP::File->new( filename => $INTERFACES_FILE_PATH )->copy( $INTERFACES_FILE_PATH . '.bak', { preserve => TRUE } );
    my $addrVersion = $self->{'net'}->getAddrVersion( $data->{'ip_address'} );
    my $cAddr = $self->{'net'}->normalizeAddr( $data->{'ip_address'} );
    my $eAddr = $self->{'net'}->expandAddr( $data->{'ip_address'} );

    my $fileContentRef = $file->getAsRef();
    replaceBlocByRef(
        qr/^\s*# i-MSCP \[(?:.*\Q:$data->{'ip_id'}\E|\Q$cAddr\E)\] entry BEGIN\n/m,
        qr/# i-MSCP \[(?:.*\Q:$data->{'ip_id'}\E|\Q$cAddr\E)\] entry ENDING\n/,
        '',
        $fileContentRef
    );

    if ( $action eq 'add'
        && $data->{'ip_config_mode'} eq 'auto'
        && ${ $fileContentRef } !~ /^[^#]*(?:address|ip\s+addr.*?)\s+(?:$cAddr|$eAddr|$data->{'ip_address'})(?:\s+|\n)/gm
    ) {
        my $iface = $data->{'ip_card'} . ( ( $addrVersion eq 'ipv4' ) ? ':' . $data->{'ip_id'} : '' );

        ${ $fileContentRef } .= process(
            {
                ip_id       => $data->{'ip_id'},
                # For IPv6 addr, we do not create aliased interface because that is not suppported everywhere.
                iface       => $iface,
                ip_address  => $cAddr,
                ip_netmask  => $data->{'ip_netmask'},
                addr_family => $addrVersion eq 'ipv4' ? 'inet' : 'inet6'
            },
            <<"STANZA"

# i-MSCP [{ip_address}] entry BEGIN
iface {iface} {addr_family} static
    address {ip_address}
    netmask {ip_netmask}
# i-MSCP [{ip_address}] entry ENDING
STANZA
        );

        # We do add the `auto' stanza only for aliased interfaces, hence, for IPv4 only
        ${ $fileContentRef } =~ s/^(# i-MSCP \[$cAddr\] entry BEGIN\n)/${1}auto $iface\n/m if $addrVersion eq 'ipv4';
    }

    $file->save();
}

=item _isDefinedInterface( $interface )

 Is the given interface defined in the interfaces configuration file?

 Param string $interface Logical interface name
 Return bool TRUE if the given interface is defined in the network interface file, false otherwise

=cut

sub _isDefinedInterface
{
    my ( undef, $interface ) = @_;

    execute( "$COMMANDS{'ifquery'} --list | grep -q '^$interface\$'" ) == 0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
