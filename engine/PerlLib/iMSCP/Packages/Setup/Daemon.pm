=head1 NAME

 iMSCP::Packages::Setup::Daemon - Setup i-MSCP Daemon for processing of backend requests

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
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->imscpDaemonTypeDialog( @_ ) }; } );
}

=item imscpDaemonTypeDialog( \%dialog )

 Ask for the i-MSCP daemon type

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub imscpDaemonTypeDialog
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'DAEMON_TYPE', iMSCP::Getopt->preseed ? 'imscp' : '' );
    my %choices = ( 'imscp', 'Via the i-MSCP daemon (real time)', 'cron', 'Via cron (every 5 minutes)' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'daemon', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'imscp' );
\\Z4\\Zb\\Zui-MSCP Daemon Type\\Zn

Please choose how the i-MSCP backend requests must be processed:
\\Z \\Zn
EOF
        return $rs if $rs >= 30;
    }

    ::setupSetQuestion( 'DAEMON_TYPE', $value );
    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    my ( $self ) = @_;

    250;
}

=item install( )

 Process installation tasks

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;

    # Reset previous install if any
    $self->uninstall();

    return iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '*/5',
        COMMAND => "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/imscp-rqst-mngr > /dev/null 2>&1"
    } ) if ::setupGetQuestion( 'DAEMON_TYPE' ) eq 'cron';

    $self->_compileDaemon();

    iMSCP::Service->getInstance()->enable( 'imscp_daemon' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices', sub { push @{ $_[0] }, [ sub { iMSCP::Service->getInstance()->start( 'imscp_daemon' ); }, 'i-MSCP Daemon' ]; }, 99
    );
}

=item uninstall( )

 Process uninstallation tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $cronServer = iMSCP::Servers::Cron->factory();

    $cronServer->deleteTask( { TASKID => __PACKAGE__ } );

    my $srvProvider = iMSCP::Service->getInstance();
    if ( iMSCP::Getopt->context() eq 'installer' ) {
        if ( $srvProvider->hasService( 'imscp_daemon' ) ) {
            # Installer context.
            # We need  stop and disable the service
            $srvProvider->stop( 'imscp_daemon' );

            if ( $srvProvider->isSystemd() ) {
                # If systemd is the current init we mask the service. Service will be disabled and masked.
                $srvProvider->getProvider()->mask( 'imscp_daemon' );
            } else {
                $srvProvider->disable( 'imscp_daemon' );
            }
        }
    } else {
        # Uninstaller context.
        # We need remove Systemd unit, Upstart job and SysVinit
        $srvProvider->remove( 'imscp_daemon' );
    }

    # Remove daemon directory
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/daemon" )->remove();
}

=item setEnginePermissions( )

 Set engine permissions

 Return void, die on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( "$::imscpConfig{'ROOT_DIR'}/daemon", {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'IMSCP_GROUP'},
        mode      => '0750',
        recursive => 1
    } ) if -d "$::imscpConfig{'ROOT_DIR'}/daemon";
}

=back

=head1 PRIVATE METHODS

=over 4

=item _compileDaemon()

 Compile and install the i-MSCP daemon

 Return void, die on failure

=cut

sub _compileDaemon
{
    my ( $self ) = @_;

    # Compile the daemon
    local $CWD = dirname( __FILE__ ) . '/Daemon';
    my $rs = execute( 'make clean imscp_daemon', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );

    # Install the daemon
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/daemon" )->make();
    iMSCP::File->new( filename => 'imscp_daemon' )->copy( "$::imscpConfig{'ROOT_DIR'}/daemon", { preserve => 1 } );

    # Leave the directory clean
    $rs = execute( 'make clean', \$stdout, \$stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
