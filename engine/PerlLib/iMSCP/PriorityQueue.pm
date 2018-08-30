=head1 NAME

 iMSCP::PriorityQueue - Provides the functionalities of a prioritized queue.

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

package iMSCP::PriorityQueue;

use strict;
use warnings;
use autouse 'Data::Clone' => 'clone';
use autouse 'Data::Compare' => 'Compare';
use Carp 'croak';
use List::Util 'max';
use Scalar::Util 'looks_like_number';
use iMSCP::Boolean;

=head1 DESCRIPTION

 This class provides the functionalities of a prioritized queue.

=head1 PUBLIC METHODS

=over 4

=item new()

 Constructor

 Return iMSCP::PriorityQueue

=cut

sub new
{
    my ( $class ) = @_;

    bless {
        highest_priority => 0,
        queue            => {}
    }, $class;
}

=item hasItem( $item )
 
 Is the given item in this priority queue?
 
 Param mixed $item Item
 Return bool TRUE if this priority queue has the given item, FALSE otherwise
 
=cut

sub hasItem
{
    my ( $self, $item ) = @_;

    for my $items ( values %{ $self->{'queue'} } ) {
        for my $v ( @{ $items } ) {
            return TRUE if Compare $item, $v;
        }
    }

    FALSE;
}

=item addItem( $item [, $priority = 0 ] )

 Add the given item into the queue

 Param mixed $item Item to add
 Param number $priority OPTIONAL Item priority (Highest values have highest priority)
 Return iMSCP::PriorityQueue, croak on failure
 
=cut

sub addItem
{
    my ( $self, $item, $priority ) = @_;
    $priority //= 0;

    looks_like_number $priority or croak( 'Invalid priority. Expects a number.' );

    push @{ $self->{'queue'}->{$priority} }, $item;
    $self->{'highest_priority'} = max $priority, $self->{'highest_priority'};
    $self;
}

=item removeItem( $item )

 Remove the given item from the queue

 Only the first item matching the provided item is removed. If the same item
 has been added multiple times, it will not remove other instances.

 Param mixed $item Item to remove
 Return bool TRUE if the given item has been found and removed, FALSE otherwise

=cut

sub removeItem
{
    my ( $self, $item ) = @_;

    return FALSE if $self->isEmpty();

    while ( my ( $priority, $items ) = each( %{ $self->{'queue'} } ) ) {
        for ( my $i = $#{ $items }; $i > -1; $i-- ) {
            next unless Compare $item, $items->[$i];

            splice @{ $items }, $i, 1;

            unless ( @{ $self->{'queue'}->{$priority} } ) {
                delete $self->{'queue'}->{$priority};
                $self->{'highest_priority'} = max keys %{ $self->{'queue'} }, 0;
            }

            # Reset internal hash iterator; see http://www.perlmonks.org/?node_id=294285
            $self->count();
            return TRUE;
        }
    }

    # Reset internal hash iterator; see http://www.perlmonks.org/?node_id=294285
    $self->count();
    FALSE;
}

=item count( )

 How many items are in the queue?

 Return int Count of items

=cut

sub count
{
    scalar keys %{ $_[0]->{'queue'} };
}

=item isEmpty( )

 Is the queue empty?

 Return bool TRUE if the queue is empty, FALSE otherwise

=cut

sub isEmpty
{
    !$_[0]->count();
}

=item pop( )

 Pop item with highter priority from the queue

 Return mixed Item or FALSE if the queue is empty

=cut

sub pop
{
    my ( $self ) = @_;

    return FALSE if $self->isEmpty();

    my $item = shift @{ $self->{'queue'}->{$self->{'highest_priority'}} };

    unless ( @{ $self->{'queue'}->{$self->{'highest_priority'}} } ) {
        delete $self->{'queue'}->{$self->{'highest_priority'}};
        $self->{'highest_priority'} = max keys %{ $self->{'queue'} }, 0;
    }

    $item;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
