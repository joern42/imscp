=head1 NAME

 iMSCP::Packages::Setup::Daemon - Setup i-MSCP Daemon for processing of backend requests

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

package iMSCP::Packages::Setup::Daemon;

use strict;
use warnings;
use File::Basename;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringInList /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Servers::Cron;
use iMSCP::Service;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Package responsible to setup the i-MSCP daemon for processing of backend requests.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners

 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub {
            push @{$_[0]}, sub { $self->imscpDaemonType( @_ ) };
            0;
        }
    );
}

=item imscpBackupDialog( \%dialog )

 Ask for the i-MSCP daemon type

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub imscpDaemonType
{
    my ($self, $dialog) = @_;

    my $value = main::setupGetQuestion( 'DAEMON_TYPE', iMSCP::Getopt->preseed ? 'daemon' : '' );
    my %choices = ( 'daemon', 'Via the i-MSCP daemon (real time)', 'cron', 'Via cron (every 5 minutes)' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'daemon', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep( $value eq $_, keys %choices ) )[0] || 'daemon' );
\\Z4\\Zb\\Zui-MSCP Daemon Type for processing of i-MSCP backend requests\\Zn

Please choose how the i-MSCP backend requests must be processed:
\\Z \\Zn
EOF
        return $rs if $rs >= 30;
    }

    main::setupSetQuestion( 'DAEMON_TYPE', $value );
    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    my ($self) = @_;

    250;
}

=item install( )

 Process installation tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    # Reset previous setup if any
    my $rs = $self->uninstall();
    return $rs if $rs;

    return iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '*/5',
        COMMAND => "perl $main::imscpConfig{'ENGINE_ROOT_DIR'}/imscp-rqst-mngr > /dev/null 2>&1"
    } ) if main::setupGetQuestion( 'DAEMON_TYPE' ) eq 'cron';

    $rs = $self->_compileDaemon();
    return $rs if $rs;

    eval { iMSCP::Service->getInstance()->enable( 'imscp_daemon' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $rs ||= $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]},
                [
                    sub {
                        iMSCP::Service->getInstance()->start( 'imscp_daemon' );
                        0;
                    },
                    'i-MSCP Daemon'
                ];
            0;
        },
        99
    );
}

=item uninstall( )

 Process uninstallation tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ($self) = @_;

    my $cronServer = iMSCP::Servers::Cron->factory();

    my $rs = $cronServer->deleteTasks( { TASKID => __PACKAGE__ } );
    return $rs if $rs;

    eval {
        # Make sure that the daemon is not running
        my $srvMngr = iMSCP::Service->getInstance();
        if ( $srvMngr->hasService( 'imscp_daemon' ) ) {
            if ( iMSCP::Getopt->context() eq 'installer' ) {
                $srvMngr->stop( 'imscp_daemon' );
                $srvMngr->disable( 'imscp_daemon' );
            } else {
                $srvMngr->remove( 'imscp_daemon' );
            }
        }

        # Remove daemon directory
        iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/daemon" )->remove();
    };
    if ( $@ ) {
        error( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
        return 1;
    }

    0;
}

=item setEnginePermissions( )

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    return 0 unless -d "$main::imscpConfig{'ROOT_DIR'}/daemon";

    setRights( "$main::imscpConfig{'ROOT_DIR'}/daemon",
        {
            user      => $main::imscpConfig{'ROOT_USER'},
            group     => $main::imscpConfig{'IMSCP_GROUP'},
            mode      => '0750',
            recursive => 1
        }
    );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _compileDaemon()

 Compile and install the i-MSCP daemon

 Return int 0 on success, other on failure

=cut

sub _compileDaemon
{
    my ($self) = @_;

    # Compile the daemon

    local $CWD = dirname ( __FILE__ ) . '/Daemon';

    my $rs = execute( 'make clean imscp_daemon', \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    # Install the daemon

    eval { iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/daemon" )->make(); };
    if ( $@ ) {
        error( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error ' );
        return 1;
    }

    $rs = iMSCP::File->new( filename => 'imscp_daemon' )->copyFile( "$main::imscpConfig{'ROOT_DIR'}/daemon" );
    return $rs if $rs;

    # Leave the directory clean

    $rs = execute( 'make clean', \ $stdout, \ $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
