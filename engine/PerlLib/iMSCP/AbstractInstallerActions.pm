=head1 NAME

 iMSCP::AbstractInstallerActions - i-MSCP abstract installer actions

=cut

package iMSCP::AbstractInstallerActions;

use strict;
use warnings;
use Carp qw / confess /;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP installer actions.
 
 This class is meant to be subclassed by i-MSCP server and packages classes. It
 provide action methods which are called by the i-MSCP installer and some other
 scripts.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Process the registerSetupListeners tasks

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    0;
}

=item installPackages( @packages )

 Install distribution packages

 Param list @packages List of packages to install
 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub installPackages
{
    my ( $self, @packages ) = @_;

    return 0 unless @packages;

    eval { iMSCP::DistPackageManager->getInstance()->installPackages( @packages, TRUE ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item removePackages( @packages )

 Remove distribution packages

 Param list @packages Packages to remove
 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub removePackages
{
    my ( $self, @packages ) = @_;

    return 0 unless @packages;

    eval { iMSCP::DistPackageManager->getInstance()->uninstallPackages( @packages, TRUE ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item preinstall( )

 Process the preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    0;
}

=item install( )

 Process the install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    0;
}

=item postinstall( )

 Process the postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    0;
}

=item preuninstall( )

 Process the preuninstall tasks

 Return int 0 on success, other on failure

=cut

sub preuninstall
{
    my ( $self ) = @_;

    0;
}

=item uninstall( )

 Process the uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    0;
}

=item postuninstall( )

 Process the postuninstall tasks

 Return int 0 on success, other on failure

=cut

sub postuninstall
{
    my ( $self ) = @_;

    0;
}

=item setEnginePermissions( )

 Process the setEnginePermissions tasks

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    0;
}

=item setGuiPermissions( )

 Process the setGuiPermissions tasks

 Return int 0 on success, other on failure

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    0;
}

=item dpkgPostInvokeTasks( )

 Process the dpkgPostInvokeTasks tasks

 Only relevant for Debian like distributions.

 Return int 0 on success, other on failure

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::AbstractInstallerAction

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or confess( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
