=head1 NAME

 iMSCP::NetworkInterface - High-level interface for network interface providers

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

package iMSCP::NetworkInterface;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::LsbRelease;
use Module::Load::Conditional qw/ can_load /;
use Scalar::Util 'blessed';
use parent qw/ Common::SingletonClass iMSCP::Provider::NetworkInterface::Interface /;

$Module::Load::Conditional::FIND_VERSION = FALSE;
$Module::Load::Conditional::VERBOSE = FALSE;
$Module::Load::Conditional::FORCE_SAFE_INC = TRUE;

=head1 DESCRIPTION

 High-level interface for network interface providers.

=head1 PUBLIC METHODS

=over 4

=item addIpAddr( \%data )

 See iMSCP::Provider::NetworkInterface::Interface

=cut

sub addIpAddr
{
    my ( $self, $data ) = @_;

    $self->{'provider'}->addIpAddr( $data );
    $self;
}

=item removeIpAddr( \%data )

 See iMSCP::Provider::NetworkInterface::Interface

=cut

sub removeIpAddr
{
    my ( $self, $data ) = @_;

    $self->{'provider'}->removeIpAddr( $data );
    $self;
}

=back

=head1 PUBLIC METHODS

=over 4

=item _init( )

 Initialize instance
 
 Return iMSCP::Provider::NetworkInterface

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'provider'} = $self->_getProvider();
    $self;
}

=item getProvider( )

 Get network interface provider

 Return iMSCP::Provider::NetworkInterface, die on failure

=cut

sub _getProvider
{
    my ( $self ) = @_;

    my $id = iMSCP::LsbRelease->getInstance->getId( 'short' );
    $id = 'Debian' if grep ( lc $id eq $_, 'devuan', 'ubuntu' );
    my $provider = "iMSCP::Provider::NetworkInterface::${id}";

    can_load( modules => { $provider => undef } ) or die(
        sprintf( "Couldn't load the '%s' network interface provider: %s", $provider, $Module::Load::Conditional::ERROR )
    );

    $provider->new();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
