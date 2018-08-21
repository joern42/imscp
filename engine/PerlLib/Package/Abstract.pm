=head1 NAME

 Package::Abstract - Abstract class for i-MSCP packages

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

package Package::Abstract;

use strict;
use warnings;
use iMSCP::DistPackageManager;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Abstract class for i-MSCP packages.

=head1 CLASS METHODS

=over 4

=item getPriority( \%data )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    my ( $self ) = @_;

    0;
}

=back

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

=item getDistPackages( )

 Get list of distribution packages to install or uninstall depending on context

 Return List List of distribution packages to install or uninstall

=cut

sub getDistPackages
{
    my ( $self ) = @_;

    ();
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

    eval { iMSCP::DistPackageManager->getInstance()->installPackages( @packages ); };
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

    eval { iMSCP::DistPackageManager->getInstance()->uninstallPackages( @packages ); };
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

=item preaddDmn( \%data )

 Process the preaddDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddDmn
{
    my ( $self ) = @_;

    0;
}

=item addDmn( \%data )

 Process the addDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addDmn
{
    my ( $self ) = @_;

    0;
}

=item postaddDmn( \%data )

 Process the postaddDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddDmn
{
    my ( $self ) = @_;

    0;
}

=item predeleteDmn( \%data )

 Process the predeleteDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteDmn
{
    my ( $self ) = @_;

    0;
}

=item deleteDmn( \%data )

 Process the deleteDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteDmn
{
    my ( $self ) = @_;

    0;
}

=item postdeleteDmn( \%data )

 Process the postdeleteDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteDmn
{
    my ( $self ) = @_;

    0;
}

=item prerestoreDmn( \%data )

 Process the prerestoreDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreDmn
{
    my ( $self ) = @_;

    0;
}

=item restoreDmn( \%data )

 Process the restoreDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreDmn
{
    my ( $self ) = @_;

    0;
}

=item postrestoreDmn( \%data )

 Process the postrestoreDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreDmn
{
    my ( $self ) = @_;

    0;
}

=item predisableDmn( \%data )

 Process the predisableDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableDmn
{
    my ( $self ) = @_;

    0;
}

=item disableDmn( \%data )

 Process the disableDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableDmn
{
    my ( $self ) = @_;

    0;
}

=item postdisableDmn( \%data )

 Process the postdisableDmn tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableDmn
{
    my ( $self ) = @_;

    0;
}

=item preaddCustomDNS( \%data )

 Process the preaddCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item addCustomDNS( \%data )

 Process the addCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item postaddCustomDNS( \%data )

 Process the postaddCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item predeleteCustomDNS( \%data )

 Process the predeleteCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item deleteCustomDNS( \%data )

 Process the deleteCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item postdeleteCustomDNS( \%data )

 Process the postdeleteCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item prerestoreCustomDNS( \%data )

 Process the prerestoreCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item restoreCustomDNS( \%data )

 Process the restoreCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item postrestoreCustomDNS( \%data )

 Process the postrestoreCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item predisableCustomDNS( \%data )

 Process the predisableCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item disableCustomDNS( \%data )

 Process the disableCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item postdisableCustomDNS( \%data )

 Process the postdisableCustomDNS tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableCustomDNS
{
    my ( $self ) = @_;

    0;
}

=item preaddFtpUser( \%data )

 Process the preaddFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddFtpUser
{
    my ( $self ) = @_;

    0;
}

=item addFtpUser( \%data )

 Process the addFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addFtpUser
{
    my ( $self ) = @_;

    0;
}

=item postaddFtpUser( \%data )

 Process the postaddFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddFtpUser
{
    my ( $self ) = @_;

    0;
}

=item predeleteFtpUser( \%data )

 Process the predeleteFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteFtpUser
{
    my ( $self ) = @_;

    0;
}

=item deleteFtpUser( \%data )

 Process the deleteFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteFtpUser
{
    my ( $self ) = @_;

    0;
}

=item postdeleteFtpUser( \%data )

 Process the postdeleteFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteFtpUser
{
    my ( $self ) = @_;

    0;
}

=item prerestoreFtpUser( \%data )

 Process the prerestoreFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreFtpUser
{
    my ( $self ) = @_;

    0;
}

=item restoreFtpUser( \%data )

 Process the restoreFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreFtpUser
{
    my ( $self ) = @_;

    0;
}

=item postrestoreFtpUser( \%data )

 Process the postrestoreFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreFtpUser
{
    my ( $self ) = @_;

    0;
}

=item predisableFtpUser( \%data )

 Process the predisableFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableFtpUser
{
    my ( $self ) = @_;

    0;
}

=item disableFtpUser( \%data )

 Process the disableFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableFtpUser
{
    my ( $self ) = @_;

    0;
}

=item postdisableFtpUser( \%data )

 Process the postdisableFtpUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableFtpUser
{
    my ( $self ) = @_;

    0;
}

=item preaddHtaccess( \%data )

 Process the preaddHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddHtaccess
{
    my ( $self ) = @_;

    0;
}

=item addHtaccess( \%data )

 Process the addHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addHtaccess
{
    my ( $self ) = @_;

    0;
}

=item postaddHtaccess( \%data )

 Process the postaddHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddHtaccess
{
    my ( $self ) = @_;

    0;
}

=item predeleteHtaccess( \%data )

 Process the predeleteHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteHtaccess
{
    my ( $self ) = @_;

    0;
}

=item deleteHtaccess( \%data )

 Process the deleteHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteHtaccess
{
    my ( $self ) = @_;

    0;
}

=item postdeleteHtaccess( \%data )

 Process the postdeleteHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteHtaccess
{
    my ( $self ) = @_;

    0;
}

=item prerestoreHtaccess( \%data )

 Process the prerestoreHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreHtaccess
{
    my ( $self ) = @_;

    0;
}

=item restoreHtaccess( \%data )

 Process the restoreHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreHtaccess
{
    my ( $self ) = @_;

    0;
}

=item postrestoreHtaccess( \%data )

 Process the postrestoreHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreHtaccess
{
    my ( $self ) = @_;

    0;
}

=item predisableHtaccess( \%data )

 Process the predisableHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableHtaccess
{
    my ( $self ) = @_;

    0;
}

=item disableHtaccess( \%data )

 Process the disableHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableHtaccess
{
    my ( $self ) = @_;

    0;
}

=item postdisableHtaccess( \%data )

 Process the postdisableHtaccess tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableHtaccess
{
    my ( $self ) = @_;

    0;
}

=item preaddHtgroup( \%data )

 Process the preaddHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddHtgroup
{
    my ( $self ) = @_;

    0;
}

=item addHtgroup( \%data )

 Process the addHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addHtgroup
{
    my ( $self ) = @_;

    0;
}

=item postaddHtgroup( \%data )

 Process the postaddHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddHtgroup
{
    my ( $self ) = @_;

    0;
}

=item predeleteHtgroup( \%data )

 Process the predeleteHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteHtgroup
{
    my ( $self ) = @_;

    0;
}

=item deleteHtgroup( \%data )

 Process the deleteHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteHtgroup
{
    my ( $self ) = @_;

    0;
}

=item postdeleteHtgroup( \%data )

 Process the postdeleteHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteHtgroup
{
    my ( $self ) = @_;

    0;
}

=item prerestoreHtgroup( \%data )

 Process the prerestoreHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreHtgroup
{
    my ( $self ) = @_;

    0;
}

=item restoreHtgroup( \%data )

 Process the restoreHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreHtgroup
{
    my ( $self ) = @_;

    0;
}

=item postrestoreHtgroup( \%data )

 Process the postrestoreHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreHtgroup
{
    my ( $self ) = @_;

    0;
}

=item predisableHtgroup( \%data )

 Process the predisableHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableHtgroup
{
    my ( $self ) = @_;

    0;
}

=item disableHtgroup( \%data )

 Process the disableHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableHtgroup
{
    my ( $self ) = @_;

    0;
}

=item postdisableHtgroup( \%data )

 Process the postdisableHtgroup tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableHtgroup
{
    my ( $self ) = @_;

    0;
}

=item preaddHtpasswd( \%data )

 Process the preaddHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item addHtpasswd( \%data )

 Process the addHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item postaddHtpasswd( \%data )

 Process the postaddHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item predeleteHtpasswd( \%data )

 Process the predeleteHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item deleteHtpasswd( \%data )

 Process the deleteHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item postdeleteHtpasswd( \%data )

 Process the postdeleteHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item prerestoreHtpasswd( \%data )

 Process the prerestoreHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item restoreHtpasswd( \%data )

 Process the restoreHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item postrestoreHtpasswd( \%data )

 Process the postrestoreHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item predisableHtpasswd( \%data )

 Process the predisableHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item disableHtpasswd( \%data )

 Process the disableHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item postdisableHtpasswd( \%data )

 Process the postdisableHtpasswd tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableHtpasswd
{
    my ( $self ) = @_;

    0;
}

=item preaddMail( \%data )

 Process the preaddMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddMail
{
    my ( $self ) = @_;

    0;
}

=item addMail( \%data )

 Process the addMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addMail
{
    my ( $self ) = @_;

    0;
}

=item postaddMail( \%data )

 Process the postaddMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddMail
{
    my ( $self ) = @_;

    0;
}

=item predeleteMail( \%data )

 Process the predeleteMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteMail
{
    my ( $self ) = @_;

    0;
}

=item deleteMail( \%data )

 Process the deleteMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteMail
{
    my ( $self ) = @_;

    0;
}

=item postdeleteMail( \%data )

 Process the postdeleteMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteMail
{
    my ( $self ) = @_;

    0;
}

=item prerestoreMail( \%data )

 Process the prerestoreMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreMail
{
    my ( $self ) = @_;

    0;
}

=item restoreMail( \%data )

 Process the restoreMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreMail
{
    my ( $self ) = @_;

    0;
}

=item postrestoreMail( \%data )

 Process the postrestoreMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreMail
{
    my ( $self ) = @_;

    0;
}

=item predisableMail( \%data )

 Process the predisableMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableMail
{
    my ( $self ) = @_;

    0;
}

=item disableMail( \%data )

 Process the disableMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableMail
{
    my ( $self ) = @_;

    0;
}

=item postdisableMail( \%data )

 Process the postdisableMail tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableMail
{
    my ( $self ) = @_;

    0;
}

=item preaddServerIP( \%data )

 Process the preaddServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddServerIP
{
    my ( $self ) = @_;

    0;
}

=item addServerIP( \%data )

 Process the addServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addServerIP
{
    my ( $self ) = @_;

    0;
}

=item postaddServerIP( \%data )

 Process the postaddServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddServerIP
{
    my ( $self ) = @_;

    0;
}

=item predeleteServerIP( \%data )

 Process the predeleteServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteServerIP
{
    my ( $self ) = @_;

    0;
}

=item deleteServerIP( \%data )

 Process the deleteServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteServerIP
{
    my ( $self ) = @_;

    0;
}

=item postdeleteServerIP( \%data )

 Process the postdeleteServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteServerIP
{
    my ( $self ) = @_;

    0;
}

=item prerestoreServerIP( \%data )

 Process the prerestoreServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreServerIP
{
    my ( $self ) = @_;

    0;
}

=item restoreServerIP( \%data )

 Process the restoreServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreServerIP
{
    my ( $self ) = @_;

    0;
}

=item postrestoreServerIP( \%data )

 Process the postrestoreServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreServerIP
{
    my ( $self ) = @_;

    0;
}

=item predisableServerIP( \%data )

 Process the predisableServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableServerIP
{
    my ( $self ) = @_;

    0;
}

=item disableServerIP( \%data )

 Process the disableServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableServerIP
{
    my ( $self ) = @_;

    0;
}

=item postdisableServerIP( \%data )

 Process the postdisableServerIP tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableServerIP
{
    my ( $self ) = @_;

    0;
}


=item preaddSSLcertificate( \%data )

 Process the preaddSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item addSSLcertificate( \%data )

 Process the addSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item postaddSSLcertificate( \%data )

 Process the postaddSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item predeleteSSLcertificate( \%data )

 Process the predeleteSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item deleteSSLcertificate( \%data )

 Process the deleteSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item postdeleteSSLcertificate( \%data )

 Process the postdeleteSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item prerestoreSSLcertificate( \%data )

 Process the prerestoreSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item restoreSSLcertificate( \%data )

 Process the restoreSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item postrestoreSSLcertificate( \%data )

 Process the postrestoreSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item predisableSSLcertificate( \%data )

 Process the predisableSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item disableSSLcertificate( \%data )

 Process the disableSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item postdisableSSLcertificate( \%data )

 Process the postdisableSSLcertificate tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableSSLcertificate
{
    my ( $self ) = @_;

    0;
}

=item preaddUser( \%data )

 Process the preaddUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub preaddUser
{
    my ( $self ) = @_;

    0;
}

=item addUser( \%data )

 Process the addUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub addUser
{
    my ( $self ) = @_;

    0;
}

=item postaddUser( \%data )

 Process the postaddUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postaddUser
{
    my ( $self ) = @_;

    0;
}

=item predeleteUser( \%data )

 Process the predeleteUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predeleteUser
{
    my ( $self ) = @_;

    0;
}

=item deleteUser( \%data )

 Process the deleteUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub deleteUser
{
    my ( $self ) = @_;

    0;
}

=item postdeleteUser( \%data )

 Process the postdeleteUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdeleteUser
{
    my ( $self ) = @_;

    0;
}

=item prerestoreUser( \%data )

 Process the prerestoreUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub prerestoreUser
{
    my ( $self ) = @_;

    0;
}

=item restoreUser( \%data )

 Process the restoreUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub restoreUser
{
    my ( $self ) = @_;

    0;
}

=item postrestoreUser( \%data )

 Process the postrestoreUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postrestoreUser
{
    my ( $self ) = @_;

    0;
}

=item predisableUser( \%data )

 Process the predisableUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub predisableUser
{
    my ( $self ) = @_;

    0;
}

=item disableUser( \%data )

 Process the disableUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub disableUser
{
    my ( $self ) = @_;

    0;
}

=item postdisableUser( \%data )

 Process the postdisableUser tasks

 Param hashref \%data Module data
 Return int 0 on success, other on failure

=cut

sub postdisableUser
{
    my ( $self ) = @_;

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
