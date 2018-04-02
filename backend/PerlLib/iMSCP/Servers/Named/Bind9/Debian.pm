=head1 NAME

 iMSCP::Servers::Named::Bind9::Debian - i-MSCP (Debian) Bind9 server implementation

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

package iMSCP::Servers::Named::Bind9::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::ProgramFinder /;
use File::Basename;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Named::Bind9::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Bind9 server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    # We do not want stop the service while installation/reconfiguration
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();

    # Update /etc/default/bind9 file (only if exist)
    if ( -f '/etc/default/bind9' ) {
        $self->{'eventManager'}->registerOne(
            'beforeBindBuildConfFile',
            sub {
                # Enable/disable local DNS resolver
                ${ $_[0] } =~ s/RESOLVCONF=(?:no|yes)/RESOLVCONF=$self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'}/i;

                return unless ${ $_[0] } =~ /OPTIONS="(.*)"/;

                # Enable/disable IPV6 support
                ( my $options = $1 ) =~ s/\s*-[46]\s*//g;
                $options = '-4 ' . $options unless $self->{'config'}->{'NAMED_IPV6_SUPPORT'} eq 'yes';
                ${ $_[0] } =~ s/OPTIONS=".*"/OPTIONS="$options"/;
            }
        );
        $self->buildConfFile( '/etc/default/bind9' );
    }

    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();

    # Fix for #IP-1333
    # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=744304
    if ( $self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'} eq 'yes' ) {
        # Service will be started automatically when Bind9 will be restarted
        $srvProvider->enable( 'bind9-resolvconf' );
    } else {
        $srvProvider->stop( 'bind9-resolvconf' );
        $srvProvider->disable( 'bind9-resolvconf' );
    }

    $srvProvider->enable( 'bind9' );

    # We need restart the service since it is already started
    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices', sub { push @{ $_[0] }, [ sub { $self->restart(); }, $self->getHumanServerName() ]; }, $self->getPriority()
    );
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_removeConfig();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'bind9' ) if $srvProvider->hasService( 'bind9' ) && $srvProvider->isRunning( 'bind9' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    return unless iMSCP::ProgramFinder->find( 'bind9-config' );

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'bind9' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'bind9' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'bind9' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'bind9' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion()

 See iMSCP::Servers::Named::Bind9::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( [ 'bind9-config', '--version' ], \my $stdout, \my $stderr );
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /version=([\d.]+)/i or die( "Couldn't guess Bind version from the `bind9-config --version` command output" );
    $self->{'config'}->{'NAMED_VERSION'} = $1;
    debug( sprintf( 'Bind version set to: %s', $1 ));
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.old.data" )->remove();

    if ( my $resolvconf = iMSCP::ProgramFinder::find( 'resolvconf' ) ) {
        my $rs = execute( [ $resolvconf, '-d', 'lo.imscp' ], \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        !$rs or die( $stderr || 'Unknown error' ) if $rs;
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_ROOT_DIR'} )->clear( qr/\.db$/ );
}

=item _shutdown( )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ( $self ) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    $self->$action();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
