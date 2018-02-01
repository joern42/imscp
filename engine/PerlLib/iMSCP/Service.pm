=head1 NAME

 iMSCP::Service - High-level interface for service providers

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

package iMSCP::Service;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug /;
use File::Basename;
use iMSCP::Debug qw/ error getMessageByType /;
use iMSCP::Execute;
use iMSCP::ProgramFinder;
use Module::Load::Conditional qw/ can_load /;
use parent qw/ iMSCP::Common::Singleton iMSCP::Providers::Service::Interface /;

$Module::Load::Conditional::FIND_VERSION = 0;
$Module::Load::Conditional::VERBOSE = 0;
$Module::Load::Conditional::FORCE_SAFE_INC = 1;

my %DELAYED_ACTIONS;

=head1 DESCRIPTION

 High-level interface for service providers.

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $service )

 See iMSCP::Providers::Service::Interface::isEnabled()

=cut

sub isEnabled
{
    my ($self, $service) = @_;

    $self->{'provider'}->isEnabled( $service );
}

=item enable( $service )

 See iMSCP::Providers::Service::Interface::enable()

=cut

sub enable
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->enable( $service ) };
    !$@ or die( sprintf( "Couldn't enable the %s service: %s", $service, $@ ));
}

=item disable( $service )

 See iMSCP::Providers::Service::Interface::disable()

=cut

sub disable
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->disable( $service ) };
    !$@ or die( sprintf( "Couldn't disable the %s service: %s", $service, $@ ));
}

=item remove( $service )

 See iMSCP::Providers::Service::Interface::remove()
 
 Because we want to remove service files, independently of the current
 init system, this method reimplement some parts of the Systemd and
 Upstart providers. Calling the remove() method on these providers when
 they are not the current init system would lead to a failure.

=cut

sub remove
{
    my ($self, $service) = @_;

    eval {
        $self->{'provider'}->remove( $service );

        unless ( $self->{'init'} eq 'Systemd' ) {
            my $provider = $self->getProvider( 'Systemd' );

            # Remove drop-in files if any
            for ( '/etc/systemd/system/', '/usr/local/lib/systemd/system/' ) {
                my $dropInDir = $_;
                ( undef, undef, my $suffix ) = fileparse(
                    $service, qw/ .automount .device .mount .path .scope .service .slice .socket .swap .timer /
                );
                $dropInDir .= $service . ( $suffix ? '' : '.service' ) . '.d';
                next unless -d $dropInDir;
                debug( sprintf ( "Removing the %s systemd drop-in directory", $dropInDir ));
                iMSCP::Dir->new( dirname => $dropInDir )->remove();
            }

            # Remove unit files if any
            while ( my $unitFilePath = eval { $provider->resolveUnit( $service, 'withpath', 'nocache' ) } ) {
                # We do not want remove units that are shipped by distribution packages
                last unless index( $unitFilePath, '/etc/systemd/system/' ) == 0 || index( $unitFilePath, '/usr/local/lib/systemd/system/' ) == 0;
                debug( sprintf ( 'Removing the %s unit', $unitFilePath ));
                iMSCP::File->new( filename => $unitFilePath )->remove();
            }
        }

        unless ( $self->{'init'} eq 'Upstart' ) {
            my $provider = $self->getProvider( 'Upstart' );
            for ( qw / conf override / ) {
                if ( my $jobfilePath = eval { $provider->getJobFilePath( $service, $_ ); } ) {
                    debug( sprintf ( "Removing the %s upstart file", $jobfilePath ));
                    iMSCP::File->new( filename => $jobfilePath )->remove();
                }
            }
        }
    };
    !$@ or die( sprintf( "Couldn't remove the %s service: %s", basename( $service, '.service' ), $@ ));
}

=item start( $service )

 See iMSCP::Providers::Service::Interface::start()

=cut

sub start
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->start( $service ) };
    !$@ or die( sprintf( "Couldn't start the %s service: %s", $service, $@ ));
}

