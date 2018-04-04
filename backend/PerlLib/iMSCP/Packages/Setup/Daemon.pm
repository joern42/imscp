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
use iMSCP::Boolean;
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
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 Package responsible to setup the i-MSCP daemon for processing of backend requests.

=head1 CLASS METHODS

=over 4

=item getPackagePriority( )

 See iMSCP::Packages::Abstract::getPackagePriority()

=cut

sub getPackagePriority
{
    my ( $self ) = @_;

    250;
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Packages::Abstract::registerSetupListeners()

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->showDialog( @_ ) }; } );
}

=item showDialog( \%dialog )

 Ask for the i-MSCP daemon type

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'DAEMON_TYPE', iMSCP::Getopt->preseed ? 'imscp' : '' );
    my %choices = ( 'imscp', 'Via the historical i-MSCP daemon (real time)', 'cron', 'Via a cron job run every 5 minutes (delayed)' );

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

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Daemon';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'i-MSCP daemon installer (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $self->getPackageImplVersion();
}

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    # Reset previous install if any
    $self->uninstall();

    return iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '*/5',
        COMMAND => "perl $::imscpConfig{'BACKEND_ROOT_DIR'}/imscp-rqst-mngr > /dev/null 2>&1"
    } ) if ::setupGetQuestion( 'DAEMON_TYPE' ) eq 'cron';

    $self->_compileDaemon();

    iMSCP::Service->getInstance()->enable( 'imscp_daemon' );

    $self->{'eventManager'}->registerOne( 'beforeSetupRestartServices', sub {
        push @{ $_[0] }, [ sub { iMSCP::Service->getInstance()->start( 'imscp_daemon' ); }, 'i-MSCP Daemon' ];
    }, 99 );
}

=item uninstall( )

 See iMSCP::Packages::Abstract::uninstall()

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

=item setBackendPermissions( )

 See iMSCP::Packages::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( "$::imscpConfig{'ROOT_DIR'}/daemon", {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'IMSCP_GROUP'},
        mode      => '0750',
        recursive => TRUE
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
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' );

    # Install the daemon
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/daemon" )->make();
    iMSCP::File->new( filename => 'imscp_daemon' )->copy( "$::imscpConfig{'ROOT_DIR'}/daemon", { preserve => TRUE } );

    # Leave the directory clean
    $rs = execute( 'make clean', \$stdout, \$stderr );
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
