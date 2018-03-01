=head1 NAME

 iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Installer - i-MSCP Chkrootkit package installer

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

package iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Installer;

use strict;
use warnings;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Servers::Cron;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Chkrootkit package installer.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    $_[0]->_disableDebianConfig();
}

=item postinstall( )

 Process post install tasks

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->_addCronTask();
    $self->_scheduleCheck();
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
    return 0 if -f -s $::imscpConfig{'CHKROOTKIT_LOG'};

    # Create an empty file to avoid planning multiple checks if installer is run more than once
    iMSCP::File->new( filename => $::imscpConfig{'CHKROOTKIT_LOG'} )->set( "Check scheduled...\n" )->save();

    my $rs = execute( "echo 'bash chkrootkit -e > $::imscpConfig{'CHKROOTKIT_LOG'} 2>&1' | at now + 10 minutes", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
