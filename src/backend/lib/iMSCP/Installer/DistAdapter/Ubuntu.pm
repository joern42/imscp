=head1 NAME

 iMSCP::Installer::DistAdapter::Ubuntu  Installer adapter for Ubuntu distribution

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 by internet Multi Server Control Panel
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

package iMSCP::Installer::DistAdapter::Ubuntu;

use strict;
use warnings;
use parent 'iMSCP::Installer::DistAdapter::Debian';

=head1 DESCRIPTION

 Installer adapter for Ubuntu distributions.

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return autoinstaller::Adapter::UbuntuAdapter

=cut

sub _init
{
    my $self = shift;

    $self->SUPER::_init();
    $self->{'repositorySections'} = [ 'universe', 'multiverse' ];
    $self;
}

=back

=head1 Author

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
