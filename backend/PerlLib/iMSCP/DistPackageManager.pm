=head1 NAME

 iMSCP::DistPackageManager - High-level interface for distribution package managers

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

package iMSCP::DistPackageManager;

use strict;
use warnings;
use iMSCP::EventManager;
use parent qw/ iMSCP::Common::Singleton iMSCP::DistPackageManager::Interface /;

=head1 DESCRIPTION

 High-level interface for distribution package managers.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::addRepositories()

=cut

sub addRepositories
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->addRepositories( @_ );
    $self;
}

=item removeRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::removeRepositories()

=cut

sub removeRepositories
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->removeRepositories( @_ );
    $self;
}

=item installPackages( @packages )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->installPackages( @_ );
    $self;
}

=item uninstallPackages( @packages )

 See iMSCP::DistPackageManager::Interface:uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->uninstallPackages( @_ );
    $self;
}

=item updateRepositoryIndexes( )

 See iMSCP::DistPackageManager::Interface:updateRepositoryIndexes()

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->updateRepositoryIndexes( @_ );
    $self;
}

=item AUTOLOAD

 Provide autoloading for distribution package managers

=cut

sub AUTOLOAD
{
    ( my $method = our $AUTOLOAD ) =~ s/.*:://;

    my $sub = __PACKAGE__->getInstance()->_getDistroPackageManager()->can( $method ) or die(
        sprintf( 'Unknown %s method', $AUTOLOAD )
    );

    # Define the subroutine to prevent further evaluation
    no strict 'refs';
    *{ $AUTOLOAD } = $sub;

    # Execute the subroutine, erasing AUTOLOAD stack frame without trace
    goto &{ $AUTOLOAD };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self;
}

=item _getDistroPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _getDistroPackageManager
{
    my ( $self ) = @_;

    $self->{'_distro_package_manager'} //= do {
        my $class = "iMSCP::DistPackageManager::$::imscpConfig{'DISTRO_FAMILY'}";
        eval "require $class; 1" or die $@;
        $class->new( eventManager => $self->{'eventManager'} );
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
