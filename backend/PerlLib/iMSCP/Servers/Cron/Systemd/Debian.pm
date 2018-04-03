=head1 NAME

 iMSCP::Servers::Cron::Vixie::Debian - i-MSCP (Debian) Systemd cron server implementation

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

package iMSCP::Servers::Cron::Systemd::Debian;

use strict;
use warnings;
use iMSCP::Debug qw/ debug /;
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
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'cron.target' );
    $self->iMSCP::Servers::Cron::postinstall();
}

=item getServerHumanName( )

 See iMSCP::Servers::Cron::Vixie::Debian::getServerHumanName()

=cut

sub getServerHumanName
{
    my ( $self ) = @_;

    sprintf( 'Cron (Systemd) %s', $self->getServerVersion());
}

=item start( )

 See iMSCP::Servers::Cron::Vixie::Debian::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'cron.target' );
}

=item stop( )

 See iMSCP::Servers::Cron::Vixie::Debian::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'cron.target' );
}

=item restart( )

 See iMSCP::Servers::Cron::Vixie::Debian::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'cron.target' );
}

=item reload( )

 See iMSCP::Servers::Cron::Vixie::Debian::reload()

=cut

sub reload
{
    my ( $self ) = @_;

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
    my ( $self ) = @_;

    my $rs = execute( 'dpkg -s systemd-cron | grep -i \'^version\'', \my $stdout, \my $stderr );
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /version:\s+([\d.]+)/i or die(
        "Couldn't guess Cron (Systemd) version from the `dpkg -s systemd-cron | grep -i '^version'` command output"
    );
    $self->{'config'}->{'CRON_VERSION'} = $1;
    debug( sprintf( 'Cron (Systemd) version set to: %s', $1 ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
