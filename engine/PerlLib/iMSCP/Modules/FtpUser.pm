=head1 NAME

 iMSCP::Modules::FtpUser - i-MSCP FtpUser module

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
use iMSCP::Boolean;
use iMSCP::Debug qw/ error getLastError warning /;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 i-MSCP FtpUser module.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 See iMSCP::Modules::Abstract::getType()

=cut

sub getType
{
    my ( $self ) = @_;

    'FtpUser';
}

=item process( $ftpUserId )

 See iMSCP::Modules::Abstract::process()

=cut

sub process
{
    my ( $self, $ftpUserId ) = @_;

    my $rs = $self->_loadData( $ftpUserId );
    return $rs if $rs;

    my @sql;
    if ( grep ( $self->{'status'} eq $_, 'toadd', 'tochange', 'toenable' ) ) {
        $rs = $self->add();
        @sql = (
            'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $rs ? getLastError( 'error' ) || 'Unknown error' : 'ok', $ftpUserId
        );
    } elsif ( $self->{'status'} eq 'todisable' ) {
        $rs = $self->disable();
        @sql = (
            'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, $rs ? getLastError( 'error' ) || 'Unknown error' : 'disabled', $ftpUserId
        );
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $rs = $self->delete();
        @sql = $rs ? (
            'UPDATE ftp_users SET status = ? WHERE userid = ?', undef, getLastError( 'error' ) || 'Unknown error', $ftpUserId
        ) : (
            'DELETE FROM ftp_users WHERE userid = ?', undef, $ftpUserId
        );
    } else {
        warning( sprintf( 'Unknown action (%s) for ftp user (ID %d)', $self->{'status'}, $ftpUserId ));
        return 0;
    }

    local $self->{'dbh'}->{'RaiseError'} = TRUE;
    $self->{'dbh'}->do( @sql );
    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $ftpUserId )

 Load data

 Param int $ftpUserId Ftp user unique identifier
 Return int 0 on success, other on failure

=cut

sub _loadData
{
    my ( $self, $ftpUserId ) = @_;

    local $self->{'dbh'}->{'RaiseError'} = TRUE;
    my $row = $self->{'dbh'}->selectrow_hashref( 'SELECT * FROM ftp_users WHERE userid = ?', undef, $ftpUserId );
    $row or die( sprintf( 'Data not found for ftp user (ID %d)', $ftpUserId ));
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
        my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'admin_id'} );

        {
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
        }
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
