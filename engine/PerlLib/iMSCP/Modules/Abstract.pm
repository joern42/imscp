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
    die( ref( $_[0] ) . ' module must implements the getEntityType( ) method' );
}

=item process( )

 Process an entity according to its current state

 Return int 0 on success, other on failure

=cut

sub process
{
    die( ref( $_[0] ) . ' module must implements the process( ) method' );
}

=item add( )

 Execute the `add' action on servers, packages

 Should be executed for items with 'toadd|tochange|toenable' status.

 Return int 0 on success, other on failure

=cut

sub add
{
    $_[0]->_execAllActions( 'add' );
}

=item delete( )

 Execute the `delete' action on servers, packages

 Should be executed for items with 'todelete' status.

 Return int 0 on success, other on failure

=cut

sub delete
{
    $_[0]->_execAllActions( 'delete' );
}

=item restore( )

 Execute the `restore' action on servers, packages

 Should be executed for items with 'torestore' status.

 Return int 0 on success, other on failure

=cut

sub restore
{
    $_[0]->_execAllActions( 'restore' );
}

=item disable( )

 Execute the `disable' action on servers, packages

 Should be executed for items with 'todisable' status.

 Return int 0 on success, other on failure

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

 Return iMSCP::Modules::Abstract

=cut

sub _init
{
    my ($self) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'_dbh'} = iMSCP::Database->getInstance()->getRawDb();
    $self->{'_data'} = {};
    $self;
}

=item _execAction( $action, $pkgType )

 Execute the given $action on all $pkgType that implement it

 Param string $action Action to execute on servers, packages (<pre|post><action><moduleType>)
 Param string $pkgType Package type (server|package)
 Return int 0 on success, other on failure

=cut

sub _execAction
{
    my ($self, $action, $pkgType) = @_;

    my $moduleData = $self->_getData();

    if ( $pkgType eq 'server' ) {
        debug( sprintf( "Executing the `%s' action on i-MSCP servers...", $action ));

        for ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
            my $rs = $_->factory()->$action( $moduleData );
            return $rs if $rs;
        }

        return 0;
    }

    debug( sprintf( "Executing the `%s' action on i-MSCP packages...", $action ));

    for ( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
        ( my $subref = $_->can( $action ) ) or next;
        my $rs = $subref->( $_->getInstance( eventManager => $self->{'eventManager'} ), $moduleData );
        return $rs if $rs;
    }

    0;
}

=item _execAllActions( $action )

 Execute pre$action, $action, post$action on servers, packages

 Param string $action Action to execute on servers, packages (add|delete|restore|disable)
 Return int 0 on success, other on failure

=cut

sub _execAllActions
{
    my ($self, $action) = @_;

    my $entityType = $self->getEntityType();

    if ( $action =~ /^(?:add|restore)$/ ) {
        for my $actionPrefix( 'pre', '', 'post' ) {
            for ( qw / server package / ) {
                my $rs = $self->_execAction( "$actionPrefix$action$entityType", $_ );
                return $rs if $rs;
            }
        }

        return 0;
    }

    for my $actionPrefix( 'pre', '', 'post' ) {
        for ( qw / package server / ) {
            my $rs = $self->_execAction( "$actionPrefix$action$entityType", $_ );
            return $rs if $rs;
        }
    }

    0;
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
