=head1 NAME

 iMSCP::Modules::Htgroup - Module for processing of htgroup entities

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

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'Htgroup';
}

=item add()

 Add, change or enable the htgroup

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval { $self->SUPER::add(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@ || 'ok', $self->{'id'} );
    $self;
}

=item delete()

 Delete the htgroup

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval { $self->SUPER::delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@, $self->{'id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM htaccess_groups WHERE id = ?', undef, $self->{'id'} );
    $self;
}

=item disable()

 Disable the htgroup

 Return self, die on failure

=cut

sub disable
{
    my ($self) = @_;

    eval { $self->SUPER::disable(); };
    $self->{'_dbh'}->do( 'UPDATE htaccess_groups SET status = ? WHERE id = ?', undef, $@ || 'disabled', $self->{'id'} );
    $self;
}

=item handleEntity( $htgroupId )

 Handle the given htgroup entity

 Param int $htgroupId Htgroup unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $htgroupId) = @_;

    $self->_loadData( $htgroupId );

    if ( $self->{'status'} =~ /^to(?:add|change|enable)$/ ) {
        $self->add();
    } elsif ( $self->{'status'} eq 'todisable' ) {
        $self->disable();
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $self->delete();
    } else {
        die( sprintf( 'Unknown action (%s) for htgroup (ID %d)', $self->{'status'}, $htgroupId ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $htgroupId )

 Load data

 Param int $htgroupId $Htgroup unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $htgroupId) = @_;

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
        undef, $htgroupId, $htgroupId
    );
    $row or die( sprintf( 'Data not found for htgroup (ID %d)', $htgroupId ));
    %{$self} = ( %{$self}, %{$row} );
}

=item _getData( $action )

 Data provider method for servers and packages

 Param string $action Action
 Return hashref Reference to a hash containing data

=cut

sub _getData
{
    my ($self, $action) = @_;

    return $self->{'_data'} if %{$self->{'_data'}};

    my $webDir = File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$self->{'domain_name'}" );
    my $usergroup = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'domain_admin_id'} );

    $self->{'_data'} = {
        ACTION                => $action,
        STATUS                => $self->{'status'},
        DOMAIN_ADMIN_ID       => $self->{'domain_admin_id'},
        USER                  => $usergroup,
        GROUP                 => $usergroup,
        WEB_DIR               => $webDir,
        HTGROUP_NAME          => $self->{'ugroup'},
        HTGROUP_USERS         => $self->{'users'},
        HTGROUP_DMN           => $self->{'domain_name'},
        WEB_FOLDER_PROTECTION => $self->{'web_folder_protection'}
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
