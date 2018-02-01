=head1 NAME

 iMSCP::Modules::Abstract - Base class for i-MSCP modules

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

package iMSCP::Modules::Abstract;

use strict;
use warnings;
use iMSCP::Database;
use iMSCP::Debug qw/ debug /;
use iMSCP::EventManager;
use iMSCP::Packages;
use iMSCP::Servers;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 i-MSCP modules abstract class.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    my ($self) = @_;

    die( sprintf( 'The %s module must implements the getEntityType( ) method', ref $self ));
}

=item handleEntity( )

 Handle the given entity according its current status

 Return void, die on failure

=cut

sub handleEntity
{
    my ($self) = @_;

    die( sprintf( 'The %s module must implements the handleEntity( ) method', ref $self ));
}

=item add( )

 Execute the `add' action on servers, packages

 Should be executed for entities with 'toadd|tochange|toenable' status.

 Return void, die on failure

=cut

sub add
{
    $_[0]->_execAllActions( 'add' );
}

=item delete( )

 Execute the `delete' action on servers, packages

 Should be executed for entities with 'todelete' status.

 Return void, die on failure

=cut

sub delete
{
    $_[0]->_execAllActions( 'delete' );
}

=item restore( )

 Execute the `restore' action on servers, packages

 Should be executed for entities with 'torestore' status.

 Return void, die on failure

=cut

sub restore
{
    $_[0]->_execAllActions( 'restore' );
}

=item disable( )

 Execute the `disable' action on servers, packages

 Should be executed for entities with 'todisable' status.

 Return void, die on failure

=cut

sub disable
{
    $_[0]->_execAllActions( 'disable' );
}

=back

=head1 PRIVATES METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Modules::Abstract, die on failure

=cut

sub _init
{
    my ($self) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'_dbh'} = iMSCP::Database->getInstance();
    $self->{'_data'} = {};
    $self;
}

=item _execAction( $action, $pkgType )

 Execute the given action on all $pkgType that implement it

 Param string $action Action to execute on servers, packages (<pre|post><action><moduleType>)
 Param string $pkgType Package type (server|package)
 Return void, die on failure

=cut

sub _execAction
{
    my ($self, $action, $pkgType) = @_;

    my $moduleData = $self->_getData();

    if ( $pkgType eq 'server' ) {
        debug( sprintf( "Executing the %s action on i-MSCP servers...", $action ));
        $_->factory()->$action( $moduleData ) for iMSCP::Servers->getInstance()->getListWithFullNames();
        return;
    }

    debug( sprintf( "Executing the %s action on i-MSCP packages...", $action ));

    for ( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
        ( my $subref = $_->can( $action ) ) or next;
        $subref->( $_->getInstance( eventManager => $self->{'eventManager'} ), $moduleData );
    }
}

=item _execAllActions( $action )

 Execute the pre$action, $action, post$action action on servers and packages

 Param string $action Action to execute on servers, packages (add|delete|restore|disable)
 Return void, die on failure

=cut

sub _execAllActions
{
    my ($self, $action) = @_;

    my $entityType = $self->getEntityType();

    if ( $action =~ /^(?:add|restore)$/ ) {
        for my $actionPrefix( 'pre', '', 'post' ) {
            $self->_execAction( "$actionPrefix$action$entityType", 'server' );
            $self->_execAction( "$actionPrefix$action$entityType", 'package' );
        }

        return;
    }

    for my $actionPrefix( 'pre', '', 'post' ) {
        $self->_execAction( "$actionPrefix$action$entityType", 'package' );
        $self->_execAction( "$actionPrefix$action$entityType", 'server' );
    }
}

=item _getData( $action )

 Data provider method for i-MSCP servers and packages

 Param string $action Action being executed (<pre|post><action><entityType>) on servers, packages
 Return hashref Reference to a hash containing data, die on failure

=cut

sub _getData
{
    $_[0]->{'_data'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
