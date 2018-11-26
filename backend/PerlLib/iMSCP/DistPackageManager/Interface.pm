=head1 NAME

 iMSCP::DistPackageManager::Interface - Interface for distribution package managers.

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

package iMSCP::DistPackageManager::Interface;

use strict;
use warnings;

=head1 DESCRIPTION

 Interface for distribution package managers.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( @repositories )

 Add the given distribution repositories

 The following events *MUST* be triggered:
  - beforeAddDistributionRepositories( \@repositories )
  - afterAddDistributionRepositories( \@repositories )

 Param list @repositories List of distribution repositories to add
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub addRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addRepositories() method', ref $self ));
}

=item removeRepositories( @repositories )

 Remove the given distribution repositories

 The following events *MUST* be triggered:
  - beforeRemoveDistributionRepositories( \@repositories )
  - afterRemoveDistributionRepositories( \@repositories )

 Param list @repositories List of distribution repositories to remove
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub removeRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeRepositories() method', ref $self ));
}

=item installPackages( @packages )

 Install the given distribution packages

 The following events *MUST* be triggered:
  - beforeInstallDistributionPackages( \@packages )
  - afterInstallDistributionPackages( \@packages )

 Param list @packages List of distribution packages to install
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub installPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the installPackages() method', ref $self ));
}

=item uninstallPackages( @packages )

 Uninstall the given distribution packages

 The following events *MUST* be triggered:
  - beforeUninstallDistributionPackages( \@packages )
  - afterUninstallDistributionPackages( \@packages )

 Param list @packages List of distribution packages to uninstall
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub uninstallPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the uninstallPackages() method', ref $self ));
}

=item updateRepositoryIndexes( )

 Update repository indexes

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the updateRepositoryIndexes() method', ref $self ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
