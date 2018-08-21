=head1 NAME

 Package::AbstractCollection - Abstract class for package collection

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

package Package::AbstractCollection;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList /;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Getopt;
use parent 'Package::Abstract';

=head1 DESCRIPTION

 Abstract class for package collection.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 Get type of packages for this collection

 Return string Type of packages

=cut

sub getType
{
    my ( $self ) = @_;

    die( sprintf( 'The %s package must implement the getType() method', ref $self || $self ));
}

=item registerSetupListeners( $eventManager )

 See Package::Abstract::registerSetupListers()

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->askForPackages( @_ ) };
        0;
    } );
}

=item askForWebstatPackages( $dialog )

 Ask for Webstats packages

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForPackages
{
    my ( $self, $dialog ) = @_;

    my $selectedPackages = [ split ',', ::setupGetQuestion( uc $self->getType() . '_PACKAGES' ) ];
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ lc $self->getType(), 'all' ] ) || !@{ $selectedPackages }
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages }
    ) {
        ( my $rs, $selectedPackages ) = $dialog->checklist(
            <<"EOF", \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $selectedPackages } ] );

Please select the @{ [ $self->getType() ] } packages you want to install:
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $selectedPackages } = grep ( $_ ne 'none', @{ $selectedPackages } );
    ::setupSetQuestion( uc $self->getType() . '_PACKAGES', @{ $selectedPackages } ? join ',', @{ $selectedPackages } : 'none' );

    my @dialogs;
    for my $package ( @{ $selectedPackages } ) {
        $package = "Package::@{ [ $self->getType() ] }::${package}::${package}";
        eval "require $package" or die;
        my $subref = $package->can( 'showDialog' );
        push @dialogs, sub { $subref->( $package->getInstance(), @_ ) } if $subref;
    }

    $dialog->executeDialogs( \@dialogs );
}

=item preinstall( )

 See Package::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my %selectedPackages;
    @{selectedPackages}{ split ',', ::setupGetQuestion( uc $self->getType() . '_PACKAGES' ) } = ();
    my @distroPackages = ();

    for my $package ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next if exists $selectedPackages{$package};
        my $class = "Package::Webstats::${package}::${package}";
        eval "require $class" or die;
        my $instance = $class->getInstance();

        debug( sprintf( 'Executing uninstall action on %s', $package ));
        my $rs = $instance->uninstall();
        return $rs if $rs;

        if ( defined $::skippackages && !$::skippackages ) {
            debug( sprintf( 'Executing getDistPackages action on %s', $package ));
            push @distroPackages, $instance->getDistPackages();
        }
    }

    if ( defined $::skippackages && !$::skippackages ) {
        my $rs = $self->removePackages( @distroPackages );
        return $rs if $rs;
    }

    @distroPackages = ();
    for my $package ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        my $class = "Package::Webstats::${package}::${package}";
        eval "require $class" or die;
        my $instance = $class->getInstance();

        debug( sprintf( 'Executing preinstall action on %s', $package ));
        my $rs = $instance->preinstall();
        return $rs if $rs;

        if ( defined $::skippackages && !$::skippackages ) {
            debug( sprintf( 'Executing getDistPackages action on %s', $package ));
            push @distroPackages, $instance->getDistPackages();
        }
    }

    if ( defined $::skippackages && !$::skippackages ) {
        my $rs = $self->installPackages( @distroPackages );
        return $rs if $rs;
    }

    0;
}

=item install( )

 See Package::Abstract::install()

=cut

sub install
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postinstall( )

 See Package::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preuninstall( )

 See Package::Abstract::preuninstall()

=cut

sub preuninstall
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item uninstall( \%data )

 See Package::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for my $package ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        my $class = "Package::Webstats::${package}::${package}";
        eval "require $class" or die;
        my $instance = $class->getInstance();

        debug( sprintf( 'Executing uninstall action on %s', $package ));
        my $rs = $instance->uninstall();
        return $rs if $rs;

        debug( sprintf( 'Executing getDistPackages action on %s', $package ));
        push @distroPackages, $instance->getDistPackages();
    }

    $self->removePackages( @distroPackages );
}

=item postuninstall( )

 See Package::Abstract::postuninstall()

=cut

sub postuninstall
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item setEnginePermissions( )

 See Package::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item setGuiPermissions( )

 See Package::Abstract::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item dpkgPostInvokeTasks( )

 See Package::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddDmn( \%data )

 See Package::Abstract::preaddDmn()

=cut

sub preaddDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addDmn( \%data )

 See Package::Abstract::addDmn()

=cut

sub addDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddDmn( \%data )

 See Package::Abstract::postaddDmn()

=cut

