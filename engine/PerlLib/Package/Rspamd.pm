=head1 NAME

 Package::Rspamd - Rspamd spam filtering system

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

package Package::Rspamd;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::EventManager;
use iMSCP::Service;
use Servers::mta;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Provides spam filtering system.

 Project homepage: https://rspamd.com/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_rspamd'};

    $self->stop();
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_rspamd'};

    Servers::mta->factory()->postconf( (
        # Our i-MSCP SA, ClamAV ... plugins set this value to 'tempfail'
        # but 'accept' is OK if we want ignore milter failures and accept
        # the mails, even if those are potentially SPAMs.
        milter_default_action => {
            action => 'replace',
            values => [ 'accept' ]
        },
        # We want filter incoming mails, that is, those that arrive via
        # smtpd(8) server.
        smtpd_milters         => {
            action => 'add',
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/,
            values => [ 'inet:localhost:11332' ]
        },
        # we want also filter customer outbound mails, that is,
        # those that arrive via sendmail(1).
        non_smtpd_milters     => {
            action => 'add',
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/,
            values => [ 'inet:localhost:11332' ]
        },
        # MILTER mail macros required for rspamd(8)
        # There should be no clash with our i-MSCP SA, ClamAV ... plugins as
        # these don't make use of those macros.
        milter_mail_macros    => {
            action => 'replace',
            values => [ 'i {mail_addr} {client_addr} {client_name} {auth_authen}' ]
        },
        # This should be default value already. We add it here for safety only.
        # (see postconf -d milter_protocol)
        milter_protocol       => {
            action => 'replace',
            values => [ 6 ]
        }
    ));
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_rspamd'};

    local $@;
    eval { iMSCP::Service->getInstance()->enable( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'Rspamd spam filtering system' ];
            0;
        },
        $self->getPriority()
    );
}

=item start( )

 Start Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub start
{
    local $@;
    eval { iMSCP::Service->getInstance()->start( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 Stop Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub stop
{
    local $@;
    eval { iMSCP::Service->getInstance()->start( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 Restart Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    local $@;
    eval { iMSCP::Service->getInstance()->restart( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item reload( )

 Reload Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub reload
{
    local $@;
    eval { iMSCP::Service->getInstance()->reload( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    7;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Package::Rspamd

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'has_rspamd'} = iMSCP::Service->getInstance()->hasService( 'rspamd' );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