=item stop( $service )

 See iMSCP::Providers::Service::Interface::stop()

=cut

sub stop
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->stop( $service ) };
    !$@ or die( sprintf( "Couldn't stop the %s service: %s", $service, $@ ));
}

=item restart( $service )

 See iMSCP::Providers::Service::Interface::restart()

=cut

sub restart
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->restart( $service ); };
    !$@ or die( sprintf( "Couldn't restart the %s service: %s", $service, $@ ));
}

=item reload( $service )

 See iMSCP::Providers::Service::Interface::reload()

=cut

sub reload
{
    my ($self, $service) = @_;

    eval { $self->{'provider'}->reload( $service ); };
    !$@ or die( sprintf( "Couldn't reload the %s service: %s", $service, $@ ));
}

=item isRunning( $service )

 See iMSCP::Providers::Service::Interface::isRunning()

=cut

sub isRunning
{
    my ($self, $service) = @_;

    $self->{'provider'}->isRunning( $service );
}

=item hasService( $service [, $nocache ] )

 See iMSCP::Providers::Service::Interface::hasService()

=cut

sub hasService
{
    my ($self, $service, $nocache) = @_;

    $self->{'provider'}->hasService( $service, $nocache );
}

=item getInitSystem()

 Get init system

 Return string Init system name (lowercase)

=cut

sub getInitSystem()
{
    $_[0]->{'init'};
}

=item isSysvinit( )

 Is sysvinit used as init system?

 Return bool TRUE if sysvinit is the current init system, FALSE otherwise

=cut

sub isSysvinit
{
    $_[0]->{'init'} eq 'Sysvinit';
}

=item isUpstart( )

 Is upstart used as init system?

 Return bool TRUE if upstart is is the current init system, FALSE otherwise

=cut

sub isUpstart
{
    $_[0]->{'init'} eq 'Upstart';
}

=item isSystemd( )

 Is systemd used as init system?

 Return bool TRUE if systemd is the current init system, FALSE otherwise

=cut

sub isSystemd
{
    $_[0]->{'init'} eq 'Systemd';
}

=item getProvider( [ $providerName = $self->{'init'} ] )

 Get service provider instance

 Param string $providerName OPTIONAL Provider name (Systemd|Sysvinit|Upstart)
 Return iMSCP::Providers::Service::Sysvinit, croak on failure

=cut

sub getProvider
{
    my ($self, $providerName) = @_;

    my $provider = 'iMSCP::Providers::Service::'
        . "@{[ $main::imscpConfig{'DISTRO_FAMILY'} ne '' ? $main::imscpConfig{'DISTRO_FAMILY'}.'::': '' ]}"
        . "@{[ $providerName // $self->{'init'} ]}";

    unless ( can_load( modules => { $provider => undef } ) ) {
        # Fallback to the base provider
        $provider = "iMSCP::Providers::Service::@{ [ $providerName // $self->{'init'} ] }";
        can_load( modules => { $provider => undef } ) or die(
            sprintf( "Couldn't load the %s service provider: %s", $provider, $Module::Load::Conditional::ERROR )
        );
    }

    $provider->getInstance();
}

=item registerDelayedAction( $service, $action [, $priority = 0] )

 Register a service action that will be executed in __END__ block.
 
 Only the 'start', 'restart' and 'reload' actions are supported, in following order of precedence:
 
 - restart
 - reload
 - start
 
 Param string $service Service name for which action must be executed
 Param coderef|array $action Action name or an array containing action name and coderef representing action logic
 Param int $priority Priority. Default (0) stands for 'no priority', croak on failure
 Return void

=cut

