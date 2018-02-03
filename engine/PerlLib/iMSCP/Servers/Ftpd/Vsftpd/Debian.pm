=head1 NAME

 iMSCP::Servers::Ftpd::Vsftpd::Debian - i-MSCP (Debian) Vsftpd server implementation

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

package iMSCP::Servers::Ftpd::Vsftpd::Debian;

use strict;
use warnings;
use iMSCP::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Ftpd::Vsftpd::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Vsftpd server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Ftpd::Vsftpd::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->enable( 'vsftpd' );
    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Ftpd::Vsftpd::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    $self->SUPER::uninstall();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'vsftpd' ) if $srvProvider->hasService( 'vsftpd' ) && $srvProvider->isRunning( 'vsftpd' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    return unless -x $self->{'config'}->{'FTPD_BIN'};

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->start( 'vsftpd' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->stop( 'vsftpd' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->restart( 'vsftpd' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    iMSCP::Service->getInstance()->reload( 'vsftpd' );
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
    my ($self) = @_;

    return unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/vsftpd.pam" )->remove();
    iMSCP::File->new( filename => "$self->{'cfgDir'}/vsftpd.old.data" )->remove();
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'vsftpd', [ $action, sub { $self->$action(); } ], $priority );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
