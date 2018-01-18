=head1 NAME

 iMSCP::Servers::Cron::Vixie::Debian - i-MSCP (Debian) Vixie cron server implementation

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

package iMSCP::Servers::Cron::Vixie::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use iMSCP::Service;
use parent 'iMSCP::Servers::Cron';

our $VERSION = '1.0.0';

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
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'cron' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->SUPER::postinstall();
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Cron (Vixie) %s', $self->getVersion());
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'cron' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'cron' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'cron' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'cron' ); };
    if ( $@ ) {
        croak( $@ );
        return 1;
    }

    0;
}

=item enableSystemCronTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::enableSystemCronTask()

 We make use of dpkg-divert(1) because renaming the file without further
 treatment doesn't prevent the cron task to be reinstalled on package upgrade.

=cut

sub enableSystemCronTask
{
    my ($self, $cronTask, $directory) = @_;

    unless ( defined $cronTask ) {
        error( 'Undefined $cronTask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$_/$cronTask" ], \my $stdout, \my $stderr );
            debug( $stdout ) if $stdout;
            error( $stderr || 'Unknown error' ) if $rs;
            return $rs if $rs;
        }

        return 0;
    }

    unless ( grep( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) ) {
        error( 'Invalid cron directory' );
        return 1;
    }

    my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$directory/$cronTask" ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;
}

=item disableSystemCronTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::disableSystemCrontask()

=cut

sub disableSystemCronTask
{
    my ($self, $cronTask, $directory) = @_;

    unless ( defined $cronTask ) {
        error( 'Undefined$cronTask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute(
                [ '/usr/bin/dpkg-divert', '--divert', "/etc/$_/$cronTask.disabled", '--rename', "/etc/$_/$cronTask" ], \my $stdout, \my $stderr
            );
            debug( $stdout ) if $stdout;
            error( $stderr || 'Unknown error' ) if $rs;
            return $rs if $rs;
        }

        return 0;
    }

    unless ( grep( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) ) {
        error( 'Invalid cron directory' );
        return 1;
    }

    my $rs ||= execute(
        [ '/usr/bin/dpkg-divert', '--divert', "/etc/$directory/$cronTask.disabled", '--rename', "/etc/$directory/$cronTask" ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Cron::_setVersion()

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( '/usr/bin/dpkg -s cron | grep -i \'^version\'', \ my $stdout, \ my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /version:\s+([\d.]+)/i ) {
        error( "Couldn't guess Cron (Vixie) version from the `/usr/bin/dpkg -s cron | grep -i '^version'` command output" );
        return 1;
    }

    $self->{'config'}->{'CRON_VERSION'} = $1;
    debug( sprintf( 'Cron (Vixie) version set to: %s', $1 ));
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
