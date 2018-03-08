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

    $self->getDistroPackageManager()->addRepository( @_ );
}

=item removeRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface

=cut

sub removeRepositories
{
    my ( $self ) = shift;

    $self->getDistroPackageManager()->removeRepositories( @_ );
}

=item installPackages( @packages )

 See iMSCP::DistPackageManager::Interface

=cut

sub installPackages
{
    my ( $self ) = shift;

    $self->getDistroPackageManager()->installPackages( @_ );
}

=item uninstallPackages( @packages )

 See iMSCP::DistPackageManager::Interface

=cut

sub uninstallPackages
{
    my ( $self ) = shift;

    $self->getDistroPackageManager()->uninstallPackages( @_ );
}

=back

=head1 PRIVATE METHODS/FUNCTIONS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Service, croak on failure

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
}

=item getDistroPackageManager()

 Get distribution package manager instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub getDistroPackageManager
{
    my ( $self ) = @_;

    CORE::state iMSCP::DistPackageManager::Interface $manager;

    $manager //= do {
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
