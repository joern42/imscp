=head1 NAME

 iMSCP::Modules::IpAddr - Module for processing of server IP address enties

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

package iMSCP::Modules::IpAddr;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of server IP address entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'IpAddr';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    return $self->_add() if $self->{'_data'}->{'ip_status'} =~ /^to(?:add|change)$/;
    return $self->_delete() if $self->{'_data'}->{'ip_status'} eq 'todelete';
}

=back

=head1 PRIVATES METHODS

=over 4

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $entityId ) = @_;

    $self->{'_data'} = $self->{'_dbh'}->selectrow_hashref(
        'SELECT ip_id, ip_card, ip_number AS ip_address, ip_netmask, ip_config_mode, ip_status FROM server_ips WHERE ip_id = ?', undef, $entityId
    );
    $self->{'_data'} or die( sprintf( 'Data not found for server IP address (ID %d)', $entityId ));
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE server_ips SET ip_status = ? WHERE ip_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'ip_id'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE server_ips SET ip_status = ? WHERE ip_id = ?', undef, $@, $self->{'_data'}->{'ip_id'} );
        return;
    }

    $self->{'_dbh'}->do( 'DELETE FROM server_ips WHERE ip_id = ?', undef, $self->{'_data'}->{'ip_id'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
