=head1 NAME

 iMSCP::Modules::User - Module for processing of user entities

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

package iMSCP::Modules::User;

use strict;
use warnings;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of user entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'User';
}

=item add( )

 Add or change the user

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval {
        if ( $self->{'admin_status'} ne 'tochangepwd' ) {
            my $user = my $group = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'admin_id'} );
            my $home = "$main::imscpConfig{'USER_WEB_DIR'}/$self->{'admin_name'}";
            $self->{'eventManager'}->trigger( 'onBeforeAddImscpUnixUser', $self->{'admin_id'}, $user, \my $pwd, $home, \my $skelPath, \my $shell );

            iMSCP::SystemUser->new(
                username     => $self->{'admin_sys_name'}, # Old username
                password     => $pwd,
                comment      => 'i-MSCP Web User',
                home         => $home,
                skeletonPath => $skelPath,
                shell        => $shell
            )->addSystemUser( $user, $group );

            my ( $uid, $gid ) = ( getpwnam( $user ) )[2, 3];
            $self->{'_dbh'}->do(
                'UPDATE admin SET admin_sys_name = ?, admin_sys_uid = ?, admin_sys_gname = ?, admin_sys_gid = ? WHERE admin_id = ?',
                undef, $user, $uid, $group, $gid, $self->{'admin_id'},
            );
            @{$self}{ qw/ admin_sys_name admin_sys_uid admin_sys_gname admin_sys_gid / } = ( $user, $uid, $group, $gid );
        }

        $self->SUPER::add()
    };

    $self->{'_dbh'}->do( 'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, $@ || 'ok', $self->{'admin_id'} );
    $self;
}

=item delete( )

 Delete the user

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval {
        my $user = my $group = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'admin_id'} );
        $self->{'eventManager'}->trigger( 'onBeforeDeleteImscpUnixUser', $user );
        $self->SUPER::delete();
        iMSCP::SystemUser->new( force => 1 )->delSystemUser( $user );
        iMSCP::SystemGroup->getInstance()->delSystemGroup( $group );
        $self->{'eventManager'}->trigger( 'onAfterDeleteImscpUnixUser', $group );
    };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, $@, $self->{'admin_id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM admin WHERE admin_id = ?', undef, $self->{'admin_id'} );
    $self;
}

=item handleEntity( $userId )

 Handle the given user entity

 Param int $userId User unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $userId) = @_;

    $self->_loadData( $userId );

    if ( $self->{'admin_status'} =~ /^to(?:add|change(?:pwd)?)$/ ) {
        $self->add();
    } elsif ( $self->{'admin_status'} eq 'todelete' ) {
        $self->delete();
    } else {
        die( sprintf( 'Unknown action (%s) for user (ID %d)', $self->{'admin_status'}, $userId ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $userId )

 Load data

 Param int $userId user unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $userId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        '
            SELECT admin_id, admin_name, admin_pass, admin_sys_name, admin_sys_uid, admin_sys_gname, admin_sys_gid, admin_status
            FROM admin
            WHERE admin_id = ?
        ',
        undef,
        $userId
    );
    $row or die( sprintf( 'User (ID %d) has not been found', $userId ));
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

    my $usergroup = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'admin_id'} );

    $self->{'_data'} = {
        ACTION        => $action,
        STATUS        => $self->{'admin_status'},
        USER_ID       => $self->{'admin_id'},
        USER_SYS_UID  => $self->{'admin_sys_uid'},
        USER_SYS_GID  => $self->{'admin_sys_gid'},
        USERNAME      => $self->{'admin_name'},
        PASSWORD_HASH => $self->{'admin_pass'},
        USER          => $usergroup,
        GROUP         => $usergroup
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
