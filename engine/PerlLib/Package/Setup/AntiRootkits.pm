=head1 NAME

 Package::Setup::AntiRootkits - i-MSCP Anti-Rootkits package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package Package::Setup::AntiRootkits;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Debug;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList /;
use iMSCP::Dir;
use iMSCP::DistPackageManager;
use iMSCP::EventManager;
use iMSCP::Execute;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP Anti-Rootkits package.

 Handles Anti-Rootkits packages found in the AntiRootkits directory.

=head1 PUBLIC METHODS

=over

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->askForAntirootkitPackages( @_ ) };
        0,
    } );
}

=item askForAntirootkitPackages( $dialog )

 Ask for antirootkit packages

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForAntirootkitPackages
{
    my ( $self, $dialog ) = @_;

    my $selectedPackages = [ split ',', ::setupGetQuestion( 'ANTI_ROOTKITS_PACKAGES' ) ];
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antirootkits', 'all' ] ) || !@{ $selectedPackages }
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages }
    ) {
        ( my $rs, $selectedPackages ) = $dialog->checklist(
            <<'EOF', \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages } ] );

Please select the Anti-Rootkits packages you want to install:
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $selectedPackages } = grep ( $_ ne 'none', @{ $selectedPackages } );
    ::setupSetQuestion( 'ANTI_ROOTKITS_PACKAGES', @{ $selectedPackages } ? join ',', @{ $selectedPackages } : 'none' );

    my @dialogs;
    for my $package ( @{ $selectedPackages } ) {
        $package = "Package::Setup::AntiRootkits::${package}::${package}";
        eval "require $package" or die;
        my $subref = $package->can( 'showDialog' );
        push @dialogs, sub { $subref->( $package->getInstance(), @_ ) } if $subref;
    }

    $dialog->executeDialogs( \@dialogs );
}

=item preinstall( )

 Process preinstall tasks

 /!\ This method also trigger uninstallation of unselected Anti-Rootkits packages.

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', ::setupGetQuestion( 'ANTI_ROOTKITS_PACKAGES' ) } = ();

    my @distroPackages = ();
    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next if exists $selectedPackages{$_};
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        if ( my $subref = $package->can( 'uninstall' ) ) {
            debug( sprintf( 'Executing uninstall action on %s', $package ));
            my $rs = $subref->( $package->getInstance());
            return $rs if $rs;
        }

        ( my $subref = $package->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $package ));
        push @distroPackages, $subref->( $package->getInstance());
    }

    if ( defined $::skippackages && !$::skippackages && @distroPackages ) {
        my $rs = $self->_removePackages( @distroPackages );
        return $rs if $rs;
    }

    @distroPackages = ();
    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_};
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";

        if ( $@ ) {
            error( $@ );
            return 1;
        }

        if ( my $subref = $package->can( 'preinstall' ) ) {
            debug( sprintf( 'Executing preinstall action on %s', $package ));
            my $rs = $subref->( $package->getInstance());
            return $rs if $rs;
        }

        ( my $subref = $package->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $package ));
        push @distroPackages, $subref->( $package->getInstance());
    }

    if ( defined $::skippackages && !$::skippackages && @distroPackages ) {
        my $rs = $self->_installPackages( @distroPackages );
        return $rs if $rs;
    }

    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', ::setupGetQuestion( 'ANTI_ROOTKITS_PACKAGES' ) } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_} && $_ ne 'none';
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'install' ) ) or next;
        debug( sprintf( 'Executing install action on %s', $package ));
        my $rs = $subref->( $package->getInstance());
        return $rs if $rs;
    }

    0;
}

=item postinstall( )

 Process post install tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', ::setupGetQuestion( 'ANTI_ROOTKITS_PACKAGES' ) } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_} && $_ ne 'none';
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'postinstall' ) ) or next;
        debug( sprintf( 'Executing postinstall action on %s', $package ));
        my $rs = $subref->( $package->getInstance());
        return $rs if $rs;
    }

    0;
}

=item uninstall( )

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        if ( my $subref = $package->can( 'uninstall' ) ) {
            debug( sprintf( 'Executing uninstall action on %s', $package ));
            my $rs = $subref->( $package->getInstance());
            return $rs if $rs;
        }

        ( my $subref = $package->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $package ));
        push @distroPackages, $subref->( $package->getInstance());
    }

    $self->_removePackages( @distroPackages );
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    0;
}

=item setEnginePermissions( )

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeAntiRootkisSetGuiPermissions' );
    return $rs if $rs;

    my %selectedPackages;
    @{selectedPackages}{ split ',', $::imscpConfig{'ANTI_ROOTKITS_PACKAGES'} } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_};
        my $package = "Package::Setup::AntiRootkits::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'setEnginePermissions' ) ) or next;
        debug( sprintf( 'Executing setEnginePermissions action on %s', $package ));
        $rs = $subref->( $package->getInstance());
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterAntiRootkisSetGuiPermissions' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( )

 Initialize instance

 Return Package::Setup::AntiRootkits

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new(
        dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/Setup/AntiRootkits"
    )->getDirs();
    $self;
}

=item _installPackages( @packages )

 Install distribution packages

 Param list @packages List of distribution packages to install
 Return int 0 on success, other on failure

=cut

sub _installPackages
{
    my ( undef, @packages ) = @_;

    return 0 unless @packages;

    eval { iMSCP::DistPackageManager->getInstance()->installPackages( @packages ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _removePackages( @packages )

 Remove distribution packages

 Param list @packages Packages to remove
 Return int 0 on success, other on failure

=cut

sub _removePackages
{
    my ( undef, @packages ) = @_;

    return 0 unless @packages;

    eval { iMSCP::DistPackageManager->getInstance()->uninstallPackages( @packages ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
