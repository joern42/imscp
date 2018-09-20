=head1 NAME

 iMSCP::Installer::Bootstrapper - i-MSCP installer bootstrapper

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

# Developer note: Only Perl builtin and modules which are available in Perl
# base installation must be used in that script.

package iMSCP::Installer::Bootstrapper;
use strict;
use warnings;

=head1 DESCRIPTION

 i-MSCP installer bootstrapper

=head1 PUBLIC METHODS

=over 4

=item new( )

 Constructor

 Return iMSCP::InstallerBootstrapper;

=cut

sub new
{
    my ( $class ) = @_;

    bless {}, $class;
}

=item Bootstrap( )

 Bootstrap installer

 Return void, die on failure

=cut

sub bootstrap
{
    my ( $self ) = @_;

    my $bootstrapFile = "iMSCP/Installer/Bootstrap/@{ [ $self->getDistBootstrapFile() ] }";
    -f $bootstrapFile or die( sprintf( "The %s distribution installer bootstrap file is missing. Please contact the i-MSCP Team.", $bootstrapFile ));
    do $bootstrapFile or die;
}

=back

=head1 PRIVATE METHODS

=over 4

=item getDistBootstrapFile

 Get distribution installer bootstrap file

 Return string Distribution installer bootstrap file, die on failure

=cut

sub getDistBootstrapFile
{
    my ( $self ) = @_;

    # Basic heuristic which should work in most cases
    return 'debian.pl' if -f '/etc/debian_version' || -f '/etc/devuan_version';
    return 'mageia.pl' if -f '/etc/mageia-release';
    return 'redhat.pl' if -f '/etc/redhat-release';
    return 'opensuse.pl' if -f '/etc/os-release' && `grep -q openSUSE /etc/os-release`;
    return 'archlinux.pl' if -f '/etc/arch-release' || -f '/etc/manjaro-release';
    return 'gentoo.pl' if -f '/etc/gentoo-release';
    die( 'Your distribution is not known yet. Please contact the i-MSCP team.' );

}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
