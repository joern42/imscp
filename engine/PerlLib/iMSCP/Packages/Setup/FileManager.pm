=head1 NAME

 iMSCP::Packages::Setup::FileManager - i-MSCP FileManager package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Packages::Setup::FileManager;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList /;
use File::Basename;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::Getopt;
use iMSCP::Packages::FrontEnd;
use version;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP FileManager package.

 Handles FileManager packages found in the FileManager directory.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners

 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->showDialog( @_ ) }; } );
}

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30, die on failure

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    @{ $self->{'SELECTED_PACKAGES'} } = split(
        ',', ::setupGetQuestion( 'FILEMANAGER_PACKAGES', iMSCP::Getopt->preseed ? join( ',', @{ $self->{'AVAILABLE_PACKAGES'} } ) : '' )
    );

    my %choices;
    @choices{@{ $self->{'AVAILABLE_PACKAGES'} }} = @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'filemanagers', 'all', 'forced' ] )
        || !@{ $self->{'SELECTED_PACKAGES'} }
        || grep { !exists $choices{$_} && $_ ne 'no' } @{ $self->{'SELECTED_PACKAGES'} }
    ) {
        ( my $rs, $self->{'SELECTED_PACKAGES'} ) = $dialog->checkbox(
            <<"EOF", \%choices, [ grep { exists $choices{$_} && $_ ne 'no' } @{ $self->{'SELECTED_PACKAGES'} } ] );
Please select the FTP filemanager packages you want to install:
\\Z \\Zn
EOF
        push @{ $self->{'SELECTED_PACKAGES'} }, 'no' unless @{ $self->{'SELECTED_PACKAGES'} };
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'FILEMANAGER_PACKAGES', join ',', @{ $self->{'SELECTED_PACKAGES'} } );

    return 0 if $self->{'SELECTED_PACKAGES'}->[0] eq 'no';

    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );
        ( my $subref = $fpackage->can( 'showDialog' ) ) or next;
        debug( sprintf( 'Executing showDialog action on %s', $fpackage ));
        my $rs = $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ), $dialog );
        return $rs if $rs;
    }

    0;
}

=item preinstall( )

 Process preinstall tasks

 /!\ This method also trigger uninstallation of unselected file manager packages.

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for my $package ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next if grep ( $package eq $_, @{ $self->{'SELECTED_PACKAGES'} });
        $package = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $package" or die( $@ );

        if ( my $subref = $package->can( 'uninstall' ) ) {
            debug( sprintf( 'Executing uninstall action on %s', $package ));
            $subref->( $package->getInstance( eventManager => $self->{'eventManager'} ));
        }

        ( my $subref = $package->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $package ));
        push @distroPackages, $subref->( $package->getInstance( eventManager => $self->{'eventManager'} ));
    }

    $self->_removePackages( @distroPackages );

    @distroPackages = ();
    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );

        if ( my $subref = $fpackage->can( 'preinstall' ) ) {
            debug( sprintf( 'Executing preinstall action on %s', $fpackage ));
            $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
        }

        ( my $subref = $fpackage->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $fpackage ));
        push @distroPackages, $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
    }

    $self->_installPackages( @distroPackages );
}

=item install( )

 Process install tasks

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;

    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );
        ( my $subref = $fpackage->can( 'install' ) ) or next;
        debug( sprintf( 'Executing install action on %s', $fpackage ));
        $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
    }
}

=item postinstall( )

 Process post install tasks

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );
        ( my $subref = $fpackage->can( 'postinstall' ) ) or next;
        debug( sprintf( 'Executing postinstall action on %s', $fpackage ));
        $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
    }
}

=item uninstall( [ $package ])

 Process uninstall tasks

 Param string $package OPTIONAL Package to uninstall
 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );

        if ( my $subref = $fpackage->can( 'uninstall' ) ) {
            debug( sprintf( 'Executing preinstall action on %s', $fpackage ));
            $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
        }

        ( my $subref = $fpackage->can( 'getDistroPackages' ) ) or next;
        debug( sprintf( 'Executing getDistroPackages action on %s', $fpackage ));
        push @distroPackages, $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
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

 Return void, die on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );
        ( my $subref = $fpackage->can( 'setEnginePermissions' ) ) or next;
        debug( sprintf( 'Executing setEnginePermissions action on %s', $fpackage ));
        $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
    }
}

=item setGuiPermissions( )

 Set gui permissions

 Return void, die on failure

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    for my $package ( @{ $self->{'SELECTED_PACKAGES'} } ) {
        my $fpackage = "iMSCP::Packages::Setup::FileManager::${package}::${package}";
        eval "require $fpackage" or die( $@ );
        ( my $subref = $fpackage->can( 'setGuiPermissions' ) ) or next;
        debug( sprintf( 'Executing setGuiPermissions action on %s', $fpackage ));
        $subref->( $fpackage->getInstance( eventManager => $self->{'eventManager'} ));
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( )

 Initialize insance

 Return iMSCP::Packages::Setup::FileManager, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    # Pydio package temporarily disabled due to PHP version constraint that is not met
    @{ $self->{'AVAILABLE_PACKAGES'} } = grep ( $_ ne 'Pydio', iMSCP::Dir->new( dirname => dirname( __FILE__ ) . '/FileManager' )->getDirs());
    @{ $self->{'SELECTED_PACKAGES'} } = grep ( $_ ne 'no', split( ',', $::imscpConfig{'FILEMANAGER_PACKAGES'} ));
    $self;
}

=item _installPackages( @packages )

 Install distribution packages

 Param list @packages List of packages to install
 Return void, die on failure

=cut

sub _installPackages
{
    my ( undef, @packages ) = @_;

    return unless @packages && !iMSCP::Getopt->skippackages;

    iMSCP::Dialog->getInstance->endGauge() unless iMSCP::Getopt->noprompt;

    local $ENV{'UCF_FORCE_CONFFNEW'} = 1;
    local $ENV{'UCF_FORCE_CONFFMISS'} = 1;

    my $stdout;
    my $rs = execute(
        [
            ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
            'apt-get', '--assume-yes', '--option', 'DPkg::Options::=--force-confnew',
            '--option', 'DPkg::Options::=--force-confmiss', '--option', 'Dpkg::Options::=--force-overwrite',
            '--auto-remove', '--purge', '--no-install-recommends',
            ( version->parse( `apt-get --version 2>/dev/null` =~ /^apt\s+(\d\.\d)/ ) < version->parse( '1.1' )
                ? '--force-yes' : '--allow-downgrades' ),
            'install', @packages
        ],
        ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ),
        \my $stderr
    );
    !$rs or die( sprintf( "Couldn't install packages: %s", $stderr || 'Unknown error' ));
}

=item _removePackages( @packages )

 Remove distribution packages

 Param list @packages Packages to remove
 Return void, die on failure

=cut

sub _removePackages
{
    my ( undef, @packages ) = @_;

    return unless @packages && !iMSCP::Getopt->skippackages;

    # Do not try to remove packages that are not available
    execute( "dpkg-query -W -f='\${Package}\\n' @packages 2>/dev/null", \my $stdout );
    @packages = split /\n/, $stdout;
    return unless @packages;

    iMSCP::Dialog->getInstance()->endGauge() unless iMSCP::Getopt->noprompt;

    my $rs = execute(
        [
            ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
            'apt-get', '--assume-yes', '--auto-remove', '--purge', '--no-install-recommends', 'remove', @packages
        ],
        ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ),
        \my $stderr
    );
    !$rs or die( sprintf( "Couldn't remove packages: %s", $stderr || 'Unknown error' ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