sub postaddDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteDmn( \%data )

 See Package::Abstract::predeleteDmn()

=cut

sub predeleteDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteDmn( \%data )

 See Package::Abstract::deleteDmn()

=cut

sub deleteDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteDmn( \%data )

 See Package::Abstract::postdeleteDmn()

=cut

sub postdeleteDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreDmn( \%data )

 See Package::Abstract::prerestoreDmn()

=cut

sub prerestoreDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreDmn( \%data )

 See Package::Abstract::restoreDmn()

=cut

sub restoreDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreDmn( \%data )

 See Package::Abstract::postrestoreDmn()

=cut

sub postrestoreDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableDmn( \%data )

 See Package::Abstract::predisableDmn()

=cut

sub predisableDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableDmn( \%data )

 See Package::Abstract::disableDmn()

=cut

sub disableDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableDmn( \%data )

 See Package::Abstract::postdisableDmn()

=cut

sub postdisableDmn
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddCustomDNS( \%data )

 See Package::Abstract::preaddCustomDNS()

=cut

sub preaddCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addCustomDNS( \%data )

 See Package::Abstract::addCustomDNS()

=cut

sub addCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddCustomDNS( \%data )

 See Package::Abstract::postaddCustomDNS()

=cut

sub postaddCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteCustomDNS( \%data )

 See Package::Abstract::predeleteCustomDNS()

=cut

sub predeleteCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteCustomDNS( \%data )

 See Package::Abstract::deleteCustomDNS()

=cut

sub deleteCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteCustomDNS( \%data )

 See Package::Abstract::postdeleteCustomDNS()

=cut

sub postdeleteCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreCustomDNS( \%data )

 See Package::Abstract::prerestoreCustomDNS()

=cut

sub prerestoreCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreCustomDNS( \%data )

 See Package::Abstract::restoreCustomDNS()

=cut

sub restoreCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreCustomDNS( \%data )

 See Package::Abstract::postrestoreCustomDNS()

=cut

sub postrestoreCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableCustomDNS( \%data )

 See Package::Abstract::predisableCustomDNS()

=cut

sub predisableCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableCustomDNS( \%data )

 See Package::Abstract::disableCustomDNS()

=cut

sub disableCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableCustomDNS( \%data )

 See Package::Abstract::postdisableCustomDNS()

=cut

sub postdisableCustomDNS
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddFtpUser( \%data )

 See Package::Abstract::preaddFtpUser()

=cut

sub preaddFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addFtpUser( \%data )

 See Package::Abstract::addFtpUser()

=cut

sub addFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddFtpUser( \%data )

 See Package::Abstract::postaddFtpUser()

=cut

sub postaddFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteFtpUser( \%data )

 See Package::Abstract::predeleteFtpUser()

=cut

sub predeleteFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteFtpUser( \%data )

 See Package::Abstract::deleteFtpUser()

=cut

sub deleteFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteFtpUser( \%data )

 See Package::Abstract::postdeleteFtpUser()

=cut

sub postdeleteFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreFtpUser( \%data )

 See Package::Abstract::prerestoreFtpUser()

=cut

sub prerestoreFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreFtpUser( \%data )

 See Package::Abstract::restoreFtpUser()

=cut

sub restoreFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreFtpUser( \%data )

 See Package::Abstract::postrestoreFtpUser()

=cut

sub postrestoreFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableFtpUser( \%data )

 See Package::Abstract::predisableFtpUser()

=cut

sub predisableFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableFtpUser( \%data )

 See Package::Abstract::disableFtpUser()

=cut

sub disableFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableFtpUser( \%data )

 See Package::Abstract::postdisableFtpUser()

=cut

sub postdisableFtpUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddHtaccess( \%data )

 See Package::Abstract::preaddHtaccess()

=cut

sub preaddHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addHtaccess( \%data )

 See Package::Abstract::addHtaccess()

=cut

sub addHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddHtaccess( \%data )

 See Package::Abstract::postaddHtaccess()

=cut

sub postaddHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteHtaccess( \%data )

 See Package::Abstract::predeleteHtaccess()

=cut

sub predeleteHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteHtaccess( \%data )

 See Package::Abstract::deleteHtaccess()

=cut

sub deleteHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteHtaccess( \%data )

 See Package::Abstract::postdeleteHtaccess()

=cut

sub postdeleteHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreHtaccess( \%data )

 See Package::Abstract::prerestoreHtaccess()

=cut

sub prerestoreHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreHtaccess( \%data )

 See Package::Abstract::restoreHtaccess()

=cut

sub restoreHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreHtaccess( \%data )

 See Package::Abstract::postrestoreHtaccess()

