=head1 NAME

 iMSCP::Modules::IpAddr - Module for processing of server IP address enties

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package iMSCP::Modules::IpAddr;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of server IP address entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'IpAddr';
}

=item add()

 Add or change the server IP address

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval { $self->SUPER::add(); };
    $self->{'_dbh'}->do( 'UPDATE server_ips SET ip_status = ? WHERE ip_id = ?', undef, $@ || 'ok', $self->{'ip_id'} );
    $self;
}

=item delete()

 Delete the server IP address

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval { $self->SUPER::delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE server_ips SET ip_status = ? WHERE ip_id = ?', undef, $@, $self->{'ip_id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM server_ips WHERE ip_id = ?', undef, $self->{'ip_id'} );
    $self;
}

=item handleEntity( $ipId )

 Handle the given IP address entitiy

 Param string $ipId Server IP unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $ipId) = @_;

    $self->_loadData( $ipId );

    if ( $self->{'_data'}->{'ip_status'} =~ /^to(?:add|change)$/ ) {
        $self->add();
    } elsif ( $self->{'_data'}->{'ip_status'} eq 'todelete' ) {
        $self->delete();
    } else {
        die( sprintf( 'Unknown action (%s) for server IP with ID %s', $self->{'_data'}->{'ip_status'}, $ipId ));
    }

    $self;
}

=back

=head1 PRIVATES METHODS

=over 4

=item _loadData( $ipId )

 Load data

 Param int $ipId Server IP unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $ipId) = @_;

    $self->{'_data'} = $self->{'_dbh'}->selectrow_hashref(
        'SELECT ip_id, ip_card, ip_number AS ip_address, ip_netmask, ip_config_mode, ip_status FROM server_ips WHERE ip_id = ?', undef, $ipId
    );
    $self->{'_data'} or die( sprintf( 'Data not found for server IP address (ID %d)', $ipId ));
}

=item _getData( $action )

 Data provider method for servers and packages

 Param string $action Action
 Return hashref Reference to a hash containing data

=cut

sub _getData
{
    my ($self, $action) = @_;

    $self->{'_data'}->{'action'} = $action;
    $self->{'_data'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
