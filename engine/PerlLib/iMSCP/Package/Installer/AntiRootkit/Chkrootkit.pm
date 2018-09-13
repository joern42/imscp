=head1 NAME

 iMSCP::Package::Installer::AntiRootkit::Chkrootkit - i-MSCP Chkrootkit package

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

package iMSCP::Package::Installer::AntiRootkit::Chkrootkit;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::SetRights 'setRights';
use Servers::cron;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP Chkrootkit package.

 The chkrootkit security scanner searches the local system for signs that it is
 infected with a 'rootkit'. Rootkits are set of programs and hacks designed to
 take control of a target machine by using known security flaws.

 Types that chkrootkit can identify are listed on the project's home page. 
 
 Please note that where chkrootkit detects no intrusions, this does not
 guarantee that the system is uncompromised. In addition to running chkrootkit,
 more specific tests should always be performed.

 Homepage: http://www.chkrootkit.org/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance->installPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_disableDebianConfig();
    $rs ||= $self->_addCronTask();
    $rs ||= $self->_scheduleCheck();
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_restoreDebianConfig();
}

=item postuninstall

 See iMSCP::Uninstaller::AbstractActions::postuninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance->uninstallPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item setEnginePermissions( )

 See iMSCP::Installer::AbstractActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( $::imscpConfig{'CHKROOTKIT_LOG'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'IMSCP_GROUP'},
        mode  => '0640'
    } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _getDistPackages( )

 Get list of distribution packages to install or uninstall, depending on context

 Return array List of distribution packages

=cut

sub _getDistPackages
{
    my ( $self ) = @_;

    [ 'chkrootkit' ];
}

=item _disableDebianConfig( )

 Disable default configuration as provided by the chkrootkit Debian package

 Return int 0 on success, other on failure

=cut

sub _disableDebianConfig
{
    my ( $self ) = @_;

    return 0 unless -f '/etc/cron.daily/chkrootkit';

    iMSCP::File->new( filename => '/etc/cron.daily/chkrootkit' )->moveFile( '/etc/cron.daily/chkrootkit.disabled' );
}

=item _addCronTask( )

 Add cron task

 Return int 0 on success, other on failure

=cut

sub _addCronTask
{
    my ( $self ) = @_;

    Servers::cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '@weekly',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 bash chkrootkit -e > $::imscpConfig{'CHKROOTKIT_LOG'} 2>&1"
    } );
}

=item _scheduleCheck( )

 Schedule a Chkrootkit check if the log file doesn't exist or is empty

 Return int 0 on success, other on failure

=cut

sub _scheduleCheck
{
    my ( $self ) = @_;

    return 0 if -f -s $::imscpConfig{'CHKROOTKIT_LOG'};

    # Create an emtpy file to avoid planning multiple check if installer is run many time
    my $file = iMSCP::File->new( filename => $::imscpConfig{'CHKROOTKIT_LOG'} );
    $file->set( "Check scheduled...\n" );
    my $rs = $file->save();
    return $rs if $rs;

    $rs = execute( "echo 'bash chkrootkit -e > $::imscpConfig{'CHKROOTKIT_LOG'} 2>&1' | at now + 20 minutes", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=item _restoreDebianConfig( )

 Restore default configuration

 Return int 0 on success, other on failure

=cut

sub _restoreDebianConfig
{
    my ( $self ) = @_;

    return 0 unless -f '/etc/cron.daily/chkrootkit.disabled';

    iMSCP::File->new( filename => '/etc/cron.daily/chkrootkit.disabled' )->moveFile( '/etc/cron.daily/chkrootkit' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
