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

=cut

sub addRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or die( 'Invalid $repositories parameter. Array expected' );

    $self->_getDistPackageManager()->addRepositories( $repositories, $delayed );
    $self;
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::removeRepositories()

=cut

sub removeRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or die( 'Invalid $repositories parameter. Array expected' );

    $self->_getDistPackageManager()->removeRepositories( $repositories, $delayed );
    $self;
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or die( 'Invalid $packages parameter. Array expected' );

    $self->_getDistPackageManager()->installPackages( $packages, $delayed );
    $self;
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or die( 'Invalid $packages parameter. Array expected' );

    $self->_getDistPackageManager()->uninstallPackages( $packages, $delayed );
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

    no strict 'refs';
    *{ $iMSCP::DistPackageManager::AUTOLOAD } = __PACKAGE__->getInstance()->_getDistPackageManager()->can( $method ) or die(
        sprintf( 'Unknown %s method', $iMSCP::DistPackageManager::AUTOLOAD )
    );

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
    $self;
}

=item _getDistPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _getDistPackageManager
{
    my ( $self ) = @_;

    my $distID = iMSCP::LsbRelease->getInstance()->getId( 'short' );
    $distID = 'Debian' if grep ( lc $distID eq $_, 'devuan', 'ubuntu' );

    $self->{'_dist_package_manager'} ||= do {
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
