=head1 NAME

 Package::Webmail - i-MSCP Webmail package

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

package Package::Webmail;

use strict;
use warnings;
use iMSCP::Debug;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList /;
use iMSCP::Dir;
use iMSCP::DistPackageManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP Webmail package.

 Wrapper that handles all available Webmail packages found in the Webmail directory.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( \%eventManager )

 Register setup event listeners

 Param iMSCP::EventManager \%eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->showDialog( @_ ) };
        0;
    } );
}

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    my $selectedPackages = [ split ',', ::setupGetQuestion( 'WEBMAIL_PACKAGES' ) ];
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'webmails', 'all', 'forced' ] )
        || !@{ $selectedPackages }
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages }
    ) {
        ( my $rs, $selectedPackages ) = $dialog->checkbox(
            <<'EOF', \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages } ] );

Please select the webmail packages you want to install:
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $selectedPackages } = grep ( $_ ne 'none', @{ $selectedPackages } );

    ::setupSetQuestion( 'WEBMAIL_PACKAGES', @{ $selectedPackages } ? join ',', @{ $selectedPackages } : 'none' );

    for ( @{ $selectedPackages } ) {
        my $package = "Package::Webmail::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'showDialog' ) ) or next;
        debug( sprintf( 'Executing showDialog action on %s', $package ));
        my $rs = $subref->( $package->getInstance(), $dialog );
        return $rs if $rs;
    }

    0;
}

=item preinstall( )

 Process preinstall tasks

 /!\ This method also triggers uninstallation of unselected webmail packages.

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', ::setupGetQuestion( 'WEBMAIL_PACKAGES' ) } = ();

    my @distroPackages = ();
    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next if exists $selectedPackages{$_};
        my $package = "Package::Webmail::${_}::${_}";
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
        my $package = "Package::Webmail::${_}::${_}";
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
    @{selectedPackages}{ split ',', ::setupGetQuestion( 'WEBMAIL_PACKAGES' ) } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_} && $_ ne 'none';
        my $package = "Package::Webmail::${_}::${_}";
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

=item uninstall( [ $package ])

 Process uninstall tasks

 Param list @packages OPTIONAL Packages to uninstall
 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        my $package = "Package::Webmail::${_}::${_}";
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

=item setGuiPermissions( )

 Set gui permissions

 Return int 0 on success, other on failure

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeWebmailSetGuiPermissions' );
    return $rs if $rs;

    my %selectedPackages;
    @{selectedPackages}{ split ',', $::imscpConfig{'WEBMAIL_PACKAGES'} } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_};
        my $package = "Package::Webmail::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'setGuiPermissions' ) ) or next;
        debug( sprintf( 'Executing setGuiPermissions action on %s', $package ));
        $rs = $subref->( $package->getInstance());
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterWebmailSetGuiPermissions' );

}

=item deleteMail( \%data )

 Process deleteMail tasks

 Param hash \%data Mail data
 Return int 0 on success, other on failure

=cut

sub deleteMail
{
    my ( $self, $data ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', $::imscpConfig{'WEBMAIL_PACKAGES'} } = ();

    for ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next unless exists $selectedPackages{$_};
        my $package = "Package::Webmail::${_}::${_}";
        eval "require $package";
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        ( my $subref = $package->can( 'deleteMail' ) ) or next;
        debug( sprintf( 'Executing deleteMail action on %s', $package ));
        my $rs = $subref->( $package->getInstance(), $data );
        return $rs if $rs;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( )

 Initialize insance

 Return Package::AntiRootkits

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new( dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/Webmail" )->getDirs();
    $self;
}

=item _installPackages( @packages )

 Install distribution packages

 Param list @packages List of packages to install
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
