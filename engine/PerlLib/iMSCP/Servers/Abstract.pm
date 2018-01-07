=head1 NAME

 iMSCP::Servers::Abstract - Factory and abstract implementation for i-MSCP servers

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

package iMSCP::Servers::Abstract;

use strict;
use warnings;
use iMSCP::Debug qw/ debug /;
use iMSCP::EventManager;
use Carp qw/ confess croak /;
use parent 'iMSCP::Common::Singleton';

# Server instances
my %_SERVER_INSTANCES;

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    0;
}

=item factory( [ $serverClass = $main::imscpConfig{$class} ] )

 Create and return an i-MSCP $serverClass server instance

 This method is not intented to be called on concret iMSCP::Servers::Abstract
 server classes.

 Param string $serverClass OPTIONAL Server class, default to selected server alternative
 Return iMSCP::Servers::Abstract, confess on failure

=cut

sub factory
{
    my ($class, $serverClass) = @_;
    $serverClass //= $main::imscpConfig{$class} || 'iMSCP::Servers::Noserver';

    return $_SERVER_INSTANCES{$class} if exists $_SERVER_INSTANCES{$class};

    eval "require $serverClass; 1" or confess( $@ );
    $_SERVER_INSTANCES{$class} = $serverClass->getInstance( eventManager => iMSCP::EventManager->getInstance());
}

=back

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process server pre-installation tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    $self->stop();
}

=item install( )

 Process server installation tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the install() method', ref $self ));
}

=item postinstall( )

 Process server post-installation tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->start(); }, $self->getHumanizedServerName() ];
            0;
        },
        $self->getPriority()
    );

    0;
}

=item uninstall( )

 Process server uninstallation tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the uninstall() method', ref $self ));
}

=item setEnginePermissions( )

 Set server permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the setEnginePermissions() method', ref $self ));
}

=item start( )

 Start the server

 Return int 0, other on failure

=cut

sub start
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the start() method', ref $self ));
}

=item stop( )

 Stop the server

 Return int 0, other on failure

=cut

sub stop
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the stop() method', ref $self ));
}

=item restart( )

 Restart the server

 Return int 0, other on failure

=cut

sub restart
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the restart() method', ref $self ));
}

=item reload( )

 Reload the server

 Return int 0, other on failure

=cut

sub reload
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the reload() method', ref $self ));
}

=item getHumanizedServerName( )

 Get humanized server name

 Return string Humanized server name

=cut

sub getHumanizedServerName
{
    my ($self) = @_;

    croak ( sprintf( 'The %s package must implement the getHumanizedServerName() method', ref $self ));
}

=item buildConfFile( $srcFile, $trgFile, [, \%mdata = { } [, \%sdata [, \%params = { } ] ] ] )

 Build the given server configuration file
 
 This method should be implemented by all servers relying on configuration files.
 
 The following events *MUST* be triggered:
  - onLoadTemplate('<SNAME>', $filename, \$cfgTpl, $mdata, $sdata, $self->{'config'}, $params )
  - before<SNAME>BuildConfFile( \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params )
  - after<SNAME>dBuildConfFile( \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params )

 Param string $srcFile Absolute source filepath or source filepath relative to the i-MSCP server configuration directory
 Param string $trgFile Target file path
 Param hashref \%mdata OPTIONAL Data as provided by i-MSCP modules
 Param hashref \%sdata OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%params OPTIONAL parameters:
  - umask : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal), default to umask()
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return int 0 on success, other on failure

=cut

sub buildConfFile
{
    my ($self) = @_;

    0;
}

=item shutdown( $priority )

 Reload or restart the server

 This method is called automatically when the program exits. It *MUST* be
 implemented by all servers that require a reload or restart when their
 configuration has been changed.

 Param int $priority Server priority
 Return void

=cut

sub shutdown
{
    my ($self) = @_;

    0;
}

=item AUTOLOAD()

 Implements autoloading for inexistent methods

 Return int 0

=cut

sub AUTOLOAD
{
    0;
}

=item DESTROY

 Short-circuit AUTOLOADING
 
 Return void

=cut

sub DESTROY
{
    debug( sprintf( 'Destroying %s server instance', ref $_[0] ));
}

=item END

 Process shutdown tasks

 Return void

=cut

END {
    return if $? || !%_SERVER_INSTANCES || ( defined $main::execmode && $main::execmode eq 'setup' );

    $_->shutdown( $_->getPriority()) for values %_SERVER_INSTANCES;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
