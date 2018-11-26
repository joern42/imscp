=head1 NAME

 iMSCP::Package::AbstractCollection - Abstract class for i-MSCP package collection

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

package iMSCP::Package::AbstractCollection;

use strict;
use warnings;
use autouse 'iMSCP::InputValidation' => 'isOneOfStringsInList';
use Carp 'confess';
use iMSCP::Boolean;
use iMSCP::Cwd '$CWD';
use iMSCP::Debug 'debug';
use iMSCP::DistPackageManager;
use iMSCP::Getopt;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Abstract class for i-MSCP package collection.
 
 An i-MSCP package collection gather i-MSCP packages which serve the same purpose.
 
 This class is meant to be subclassed by i-MSCP package collection classes.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, sub { $self->_askForPackages( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()
 
 This will first uninstall unselected packages.

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = 0;

    ACTION:
    for my $action ( 'preuninstall', 'uninstall', 'postuninstall' ) {
        for my $package ( @{ $self->getUnselectedPackages() } ) {
            debug( sprintf( 'Executing %s %s tasks...', ref $package, $action ));
            $rs = $package->$action();
            last ACTION if $rs;
        }
    }

    iMSCP::DistPackageManager->getInstance()->processDelayedTasks();

    $rs ||= $self->_executeActionOnSelectedPackages( 'preinstall' );
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'install' );
}

=item postinstall( )

 See iMSCP::Installer::AbstractActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'postinstall' );
}

=item preuninstall( )

 See iMSCP::Uninstaller::AbstractActions::preuninstall()

=cut

sub preuninstall
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'preuninstall' );
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'uninstall' );
}

=item postuninstall( )

 See iMSCP::Uninstaller::AbstractActions::postuninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'postuninstall' );
}

=item setEnginePermissions( )

 See iMSCP::Installer::AbstractActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'setEnginePermissions' );
}

=item setGuiPermissions( )

 See iMSCP::Installer::AbstractActions::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'setGuiPermissions' );
}

=item dpkgPostInvokeTasks( )

 See iMSCP::Installer::AbstractActions::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    $self->_executeActionOnSelectedPackages( 'dpkgPostInvokeTasks' );
}

=item preaddDmn( \%data )

 See iMSCP::Modules::AbstractActions::preaddDmn()

=cut

sub preaddDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddDmn', $data );
}

=item addDmn( \%data )

 See iMSCP::Modules::AbstractActions::addDmn()

=cut

sub addDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addDmn', $data );
}

=item postaddDmn( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddDmn', $data );
}

=item predeleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::predeleteDmn()

=cut

sub predeleteDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteDmn', $data );
}

=item deleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::deleteDmn()

=cut

sub deleteDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteDmn', $data );
}

=item postdeleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteDmn()

=cut

sub postdeleteDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteDmn', $data );
}

=item prerestoreDmn( \%data )

 See iMSCP::Modules::AbstractActions::prerestoreDmn()

=cut

sub prerestoreDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'prerestoreDmn', $data );
}

=item restoreDmn( \%data )

 See iMSCP::Modules::AbstractActions::restoreDmn()

=cut

sub restoreDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'restoreDmn', $data );
}

=item postrestoreDmn( \%data )

 See iMSCP::Modules::AbstractActions::postrestoreDmn()

=cut

sub postrestoreDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postrestoreDmn', $data );
}

=item predisableDmn( \%data )

 See iMSCP::Modules::AbstractActions::predisableDmn()

=cut

sub predisableDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableDmn', $data );
}

=item disableDmn( \%data )

 See iMSCP::Modules::AbstractActions::disableDmn()

=cut

sub disableDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableDmn', $data );
}

=item postdisableDmn( \%data )

 See iMSCP::Modules::AbstractActions::postdisableDmn()

=cut

sub postdisableDmn
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableDmn', $data );
}

=item preaddSub( \%data )

 See iMSCP::Modules::AbstractActions::preaddSub()

=cut

sub preaddSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddSub', $data );
}

=item addSub( \%data )

 See iMSCP::Modules::AbstractActions::addSub()

=cut

sub addSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addSub', $data );
}

=item postaddSub( \%data )

 See iMSCP::Modules::AbstractActions::postaddSub()

=cut

sub postaddSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddSub', $data );
}

=item predeleteSub( \%data )

 See iMSCP::Modules::AbstractActions::predeleteSub()

=cut

sub predeleteSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteSub', $data );
}

=item deleteSub( \%data )

 See iMSCP::Modules::AbstractActions::deleteSub()

=cut

sub deleteSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteSub', $data );
}

=item postdeleteSub( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteSub()

=cut

sub postdeleteSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteSub', $data );
}

=item prerestoreSub( \%data )

 See iMSCP::Modules::AbstractActions::prerestoreSub()

=cut

