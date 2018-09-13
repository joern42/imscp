=head1 NAME

 iMSCP::Package::Installer::AntiRootkit::Rkhunter - i-MSCP Rkhunter package

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

package iMSCP::Package::Installer::AntiRootkit::Rkhunter;

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

 i-MSCP Rkhunter package.
 
 Rootkit Hunter scans systems for known and unknown rootkits, backdoors,
 sniffers and exploits.
 
 It checks for: 
  - SHA256 hash changes 
  - files commonly created by rootkits 
  - executables with anomalous file permissions 
  - suspicious strings in kernel modules
  - hidden files in system directories
  and can optionally scan within files. 
 
  Using rkhunter alone does not guarantee that a system is not compromised.
  Running additional tests, such as chkrootkit, is recommended.

 Homepage: http://rkhunter.sourceforge.net

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

sub postinstall
{
    my ( $self ) = @_;

    my $rs = $self->_disableDebianConfig();
    $rs = $self->_addCronTask();
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

=item postuninstall( )

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

    return 0 unless -f $::imscpConfig{'RKHUNTER_LOG'};

    setRights( $::imscpConfig{'RKHUNTER_LOG'}, {
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

    [ 'rkhunter' ];
}

=item _disableDebianConfig( )

 Disable default configuration

 Return int 0 on success, other on failure

=cut

sub _disableDebianConfig
{
    my ( $self ) = @_;

    if ( -f '/etc/default/rkhunter' ) {
        my $file = iMSCP::File->new( filename => '/etc/default/rkhunter' );
        my $fileC = $file->getAsRef();
        return 1 unless defined $fileC;

        ${ $fileC } =~ s/CRON_DAILY_RUN=".*"/CRON_DAILY_RUN="false"/i;
        ${ $fileC } =~ s/CRON_DB_UPDATE=".*"/CRON_DB_UPDATE="false"/i;

        my $rs = $file->save();
        return $rs if $rs;
    }

    if ( -f '/etc/cron.daily/rkhunter' ) {
        my $rs = iMSCP::File->new( filename => '/etc/cron.daily/rkhunter' )->moveFile( '/etc/cron.daily/rkhunter.disabled' );
        return $rs if $rs;
    }

    if ( -f '/etc/cron.weekly/rkhunter' ) {
        my $rs = iMSCP::File->new( filename => '/etc/cron.weekly/rkhunter' )->moveFile( '/etc/cron.weekly/rkhunter.disabled' );
        return $rs if $rs;
    }

    if ( -f "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter" ) {
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter" )->moveFile( '/etc/logrotate.d/rkhunter.disabled' );
        return $rs if $rs;
    }

    0;
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
        COMMAND => "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Installer/AntiRootkits/Rkhunter/bin/rkhunter.pl > /dev/null 2>&1"
    } );
}

=item _scheduleCheck( )

 Schedule a Rkhunter check if the log file doesn't exist or is empty

 Return int 0 on success, other on failure

=cut

sub _scheduleCheck
{
    return 0 if -f -s $::imscpConfig{'RKHUNTER_LOG'};

    # Create an empty file to avoid planning multiple check if installer is run many time
    my $file = iMSCP::File->new( filename => $::imscpConfig{'RKHUNTER_LOG'} );
    $file->set( "Check scheduled...\n" );
    my $rs = $file->save();
    return $rs if $rs;

    $rs = execute(
        "echo 'perl $::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Installer/AntiRootkits/Rkhunter/bin/rkhunter.pl > /dev/null 2>&1' "
            .'| at now + 20 minutes',
        \my $stdout,
        \my $stderr
    );
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

    if ( -f '/etc/default/rkhunter' ) {
        my $file = iMSCP::File->new( filename => '/etc/default/rkhunter' );
        my $fileC = $file->getAsRef();
        return 1 unless defined $fileC;

        ${ $fileC } =~ s/CRON_DAILY_RUN=".*"/CRON_DAILY_RUN=""/i;
        ${ $fileC } =~ s/CRON_DB_UPDATE=".*"/CRON_DB_UPDATE=""/i;

        my $rs = $file->save();
        return $rs if $rs;
    }

    if ( -f '/etc/cron.daily/rkhunter.disabled' ) {
        my $rs = iMSCP::File->new( filename => '/etc/cron.daily/rkhunter.disabled' )->moveFile( '/etc/cron.daily/rkhunter' );
        return $rs if $rs;
    }

    if ( -f '/etc/cron.weekly/rkhunter.disabled' ) {
        my $rs = iMSCP::File->new( filename => '/etc/cron.weekly/rkhunter.disabled' )->moveFile( '/etc/cron.weekly/rkhunter' );
        return $rs if $rs;
    }

    if ( -f "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter.disabled" ) {
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter.disabled" )->moveFile(
            "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter"
        );
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
