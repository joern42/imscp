=head1 NAME

 iMSCP::Modules::FtpUser - Module for processing of ftp user entities

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

package iMSCP::Modules::FtpUser;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of ftp user entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'FtpUser';
}

=item add()

 Add, change or enable the ftp user

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval { $self->SUPER::add(); };
    $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@ || 'ok', $self->{'userid'} );
    $self;
}

=item delete()

 Delete the ftp user

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval { $self->SUPER::delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@, $self->{'userid'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM ftp_users WHERE userid = ?', undef, $self->{'userid'} );
    $self;
}

=item disable()

 Disable the ftp user

 Return self, die on failure

=cut

sub disable
{
    my ($self) = @_;

    eval { $self->SUPER::disable(); };
    $self->{'_dbh'}->do( 'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $@ || 'disabled', $self->{'userid'} );
    $self;
}

=item handleEntity( $userid )

 Handle the given ftp user entity

 Param int $userid Ftp user unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $userid) = @_;

    $self->_loadData( $userid );

    if ( $self->{'status'} =~ /^to(?:add|change|enable)$/ ) {
        $self->add();
    } elsif ( $self->{'status'} eq 'todisable' ) {
        $self->disable();
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $self->delete();
    } else {
        die( sprintf( 'Unknown action (%s) for ftp user (ID %d)', $self->{'status'}, $userid ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $ftpUserId )

 Load data

 Param int $ftpUserId Ftp user unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $ftpUserId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref( 'SELECT * FROM ftp_users WHERE userid = ?', undef, $ftpUserId );
    $row or die( sprintf( 'Data not found for ftp user (ID %d)', $ftpUserId ));
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
        ACTION         => $action,
        STATUS         => $self->{'status'},
        OWNER_ID       => $self->{'admin_id'},
        USERNAME       => $self->{'userid'},
        PASSWORD_CRYPT => $self->{'passwd'},
        PASSWORD_CLEAR => $self->{'rawpasswd'},
        SHELL          => $self->{'shell'},
        HOMEDIR        => $self->{'homedir'},
        USER_SYS_GID   => $self->{'uid'},
        USER_SYS_GID   => $self->{'gid'},
        USER_SYS_NAME  => $usergroup,
        USER_SYS_GNAME => $usergroup
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
