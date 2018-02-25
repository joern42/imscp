=head1 NAME

 iMSCP::Servers - Package that allows to load and get list of available i-MSCP servers

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
use File::Basename;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Package that allows to load and get list of available i-MSCP servers

=head1 PUBLIC METHODS

=over 4

=item getList( )

 Get server list, sorted in descending order of priority

 Return server list

=cut

sub getList
{
    @{$_[0]->{'servers'}};
}

=item getListWithFullNames( )

 Get server list with full names, sorted in descending order of priority

 Return server list

=cut

sub getListWithFullNames
{
    @{$_[0]->{'servers_full_names'}};
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Servers, die on failure

=cut

sub _init
{
    my ($self) = @_;

    s%^.*?([^/]+)\.pm$%$1% for @{$self->{'servers'}} = grep (!/(?:Abstract|NoServer)\.pm$/, glob( dirname( __FILE__ ) . '/Servers/*.pm' ) );

    # Load all server
    for my $server( @{$self->{'servers'}} ) {
        my $fserver = "iMSCP::Servers::${server}";
        eval "require $fserver; 1" or die( sprintf( "Couldn't load %s server class: %s", $fserver, $@ ));
    }

    # Sort servers by priority (descending order)
    @{$self->{'servers'}} = sort { "iMSCP::Servers::${b}"->getPriority() <=> "iMSCP::Servers::${a}"->getPriority() } @{$self->{'servers'}};
    @{$self->{'servers_full_names'}} = map { "iMSCP::Servers::${_}" } @{$self->{'servers'}};
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
