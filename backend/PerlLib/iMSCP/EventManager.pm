=head1 NAME

 iMSCP::EventManager - i-MSCP Event Manager

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

package iMSCP::EventManager;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug /;
use iMSCP::PriorityQueue;
use iMSCP::Getopt;
use Scalar::Util qw/ blessed /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 The i-MSCP event manager is the central point of the event system.

 Event listeners are registered on the event manager and events are triggered
 through the event manager. Event listeners are references to subroutines or
 objects that listen to particular event(s).

=head1 PUBLIC METHODS

=over 4

=item hasListener( $eventName, $listener )

 Is the given listener registered for the given event?

 Param string $eventName Event name on which $listener listen on
 Param coderef $listener A CODE reference
 Return bool TRUE if the given event has the given listener, FALSE otherwise, croak on failure

=cut

sub hasListener
{
    my ( $self, $eventName, $listener ) = @_;

    defined $eventName or croak 'Missing $eventName parameter';
    ref $listener eq 'CODE' or croak 'Missing or invalid $listener parameter';
    exists $self->{'events'}->{$eventName} && $self->{'events'}->{$eventName}->hasItem( $listener );
}

=item register( $eventNames, $listener [, priority = 0 [, $once = FALSE ] ] )

 Registers an event listener for the given events

 Param string|arrayref $eventNames Event(s) that the listener listen to
 Param coderef|object $listener A CODE reference or an object implementing $eventNames method
 Param int $priority OPTIONAL Listener priority (Highest values have highest priority)
 Param bool $once OPTIONAL If TRUE, $listener will be executed at most once for the given events
 Return self, croak on failure

=cut

sub register
{
    my ( $self, $eventNames, $listener, $priority, $once ) = @_;

    defined $eventNames or croak 'Missing $eventNames parameter';

    if ( ref $eventNames eq 'ARRAY' ) {
        $self->register( $_, $listener, $priority, $once ) for @{ $eventNames };
        return $self;
    }

    ( ref $listener eq 'CODE' || blessed $listener ) or croak( 'Invalid $listener parameter. Expects an object or code reference.' );
    ( $self->{'events'}->{$eventNames} //= iMSCP::PriorityQueue->new() )->addItem( $listener, $priority );
    $self->{'nonces'}->{$eventNames}->{$listener}++ if $once;
    $self;
}

=item registerOne( $eventNames, $listener [, priority = 0 ] )

 Registers an event listener that will be executed at most once for the given events
 
 This is shortcut method for ::register( $eventNames, $listener, $priority, $once )

 Param string|arrayref $eventNames Event(s) that the listener listen to
 Param coderef|object $listener A CODE reference or object implementing $eventNames method
 Param int $priority OPTIONAL Listener priority (Highest values have highest priority)
 Return self, croak on failure

=cut

sub registerOne
{
    my ( $self, $eventNames, $listener, $priority ) = @_;

    $self->register( $eventNames, $listener, $priority, 1 );
}

=item unregister( $listener [, $eventName = $self->{'events'} ] )

 Unregister the given listener from all or the given event

 Param coderef $listener Listener
 Param string OPTIONAL $eventName Event name
 Return self, croak on failure

=cut

sub unregister
{
    my ( $self, $listener, $eventName ) = @_;

    ref $listener eq 'CODE' or croak 'Missing or invalid $listener parameter';

    if ( defined $eventName ) {
        return $self unless exists $self->{'events'}->{$eventName};

        $self->{'events'}->{$eventName}->removeItem( $listener );

        if ( $self->{'events'}->{$eventName}->isEmpty() ) {
            delete $self->{'events'}->{$eventName};
            delete $self->{'nonces'}->{$eventName};
            return $self;
        }

        if ( delete $self->{'nonces'}->{$eventName}->{$listener} ) {
            delete $self->{'nonces'}->{$eventName} unless %{ $self->{'nonces'}->{$eventName} };
        }

        return $self;
    }

    $self->unregister( $listener, $_ ) for keys %{ $self->{'events'} };
    $self;
}

=item clearListeners( $eventName )

 Clear all listeners for the given event

 Param string $event Event name
 Return self, croak on failure

=cut

sub clearListeners
{
    my ( $self, $eventName ) = @_;

    defined $eventName or croak( 'Missing $eventName parameter' );
    delete $self->{'events'}->{$eventName} if exists $self->{'events'}->{$eventName};
    delete $self->{'nonces'}->{$eventName} if exists $self->{'nonces'}->{$eventName};
    $self;
}

=item trigger( $eventName [, @params ] )

 Triggers the given event

 Param string $eventName Event name
 Param mixed @params OPTIONAL parameters passed-in to the listeners
 Return self, croak on failure

=cut

sub trigger
{
    my ( $self, $eventName, @params ) = @_;

    defined $eventName or croak( 'Missing $eventName parameter' );

    return $self unless exists $self->{'events'}->{$eventName};

    debug( sprintf( '%s event', $eventName ));

    # The priority queue acts as a heap which implies that as items are popped
    # they are also removed. Thus we clone it (in surface) for purposes of iteration.
    my $priorityQueue = $self->{'events'}->{$eventName}->clone();
    while ( my $listener = $priorityQueue->pop ) {
        # Execute the event listener.
        blessed $listener ? $listener->$eventName( @params ) : $listener->( @params );

        if ( $self->{'nonces'}->{$eventName}->{$listener} ) {
            # Event listener has been registered to be run only once.
            # We need to remove it from the original priority queue
            $self->{'events'}->{$eventName}->removeItem( $listener );
            delete $self->{'nonces'}->{$eventName}->{$listener} if --$self->{'nonces'}->{$eventName}->{$listener} < 1;
        }
    }

    # We must test for priority queue existence here too because a listener can self-unregister
    if ( exists $self->{'events'}->{$eventName} && $self->{'events'}->{$eventName}->isEmpty() ) {
        delete $self->{'events'}->{$eventName};
        delete $self->{'nonces'}->{$eventName};
        return $self;
    }

    delete $self->{'nonces'}->{$eventName} if $self->{'nonces'}->{$eventName} && !%{ $self->{'nonces'}->{$eventName} };
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::EventManager, croaka on failure

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'events'} = {};
    $self->{'nonces'} = {};

    for my $listenerFile (
        ( iMSCP::Getopt->context() eq 'installer' ? <$::imscpConfig{'CONF_DIR'}/listeners.d/installer/*.pl> : () ),
        <$::imscpConfig{'CONF_DIR'}/listeners.d/*.pl>
    ) {
        debug( sprintf( 'Loading %s listener file', $listenerFile ));
        require $listenerFile;
    }

    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
