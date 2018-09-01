=head1 NAME

 iMSCP::ConfigProvider::Hash - Configuration provider for Perl hashes

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

package iMSCP::ConfigProvider::Hash;

use strict;
use warnings;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Provider that returns the hashref seeded to itself.

 Primary use case is configuration cache-related settings.

=head1 CLASS METHODS

=over 4

=item new( $hash )

 Constructor
 
 Param $hashref $hash A hash reference
 Return iMSCP::ConfigProvider::Hash

=cut

sub new
{
    my ( $self, $hash ) = @_;

    ref $hash eq 'HASH' or die( 'Invalid $hash parameter. HASH reference expected.' );

    $self->SUPER::new( config => $hash );
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref

=cut

sub __invoke
{
    my ( $self ) = @_;

    $self->{'config'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
