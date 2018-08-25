=head1 NAME

 iMSCP::AbstractUninstallerActions - i-MSCP abstract uninstaller actions

=cut

package iMSCP::AbstractUninstallerActions;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;

=head1 DESCRIPTION

 i-MSCP uninstaller actions.

 This class is meant to be subclassed by i-MSCP server and package classes. It
 provide default implementation for actions that are called by the i-MSCP
 uninstaller.

=head1 PUBLIC METHODS

=over 4

=item preuninstall( )

 Process the preuninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub preuninstall
{
    my ( $self ) = @_;

    0;
}

=item uninstall( )

 Process the uninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    0;
}

=item postuninstall( )

 Process the postuninstall tasks

 Return int 0 on success, other or die on failure

=cut

sub postuninstall
{
    my ( $self ) = @_;

    0;
}

=back

=head1 PUBLIC METHODS

=over 4

=item _uninstallPackages( \@packages )

 Schedule the given distribution packages for uninstallation
 
 In uninstaller context, processing of delayed tasks on the distribution
 package manager is triggered by the uninstaller after the call of the
 postinstall action on the packages and servers. Thus, those last SHOULD
 call this method in the postinstall action.

 Param arrayref \@packages Array containing a list of distribution packages to uninstall
 Return int 0 on success, other or die on failure

=cut

sub _removePackages
{
    my ( $self, $packages ) = @_;

    return 0 unless @{ $packages };

    iMSCP::DistPackageManager->getInstance()->uninstallPackages( $packages, TRUE );
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
