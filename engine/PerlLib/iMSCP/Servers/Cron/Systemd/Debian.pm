=head1 NAME

 iMSCP::Servers::Cron::Vixie::Debian - i-MSCP (Debian) Systemd cron server implementation

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

package iMSCP::Servers::Cron::Systemd::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use iMSCP::Service;
use parent 'iMSCP::Servers::Cron::Vixie::Debian';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) systemd cron server implementation.
 
 See SYSTEMD.CRON(7) manpage.

=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Cron::Vixie::Debian::Postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'cron.target' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->iMSCP::Servers::Cron::postinstall();
}

=item getHumanServerName( )

 See iMSCP::Servers::Cron::Vixie::Debian::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Cron (Systemd) %s', $self->getVersion());
}

=item start( )

 See iMSCP::Servers::Cron::Vixie::Debian::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'cron.target' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item stop( )

 See iMSCP::Servers::Cron::Vixie::Debian::stop()

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'cron.target' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Cron::Vixie::Debian::restart()

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'cron.target' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item reload( )

 See iMSCP::Servers::Cron::Vixie::Debian::reload()

=cut

sub reload
{
    my ($self) = @_;

    # Job type reload is not applicable for unit cron.target, do a restart instead
    $self->restart();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Cron::Vixie::Debian::_setVersion()

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( '/usr/bin/dpkg -s systemd-cron | grep -i \'^version\'', \ my $stdout, \ my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /version:\s+([\d.]+)/i ) {
        error( "Couldn't guess Cron (Systemd) version from the `/usr/bin/dpkg -s systemd-cron | grep -i '^version'` command output" );
        return 1;
    }

    $self->{'config'}->{'CRON_VERSION'} = $1;
    debug( sprintf( 'Cron (Systemd) version set to: %s', $1 ));
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
