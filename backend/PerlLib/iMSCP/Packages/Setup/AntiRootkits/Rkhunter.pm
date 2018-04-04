=head1 NAME

 iMSCP::Packages::Setup::AntiRootkits::Rkhunter - i-MSCP Rkhunter package

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

package iMSCP::Packages::Setup::AntiRootkits::Rkhunter;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Servers::Cron iMSCP::File /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 Rkhunter package.

=head1 PUBLIC METHODS

=over 4

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Rkhunter';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'Rkhunter antirootkit (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my $stdout = `rkhunter -V`;
    $stdout =~ /\s+([\d.]+)/mi or die( "Couldn't guess Rkhunter version from the `rkhunter -V` command output" );
    $1;
}

=item preinstall( )

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->_disableDebianConfig();
}

=item postinstall( )

 See iMSCP::Packages::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->_addCronTask();
    $self->_scheduleCheck();
}

=item uninstall( )

 See iMSCP::Packages::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    if ( -f '/etc/default/rkhunter' ) {
        my $file = iMSCP::File->new( filename => '/etc/default/rkhunter' );
        my $fileContentRef = $file->getAsRef();
        ${ $fileContentRef } =~ s/CRON_DAILY_RUN=".*"/CRON_DAILY_RUN=""/i;
        ${ $fileContentRef } =~ s/CRON_DB_UPDATE=".*"/CRON_DB_UPDATE=""/i;
        $file->save();
    }

    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';

    iMSCP::Servers::Cron->factory()->enableSystemTask( 'rkhunter', $_ ) for qw/ cron.daily cron.weekly /;

    return unless -f "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter.disabled";

    iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter.disabled" )->move(
        "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter"
    );
}

=item setBackendPermissions( )

 See iMSCP::Packages::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( "$::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Setup/AntiRootkits/Rkhunter/Cron.pl", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_USER'},
        mode  => '0700'
    } );
    setRights( $::imscpConfig{'RKHUNTER_LOG'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'IMSCP_GROUP'},
        mode  => '0640'
    } ) if -f $::imscpConfig{'RKHUNTER_LOG'};
}

=item getDistroPackages( )

 See iMSCP::Packages::Abstract::getDistroPackages()

=cut

sub getDistroPackages
{
    my ( $self ) = @_;

    return 'rkhunter' if $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';
    ();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _disableDebianConfig( )

 Disable default configuration

 Return void, die on failure

=cut

sub _disableDebianConfig
{
    if ( -f '/etc/default/rkhunter' ) {
        my $file = iMSCP::File->new( filename => '/etc/default/rkhunter' );
        my $fileContentRef = $file->getAsRef();
        ${ $fileContentRef } =~ s/CRON_DAILY_RUN=".*"/CRON_DAILY_RUN="false"/i;
        ${ $fileContentRef } =~ s/CRON_DB_UPDATE=".*"/CRON_DB_UPDATE="false"/i;
        $file->save();
    }

    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';

    iMSCP::Servers::Cron->factory()->disableSystemTask( 'rkhunter', $_ ) for qw/ cron.daily cron.weekly /;

    return unless -f "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter";

    iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/rkhunter" )->move( '/etc/logrotate.d/rkhunter.disabled' );
}

=item _addCronTask( )

 Add cron task

 Return void, die on failure

=cut

sub _addCronTask
{
    iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => 'iMSCP::Packages::Setup::AntiRootkits::Rkhunter',
        MINUTE  => '@weekly',
        HOUR    => '',
        DAY     => '',
        MONTH   => '',
        DWEEK   => '',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 perl $::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Setup/AntiRootkits/Rkhunter/Cron.pl > "
            . '/dev/null 2>&1'
    } );
}

=item _scheduleCheck( )

 Schedule check if log file doesn't exist or is empty

 Return void, die on failure

=cut

sub _scheduleCheck
{
    return if -f -s $::imscpConfig{'RKHUNTER_LOG'};

    # Create an empty file to avoid planning multiple check if installer is run many time
    iMSCP::File->new( filename => $::imscpConfig{'RKHUNTER_LOG'} )->set( "Check scheduled...\n" )->save();

    my $rs = execute(
        "echo 'perl $::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Setup/AntiRootkits/Rkhunter/Cron.pl > /dev/null 2>&1' "
            . ' | at now + 25 minutes',
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
