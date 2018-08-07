=head1 NAME

 Package::Setup::FileManager - i-MSCP FileManager package

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

package Package::Setup::FileManager;

use strict;
use warnings;
use iMSCP::Debug;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute;
use iMSCP::Getopt;
use Package::Setup::FrontEnd;
use version;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP FileManager package.

 Handles FileManager packages found in the FileManager directory.

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

    my $package = ::setupGetQuestion( 'FILEMANAGER_PACKAGE' );
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    my $rs = 0;
    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'filemanager', 'all', 'forced' ] )
        || !grep ($_ eq $package, @{ $self->{'AVAILABLE_PACKAGES'} })
    ) {
        ( $rs, $package ) = $dialog->radiolist( <<'EOF', \%choices, ( grep ( $package eq $_, keys %choices ) )[0] || ( keys %choices )[0] );

Please select the Web FTP file manager package you want to install:
\Z \Zn
EOF
    }

    return $rs unless $rs < 30;

    ::setupSetQuestion( 'FILEMANAGER_PACKAGE', $package );

    $package = "Package::Setup::FileManager::${package}::${package}";
    eval "require $package";
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 unless my $subref = $package->can( 'showDialog' );
    debug( sprintf( 'Executing showDialog action on %s', $package ));
    $subref->( $package->getInstance(), $dialog );
}

=item preinstall( )

 Process preinstall tasks

 /!\ This method also trigger uninstallation of unselected file manager packages.

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $oldPackage = exists $::imscpOldConfig{'FILEMANAGER_ADDON'}
        ? $::imscpOldConfig{'FILEMANAGER_ADDON'} # backward compatibility with 1.1.x Serie (upgrade process)
        : $::imscpOldConfig{'FILEMANAGER_PACKAGE'};

    # Ensure backward compatibility
    $oldPackage = 'Pydio' if $oldPackage eq 'AjaXplorer';

    if ( grep ($_ eq $oldPackage, @{ $self->{'AVAILABLE_PACKAGES'} }) ) {
        my $rs = $self->uninstall( $oldPackage );
        return $rs if $rs;
    }

    my $package = ::setupGetQuestion( 'FILEMANAGER_PACKAGE' );

    $package = "Package::Setup::FileManager::${package}::${package}";
    eval "require $package";
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 unless my $subref = $package->can( 'preinstall' );
    debug( sprintf( 'Executing preinstall action on %s', $package ));
    $subref->( $package->getInstance());
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my $package = ::setupGetQuestion( 'FILEMANAGER_PACKAGE' );
    $package = "Package::Setup::FileManager::${package}::${package}";
    eval "require $package";
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 unless my $subref = $package->can( 'install' );
    debug( sprintf( 'Executing install action on %s', $package ));
    $subref->( $package->getInstance());
}

=item uninstall( [ $package ])

 Process uninstall tasks

 Param string $package OPTIONAL Package to uninstall
 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ( undef, $package ) = @_;

    $package ||= $::imscpConfig{'FILEMANAGER_PACKAGE'};
    return 0 unless $package ne '';

    $package = "Package::Setup::FileManager::${package}::${package}";
    eval "require $package";
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 unless my $subref = $package->can( 'uninstall' );
    debug( sprintf( 'Executing uninstall action on %s', $package ));
    $subref->( $package->getInstance());
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

    my $rs = $self->{'eventManager'}->trigger( 'beforeFileManagerSetGuiPermissions' );
    return $rs if $rs;

    my $package = $::imscpConfig{'FILEMANAGER_PACKAGE'};
    return 0 unless grep { $_ eq $package } @{ $self->{'AVAILABLE_PACKAGES'} };

    $package = "Package::Setup::FileManager::${package}::${package}";
    eval "require $package";
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 unless my $subref = $package->can( 'setGuiPermissions' );

    debug( sprintf( 'Executing setGuiPermissions action on %s', $package ));
    $rs = $subref->( $package->getInstance());
    $rs ||= $self->{'eventManager'}->trigger( 'afterFileManagerSetGuiPermissions' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( )

 Initialize insance

 Return Package::Setup::FileManager

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new(
        dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/Setup/FileManager"
    )->getDirs();

    # Quick fix for disabling Pydio package if PHP >= 7 is detected
    if ( defined $::execmode && $::execmode eq 'setup'
        && version->parse( Package::Setup::FrontEnd->getInstance()->{'config'}->{'PHP_VERSION'} ) >= version->parse( '7.0.0' )
    ) {
        @{ $self->{'AVAILABLE_PACKAGES'} } = grep { $_ ne 'Pydio' } @{ $self->{'AVAILABLE_PACKAGES'} };
    }

    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