sub registerDelayedAction
{
    my (undef, $service, $action, $priority) = @_;
    $priority //= 0;

    defined $service or croak( 'Missing or undefined $service parameter' );
    defined $action or croak( 'Missing or undefined $action parameter' );

    $priority =~ /^\d+$/ or croak( 'Invalid $priority parameter.' );

    if ( ref $action eq 'ARRAY' ) {
        @{$action} == 2 or croak( 'When defined as array, $action must contains both the action name and coderef for action logic.' );
        grep($action->[0], 'restart', 'reload', 'start') or croak( 'Unexpected action name. Only start, restart and reload actions can be delayed' );
        ref $action->[1] eq 'CODE' or croak( 'Unexpected action coderef.' );
    } else {
        grep($action eq $_, 'restart', 'reload', 'start') or croak( 'Unexpected action. Only start, restart and reload actions can be delayed' );
    }

    unless ( $DELAYED_ACTIONS{$service} ) {
        $DELAYED_ACTIONS{$service} = {
            action   => $action,
            priority => $priority
        };

        return;
    }

    # Identical action (coderef), return early
    return if ref $DELAYED_ACTIONS{$service}->{'action'} eq 'ARRAY' && ref $action eq 'ARRAY' && $DELAYED_ACTIONS{$service}->{'action'} eq $action;

    my $oaction = ref $DELAYED_ACTIONS{$service}->{'action'} eq 'ARRAY'
        ? $DELAYED_ACTIONS{$service}->{'action'}->[0] : $DELAYED_ACTIONS{$service}->{'action'};
    my $naction = ref $action eq 'ARRAY' ? $action->[0] : $action;

    # reload action can be replaced by reload or restart action only
    # restart action can be replaced by restart action only
    return if ( $oaction eq 'reload' && !grep($action eq $_, 'restart', 'reload') ) || ( $oaction eq 'restart' && $naction ne 'restart' );

    $DELAYED_ACTIONS{$service} = {
        action   => $action,
        priority => $priority
    };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Service, croak on failure

=cut

sub _init
{
    my ($self) = @_;

    exists $main::imscpConfig{'DISTRO_FAMILY'} or croak( 'You must first bootstrap the i-MSCP backend' );
    $self->{'init'} = _detectInit();
    $self->{'provider'} = $self->getProvider();
    $self;
}

=item _detectInit( )

 Detect init system

 Return string init system in use

=cut

sub _detectInit
{
    return $main::imscpConfig{'SYSTEM_INIT'} if exists $main::imscpConfig{'SYSTEM_INIT'} && $main::imscpConfig{'SYSTEM_INIT'} ne '';
    return 'Systemd' if -d '/run/systemd/system';
    return 'Upstart' if iMSCP::ProgramFinder::find( 'initctl' ) && execute( 'initctl version 2>/dev/null | grep -q upstart' ) == 0;
    'Sysvinit';
}

=item _getLastError( )

 Get last error

 Return string

=cut

sub _getLastError
{
    getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error';
}

=item _executeDelayedActions( )

 Execute delayed actions

 Return int 0 on success, 1 on failure

=cut

sub _executeDelayedActions
{
    my ($self) = @_;

    return 0 unless %DELAYED_ACTIONS;

    # Sort services by priority (DESC)
    my @services = sort { $DELAYED_ACTIONS{$b}->{'priority'} <=> $DELAYED_ACTIONS{$a}->{'priority'} } keys %DELAYED_ACTIONS;

    for my $service( @services ) {
        my $action = $DELAYED_ACTIONS{$service}->{'action'};

        if ( ref $action eq 'ARRAY' ) {
            eval { $action->[1]->(); };
            if ( $@ ) {
                error( $@ );
                return 1;
            }

            next;
        }

        $self->$action( $service );
        if ( $@ ) {
            error( $@ || $self->_getLastError());
            return 1;
        }
    }

    0;
}

=back

=head1 SHUTDOWN TASKS

=over 4

=item END

 Execute delayed actions

=cut

END {
    return unless $? == 0 && exists $main::imscpConfig{'DISTRO_FAMILY'};

    $? = __PACKAGE__->getInstance()->_executeDelayedActions();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
