=head1 NAME

 iMSCP::Modules::Htpasswd - Module for processing of htpasswd entties

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

package iMSCP::Modules::Htpasswd;

use strict;
use warnings;
use File::Spec;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of htpasswd entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Htpasswd';
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
        '
            SELECT t1.id, t1.uname, t1.upass, t1.status, t2.domain_name, t2.domain_admin_id, t2.web_folder_protection
            FROM htaccess_users AS t1
            JOIN domain AS t2 ON (t2.domain_id = t1.dmn_id)
            WHERE t1.id = ?
        ',
        undef, $entityId
    );
    $row or die( sprintf( 'Data not found for htuser (ID %d)', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'domain_admin_id'} );

    $self->{'_data'} = {
        ID                    => $row->{'id'},
        STATUS                => $row->{'status'},
        USER                  => $usergroup,
        GROUP                 => $usergroup,
        HOME_PATH             => File::Spec->canonpath( "$::imscpConfig{'USER_WEB_DIR'}/$row->{'domain_name'}" ),
        HTUSER_NAME           => $row->{'uname'},
        HTUSER_PASS           => $row->{'upass'},
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
    $self->{'_dbh'}->do( 'UPDATE htaccess_users SET status = ? WHERE id = ?', undef, $@ || 'ok', $self->{'_data'}->{'ID'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE htaccess_users SET status = ? WHERE id = ?', undef, $@, $self->{'_data'}->{'ID'} );
        return;
    }

    $self->{'_dbh'}->do( 'DELETE FROM htaccess_users WHERE id = ?', undef, $self->{'_data'}->{'ID'} );
}

=item _disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ( $self ) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess_users SET status = ? WHERE id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'ID'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
