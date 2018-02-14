=head1 NAME

 iMSCP::Servers::Mta::Postfix::Driver::Database::CDB - i-MSCP CDB database driver for Postfix

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

package iMSCP::Servers::Mta::Postfix::Driver::Database::CDB;

use strict;
use warnings;
use parent 'iMSCP::Servers::Mta::Postfix::Driver::Database::Hash';

=head1 DESCRIPTION

 i-MSCP CDB database driver for Postfix.
 
 See http://www.postfix.org/CDB_README.html

=head1 PUBLIC METHODS

=over 4

=item getDbType( )

 See iMSCP::Server::Mta::Posfix::Driver::Database::Hash::getDbType()

=cut

sub getDbType
{
    my ($self) = @_;

    'cdb';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
