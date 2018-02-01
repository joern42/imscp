=head1 NAME

 iMSCP::Modules::Mail - Module for processing of mail user entities

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

package iMSCP::Modules::Mail;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of mail user entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'Mail';
}

=item add()

 Add, change or enable the mail user

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval { $self->SUPER::add(); };
    $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@ || 'ok', $self->{'mail_id'} );
    $self;
}

=item delete()

 Delete the mail user

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval { $self->SUPER::delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@, $self->{'mail_id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM mail_users WHERE mail_id = ?', undef, $self->{'mail_id'} );
    $self;
}

=item disable()

 Disable the mail user

 Return self, die on failure

=cut

sub disable
{
    my ($self) = @_;

    eval { $self->SUPER::disable(); };
    $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@ || 'disabled', $self->{'mail_id'} );
    $self;
}

=item handleEntity( $mailUserId )

 Handle the given mail user entity

 Param int $mailUserId Mail user unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $mailId) = @_;

    $self->_loadData( $mailUserId );

    if ( $self->{'status'} =~ /^to(?:add|change|enable)$/ ) {
        $self->add();
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $self->delete();
    } elsif ( $self->{'status'} eq 'todisable' ) {
        $self->disable();
    } else {
        die( sprintf( 'Unknown action (%s) for mail user (ID %d)', $self->{'status'}, $mailId ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $mailUserId )

 Load data

 Param int $mailUserId Mail unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $mailUserId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        ' SELECT mail_id, mail_acc, mail_pass, mail_forward, mail_type, mail_auto_respond, status, quota, mail_addr FROM mail_users WHERE mail_id = ?',
        undef,
        $mailUserId
    );
    $row or die( sprintf( 'Data not found for mail user (ID %d)', $mailUserId ));
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

    my ($user, $domain) = split '@', $self->{'mail_addr'};

    $self->{'_data'} = {
        ACTION                  => $action,
        STATUS                  => $self->{'status'},
        DOMAIN_NAME             => $domain,
        MAIL_ACC                => $user,
        MAIL_PASS               => $self->{'mail_pass'},
        MAIL_FORWARD            => $self->{'mail_forward'},
        MAIL_TYPE               => $self->{'mail_type'},
        MAIL_QUOTA              => $self->{'quota'},
        MAIL_HAS_AUTO_RESPONDER => $self->{'mail_auto_respond'},
        MAIL_STATUS             => $self->{'status'},
        MAIL_ADDR               => $self->{'mail_addr'},
        MAIL_CATCHALL           => ( index( $self->{'mail_type'}, 'catchall' ) != -1 ) ? $self->{'mail_acc'} : undef
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
