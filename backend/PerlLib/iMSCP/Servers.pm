=head1 NAME

 iMSCP::Servers - Library for loading and retrieval of i-MSCP servers

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

package iMSCP::Servers;

use strict;
use warnings;
use File::Basename qw/ dirname /;
use iMSCP::Cwd;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Library for loading and retrieval of i-MSCP servers.

=head1 PUBLIC METHODS

=over 4

=item getList( )

 Get list of servers sorted in descending order of priority

 Return list of servers

=cut

sub getList
{
    @{ $_[0]->{'_servers'} };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return self, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    local $CWD = dirname( __FILE__ ) . '/Servers';
    s%(.*)\.pm$%iMSCP::Servers::$1% for @{ $self->{'_servers'} } = grep !/(?:Abstract|NoServer)\.pm$/, <*.pm>;
    eval "require $_; 1" or die( sprintf( "Couldn't load %s server class: %s", $_, $@ )) for @{ $self->{'_servers'} };
    @{ $self->{'_servers'} } = sort { $b->getServerPriority() <=> $a->getServerPriority() } @{ $self->{'_servers'} };
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
