=head1 NAME

 iMSCP::DistPackageManager - High-level interface for distribution package managers

=cut

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

 See iMSCP::DistPackageManager::Interface

=cut

sub addRepositories
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->addRepositories( @_ );
    $self;
}

=item removeRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface

=cut

sub removeRepositories
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->removeRepositories( @_ );
    $self;
}

=item installPackages( @packages )

 See iMSCP::DistPackageManager::Interface

=cut

sub installPackages
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->installPackages( @_ );
    $self;
}

=item uninstallPackages( @packages )

 See iMSCP::DistPackageManager::Interface

=cut

sub uninstallPackages
{
    my ( $self ) = shift;

    $self->_getDistroPackageManager()->uninstallPackages( @_ );
    $self;
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
}

=item _getDistroPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _getDistroPackageManager
{
    my ( $self ) = @_;

    $self->{'_distro_manager'} //= do {
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
