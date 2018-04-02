=head1 NAME

 iMSCP::Modules::Htgroup - Module for processing of htgroup entities

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

package iMSCP::Modules::Htgroup;

use strict;
use warnings;
use File::Spec;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of htgroup entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Htgroup';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    return $self->_add() if $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change|enable)$/;
    return $self->_disable() if $self->{'_data'}->{'STATUS'} eq 'todisable';
    return $self->_delete() if $self->{'_data'}->{'STATUS'} eq 'todelete';
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $entityId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        "
            SELECT t2.id, t2.ugroup, t2.status, t2.users, t3.domain_name, t3.domain_admin_id, t3.web_folder_protection
            FROM (SELECT * from htaccess_groups, (SELECT IFNULL(
                (
                    SELECT group_concat(uname SEPARATOR ' ')
                    FROM htaccess_users
                    WHERE id regexp (CONCAT('^(', (SELECT REPLACE((SELECT members FROM htaccess_groups WHERE id = ?), ',', '|')), ')\$'))
                    GROUP BY dmn_id
                ), '') AS users) AS t1
            ) AS t2
            JOIN domain AS t3 ON (t2.dmn_id = t3.domain_id)
            WHERE id = ?
        ",
        undef, $entityId, $entityId
    );
    $row or die( sprintf( 'Data not found for htgroup (ID %d)', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'domain_admin_id'} );

    $self->{'_data'} = {
        ID                    => $row->{'id'},
        STATUS                => $row->{'status'},
        DOMAIN_ADMIN_ID       => $row->{'domain_admin_id'},
        USER                  => $usergroup,
        GROUP                 => $usergroup,
        WEB_DIR               => File::Spec->canonpath( "$::imscpConfig{'USER_WEB_DIR'}/$row->{'domain_name'}" ),
        HTGROUP_NAME          => $row->{'ugroup'},
        HTGROUP_USERS         => $row->{'users'},
        HTGROUP_DMN           => $row->{'domain_name'},
        WEB_FOLDER_PROTECTION => $row->{'web_folder_protection'}
    };
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@ || 'ok', $self->{'_data'}->{'ID'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@, $self->{'_data'}->{'ID'} );
        return;
    }

    $self->{'_dbh'}->do( 'DELETE FROM htaccess_groups WHERE id = ?', undef, $self->{'_data'}->{'ID'} );
}

=item _disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ( $self ) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'ID'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
