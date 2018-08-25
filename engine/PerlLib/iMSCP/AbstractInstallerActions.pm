=head1 NAME

 iMSCP::AbstractInstallerActions - i-MSCP abstract installer actions

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

package iMSCP::AbstractInstallerActions;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;

=head1 DESCRIPTION

 i-MSCP installer actions.

 This class is meant to be subclassed by i-MSCP server and package classes. It
 provide default (dummy) implementation for actions that are called on i-MSCP
 server and package classes by the i-MSCP installer and some other scripts. The
 server and package classes MUST override these methods to provide concret
 implementations when applyable.
 
 The following methods are called by specific scripts:
  - setEnginePermissions : engine/setup/set-engine-permissions.pl
  - setGuiPermissions    : engine/setup/set-gui-permissions.pl
  - dpkgPostInvokeTasks  : engine/tools/imscp-dpkg-post-invoke.pl
    
 All other methods (public) are called by the installer directly.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerEventListeners( $eventManager )

 Register installer event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other or die on failure

=cut

sub registerInstallerEventListeners
{
    my ( $self, $eventManager ) = @_;

    0;
}

=item registerInstallerDialogs( $dialogs )

 Register installer dialogs

 Param arrayref $dialogs Array into which dialog routine must be pushed
 Return int 0 on success, other or die on failure

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    0;
}

=item preinstall( )

 Process the preinstall tasks

 Return int 0 on success, other or die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    0;
}

=item install( )

 Process the install tasks

 Return int 0 on success, other or die on failure

=cut

sub install
{
    my ( $self ) = @_;

    0;
}

=item postinstall( )

 Process the postinstall tasks

 Return int 0 on success, other or die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    0;
}

=item setEnginePermissions( )

 Process the setEnginePermissions tasks

 Return int 0 on success, other or die on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    0;
}

=item setGuiPermissions( )

 Process the setGuiPermissions tasks

 Return int 0 on success, other or die on failure

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    0;
}

=item dpkgPostInvokeTasks( )

 Process the dpkgPostInvokeTasks tasks

 Only relevant for Debian like distributions. This method is called after an
 invocation of DPKG(8). See APT.CONF(5)

 Return int 0 on success, other or die on failure

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    0;
}

=back

=head1 PUBLIC METHODS

=over 4

=item _installPackages( \@packages )

 Schedule the given distribution packages for installation

 In installer context, processing of delayed tasks on the distribution
 package manager is triggered by the installer after the call of the
 preinstall action on the packages and servers. Thus, those last SHOULD
 call this method in the preinstall action.

 Param arrayref \@packages Array containing a list of distribution packages to install
 Return int 0 on success, other or die on failure

=cut

sub _installPackages
{
    my ( $self, $packages ) = @_;

    return 0 unless @{ $packages };

    iMSCP::DistPackageManager->getInstance()->installPackages( $packages, TRUE );
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
