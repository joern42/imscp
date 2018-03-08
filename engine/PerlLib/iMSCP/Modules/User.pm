=head1 NAME

 iMSCP::Modules::User - Module for processing of user entities

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

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'User';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    if ( $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change(?:pwd)?)$/ ) {
        $self->_add();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todelete' ) {
        $self->_delete();
    } else {
        die( sprintf( 'Unknown action (%s) for user (ID %d)', $self->{'_data'}->{'STATUS'}, $entityId ));
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
    my ( $self, $entityId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        '
            SELECT admin_id, admin_name, admin_pass, admin_sys_name, admin_sys_uid, admin_sys_gname, admin_sys_gid, admin_status
            FROM admin
            WHERE admin_id = ?
        ',
        undef,
        $entityId
    );
    $row or die( sprintf( 'User (ID %d) has not been found', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'admin_id'} );

    $self->{'_data'} = {
        STATUS        => $row->{'admin_status'},
        USER_ID       => $row->{'admin_id'},
        USER_SYS_UID  => $row->{'admin_sys_uid'},
        USER_SYS_GID  => $row->{'admin_sys_gid'},
        USERNAME      => $row->{'admin_name'},
        PASSWORD_HASH => $row->{'admin_pass'},
        USER          => $usergroup,
        GROUP         => $usergroup
    };
}

=item _add( )

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval {
        if ( $self->{'_data'}->{'STATUS'} ne 'tochangepwd' ) {
            my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'_data'}->{'USER_ID'} );
            my $home = "$::imscpConfig{'USER_WEB_DIR'}/$self->{'_data'}->{'USERNAME'} ";
            $self->{'eventManager'}->trigger(
                'onBeforeAddImscpUnixUser', $self->{'_data'}->{'USER_ID'}, $usergroup, \my $pwd, $home, \my $skelPath, \my $shell
            );

            iMSCP::SystemUser->new(
                username     => $self->{'_data'}->{'admin_sys_name'}, # Old username
                password     => $pwd,
                comment      => 'i-MSCP Web User',
                home         => $home,
                skeletonPath => $skelPath,
                shell        => $shell
            )->addSystemUser( $usergroup, $usergroup );

            my ( $uid, $gid ) = ( getpwnam( $usergroup ) )[2, 3];
            $self->{'_dbh'}->do(
                'UPDATE admin SET admin_sys_name = ?, admin_sys_uid = ?, admin_sys_gname = ?, admin_sys_gid = ? WHERE admin_id = ?',
                undef, $usergroup, $uid, $usergroup, $gid, $self->{'_data'}->{'USER_ID'},
            );
            @{ $self }{ qw/ admin_sys_name admin_sys_uid admin_sys_gname admin_sys_gid / } = ( $usergroup, $uid, $usergroup, $gid );
        }

        $self->SUPER::_add()
    };
    $self->{'_dbh'}->do( 'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'USER_ID'} );
    $self;
}

=item _delete( )

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval {
        my $user = my $group = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'_data'}->{'USER_ID'} );
        $self->{'eventManager'}->trigger( 'onBeforeDeleteImscpUnixUser', $user );
        $self->SUPER::_delete();
        iMSCP::SystemUser->new( force => 1 )->delSystemUser( $user );
        iMSCP::SystemGroup->getInstance()->delSystemGroup( $group );
        $self->{'eventManager'}->trigger( 'onAfterDeleteImscpUnixUser', $group );
    };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, $@, $self->{'_data'}->{'USER_ID'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM admin WHERE admin_id = ?', undef, $self->{'_data'}->{'USER_ID'} );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
