=head1 NAME

 iMSCP::Modules::Mail - Module for processing of mail user entities

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

package iMSCP::Modules::Mail;

use strict;
use warnings;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of mail user entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Mail';
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
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todelete' ) {
        $self->_delete();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todisable' ) {
        $self->_disable();
    } else {
        die( sprintf( 'Unknown action (%s) for mail user (ID %d)', $self->{'_data'}->{'STATUS'}, $entityId ));
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
        'SELECT mail_id, mail_acc, mail_pass, mail_forward, mail_type, mail_auto_respond, status, quota, mail_addr FROM mail_users WHERE mail_id = ?',
        undef,
        $entityId
    );
    $row or die( sprintf( 'Data not found for mail user (ID %d)', $entityId ));

    my ( $user, $domain ) = split '@', $row->{'mail_addr'};

    $self->{'_data'} = {
        STATUS                  => $row->{'status'},
        DOMAIN_NAME             => $domain,
        MAIL_ID                 => $row->{'mail_id'},
        MAIL_ACC                => $user,
        MAIL_PASS               => $row->{'mail_pass'},
        MAIL_FORWARD            => $row->{'mail_forward'},
        MAIL_TYPE               => $row->{'mail_type'},
        MAIL_QUOTA              => $row->{'quota'},
        MAIL_HAS_AUTO_RESPONDER => $row->{'mail_auto_respond'},
        MAIL_STATUS             => $row->{'status'},
        MAIL_ADDR               => $row->{'mail_addr'},
        MAIL_CATCHALL           => index( $row->{'mail_type'}, 'catchall' ) != -1 ? $row->{'mail_acc'} : undef
    };
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'MAIL_ID'} );
}

=item delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@, $self->{'_data'}->{'MAIL_ID'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM mail_users WHERE mail_id = ?', undef, $self->{'_data'}->{'MAIL_ID'} );
}

=item disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ( $self ) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do( 'UPDATE mail_users SET status = ? WHERE mail_id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'MAIL_ID'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
