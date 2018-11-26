=head1 NAME

 iMSCP::Modules::User - i-MSCP User module

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
use iMSCP::Boolean;
use iMSCP::Debug qw/ error getLastError warning /;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 i-MSCP User module.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 See iMSCP::Modules::Abstract::getType()

=cut

sub getType
{
    'User';
}

=item process( $userId )

 See Module::Abstract::process()

=cut

sub process
{
    my ( $self, $userId ) = @_;

    my $rs = $self->_loadData( $userId );
    return $rs if $rs;

    my @sql;
    if ( grep ( $self->{'admin_status'} eq $_, 'toadd', 'tochange', 'toenable' ) ) {
        $rs = $self->add();
        @sql = ( 'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, $rs ? getLastError( 'error' ) || 'Unknown error' : 'ok', $userId );
    } elsif ( $self->{'admin_status'} eq 'todelete' ) {
        $rs = $self->delete();
        @sql = $rs ? (
            'UPDATE admin SET admin_status = ? WHERE admin_id = ?', undef, getLastError( 'error' ) || 'Unknown error', $userId
        ) : (
            'DELETE FROM admin WHERE admin_id = ?', undef, $userId
        );
    } else {
        warning( sprintf( 'Unknown action (%s) for user (ID %d)', $self->{'admin_status'}, $userId ));
        return 0;
    }

    local $self->{'dbh'}->{'RaiseError'} = TRUE;
    $self->{'dbh'}->do( @sql );
    $rs;
}

=item add( )

 See iMSCP::Modules::Abstract::add()

=cut

sub add
{
    my ( $self ) = @_;

    return $self->SUPER::add() if $self->{'admin_status'} eq 'tochangepwd';

    my $user = my $group = $::imscpConfig{'USER_PREFIX'} . ( $::imscpConfig{'USER_MIN_UID'}+$self->{'admin_id'} );
    my $home = "$::imscpConfig{'SRV_DIR'}/$self->{'admin_name'}";

    my $rs = $self->{'eventManager'}->trigger( 'onBeforeAddImscpUnixUser', $self->{'admin_id'}, $user, \my $pwd, $home, \my $skelPath, \my $shell );
    return $rs if $rs;

    my ( $oldUser, $uid, $gid ) = $self->{'admin_sys_uid'} && $self->{'admin_sys_uid'} ne '0' ? ( getpwuid( $self->{'admin_sys_uid'} ) )[0, 2, 3] : ();

    $rs = iMSCP::SystemUser->new(
        username     => $oldUser,
        password     => $pwd,
        comment      => 'i-MSCP Web User',
        home         => $home,
        skeletonPath => $skelPath,
        shell        => $shell
    )->addSystemUser( $user, $group );
    return $rs if $rs;

    ( $uid, $gid ) = ( getpwnam( $user ) )[2, 3];

    {
        local $self->{'dbh'}->{'RaiseError'} = TRUE;

        $self->{'dbh'}->do(
            'UPDATE admin SET admin_sys_name = ?, admin_sys_uid = ?, admin_sys_gname = ?, admin_sys_gid = ? WHERE admin_id = ?',
            undef, $user, $uid, $group, $gid, $self->{'admin_id'},
        );
    }

    @{ $self }{ qw/ admin_sys_name admin_sys_uid admin_sys_gname admin_sys_gid / } = ( $user, $uid, $group, $gid );
    $self->SUPER::add();
}

=item delete( )

 See iMSCP::Modules::Abstract::delete()

=cut

sub delete
{
    my ( $self ) = @_;

    my $user = my $group = $::imscpConfig{'USER_PREFIX'} . ( $::imscpConfig{'USER_MIN_UID'}+$self->{'admin_id'} );
    my $rs = $self->{'eventManager'}->trigger( 'onBeforeDeleteImscpUnixUser', $user );
    $rs ||= $self->SUPER::delete();
    $rs ||= iMSCP::SystemUser->new( force => 1 )->delSystemUser( $user );
    $rs ||= iMSCP::SystemGroup->getInstance()->delSystemGroup( $group );
    $rs ||= $self->{'eventManager'}->trigger( 'onAfterDeleteImscpUnixUser', $group );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $userId )

 Load data

 Param int $userId user unique identifier
 Return int 0 on success, other on failure

=cut

sub _loadData
{
    my ( $self, $userId ) = @_;

    local $self->{'dbh'}->{'RaiseError'} = TRUE;
    my $row = $self->{'dbh'}->selectrow_hashref(
        '
            SELECT admin_id, admin_name, admin_pass, admin_sys_name, admin_sys_uid, admin_sys_gname, admin_sys_gid, admin_status
            FROM admin
            WHERE admin_id = ?
        ',
        undef, $userId
    );
    $row or die( sprintf( 'User (ID %d) has not been found', $userId ));
    %{ $self } = ( %{ $self }, %{ $row } );
    0;
}

=item _getData( $action )

 See iMSCP::Modules::Abstract::_getData()

=cut

sub _getData
{
    my ( $self, $action ) = @_;

    $self->{'_data'} ||= do {
        my $usergroup = $::imscpConfig{'USER_PREFIX'} . ( $::imscpConfig{'USER_MIN_UID'}+$self->{'admin_id'} );

        {
            ACTION        => $action,
            STATUS        => $self->{'admin_status'},
            USER_ID       => $self->{'admin_id'},
            USER_SYS_UID  => $self->{'admin_sys_uid'},
            USER_SYS_GID  => $self->{'admin_sys_gid'},
            USERNAME      => $self->{'admin_name'},
            PASSWORD_HASH => $self->{'admin_pass'},
            USER          => $usergroup,
            GROUP         => $usergroup
        }
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
