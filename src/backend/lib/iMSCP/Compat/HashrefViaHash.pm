=head1 NAME

 iMSCP::Compat::HashrefViaHash - Access an hashref through a tied hash

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

package iMSCP::Compat::HashrefViaHash;

use strict;
use warnings;
use iMSCP::Boolean;
use Params::Check qw/ check last_error /;

=head1 DESCRIPTION

 Make an hashref accessible through simple (tied) hash.
 
 Provided for compatibility only. Usage of this class should be
 avoided as this involve performance penalties.
 
 Current use cases are:
 - Make i-MSCP master configuration accessible through %::imscpConfig package
   variable
 - Make i-MSCP old master configuration accessible through %::imscpOldConfig
   package variable

=head1 PUBLIC METHODS

=over 4

=item TIEHASH( HASHREF => {} )

 Constructor

 Named parameters:
  HASHREF: Reference to a hash
 Return iMSCP::Compat::HashrefViaHash

=cut

sub TIEHASH
{
    my ( $class, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;

    my $hashref = check(
        { HASHREF => { default => {}, required => TRUE, strict_type => TRUE } }, \%params, TRUE
    ) or die( Params::Check::last_error());

    bless [ $hashref->{'HASHREF'} ], $class;
}

=item STORE( key, value )

 Store an element

=cut

sub STORE
{
    $_[0]->[0]->{$_[1]} = $_[2];
}

=item FETCH( key )

 Fetch an element

=cut

sub FETCH
{
    $_[0]->[0]->{ $_[1] };
}

=item FIRSTKEY( )

 Method will be triggered when the user is going to iterate through the hash,
 such as via a keys(), values(), or each() call.

=cut

sub FIRSTKEY
{
    scalar keys %{ $_[0]->[0] };
    each %{ $_[0]->[0] };
}

=item NEXTKEY( )

 Method triggered during a keys(), values(), or each() iteration.

=cut

sub NEXTKEY
{
    each %{ $_[0]->[0] };
}

=item EXISTS( key )

 Check if an element exists

=cut

sub EXISTS
{
    exists $_[0]->[0]->{ $_[1] };
}

=item DELETE( key )

 Delete an element

=cut

sub DELETE
{
    delete $_[0]->[0]->{ $_[1] };
}

=item CLEAR( )

 Clear all elements

=cut

sub CLEAR
{
    %{ $_[0]->[0] } = ();
}

=item SCALAR( )

 Method called when the tied hash is evaluated in scalar context

=cut

sub SCALAR
{
    scalar %{ $_[0]->[0] };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__

Usage example:

use Data::Dumper;
use iMSCP::Compat::HashrefViaHash;

my $hashref = { foo => 1 };
tie my %simpleHash, 'iMSCP::Compat::HashrefViaHash', HASHREF => $hashref;
print Dumper( \%simpleHash );
$hashref-> { 'bar' } = 1;
print Dumper( \%simpleHash );
