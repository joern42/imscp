=head1 NAME

 iMSCP::Packages::Setup::AntiRootkits::Chkrootkit - i-MSCP Chkrootkit package

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

package iMSCP::Packages::Setup::AntiRootkits::Chkrootkit;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::File iMSCP::Servers::Cron /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP Chkrootkit package.

 The chkrootkit security scanner searches the local system for signs that it is infected with a 'rootkit'. Rootkits are
 set of programs and hacks designed to take control of a target machine by using known security flaws.

=head1 PUBLIC METHODS

=over 4

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Chkrootkit';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'Chkrootkit antirootkit (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;
    my $stdout = `chkrootkit -V 2>&1`;
    $stdout =~ /version\s+([\d.]+)/mi or die( "Couldn't guess Chkrootkit version from the `chkrootkit -V` command output" );
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

    iMSCP::Servers::Cron->factory()->enableSystemTask( 'chkrootkit', 'cron.daily' );
}

=item setBackendPermissions( )

 See iMSCP::Packages::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( $::imscpConfig{'CHKROOTKIT_LOG'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'IMSCP_GROUP'},
        mode  => '0640'
    } );
}

=item getDistroPackages( )

 See iMSCP::Packages::Abstract::getDistroPackages()

=cut

sub getDistroPackages
{
    my ( $self ) = @_;

    return 'chkrootkit' if $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';
    ();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _disableDebianConfig( )

 Disable default configuration as provided by the chkrootkit Debian package

 Return void, die on failure

=cut

sub _disableDebianConfig
{
    iMSCP::Servers::Cron->factory()->disableSystemTask( 'chkrootkit', 'cron.daily' );
}

=item _addCronTask( )

 Add cron task

 Return void, die on failure

=cut

sub _addCronTask
{
    iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => 'iMSCP::Packages::Setup::AntiRootkits::Chkrootkit',
        MINUTE  => '@weekly',
        HOUR    => '',
        DAY     => '',
        MONTH   => '',
        DWEEK   => '',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 bash chkrootkit -e > $::imscpConfig{'CHKROOTKIT_LOG'} 2>&1"
    } );
}

=item _scheduleCheck( )

 Schedule check if log file doesn't exist or is empty

 Return void, die on failure

=cut

sub _scheduleCheck
{
    return if -f -s $::imscpConfig{'CHKROOTKIT_LOG'};

    # Create an empty file to avoid planning multiple checks if installer is run more than once
    iMSCP::File->new( filename => $::imscpConfig{'CHKROOTKIT_LOG'} )->set( "Check scheduled...\n" )->save();

    my $rs = execute( "echo 'bash chkrootkit -e > $::imscpConfig{'CHKROOTKIT_LOG'} 2>&1' | at now + 20 minutes", \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