sub prerestoreSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'prerestoreSub', $data );
}

=item restoreSub( \%data )

 See iMSCP::Modules::AbstractActions::restoreSub()

=cut

sub restoreSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'restoreSub', $data );
}

=item postrestoreSub( \%data )

 See iMSCP::Modules::AbstractActions::postrestoreSub()

=cut

sub postrestoreSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postrestoreSub', $data );
}

=item predisableSub( \%data )

 See iMSCP::Modules::AbstractActions::predisableSub()

=cut

sub predisableSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableSub', $data );
}

=item disableSub( \%data )

 See iMSCP::Modules::AbstractActions::disableSub()

=cut

sub disableSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableSub', $data );
}

=item postdisableSub( \%data )

 See iMSCP::Modules::AbstractActions::postdisableSub()

=cut

sub postdisableSub
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableSub', $data );
}

=item preaddCustomDNS( \%data )

 See iMSCP::Modules::AbstractActions::preaddCustomDNS()

=cut

sub preaddCustomDNS
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddCustomDNS', $data );
}

=item addCustomDNS( \%data )

 See iMSCP::Modules::AbstractActions::addCustomDNS()

=cut

sub addCustomDNS
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addCustomDNS', $data );
}

=item postaddCustomDNS( \%data )

 See iMSCP::Modules::AbstractActions::postaddCustomDNS()

=cut

sub postaddCustomDNS
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddCustomDNS', $data );
}

=item preaddFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::preaddFtpUser()

=cut

sub preaddFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddFtpUser', $data );
}

=item addFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::addFtpUser()

=cut

sub addFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addFtpUser', $data );
}

=item postaddFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::postaddFtpUser()

=cut

sub postaddFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddFtpUser', $data );
}

=item predeleteFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::predeleteFtpUser()

=cut

sub predeleteFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteFtpUser', $data );
}

=item deleteFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::deleteFtpUser()

=cut

sub deleteFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteFtpUser', $data );
}

=item postdeleteFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteFtpUser()

=cut

sub postdeleteFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteFtpUser', $data );
}

=item predisableFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::predisableFtpUser()

=cut

sub predisableFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableFtpUser', $data );
}

=item disableFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::disableFtpUser()

=cut

sub disableFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableFtpUser', $data );
}

=item postdisableFtpUser( \%data )

 See iMSCP::Modules::AbstractActions::postdisableFtpUser()

=cut

sub postdisableFtpUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableFtpUser', $data );
}

=item preaddHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::preaddHtaccess()

=cut

sub preaddHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddHtaccess', $data );
}

=item addHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::addHtaccess()

=cut

sub addHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addHtaccess', $data );
}

=item postaddHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::postaddHtaccess()

=cut

sub postaddHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteHtaccess', $data );
}

=item predeleteHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::predeleteHtaccess()

=cut

sub predeleteHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteHtaccess', $data );
}

=item deleteHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::deleteHtaccess()

=cut

sub deleteHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteHtaccess', $data );
}

=item postdeleteHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteHtaccess()

=cut

sub postdeleteHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteHtaccess', $data );
}

=item predisableHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::predisableHtaccess()

=cut

sub predisableHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableHtaccess', $data );
}

=item disableHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::disableHtaccess()

=cut

sub disableHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableHtaccess', $data );
}

=item postdisableHtaccess( \%data )

 See iMSCP::Modules::AbstractActions::postdisableHtaccess()

=cut

sub postdisableHtaccess
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableHtaccess', $data );
}

=item preaddHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::preaddHtgroup()

=cut

sub preaddHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddHtgroup', $data );
}

=item addHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::addHtgroup()

=cut

sub addHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addHtgroup', $data );
}

=item postaddHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::postaddHtgroup()

=cut

sub postaddHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddHtgroup', $data );
}

=item predeleteHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::predeleteHtgroup()

=cut

sub predeleteHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteHtgroup', $data );
}

=item deleteHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::deleteHtgroup()

=cut

sub deleteHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteHtgroup', $data );
}

=item postdeleteHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteHtgroup()

=cut

sub postdeleteHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteHtgroup', $data );
}

=item predisableHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::predisableHtgroup()

=cut

sub predisableHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableHtgroup', $data );
}

=item disableHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::disableHtgroup()

=cut

sub disableHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableHtgroup', $data );
}

=item postdisableHtgroup( \%data )

 See iMSCP::Modules::AbstractActions::postdisableHtgroup()

=cut

sub postdisableHtgroup
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableHtgroup', $data );
}

=item preaddHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::preaddHtpasswd()

=cut

sub preaddHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddHtpasswd', $data );
}

=item addHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::addHtpasswd()

=cut

sub addHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addHtpasswd', $data );
}

=item postaddHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::postaddHtpasswd()

=cut

