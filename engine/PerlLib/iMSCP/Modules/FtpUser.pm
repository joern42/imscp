=head1 NAME

 iMSCP::Modules::FtpUser - Module for processing of ftp user entities

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

package iMSCP::Modules::FtpUser;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of ftp user entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'FtpUser';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    if ( $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change|enable)$/ ) {
        $self->_add();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todisable' ) {
        $self->_disable();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todelete' ) {
        $self->_delete();
    } else {
        die( sprintf( 'Unknown action (%s) for ftp user (ID %s)', $self->{'_data'}->{'STATUS'}, $entityId ));
    }
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

    my $row = $self->{'_dbh'}->selectrow_hashref( 'SELECT * FROM ftp_users WHERE userid = ?', undef, $entityId );
    $row or die( sprintf( 'Data not found for ftp user (ID %d)', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'admin_id'} );

    $self->{'_data'} = {
        STATUS         => $row->{'status'},
        OWNER_ID       => $row->{'admin_id'},
        USERNAME       => $row->{'userid'},
        PASSWORD_CRYPT => $row->{'passwd'},
        PASSWORD_CLEAR => $row->{'rawpasswd'},
        SHELL          => $row->{'shell'},
        HOMEDIR        => $row->{'homedir'},
        USER_SYS_GID   => $row->{'uid'},
        USER_SYS_GID   => $row->{'gid'},
        USER_SYS_NAME  => $usergroup,
        USER_SYS_GNAME => $usergroup
    };
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@ || 'ok', $self->{'_data'}->{'USERNAME'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@, $self->{'_data'}->{'USERNAME'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM ftp_users WHERE userid = ?', undef, $self->{'_data'}->{'USERNAME'} );
}

=item _disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ( $self ) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@ || 'disabled', $self->{'_data'}->{'USERNAME'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
