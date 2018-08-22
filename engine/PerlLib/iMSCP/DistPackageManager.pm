=head1 NAME

 iMSCP::DistPackageManager - High-level interface for distribution package managers

=cut

package iMSCP::DistPackageManager;

use strict;
use warnings;
use iMSCP::EventManager;
use iMSCP::LsbRelease;
use parent qw/ Common::SingletonClass iMSCP::DistPackageManager::Interface /;

=head1 DESCRIPTION

 High-level interface for distribution package managers.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::addRepositories()
 
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub addRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    if ( $delayed ) {
        push @{ $self->{'repositoriesToAdd'} }, $repositories;
        return $self;
    }

    $self->_getDistroPackageManager()->addRepositories( @_ );
    $self;
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::removeRepositories()
 
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub removeRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    if ( $delayed ) {
        push @{ $self->{'repositoriesToRemove'} }, $repositories;
        return $self;
    }

    $self->_getDistroPackageManager()->removeRepositories( @_ );
    $self;
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::installPackages()
 
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub installPackages
{
    my ( $self, $packages, $delayed ) = @_;

    if ( $delayed ) {
        push @{ $self->{'packagesToInstall'} }, $packages;
        return $self;
    }

    $self->_getDistroPackageManager()->installPackages( @_ );
    $self;
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:uninstallPackages()

 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub uninstallPackages
{
    my ( $self, $packages, $delayed ) = @_;

    if ( $delayed ) {
        push @{ $self->{'packagesToUninstall'} }, $packages;
        return $self;
    }

    $self->_getDistroPackageManager()->uninstallPackages( $packages );
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

=item processDelayedTasks( )

 Process delayed tasks if any

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub processDelayedTasks
{
    my ( $self ) = @_;

    if ( @{ $self->{'repositoriesToRemove'} } || @{ $self->{'repositoriesToAdd'} } ) {
        $self
            ->removeRepositories( delete $self->{'repositoriesToRemove'} )
            ->addRepositories( delete $self->{'repositoriesToAdd'} )
            ->updateRepositoryIndexes()
    }

    $self
        ->installPackages( delete $self->{'packagesToInstall'} )
        ->uninstallPackages( delete $self->{'packagesToUninstall'} );
    $self;
}

=item AUTOLOAD

 Provide autoloading for distribution package managers

=cut

sub AUTOLOAD
{
    ( my $method = $iMSCP::DistPackageManager::AUTOLOAD ) =~ s/.*:://;

    # Define the subroutine to prevent further evaluation
    no strict 'refs';
    *{ $iMSCP::DistPackageManager::AUTOLOAD } = __PACKAGE__->getInstance()->_getDistroPackageManager()->can( $method ) or die(
        sprintf( 'Unknown %s method', $iMSCP::DistPackageManager::AUTOLOAD )
    );

    # Execute the subroutine, erasing AUTOLOAD stack frame without trace
    goto &{ $iMSCP::DistPackageManager::AUTOLOAD };
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

=item _init( )

 Initialize instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{ $self }{qw/ repositoriesToAdd repositoriesToRemove packagesToInstall packagesToUninstall /} = ( [], [], [], [] );
    $self;
}

=item _getDistroPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _getDistroPackageManager
{
    my ( $self ) = @_;

    my $distID = iMSCP::LsbRelease->getInstance()->getId( 'short' );
    $distID = 'Debian' if grep ( lc $distID eq $_, 'devuan', 'ubuntu' );

    $self->{'_distro_package_manager'} //= do {
        my $class = "iMSCP::DistPackageManager::$distID";
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
