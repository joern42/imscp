=head1 NAME

 iMSCP::Servers::Po::Dovecot::Debian - i-MSCP (Debian) Dovecot IMAP/POP3 server implementation

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

package iMSCP::Servers::Po::Dovecot::Debian;

use strict;
use warnings;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Po::Dovecot::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Dovecot IMAP/POP3 server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item preinstall( )

 See iMSCP::Servers::Po::Dovecot::Abstract::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    my $srvProvider = iMSCP::Service->getInstance();

    # Disable dovecot.socket unit if any
    # Dovecot as configured by i-MSCP doesn't rely on systemd activation socket
    # This also solve problem on boxes where IPv6 is not available; default dovecot.socket unit file make
    # assumption that IPv6 is available without further checks...
    # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=814999
    if ( $srvProvider->isSystemd() && $srvProvider->hasService( 'dovecot.socket' ) ) {
        $srvProvider->stop( 'dovecot.socket' );
        $srvProvider->disable( 'dovecot.socket' );
    }

    $self->SUPER::preinstall();
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->enable( 'dovecot' );

    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Po::Dovecot::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    $self->SUPER::uninstall();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'dovecot' ) if $srvProvider->hasService( 'dovecot' ) && $srvProvider->isRunning( 'dovecot' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    return unless -x $self->{'config'}->{'PO_BIN'};

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->start( 'dovecot' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->stop( 'dovecot' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->restart( 'dovecot' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->reload( 'dovecot' );
}

=back

=head1 PRIVATE METHOD

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    iMSCP::File->new( filename => "$self->{'config'}->{'PO_CONF_DIR'}/dovecot-dict-sql.conf" )->remove();
    iMSCP::Dir->new( dirname => "$self->{'cfgDir'}/$_" )->remove() for qw/ backup working /;
    iMSCP::File->new( filename => "$self->{'cfgDir'}/dovecot.old.data" )->remove();
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'dovecot', [ $action, sub { $self->$action(); } ], $priority );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