sub postaddHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddHtpasswd', $data );
}

=item predeleteHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::predeleteHtpasswd()

=cut

sub predeleteHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteHtpasswd', $data );
}

=item deleteHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::deleteHtpasswd()

=cut

sub deleteHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteHtpasswd', $data );
}

=item postdeleteHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteHtpasswd()

=cut

sub postdeleteHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteHtpasswd', $data );
}

=item predisableHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::predisableHtpasswd()

=cut

sub predisableHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableHtpasswd', $data );
}

=item disableHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::disableHtpasswd()

=cut

sub disableHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableHtpasswd', $data );
}

=item postdisableHtpasswd( \%data )

 See iMSCP::Modules::AbstractActions::postdisableHtpasswd()

=cut

sub postdisableHtpasswd
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableHtpasswd', $data );
}

=item preaddMail( \%data )

 See iMSCP::Modules::AbstractActions::preaddMail()

=cut

sub preaddMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddMail', $data );
}

=item addMail( \%data )

 See iMSCP::Modules::AbstractActions::addMail()

=cut

sub addMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addMail', $data );
}

=item postaddMail( \%data )

 See iMSCP::Modules::AbstractActions::postaddMail()

=cut

sub postaddMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddMail', $data );
}

=item predeleteMail( \%data )

 See iMSCP::Modules::AbstractActions::predeleteMail()

=cut

sub predeleteMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteMail', $data );
}

=item deleteMail( \%data )

 See iMSCP::Modules::AbstractActions::deleteMail()

=cut

sub deleteMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteMail', $data );
}

=item postdeleteMail( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteMail()

=cut

sub postdeleteMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteMail', $data );
}

=item predisableMail( \%data )

 See iMSCP::Modules::AbstractActions::predisableMail()

=cut

sub predisableMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predisableMail', $data );
}

=item disableMail( \%data )

 See iMSCP::Modules::AbstractActions::disableMail()

=cut

sub disableMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'disableMail', $data );
}

=item postdisableMail( \%data )

 See iMSCP::Modules::AbstractActions::postdisableMail()

=cut

sub postdisableMail
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdisableMail', $data );
}


=item preaddServerIP( \%data )

 See iMSCP::Modules::AbstractActions::preaddServerIP()

=cut

sub preaddServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddServerIP', $data );
}

=item addServerIP( \%data )

 See iMSCP::Modules::AbstractActions::addServerIP()

=cut

sub addServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addServerIP', $data );
}

=item postaddServerIP( \%data )

 See iMSCP::Modules::AbstractActions::postaddServerIP()

=cut

sub postaddServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddServerIP', $data );
}

=item predeleteServerIP( \%data )

 See iMSCP::Modules::AbstractActions::predeleteServerIP()

=cut

sub predeleteServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteServerIP', $data );
}

=item deleteServerIP( \%data )

 See iMSCP::Modules::AbstractActions::deleteServerIP()

=cut

sub deleteServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteServerIP', $data );
}

=item postdeleteServerIP( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteServerIP()

=cut

sub postdeleteServerIP
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteServerIP', $data );
}

=item preaddSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::preaddSSLcertificate()

=cut

sub preaddSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddSSLcertificate', $data );
}

=item addSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::addSSLcertificate()

=cut

sub addSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addSSLcertificate', $data );
}

=item postaddSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::postaddSSLcertificate()

=cut

sub postaddSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddSSLcertificate', $data );
}

=item predeleteSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::predeleteSSLcertificate()

=cut

sub predeleteSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteSSLcertificate', $data );
}

=item deleteSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::deleteSSLcertificate()

=cut

sub deleteSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteSSLcertificate', $data );
}

=item postdeleteSSLcertificate( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteSSLcertificate()

=cut

sub postdeleteSSLcertificate
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteSSLcertificate', $data );
}

=item preaddUser( \%data )

 See iMSCP::Modules::AbstractActions::preaddUser()

=cut

sub preaddUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'preaddUser', $data );
}

=item addUser( \%data )

 See iMSCP::Modules::AbstractActions::addUser()

=cut

sub addUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'addUser', $data );
}

=item postaddUser( \%data )

 See iMSCP::Modules::AbstractActions::postaddUser()

=cut

sub postaddUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postaddUser', $data );
}

=item predeleteUser( \%data )

 See iMSCP::Modules::AbstractActions::predeleteUser()

=cut

sub predeleteUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'predeleteUser', $data );
}

=item deleteUser( \%data )

 See iMSCP::Modules::AbstractActions::deleteUser()

=cut

sub deleteUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'deleteUser', $data );
}

