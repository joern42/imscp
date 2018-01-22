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
use autouse 'iMSCP::Execute' => qw/ execute /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error /;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef /;
use iMSCP::Umask;
use iMSCP::Service;
use parent 'iMSCP::Servers::Ftpd::Vsftpd::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Vsftpd server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'vsftpd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 Process uninstall tasks

 Return int 0 on success

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->SUPER::uninstall();
    return $rs if $rs;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();
        $srvProvider->restart( 'vsftpd' ) if $srvProvider->hasService( 'vsftpd' ) && $srvProvider->isRunning( 'vsftpd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    return 0 unless -x $self->{'config'}->{'FTPD_BIN'};

    $self->_setVersion();
}

=item start( )

 Start vsftpd

 Return int 0, other on failure

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'vsftpd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 Stop vsftpd

 Return int 0, other on failure

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'vsftpd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 Restart vsftpd

 Return int 0, other on failure

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'vsftpd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item reload( )

 Reload vsftpd

 Return int 0, other on failure

=cut

sub reload
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'vsftpd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/vsftpd.pam" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/vsftpd.pam" )->delFile();
        return $rs if $rs;
    }

    return 0 unless -f "$self->{'cfgDir'}/vsftpd.old.data";

    iMSCP::File->new( filename => "$self->{'cfgDir'}/vsftpd.old.data" )->delFile();
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
