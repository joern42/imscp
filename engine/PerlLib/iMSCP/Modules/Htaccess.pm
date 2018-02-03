=head1 NAME

 iMSCP::Modules::Htaccess - Module for processing of htaccess entities

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

package iMSCP::Modules::Htaccess;

use strict;
use warnings;
use Encode qw/ encode_utf8 /;
use File::Spec;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of htaccess entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ($self) = @_;

    'Htaccess';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ($self, $entityId) = @_;

    $self->_loadEntityData( $entityId );

    if ( $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change|enable)$/ ) {
        $self->_add();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todisable' ) {
        $self->_disable();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todelete' ) {
        $self->_delete();
    } else {
        die( sprintf( 'Unknown action (%s) for htaccess (ID %d)', $self->{'_data'}->{'STATUS'}, $entityId ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ($self, $entityId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        "
            SELECT t3.id, t3.auth_type, t3.auth_name, t3.path, t3.status, t3.users, t3.groups,
                t4.domain_name, t4.domain_admin_id
            FROM (SELECT * FROM htaccess, (SELECT IFNULL(
                (
                    SELECT group_concat(uname SEPARATOR ' ')
                    FROM htaccess_users
                    WHERE id regexp (CONCAT('^(', (SELECT REPLACE((SELECT user_id FROM htaccess WHERE id = ?), ',', '|')), ')\$'))
                    GROUP BY dmn_id
                ), '') AS users) AS t1, (SELECT IFNULL(
                    (
                        SELECT group_concat(ugroup SEPARATOR ' ')
                        FROM htaccess_groups
                        WHERE id regexp (
                            CONCAT('^(', (SELECT REPLACE((SELECT group_id FROM htaccess WHERE id = ?), ',', '|')), ')\$')
                        )
                        GROUP BY dmn_id
                    ), '') AS groups) AS t2
                ) AS t3
            JOIN domain AS t4 ON (t3.dmn_id = t4.domain_id)
            WHERE t3.id = ?
        ",
        undef,
        $entityId,
        $entityId,
        $entityId
    );
    $row or die( sprintf( 'Data not found for htaccess (ID %d)', $entityId ));

    my $usergroup = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'domain_admin_id'} );

    $self->{'_data'} = {
        ID              => $row->{'id'},
        STATUS          => $row->{'status'},
        DOMAIN_ADMIN_ID => $row->{'domain_admin_id'},
        USER            => $usergroup,
        GROUP           => $usergroup,
        AUTH_TYPE       => $row->{'auth_type'},
        AUTH_NAME       => encode_utf8( $row->{'auth_name'} ),
        AUTH_PATH       => File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$row->{'domain_name'}/$row->{'path'}" ),
        HOME_PATH       => File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$row->{'domain_name'}" ),
        DOMAIN_NAME     => $row->{'domain_name'},
        HTUSERS         => $row->{'users'},
        HTGROUPS        => $row->{'groups'}
    };
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ($self) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess SET status = ? WHERE id = ?', undef, $@ || 'ok', $self->{'_data'}->{'ID'} );
    $self;
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ($self) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE htaccess SET status = ? WHERE id = ?', undef, $@, $self->{'_data'}->{'ID'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM htaccess WHERE id = ?', undef, $self->{'_data'}->{'ID'} );
    $self;
}

=item _disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ($self) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess SET status = ? WHERE id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'ID'} );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
