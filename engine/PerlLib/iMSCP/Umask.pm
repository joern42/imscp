=head1 NAME

 iMSCP::Umask - Allows to restrict UMASK(2) scope

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

package iMSCP::Umask;

use Carp qw/ croak /;
use Exporter qw/ import /;

our $UMASK;
our @EXPORT = qw/ $UMASK /;

tie $UMASK, 'iMSCP::Umask::SCALAR' or croak "Can't tie \$UMASK";

{
    package iMSCP::Umask::SCALAR;

    # Cache UMASK(2) to avoid calling umask() on each FETCH (performance boost)
    my $_UMASK = umask();

    # Override built-in umask() globally as we want get notified of change when
    # it get called directly
    BEGIN {
        *CORE::GLOBAL::umask = sub {
            my $oldMask = $_UMASK;
            umask( $_UMASK = $_[0] ) if defined $_[0] && $_[0] ne $oldMask;
            $oldMask;
        };
    }

    sub TIESCALAR
    {
        bless [], $_[0];
    }

    sub FETCH
    {
        $_UMASK;
    }

    sub STORE
    {
        return unless defined $_[1];
        umask( $_[1] );
    }
}

1;
__END__
