=head1 NAME

 iMSCP::Servers::Po::Courier::Debian - i-MSCP (Debian) Courier IMAP/POP3 server implementation

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

package iMSCP::Servers::Po::Courier::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::ProgramFinder /;
use iMSCP::Debug qw/ debug /;
use iMSCP::Execute qw/ execute /;
use iMSCP::Getopt;
use iMSCP::Mount qw/ umount /;
use iMSCP::TemplateParser qw/ replaceBlocByRef /;
use Class::Autouse qw/ :nostat File::Spec iMSCP::Dir iMSCP::File iMSCP::SystemUser /;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Po::Courier::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Courier IMAP/POP3 server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 iMSCP::Servers::Po::Courier::Abstract()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my @toEnableServices = ( 'courier-authdaemon', 'courier-pop', 'courier-pop' );
    my @toDisableServices = ();

    if ( $::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
        push @toEnableServices, 'courier-pop-ssl', 'courier-imap-ssl';
    } else {
        push @toDisableServices, 'courier-pop-ssl', 'courier-imap-ssl';
    }

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->enable( $_ ) for @toEnableServices;

    for my $service ( @toDisableServices ) {
        $srvProvider->stop( $service );
        $srvProvider->disable( $service );
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Po::Courier::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->SUPER::uninstall();

    my $srvProvider = iMSCP::Service->getInstance();
    for my $service ( 'courier-authdaemon', 'courier-pop', 'courier-pop-ssl', 'courier-imap', 'courier-imap-ssl' ) {
        $srvProvider->restart( $service ) if $srvProvider->hasService( $service ) && $srvProvider->isRunning( $service );
    };
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    return unless iMSCP::ProgramFinder->find( 'courier-config' );

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->start( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap';

    if ( $::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
        $srvProvider->start( $_ ) for 'courier-pop-ssl', 'courier-imap-ssl';
    }
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();

    $srvProvider->stop( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap', 'courier-pop-ssl', 'courier-imap-ssl';
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap';

    if ( $::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
        $srvProvider->restart( $_ ) for 'courier-pop-ssl', 'courier-imap-ssl';
    }
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->reload( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap';

    if ( $::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
        $srvProvider->reload( $_ ) for 'courier-pop-ssl', 'courier-imap-ssl';
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Po::Courier::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $stderr;
    execute( 'dpkg -s courier-base | grep -i \'^version\'', \my $stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
    $stdout =~ /version:\s+([\d.]+)/i or die( "Couldn't guess Courier version from the `dpkg -s courier-base | grep -i '^version'` command output" );
    $self->{'config'}->{'PO_VERSION'} = $1;
    debug( sprintf( 'Courier version set to: %s', $1 ));
}

=item _cleanup( )

 Processc cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    my $oldPluginApiVersion = version->parse( $::imscpOldConfig{'PluginApi'} );

    return unless $oldPluginApiVersion < version->parse( '1.6.0' );

    for my $service ( qw/ pop3d pop3d-ssl imapd imapd-ssl / ) {
        next unless -f "$self->{'config'}->{'PO_CONF_DIR'}/$service";

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'PO_CONF_DIR'}/$service" );
        my $fileContentRef = $file->getAsRef();

        replaceBlocByRef(
            qr/(:?^\n)?# Servers::po::courier::installer - BEGIN\n/m, qr/# Servers::po::courier::installer - ENDING\n/, '', $fileContentRef
        );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/courier.old.data" )->remove();

    # Remove userdb database (we now use mysql)
    for my $filename ( qw/ userdb userdb.dat / ) {
        iMSCP::File->new( filename => "$self->{'config'}->{'PO_CONF_DIR'}/$filename" )->remove();
    }

    # Remove postfix user from authdaemon group.
    # It is now added in mail group (since 1.5.0)
    iMSCP::SystemUser->new()->removeFromGroup( $self->{'config'}->{'PO_GROUP'}, $self->{'mta'}->{'config'}->{'MTA_USER'} );

    # Remove old authdaemon socket private/authdaemon mount directory.
    # Replaced by var/run/courier/authdaemon (since 1.5.0)
    my $fsFile = File::Spec->canonpath( "$self->{'mta'}->{'config'}->{'MTA_QUEUE_DIR'}/private/authdaemon" );
    umount( $fsFile );

    iMSCP::Dir->new( dirname => $fsFile )->remove();
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
