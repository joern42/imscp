=head1 NAME

 iMSCP::Common::Functor - Functor object base class

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

package iMSCP::Common::Functor;

use strict;
use warnings;
use iMSCP::Boolean;
use parent 'iMSCP::Common::Object';
use overload
    '&{}'    => sub { $_[0]->can( '__invoke' ) or die( sprintf( 'The %s class must implement the __invoke() method', ref $_[0] )); },
    fallback => TRUE;

=head1 DESCRIPTION

 Functor object base class.

=cut

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
