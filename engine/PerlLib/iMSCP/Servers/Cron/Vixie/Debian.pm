=head1 NAME

 iMSCP::Servers::Cron::Vixie::Debian - i-MSCP (Debian) Vixie cron server implementation

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

package iMSCP::Servers::Cron::Vixie::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug /;
use iMSCP::Execute qw/ execute /;
use iMSCP::Service;
use parent 'iMSCP::Servers::Cron';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Vixie cron server implementation.
 
 See CRON(8) manpage.
 
=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'cron' );
    $self->SUPER::postinstall();
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'Cron (Vixie) %s', $self->getVersion());
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'cron' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'cron' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'cron' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'cron' );
}

=item enableSystemTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::enableSystemTask()

 We make use of dpkg-divert(1) because renaming the file without further
 treatment doesn't prevent the cron task to be reinstalled on package upgrade.

=cut

sub enableSystemTask
{
    my ( $self, $cronTask, $directory ) = @_;

    defined $cronTask or croak( 'Undefined $cronTask parameter' );

    unless ( $directory ) {
        for my $dir ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute( [ 'dpkg-divert', '--rename', '--remove', "/etc/$dir/$cronTask" ], \my $stdout, \my $stderr );
            debug( $stdout ) if $stdout;
            !$rs or die( $stderr || 'Unknown error' );
        }

        return;
    }

    grep ( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) or die( 'Invalid cron directory' );

    my $rs = execute( [ 'dpkg-divert', '--rename', '--remove', "/etc/$directory/$cronTask" ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=item disableSystemTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::disableSystemTask()

=cut

sub disableSystemTask
{
    my ( $self, $cronTask, $directory ) = @_;

    defined $cronTask or croak( 'Undefined $cronTask parameter' );

    unless ( $directory ) {
        for my $dir ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute(
                [ 'dpkg-divert', '--divert', "/etc/$dir/$cronTask.disabled", '--rename', "/etc/$dir/$cronTask" ], \my $stdout, \my $stderr
            );
            debug( $stdout ) if $stdout;
            !$rs or die( $stderr || 'Unknown error' );
        }

        return;
    }

    grep ( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) or die( 'Invalid cron directory' );

    my $rs ||= execute(
        [ 'dpkg-divert', '--divert', "/etc/$directory/$cronTask.disabled", '--rename', "/etc/$directory/$cronTask" ], \my $stdout, \my $stderr
    );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Cron::_setVersion()

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( 'dpkg -s cron | grep -i \'^version\'', \my $stdout, \my $stderr );
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /version:\s+([\d.]+)/i or die( "Couldn't guess Cron (Vixie) version from the `dpkg -s cron | grep -i '^version'` command output" );
    $self->{'config'}->{'CRON_VERSION'} = $1;
    debug( sprintf( 'Cron (Vixie) version set to: %s', $1 ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
