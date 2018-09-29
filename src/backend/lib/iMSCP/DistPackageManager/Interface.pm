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
 
 Since distribution package managers can be used early in the i-MSCP
 installation process, they *MUST* be implemented using the builtin
 functions and modules that are part of the base Perl installation.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( \@repositories [, $delayed = FALSE ] )

 Add the given distribution repositories

 Param arrayref @repositories Array containing a list of distribution repositories to add
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub addRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addRepositories() method', ref $self ));
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 Remove the given distribution repositories

 Param arrayref \@repositories Array containing a list of distribution repositories to remove
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub removeRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeRepositories() method', ref $self ));
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 Install the given distribution packages

 Param arrayref \@packages Array containing a list of distribution packages to install
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub installPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the installPackages() method', ref $self ));
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 Uninstall the given distribution packages

 Param arrayref \@packages Array containing a list of distribution package to uninstall
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub uninstallPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the uninstallPackages() method', ref $self ));
}

=item installPerlModules( \@modules [, $delayed = FALSE ] )

 Install the given Perl module from CPAN

 Param arrayref \@modules Array containing a list of Perl modules to install
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub installPerlModules
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the installPerlModule() method', ref $self ));
}

=item uninstallPerlModules( \@packages [, $delayed = FALSE ] )

 Uninstall the given Perl modules from CPAN

 Param arrayref \@modules Array containing a list of Perl modules to uninstall
 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub uninstallPerlModules
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the uninstallPerlModule() method', ref $self ));
}

=item updateRepositoryIndexes( )

 Update repository indexes

 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the updateRepositoryIndexes() method', ref $self ));
}

=item processDelayedTasks( )

 Process delayed tasks if any

 Return iMSCP::DistPackageManager::Interface, die or croak on failure

=cut

sub processDelayedTasks
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the processDelayedTasks() method', ref $self ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
