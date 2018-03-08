=head1 NAME

 iMSCP::DistPackageManager::Interface - Interface for distribution package managers.

=cut

package iMSCP::DistPackageManager::Interface;

use strict;
use warnings;
use Carp qw/ croak /;

=head1 DESCRIPTION

 Interface for distribution package managers.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( @repositories )

 Add the given distribution repositories

 Param array @repositories An array containing list of repositories to add
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub addRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addRepositories() method', ref $self ));
}

=item removeRepositories( @repositories )

 Remove the given distribution repositories

 Param array @repositories An array containing list of repositories to remove
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub removeRepositories
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeRepositories() method', ref $self ));
}

=item installPackages( @packages )

 Install the given packages

 Param array @packages An array containing list of package to install
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub installPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the installPackages() method', ref $self ));
}

=item uninstallPackages( @packages )

 Uninstall the given packages

 Param array @packages An array containing list of packages to uninstall
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub uninstallPackages
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the uninstallPackages() method', ref $self ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
