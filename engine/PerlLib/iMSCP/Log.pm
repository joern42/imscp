=head1 NAME

 iMSCP::Log - i-MSCP generic message storing mechanism

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

package iMSCP::Log;

use strict;
use warnings;
use Params::Check qw[ check ];
use iMSCP::Boolean;

local $Params::Check::VERBOSE = TRUE;

=head1 DESCRIPTION

 Generic message storage mechanism allowing to store messages on a stack.

=head1 PUBLIC METHODS

=over 4

=item new( )

 Create new iMSCP::Log object

 Return iMSCP::Log, die on failure

=cut

sub new
{
    my $class = shift;
    my %hash = @_;

    my $tmpl = {
        id    => {
            strict_type => TRUE,
            required    => TRUE
        },
        stack => {
            default => []
        }
    };

    my $args = check( $tmpl, \%hash ) or die( sprintf( "Couldn't create a new iMSCP::Log object: %s1", Params::Check->last_error ));
    bless $args, $class
}

=item getId( )

 Get identifier

 Return string

=cut

sub getId
{
    $_[0]->{'id'};
}

=item store( )

 Create a new item hash and store it on the stack.

 Possible arguments you can give to it are:

=over 4

=item message

 This is the only argument that is required. If no other arguments are given, you may even leave off the C<message> key.
 The argument will then automatically be assumed to be the message.

=item tag

 The tag to add to this message. If not provided, default tag 'none' will be used.

=item when

 The time to add to this message. If not provided, value from localtime will be used

=back

 Return TRUE upon success and FALSE upon failure, as well as issue a warning as to why it failed.

=cut

sub store
{
    my $self = shift;

    my %hash = ();
    my $tmpl = {
        when    => {
            default => scalar localtime,
                strict_type => TRUE, # based no default attribute type, default to SCALAR
        },
        message => {
            default     => 'empty log',
            strict_type => TRUE,
            required    => TRUE # based no default attribute type, default to SCALAR
        },
        tag     => {
            default     => 'none',
            strict_type => TRUE
        }
    };

    if ( @_ == 1 ) {
        $hash{'message'} = shift;
    } else {
        %hash = @_;
    }

    my $args = check( $tmpl, \%hash ) or (
        warn( sprintf( "Couldn't store message: %s", Params::Check->last_error )),
        return FALSE
    );

    my $item = {
        when    => $args->{'when'},
        message => $args->{'message'},
        tag     => $args->{'tag'}
    };

    push @{ $self->{'stack'} }, $item;
    TRUE;
}

=item retrieve( )

 Retrieve all message items matching the criteria specified from the stack.

 Here are the criteria you can discriminate on:

=over 4

=item tag

 A regex to which the tag must adhere. For example C<qr/\w/>.

=item message

 A regex to which the message must adhere.

=item amount

 Maximum amount of errors to return

=item chrono

 Return in chronological order, or not?

=item remove

 If TRUE, remove items from the stack upon retrieval. Only returned items are removed.

=back

 In scalar context it will return the first item matching your criteria and in list context, it will return all of them.

 If an error occurs while retrieving, a warning will be issued and undef will be returned.

=cut

sub retrieve
{
    my $self = shift;

    my %hash = ();
    my $tmpl = {
        tag     => { default => qr/.*/ },
        message => { default => undef },
        amount  => { default => scalar @{ $self->{'stack'} }, strict_type => TRUE },
        remove  => { default => FALSE },
        chrono  => { default => TRUE }
    };

    # single arg means just the amount otherwise, they are named
    if ( @_ == 1 ) {
        $hash{'amount'} = shift;
    } else {
        %hash = @_;
    }

    my $args = check( $tmpl, \%hash ) or ( warn( sprintf( "Couldn't parse input: %s", Params::Check->last_error )), return );

    # Prevent removal of items which are not effectively returned to caller ( amount > 1 but scalar context)
    $args->{'amount'} = 1 unless wantarray;

    my @list = ();
    for my $log ( $args->{'chrono'} ? @{ $self->{'stack'} } : reverse @{ $self->{'stack'} } ) {
        next unless $log->{'tag'} =~ /$args->{'tag'}/ && ( !defined $args->{'message'} || $log->{'message'} =~ /$args->{'message'}/ );
        push @list, $log;
        undef $log if $args->{'remove'};
        $args->{'amount'}--;
        last unless $args->{'amount'};
    }

    @{ $self->{'stack'} } = grep defined, @{ $self->{'stack'} } if $args->{'remove'} && @list;

    wantarray ? @list : $list[0];
}

=item first( )

 Retrieve the first item(s) stored on the stack. It will default to only retrieving one if called with no arguments, and
 will always return results in chronological order.

 If you only supply one argument, it is assumed to be the amount you wish returned.

 Furthermore, it can take the same arguments as C<retrieve> can.

=cut

sub first
{
    my $self = shift;

    $self->retrieve( amount => @_ == 1 ? shift @_ : 1, @_, chrono => TRUE );
}

=item final( )

 Retrieve the last item(s) stored on the stack. It will default to only retrieving one if called with no arguments, and
 will always return results in reverse chronological order.

 If you only supply one argument, it is assumed to be the amount you wish returned.

 Furthermore, it can take the same arguments as C<retrieve> can.

=cut

sub final
{
    my $self = shift;

    $self->retrieve( amount => @_ == 1 ? shift @_ : 1, @_, chrono => FALSE );
}

=item flush( )

 Removes all items from the stack and returns them to the caller

=cut

sub flush
{
    splice @{ $_[0]->{'stack'} };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
