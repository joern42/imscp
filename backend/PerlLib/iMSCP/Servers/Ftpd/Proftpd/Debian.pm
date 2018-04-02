=head1 NAME

 iMSCP::Servers::Ftpd::Proftpd::Debian - i-MSCP (Debian) ProFTPD server implementation

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

package iMSCP::Servers::Ftpd::Proftpd::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::File /;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Ftpd::Proftpd::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) ProFTPD server implementation.

=head1 PUBLIC METHODS

=over 4


=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item postinstall( )

 iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'proftpd' );
    $self->SUPER::postinstall();
}

=item uninstall( )

 iMSCP::Servers::Ftpd::Proftpd::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->SUPER::uninstall();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'proftpd' ) if $srvProvider->hasService( 'proftpd' ) && $srvProvider->isRunning( 'proftpd' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    return unless -x $self->{'config'}->{'FTPD_BIN'};

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'proftpd' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'proftpd' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'proftpd' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'proftpd' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/proftpd.old.data" )->remove();
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
