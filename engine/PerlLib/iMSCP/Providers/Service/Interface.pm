=head1 NAME

 iMSCP::Providers::Service::Interface - Interface for service (Systemd, SysVinit, Upstart...) providers

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

package iMSCP::Providers::Service::Interface;

use strict;
use warnings;
use Carp qw/ croak /;

=head1 DESCRIPTION

 Interface for service (Systemd, SysVinit, Upstart...) providers.

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $service )

 is the given service is enabled?

 Param string $service Service name
 Return TRUE if the given service is enabled, FALSE otherwise

=cut

sub isEnabled
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the isEnabled() method', ref $self ));
}

=item enable( $service )

 Enable the given service

 If $service is already enabled, no failure must be reported.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub enable
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the enable() method', ref $self ));
}

=item disable( $service )

 Disable the given service

 If $service is already disabled, no failure must be reported.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub disable
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disable() method', ref $self ));
}

=item remove( $service )

 Remove the given service

 If $service doesn't exist, no failure must be reported.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub remove
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the remove() method', ref $self ));
}

=item start( $service )

 Start the given service

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub start
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the start() method', ref $self ));
}

=item stop( $service )

 Stop the given service

 If $service is not running, no failure must be reported.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub stop
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the stop() method', ref $self ));
}

=item restart( $service )

 Restart the given service

 If $ervice is not running, it must be started.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub restart
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the restart() method', ref $self ));
}

=item reload( $service )

 Reload the given service

 If $service doesn't support reload, it must be restarted.
 If $service is not running, it must be started.

 Param string $service Service name
 Return bool TRUE on success, croak on failure

=cut

sub reload
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the reload() method', ref $self ));
}

=item isRunning( $service )

 Is the given service running?

 Param string $service Service name
 Return bool TRUE if the given service is running, FALSE otherwise

=cut

sub isRunning
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the isRunning() method', ref $self ));
}

=item hasService( $service )

 Does the given service exists?

 Param string $service Service name
 Return bool TRUE if the given service exits, FALSE otherwise

=cut

sub hasService
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the hasService() method', ref $self ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
