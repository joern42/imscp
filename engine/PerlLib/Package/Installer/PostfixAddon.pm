=head1 NAME

 Package::PostfixAddon - i-MSCP Postfix addon package collection

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

package Package::Postfix;

use strict;
use warnings;
use parent 'Package::AbstractCollection';

=head1 DESCRIPTION

 i-MSCP Postfix addon package collection.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 See Package::AbstractCollection::getType()

=cut

sub getType
{
    my ( $self ) = @_;

    'PostfixAddon';
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadAvailablePackages()

 Load list of available packages for this collection

 Return void, die on failure

=cut

sub _loadAvailablePackages
{
    my ( $self ) = @_;

    s/\.pm$// for @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new(
        dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/Installer/" . $self->getType()
    )->getFiles();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