=cut

sub postrestoreHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableHtaccess( \%data )

 See Package::Abstract::predisableHtaccess()

=cut

sub predisableHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableHtaccess( \%data )

 See Package::Abstract::disableHtaccess()

=cut

sub disableHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableHtaccess( \%data )

 See Package::Abstract::postdisableHtaccess()

=cut

sub postdisableHtaccess
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddHtgroup( \%data )

 See Package::Abstract::preaddHtgroup()

=cut

sub preaddHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addHtgroup( \%data )

 See Package::Abstract::addHtgroup()

=cut

sub addHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddHtgroup( \%data )

 See Package::Abstract::postaddHtgroup()

=cut

sub postaddHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteHtgroup( \%data )

 See Package::Abstract::predeleteHtgroup()

=cut

sub predeleteHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteHtgroup( \%data )

 See Package::Abstract::deleteHtgroup()

=cut

sub deleteHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteHtgroup( \%data )

 See Package::Abstract::postdeleteHtgroup()

=cut

sub postdeleteHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreHtgroup( \%data )

 See Package::Abstract::prerestoreHtgroup()

=cut

sub prerestoreHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreHtgroup( \%data )

 See Package::Abstract::restoreHtgroup()

=cut

sub restoreHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreHtgroup( \%data )

 See Package::Abstract::postrestoreHtgroup()

=cut

sub postrestoreHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableHtgroup( \%data )

 See Package::Abstract::predisableHtgroup()

=cut

sub predisableHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableHtgroup( \%data )

 See Package::Abstract::disableHtgroup()

=cut

sub disableHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableHtgroup( \%data )

 See Package::Abstract::postdisableHtgroup()

=cut

sub postdisableHtgroup
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddHtpasswd( \%data )

 See Package::Abstract::preaddHtpasswd()

=cut

sub preaddHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addHtpasswd( \%data )

 See Package::Abstract::addHtpasswd()

=cut

sub addHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddHtpasswd( \%data )

 See Package::Abstract::postaddHtpasswd()

=cut

sub postaddHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteHtpasswd( \%data )

 See Package::Abstract::predeleteHtpasswd()

=cut

sub predeleteHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteHtpasswd( \%data )

 See Package::Abstract::deleteHtpasswd()

=cut

sub deleteHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteHtpasswd( \%data )

 See Package::Abstract::postdeleteHtpasswd()

=cut

sub postdeleteHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreHtpasswd( \%data )

 See Package::Abstract::prerestoreHtpasswd()

=cut

sub prerestoreHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreHtpasswd( \%data )

 See Package::Abstract::restoreHtpasswd()

=cut

sub restoreHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreHtpasswd( \%data )

 See Package::Abstract::postrestoreHtpasswd()

=cut

sub postrestoreHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableHtpasswd( \%data )

 See Package::Abstract::predisableHtpasswd()

=cut

sub predisableHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableHtpasswd( \%data )

 See Package::Abstract::disableHtpasswd()

=cut

sub disableHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableHtpasswd( \%data )

 See Package::Abstract::postdisableHtpasswd()

=cut

sub postdisableHtpasswd
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddMail( \%data )

 See Package::Abstract::preaddMail()

=cut

sub preaddMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addMail( \%data )

 See Package::Abstract::addMail()

=cut

sub addMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddMail( \%data )

 See Package::Abstract::postaddMail()

=cut

sub postaddMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteMail( \%data )

 See Package::Abstract::predeleteMail()

=cut

sub predeleteMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteMail( \%data )

 See Package::Abstract::deleteMail()

=cut

sub deleteMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteMail( \%data )

 See Package::Abstract::postdeleteMail()

=cut

sub postdeleteMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreMail( \%data )

 See Package::Abstract::prerestoreMail()

=cut

sub prerestoreMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreMail( \%data )

 See Package::Abstract::restoreMail()

=cut

sub restoreMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreMail( \%data )

 See Package::Abstract::postrestoreMail()

=cut

sub postrestoreMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableMail( \%data )

 See Package::Abstract::predisableMail()

=cut

sub predisableMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableMail( \%data )

 See Package::Abstract::disableMail()

=cut

sub disableMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableMail( \%data )

 See Package::Abstract::postdisableMail()

=cut

sub postdisableMail
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}


=item preaddServerIP( \%data )

 See Package::Abstract::preaddServerIP()

=cut

sub preaddServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addServerIP( \%data )

 See Package::Abstract::addServerIP()

=cut

sub addServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddServerIP( \%data )

 See Package::Abstract::postaddServerIP()

=cut

