=head1 NAME

 iMSCP::Provider::Service::Debian::Upstart - Service provider for Debian `upstart' jobs.

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

package iMSCP::Provider::Service::Debian::Upstart;

use strict;
use warnings;
use Carp qw/ croak /;
use parent qw/ iMSCP::Provider::Service::Upstart iMSCP::Provider::Service::Debian::Sysvinit /;

=head1 DESCRIPTION

 Upstart service provider for Debian like distributions.
 
 Difference with the iMSCP::Provider::Service::Upstart is the support for the
 SysVinit scripts.

 See: https://wiki.debian.org/Upstart

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $job )

 See iMSCP::Provider::Service::Interface::isEnabled()

=cut

sub isEnabled
{
    my ( $self, $job ) = @_;

    defined $job or croak( 'parameter $job is not defined' );

    return $self->SUPER::isEnabled( $job ) if $self->_isUpstart( $job );

    $self->iMSCP::Provider::Service::Debian::Sysvinit::isEnabled( $job );
}

=item enable( $job )

 See iMSCP::Provider::Service::Interface::enable()

=cut

sub enable
{
    my ( $self, $job ) = @_;

    defined $job or croak( 'parameter $job is not defined' );

    $self->SUPER::enable( $job ) if $self->_isUpstart( $job );
    $self->iMSCP::Provider::Service::Debian::Sysvinit::enable( $job ) if $self->_isSysvinit( $job );
}

=item disable( $job )

 See iMSCP::Provider::Service::Interface::disable()

=cut

sub disable
{
    my ( $self, $job ) = @_;

    defined $job or croak( 'parameter $job is not defined' );

    $self->SUPER::disable( $job ) if $self->_isUpstart( $job );
    $self->iMSCP::Provider::Service::Debian::Sysvinit::disable( $job ) if $self->_isSysvinit( $job );
}

=item remove( $job )

 See iMSCP::Provider::Service::Interface::remove()

=cut

sub remove
{
    my ( $self, $job ) = @_;

    defined $job or croak( 'parameter $job is not defined' );

    $self->SUPER::remove( $job );
    $self->iMSCP::Provider::Service::Debian::Sysvinit::remove( $job );
}

=item hasService( $service )

 See iMSCP::Provider::Service::Interface::hasService()

=cut

sub hasService
{
    my ( $self, $job ) = @_;

    defined $job or croak( 'parameter $service is not defined' );

    $self->SUPER::hasService( $job ) || $self->iMSCP::Provider::Service::Debian::Sysvinit::hasService( $job );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
