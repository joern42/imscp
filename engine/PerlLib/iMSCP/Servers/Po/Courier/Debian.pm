=head1 NAME

 iMSCP::Servers::Po::Courier::Debian - i-MSCP (Debian) Courier IMAP/POP3 server implementation

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

package iMSCP::Servers::Po::Courier::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat File::Spec iMSCP::Dir iMSCP::File iMSCP::SystemUser iMSCP::Service /;
use version;
use parent 'iMSCP::Servers::Po::Courier::Abstract';

=head1 DESCRIPTION

 i-MSCP (Debian) Courier IMAP/POP3 server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    $self->stop();
}

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

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ($self) = @_;

    eval {
        my @toEnableServices = ( 'courier-authdaemon', 'courier-pop', 'courier-pop' );
        my @toDisableServices = ();

        if ( $main::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
            push @toEnableServices, 'courier-pop-ssl', 'courier-imap-ssl';
        } else {
            push @toDisableServices, 'courier-pop-ssl', 'courier-imap-ssl';
        }

        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->enable( $_ ) for @toEnableServices;

        for ( @toDisableServices ) {
            $serviceMngr->stop( $_ );
            $serviceMngr->disable( $_ );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->start(); }, 'Courier IMAP/POP, Courier Authdaemon' ];
            0;
        },
        5
    );
}

=item start( )

 See iMSCP::Servers::Po::Courier::abstract::start()

=cut

sub start
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeCourierStart' );
    return $rs if $rs;

    eval {
        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->start( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap';

        if ( $main::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
            $serviceMngr->start( $_ ) for 'courier-pop-ssl', 'courier-imap-ssl';
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterCourierStart' );
}

=item stop( )

 See iMSCP::Servers::Po::Courier::abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeCourierStop' );
    return $rs if $rs;

    eval {
        my $serviceMngr = iMSCP::Service->getInstance();

        for ( 'courier-authdaemon', 'courier-pop', 'courier-imap', 'courier-pop-ssl', 'courier-imap-ssl' ) {
            $serviceMngr->stop( $_ );
        }

    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterCourierStop' );
}

=item restart( )

 See iMSCP::Servers::Po::Courier::abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeCourierRestart' );
    return $rs if $rs;

    eval {
        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->restart( $_ ) for 'courier-authdaemon', 'courier-pop', 'courier-imap';

        if ( $main::imscpConfig{'SERVICES_SSL_ENABLED'} eq 'yes' ) {
            $serviceMngr->restart( $_ ) for 'courier-pop-ssl', 'courier-imap-ssl';
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterCourierRestart' );
}

=back

=head1 SHUTDOWN TASKS

=over 4

=item shutdown( $priority )

 Restart the Courier IMAP/POP servers when needed

 This method is called automatically before the program exit.

 Param int $priority Server priority
 Return void

=cut

sub shutdown
{
    my ($self, $priority) = @_;

    return unless $self->{'restart'};

    iMSCP::Service->getInstance()->registerDelayedAction( 'courier', [ 'restart', sub { $self->restart(); } ], $priority );
}

=back

=head PRIVATE METHODS

=over 4

=item _cleanup( )

 Processc cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    my $oldPluginApiVersion = version->parse( $main::imscpOldConfig{'PluginApi'} );

    return 0 if $oldPluginApiVersion > version->parse( '1.5.2' );

    for ( qw/ pop3d pop3d-ssl imapd imapd-ssl / ) {
        next unless -f "$self->{'config'}->{'COURIER_CONF_DIR'}/$sname";

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'COURIER_CONF_DIR'}/$_" );
        my $fileContentRef = $file->getAsRef();
        unless ( defined $fileContentRef ) {
            error( sprintf( "Couldn't read the %s file", $file->{'filename'} ));
            return 1;
        }

        replaceBlocByRef(
            qr/(:?^\n)?# Servers::po::courier::installer - BEGIN\n/m, qr/# Servers::po::courier::installer - ENDING\n/, '', $fileContentRef
        );
    }

    return 0 if $oldPluginApiVersion > version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/courier.old.data" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/courier.old.data" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'AUTHLIB_CONF_DIR'}/userdb" ) {
        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'AUTHLIB_CONF_DIR'}/userdb" );
        $file->set( '' );
        my $rs = $file->save();
        $rs ||= $file->mode( 0600 );
        return $rs if $rs;

        $rs = execute( [ 'makeuserdb', '-f', "$self->{'config'}->{'AUTHLIB_CONF_DIR'}/userdb" ], \ my $stdout, \ my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    # Remove postfix user from authdaemon group.
    # It is now added in mail group (since 1.5.0)
    my $rs = iMSCP::SystemUser->new()->removeFromGroup( $self->{'config'}->{'AUTHDAEMON_GROUP'}, $self->{'mta'}->{'config'}->{'POSTFIX_USER'} );
    return $rs if $rs;

    # Remove old authdaemon socket private/authdaemon mount directory.
    # Replaced by var/run/courier/authdaemon (since 1.5.0)
    my $fsFile = File::Spec->canonpath( "$self->{'mta'}->{'config'}->{'POSTFIX_QUEUE_DIR'}/private/authdaemon" );
    $rs ||= umount( $fsFile );
    return $rs if $rs;

    eval { iMSCP::Dir->new( dirname => $fsFile )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
