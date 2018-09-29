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
use Carp 'croak';
use iMSCP::Boolean;
use iMSCP::LsbRelease;
use parent qw/ iMSCP::Common::SingletonClass iMSCP::DistPackageManager::Interface /;

=head1 DESCRIPTION

 High-level interface for distribution package managers.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::addRepositories()

=cut

sub addRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or croak( 'Invalid $repositories parameter. Array expected' );

    $self->_getDistPackageManager()->addRepositories( $repositories, $delayed );
    $self;
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::removeRepositories()

=cut

sub removeRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or croak( 'Invalid $repositories parameter. Array expected' );

    $self->_getDistPackageManager()->removeRepositories( $repositories, $delayed );
    $self;
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or croak( 'Invalid $packages parameter. Array expected' );

    $self->_getDistPackageManager()->installPackages( $packages, $delayed );
    $self;
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or croak( 'Invalid $packages parameter. Array expected' );

    $self->_getDistPackageManager()->uninstallPackages( $packages, $delayed );
    $self;
}

=item installPerlModule( \@modules [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:installPerlModules()

=cut

sub installPerlModules
{
    my ( $self, $modules, $delayed ) = @_;

    ref $modules eq 'ARRAY' or croak( 'Invalid $modules parameter. Array expected' );

    $self->_getDistPackageManager()->installPerlModules( $modules, $delayed );
    $self;
}

=item uninstallPerlModule( \@modules [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:uninstallPerlModules()

=cut

sub uninstallPerlModules
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or croak( 'Invalid $modules parameter. Array expected' );

    $self->_getDistPackageManager()->uninstallPerlModules( $packages, $delayed );
    $self;
}

=item updateRepositoryIndexes( )

 See iMSCP::DistPackageManager::Interface:updateRepositoryIndexes()

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = @_;

    $self->_getDistPackageManager()->updateRepositoryIndexes();
    $self;
}

=item processDelayedTasks( )

 See iMSCP::DistPackageManager::Interface:processDelayedTasks()
 
 In installer context, processing of delayed tasks on the distribution
 package manager is triggered by the installer after the call of the
 preinstall action on the packages and servers. Thus, those last SHOULD
 call this method in the preinstall action.
 
 In uninstaller context, processing of delayed tasks on the distribution
 package manager is triggered by the uninstaller after the call of the
 postuninstall action on the packages and servers. Thus, those last SHOULD
 call this method in the postuninstall action.

=cut

sub processDelayedTasks
{
    my ( $self ) = @_;

    $self->_getDistPackageManager()->processDelayedTasks();
    $self;
}

=item AUTOLOAD

 Provide autoloading for distribution package managers

=cut

sub AUTOLOAD
{
    ( my $method = $iMSCP::DistPackageManager::AUTOLOAD ) =~ s/.*:://;

    my $instance = _getDialogInstance();
    $method = $instance->can( $method ) or croak( sprintf( 'Unknown %s method', $iMSCP::Dialog::AUTOLOAD ));

    no strict 'refs';
    *{ $iMSCP::Dialog::AUTOLOAD } = sub {
        shift;
        $method->( $instance, @_ );
    };
    goto &{ $iMSCP::Dialog::AUTOLOAD };

    #no strict 'refs';
    #*{ $iMSCP::DistPackageManager::AUTOLOAD } = __PACKAGE__->getInstance()->_getDistPackageManager()->can( $method ) or die(
    #    sprintf( 'Unknown %s method', $iMSCP::DistPackageManager::AUTOLOAD )
    #);
    #
    #goto &{ $iMSCP::DistPackageManager::AUTOLOAD };
}

=item DESTROY

 Needed due to autoloading

=cut

sub DESTROY
{

}

=back

=head1 PRIVATE METHODS

=over 4

=item _getDistPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _getDistPackageManager
{
    my ( $self ) = @_;

    $self->{'_dist_package_manager'} ||= do {
        my $class = "iMSCP::DistPackageManager::@{ [ iMSCP::LsbRelease->getInstance()->getId( TRUE ) ] }";
        eval "require $class; 1" or die;
        $class->new();
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