=item postdeleteUser( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteUser()

=cut

sub postdeleteUser
{
    my ( $self, $data ) = @_;

    $self->_executeActionOnSelectedPackages( 'postdeleteUser', $data );
}

=item getType( )

 Get type of packages for this collection

 Return string Type of packages

=cut

sub getType
{
    my ( $self ) = @_;

    confess( sprintf( 'The %s package must implement the getType() method', ref $self ));
}

=item getSelectedPackages( )

 Get list of selected package instances from this collection, sorted in descending order of priority

 Return arrayref Array containing list of selected package instances

=cut

sub getSelectedPackages
{
    my ( $self ) = @_;

    $self->{'SELECTED_PACKAGE_INSTANCES'} ||= do {
        [
            sort { $b->getPriority() <=> $a->getPriority() } map {
                my $package = "iMSCP::Package::@{ [ $self->getType() ] }::${_}";
                eval "require $package; 1" or die( sprintf( "Couldn't load the '%s' package: %s", $_, $@ ));
                $package->getInstance()
            } @{ $self->{'SELECTED_PACKAGES'} }
        ]
    };
}

=item getUnselectedPackages( )

 Get list of unselected package instances from this collection, sorted in descending order of priority

 Return array Array containing list of unselected package instances

=cut

sub getUnselectedPackages
{
    my ( $self ) = @_;

    $self->{'UNSELECTED_PACKAGE_INSTANCES'} ||= do {
        my @unselectedPackages;
        for my $package ( $self->{'AVAILABLE_PACKAGES'} ) {
            next if grep ( $package eq $_, @{ $self->{'SELECTED_PACKAGES'} } );
            push @unselectedPackages, $package;
        }

        [
            sort { $b->getPriority() <=> $a->getPriority() } map {
                my $package = "iMSCP::Package::@{ [ $self->getType() ] }::${_}";
                eval "require $package; 1" or die( sprintf( "Couldn't load the '%s' package: %s", $_, $@ ));
                $package->getInstance();
            } @unselectedPackages
        ]
    };
}

=back

=head1 PRIVATE METHODS

=over 4

=item init( )

 See iMSCP::Package::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    $self->_loadAvailablePackages() if iMSCP::Getopt->context() eq 'installer';
    $self->_loadSelectedPackages();
    $self;
}

=item _askForPackages( $dialog )

 Ask for packages to install

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub _askForPackages
{
    my ( $self, $dialog ) = @_;

    my $packageType = $self->getType();
    my $ucPackageType = uc $packageType;

    @{ $self->{'SELECTED_PACKAGES'} } = split ',', ::setupGetQuestion( $ucPackageType . '_PACKAGES' );
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ lc $packageType, 'all' ] ) || !@{ $self->{'SELECTED_PACKAGES'} }
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $self->{'SELECTED_PACKAGES'} }
    ) {
        ( my $rs, $self->{'SELECTED_PACKAGES'} ) = $dialog->multiselect(
            <<"EOF", \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $self->{'SELECTED_PACKAGES'} } ] );

Please select the $packageType packages you want to install:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $self->{'SELECTED_PACKAGES'} } = grep ( $_ ne 'none', @{ $self->{'SELECTED_PACKAGES'} } );
    ::setupSetQuestion( $ucPackageType . '_PACKAGES', @{ $self->{'SELECTED_PACKAGES'} } ? join( ',', @{ $self->{'SELECTED_PACKAGES'} } ) : 'none' );

    my $dialogs = [];
    for my $package ( @{ $self->getSelectedPackages() } ) {
        my $rs = $package->registerInstallerDialogs( $dialogs );
        return $rs if $rs;
    }

    $dialog->executeDialogs( $dialogs );
}

=item _loadAvailablePackages()

 Load list of available packages for this collection

 Return void, die on failure

=cut

sub _loadAvailablePackages
{
    my ( $self ) = @_;

    local $CWD = "$::imscpConfig{'SHARE_DIR'}/iMSCP/Package/" . $self->getType();
    s/\.pm$// for @{ $self->{'AVAILABLE_PACKAGES'} } = <*.pm>;
}

=item _loadAvailablePackages()

 Load list of selected packages for this collection

 Return void, die on failure

=cut

sub _loadSelectedPackages
{
    my ( $self ) = @_;

    @{ $self->{'SELECTED_PACKAGES'} } = grep ( $_ ne 'none', split( ',', $::imscpConfig{ $self->getType() . '_PACKAGES' } ) );
}

=item _executeActionOnSelectedPackages( $action [, @params ] )

 Execute the given action on selected packages

 Param coderef $action Action to execute on packages
 Param List @params List of parameters to pass to the package action method
 Return int 0 on success, other on failure

=cut

sub _executeActionOnSelectedPackages
{
    my ( $self, $action, @params ) = @_;

    for my $package ( @{ $self->getSelectedPackages() } ) {
        debug( sprintf( "Executing '%s' action on %s", $action, $package ));
        my $rs = $package->$action( @params );
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
