=head1 NAME

 iMSCP::Providers::Service::Debian::Systemd - Systemd service provider for Debian like distributions

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

package iMSCP::Providers::Service::Debian::Systemd;

use strict;
use warnings;
use File::Basename;
use parent qw/ iMSCP::Providers::Service::Systemd iMSCP::Providers::Service::Debian::Sysvinit /;

=head1 DESCRIPTION

 Systemd service provider for Debian like distributions.
 
 Difference with the iMSCP::Providers::Service::Systemd base provider is the
 support for the 'is-enabled' API call that is not available till Systemd
 version 220-1 (Debian package) and support for SysVinit script removal.

 See:
  https://wiki.debian.org/systemd
  https://wiki.debian.org/systemd/Packaging
  https://wiki.debian.org/systemd/Integration

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $unit )

 See iMSCP::Providers::Service::Systemd::isEnabled()

=cut

sub isEnabled
{
    my ($self, $unit) = @_;

    # We need to catch STDERR here as we do not want raise failure when command
    # status is other than 0 but no STDERR
    my $ret = $self->_exec(
        [ $iMSCP::Providers::Service::Systemd::COMMANDS{'systemctl'}, 'is-enabled', $self->resolveUnit( $unit ) ], \ my $stdout, \ my $stderr
    );
    croak( $stderr ) if $ret && $stderr;

    # The indirect state indicates that the unit is not enabled.
    return 0 if $stdout eq 'indirect';

    # The 'is-enabled' API call for SysVinit scripts is not implemented till
    # the Systemd version 220-1 (Debian package), that is, under the following
    # distributions (main repository):
    #  - Debian < 9 (Stretch)
    #  - Ubuntu < 18.04 (Bionic Beaver)
    if ( $ret > 0 && $self->_getLastExecOutput() eq '' ) {
        # For the SysVinit scripts, we want operate only on services
        ( $unit, undef, my $suffix ) = fileparse( $unit, qr/\.[^.]*/ );
        return $self->iMSCP::Providers::Service::Debian::Sysvinit::isEnabled( $unit ) if grep( $suffix eq $_, '', '.service' );
    }

    # The command status 0 indicate that the service is enabled
    $ret == 0;
}

=item remove( $unit )

 See iMSCP::Providers::Service::Interface::remove()

=cut

sub remove
{
    my ($self, $unit) = @_;

    defined $unit or die( 'parameter $unit is not defined' );

    # For the SysVinit scripts, we want operate only on services
    my ( $init, undef, $suffix ) = fileparse( $unit, qr/\.[^.]*/ );
    $self->iMSCP::Providers::Service::Debian::Sysvinit::remove( $init ) if grep( $suffix eq $_, '', '.service' );
    $self->SUPER::remove( $unit );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
