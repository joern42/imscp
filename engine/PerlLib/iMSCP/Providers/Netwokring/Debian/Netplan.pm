=head1 NAME

 iMSCP::Providers::Networking::Debian::Netplan - Netplan networking configuration provider implementation for Debian like distributions

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

package iMSCP::Providers::Networking::Debian::Netplan;

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
    ip      => '/sbin/ip',
    netplan => '/usr/sbin/netplan'
);

#  Netplan configuration directory
my $NETPLAN_CONF_DIR = '/etc/netplan';

=head1 DESCRIPTION

 Netplan networking configuration provider implementation for Debian like distributions
 
 See:
    https://wiki.ubuntu.com/Netplan
    https://netplan.io/

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

    $data->{'ip_netmask'} ||= ( $self->{'net'}->getAddrVersion( $data->{'ip_address'} ) eq 'ipv4' ) ? 24 : 64;

    return $self->_updateConfig( 'remove', $data ) unless $data->{'ip_config_mode'} eq 'auto';

    $self->_updateConfig( 'add', $data );

    # Handle case where the IP netmask or NIC has been changed
    if ( $self->{'net'}->isKnownAddr( $data->{'ip_address'} )
        && ( $self->{'net'}->getAddrDevice( $data->{'ip_address'} ) ne $data->{'ip_card'}
        || $self->{'net'}->getAddrNetmask( $data->{'ip_address'} ) ne $data->{'ip_netmask'} )
    ) {
        $self->{'net'}->delAddr( $data->{'ip_address'} );
    }

    my ( $stdout, $stderr );
    execute( [ $COMMANDS{'netplan'}, 'apply' ], \$stdout, \$stderr ) == 0 or die(
        sprintf( "Couldn't bring up the %s network interface: %s", "$data->{'ip_card'}:$data->{'ip_id'}", $stderr || 'Unknown error' )
    );

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

    $self->_updateConfig( 'remove', $data );

    my $vlan = "veth$data->{'ip_id'}";

    return unless $data->{'ip_config_mode'} eq 'auto' || !$self->{'net'}->isKnownDevice( $vlan );

    my ( $stdout, $stderr );
    execute( [ $COMMANDS{'ip'}, 'link', 'delete', $vlan ], \$stdout, \$stderr ) == 0 or die(
        sprintf( "Couldn't bring down the %s network interface: %s", "$data->{'ip_card'}:$data->{'ip_id'}", $stderr || 'Unknown error' )
    );

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

=item _updateConfig( $action, \%data )

 Write or remove netplan configuration file for the given vlan

 Param string $action Action to perform (add|remove)
 Param string $data Template data
 Return void, die on failure

=cut

sub _updateConfig
{
    my ( $self, $action, $data ) = @_;

    my $file = iMSCP::File->new( filename => "$NETPLAN_CONF_DIR/99-imscp-$data->{'ip_id'}.yaml" );
    return $file->delete() if $action eq 'remove' && -f $file;

    $file->set( process(
        {
            vlan_id    => $data->{'ip_id'},
            iface      => "veth$data->{'ip_id'}",
            ip_address => $self->{'net'}->normalizeAddr( $data->{'ip_address'} ),
            ip_netmask => $data->{'ip_netmask'},
        },
        <<"STANZA"
network:
  version: 2
  renderer: networkd
  vlans:
   veth{vlan_id}:
    id: {vlan_id}
    link: iface
    addresses:
     - {ip_address}/{ip_netmask}
STANZA
    ))->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
