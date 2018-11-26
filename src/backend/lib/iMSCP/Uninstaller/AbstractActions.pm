=head1 NAME

 iMSCP::Uninstaller::AbstractActions - i-MSCP abstract uninstaller actions

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

package iMSCP::Uninstaller::AbstractActions;

use strict;
use warnings;

=head1 DESCRIPTION

 i-MSCP uninstaller actions.

 This class is meant to be subclassed by i-MSCP server and package classes. It
 provide default (dummy) implementation for actions that are called on i-MSCP
 server and package instances by the i-MSCP uninstaller. The server and package
 classes MUST override these methods to provide concret implementations when
 applyable.

=head1 PUBLIC METHODS

=over 4

=item preuninstall( )

 Process the preuninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub preuninstall
{
    my ( $self ) = @_;

    0;
}

=item uninstall( )

 Process the uninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    0;
}

=item postuninstall( )

 Process the postuninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub postuninstall
{
    my ( $self ) = @_;

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
