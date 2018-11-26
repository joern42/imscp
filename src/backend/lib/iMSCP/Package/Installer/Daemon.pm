=head1 NAME

 iMSCP::Package::Installer::Daemon - i-MSCP Daemon for processing of backend requests

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
use iMSCP::Boolean;
use iMSCP::Cwd '$CWD';
use iMSCP::Debug 'debug';
use iMSCP::Dir;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Rights 'setRights';
use iMSCP::Service;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Package providing i-MSCP daemon for processing of backend requests.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 See iMSCP::Package::Abstract::getPriority()

=cut

sub getPriority
{
    my ( $self ) = @_;

    250;
}

=back

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->stop( 'imscp_daemon' ) if $srvProvider->hasService( 'imscp_daemon' );
    0;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_compileDaemon();
}

=item postinstall( )

 See iMSCP::Installer::AbstractActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->enable( 'imscp_daemon' );

    $self->{'eventManager'}->registerOne( 'beforeSetupRestartServices', sub {
        push @{ $_[0] }, [ sub { $srvProvider->restart( 'imscp_daemon' ); }, 'i-MSCP Daemon' ];
    }, 99 );
}

=item uninstall( )

 See iMSCP::Installer::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();

    if ( $srvProvider->hasService( 'imscp_daemon' ) ) {
        $srvProvider->getInstance()->remove( 'imscp_daemon' );
    }

    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/daemon" )->remove();
}

=item setEnginePermissions( )

 See iMSCP::Installer::AbstractActions::setBackendPermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( "$::imscpConfig{'ROOT_DIR'}/daemon", {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'IMSCP_GROUP'},
        mode      => '0750',
        recursive => TRUE
    } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _compileDaemon()

 Compile and install the i-MSCP daemon

 Return int 0 on success other or die on failure

=cut

sub _compileDaemon
{
    my ( $self ) = @_;

    local $CWD = "$::imscpConfig{'SHARE_DIR'}/iMSCP/Package/Installer/Daemon/src";

    my $rs = execute( [ 'make', 'clean', 'imscp_daemon' ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    return $rs if $rs;

    iMSCP::File->new( filename => 'imscp_daemon' )->copy( $::imscpConfig{'SBIN_DIR'}, { preserve => TRUE } );

    $rs = execute( [ 'make', 'clean' ], \$stdout, \$stderr );
    debug( $stdout ) if length $stdout;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
