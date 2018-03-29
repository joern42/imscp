=head1 NAME

 iMSCP::Providers::Networking - High-level interface for networking configuration providers

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

package iMSCP::Providers::Networking;

use strict;
use warnings;
use Carp qw/ croak /;
use Module::Load::Conditional qw/ can_load /;
use Scalar::Util 'blessed';
use parent qw/ iMSCP::Common::Singleton iMSCP::Providers::Networking::Interface /;

$Module::Load::Conditional::FIND_VERSION = 0;

=head1 DESCRIPTION

 High-level interface for networking configuration providers.

=head1 PUBLIC METHODS

=over 4

=item addIpAddr( \%data )

 See iMSCP::Providers::Networking::Interface

=cut

sub addIpAddr
{
    my ( $self, $data ) = @_;

    $self->getProvider()->addIpAddr( $data );
    $self;
}

=item removeIpAddr( \%data )

 See iMSCP::Providers::Networking::Interface

=cut

sub removeIpAddr
{
    my ( $self, $data ) = @_;

    $self->getProvider()->removeIpAddr( $data );
    $self;
}

=item getProvider( )

 Get network interface provider

 Return iMSCP::Providers::Networking, die on failure

=cut

sub getProvider
{
    my ( $self ) = @_;

    exists $::imscpConfig{'iMSCP::Providers::Networking'} or croak( 'You must first bootstrap the i-MSCP backend' );

    $self->{'_provider'} ||= do {
        can_load( modules => { $::imscpConfig{'iMSCP::Providers::Networking'} => undef } ) or die(
            sprintf(
                "Couldn't load the %s network interface provider: %s", $::imscpConfig{'iMSCP::Providers::Networking'},
                $Module::Load::Conditional::ERROR
            )
        );
        my $provider = $::imscpConfig{'iMSCP::Providers::Networking'}->new();
        $self->setProvider( $provider );
        $provider;
    };
}

=item setProvider( $provider )

 Set network interface provider

 Param iMSCP::Providers::Networking::Interface $provider
 Return iMSCP::Providers::Networking, die failure

=cut

sub setProvider
{
    my ( $self, $provider ) = @_;

    blessed( $provider ) && $provider->isa( 'iMSCP::Providers::Networking::Interface' ) or croak(
        '$provider parameter is either not defined or not an iMSCP::Providers::Networking::Interface object'
    );
    $self->{'_provider'} = $provider;
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