sub postaddServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteServerIP( \%data )

 See Package::Abstract::predeleteServerIP()

=cut

sub predeleteServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteServerIP( \%data )

 See Package::Abstract::deleteServerIP()

=cut

sub deleteServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteServerIP( \%data )

 See Package::Abstract::postdeleteServerIP()

=cut

sub postdeleteServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreServerIP( \%data )

 See Package::Abstract::prerestoreServerIP()

=cut

sub prerestoreServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreServerIP( \%data )

 See Package::Abstract::restoreServerIP()

=cut

sub restoreServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreServerIP( \%data )

 See Package::Abstract::postrestoreServerIP()

=cut

sub postrestoreServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableServerIP( \%data )

 See Package::Abstract::predisableServerIP()

=cut

sub predisableServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableServerIP( \%data )

 See Package::Abstract::disableServerIP()

=cut

sub disableServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableServerIP( \%data )

 See Package::Abstract::postdisableServerIP()

=cut

sub postdisableServerIP
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddSSLcertificate( \%data )

 See Package::Abstract::preaddSSLcertificate()

=cut

sub preaddSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addSSLcertificate( \%data )

 See Package::Abstract::addSSLcertificate()

=cut

sub addSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddSSLcertificate( \%data )

 See Package::Abstract::postaddSSLcertificate()

=cut

sub postaddSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteSSLcertificate( \%data )

 See Package::Abstract::predeleteSSLcertificate()

=cut

sub predeleteSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteSSLcertificate( \%data )

 See Package::Abstract::deleteSSLcertificate()

=cut

sub deleteSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteSSLcertificate( \%data )

 See Package::Abstract::postdeleteSSLcertificate()

=cut

sub postdeleteSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreSSLcertificate( \%data )

 See Package::Abstract::prerestoreSSLcertificate()

=cut

sub prerestoreSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreSSLcertificate( \%data )

 See Package::Abstract::restoreSSLcertificate()

=cut

sub restoreSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreSSLcertificate( \%data )

 See Package::Abstract::postrestoreSSLcertificate()

=cut

sub postrestoreSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableSSLcertificate( \%data )

 See Package::Abstract::predisableSSLcertificate()

=cut

sub predisableSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableSSLcertificate( \%data )

 See Package::Abstract::disableSSLcertificate()

=cut

sub disableSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableSSLcertificate( \%data )

 See Package::Abstract::postdisableSSLcertificate()

=cut

sub postdisableSSLcertificate
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item preaddUser( \%data )

 See Package::Abstract::preaddUser()

=cut

sub preaddUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item addUser( \%data )

 See Package::Abstract::addUser()

=cut

sub addUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postaddUser( \%data )

 See Package::Abstract::postaddUser()

=cut

sub postaddUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predeleteUser( \%data )

 See Package::Abstract::predeleteUser()

=cut

sub predeleteUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item deleteUser( \%data )

 See Package::Abstract::deleteUser()

=cut

sub deleteUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdeleteUser( \%data )

 See Package::Abstract::postdeleteUser()

=cut

sub postdeleteUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item prerestoreUser( \%data )

 See Package::Abstract::prerestoreUser()

=cut

sub prerestoreUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item restoreUser( \%data )

 See Package::Abstract::restoreUser()

=cut

sub restoreUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postrestoreUser( \%data )

 See Package::Abstract::postrestoreUser()

=cut

sub postrestoreUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item predisableUser( \%data )

 See Package::Abstract::predisableUser()

=cut

sub predisableUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item disableUser( \%data )

 See Package::Abstract::disableUser()

=cut

sub disableUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=item postdisableUser( \%data )

 See Package::Abstract::postdisableUser()

=cut

sub postdisableUser
{
    my ( $self ) = shift;

    $self->_executePackageAction( @_ );
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( \%data )

 Initialize instance

 Return Package::AbstractCollection

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new(
        dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/@{ [ $self->getType() ] }"
    )->getDirs();
    $self;
}

=item _executePackageAction( [ \%data ] )

 Call action on selected packages

 Param hashref \$data Module data if action called by a module
 Return int 0 on success, other on failure

=cut

sub _executePackageAction
{
    my ( $self ) = shift;
    ( my $method = $Package::Webstats::AUTOLOAD ) =~ s/.*:://;

    CORE::state @packages;
    @packages = split ',', $::imscpConfig{uc $self->getType() } unless @packages;

    for my $package ( @packages ) {
        my $class = "Package::Webstats::${package}::${package}";
        eval "require $package" or die;
        debug( sprintf( "Executing '%s' action on %s", $method, $package ));
        my $rs = $class->getInstance()->$method( @_ );
        return $rs if $rs;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
