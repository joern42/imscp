=head1 NAME

 iMSCP::Provider::Service::Sysvinit - Service provider for Debian `sysvinit' scripts

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

package iMSCP::Provider::Service::Debian::Sysvinit;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Boolean;
use parent 'iMSCP::Provider::Service::Sysvinit';

# Commands used in that package
my %COMMANDS = (
    'update-rc.d' => 'update-rc.d'
);

=head1 DESCRIPTION

 SysVinit service provider for Debian like distributions.

 Differences with the base sysvinit provider are support for enabling,
 disabling and removing services via 'update-rc.d' and the ability to determine
 enabled status.


=head1 PUBLIC METHODS

=over 4

=item isEnabled( $service )

 See iMSCP::Provider::Service::Interface::isEnabled()

=cut

sub isEnabled
{
    my ( $self, $service ) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    $self->_isSysvinit() or croak( sprintf( 'Unknown %s service', $service ));

    scalar glob "/etc/rc[S5].d/S??$service" ? TRUE : FALSE;
}

=item enable( $service )

 See iMSCP::Provider::Service::Interface::enable()

=cut

sub enable
{
    my ( $self, $service ) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    $self->_exec( [ $COMMANDS{'update-rc.d'}, $service, 'defaults' ] );
    $self->_exec( [ $COMMANDS{'update-rc.d'}, $service, 'enable' ] );
}

=item disable( $service )

 See iMSCP::Provider::Service::Interface::disable()

=cut

sub disable
{
    my ( $self, $service ) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    $self->_exec( [ $COMMANDS{'update-rc.d'}, $service, 'defaults' ] );
    $self->_exec( [ $COMMANDS{'update-rc.d'}, $service, 'disable' ] );
}

=item remove( $service )

 See iMSCP::Provider::Service::Interface::remove()

=cut

sub remove
{
    my ( $self, $service ) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    return unless $self->_isSysvinit( $service, 'nocache' );

    $self->stop( $service );
    $self->_exec( [ $COMMANDS{'update-rc.d'}, '-f', $service, 'remove' ] );
    $self->SUPER::remove( $service );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
