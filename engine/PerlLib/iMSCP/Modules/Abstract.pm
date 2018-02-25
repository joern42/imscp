=head1 NAME

 iMSCP::Modules::Abstract - Base class for i-MSCP modules

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

package iMSCP::Modules::Abstract;

use strict;
use warnings;
use iMSCP::Database;
use iMSCP::Debug qw/ debug /;
use iMSCP::EventManager;
use iMSCP::Packages;
use iMSCP::Servers;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP modules abstract class.

=head1 PUBLIC METHODS

=over 4

=item getPriority( )

 Get module priority

 Not used yet. Will be when the modules responsibility will be extended:
  Installer -- *Modules -- *Servers -- *InstallationRoutines
  Installer -- *Servers -- *InstallationRoutines (current)

 Return int module priority

=cut

sub getPriority
{
    my ($self) = @_;

    0;
}

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

=back

=head1 PRIVATES METHODS

=over 4

=item _init( )

 See iMSCP::Common::Object::_init()

=cut

sub _init
{
    my ($self) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'_dbh'} = iMSCP::Database->getInstance();
    $self->{'_data'} = {};
    $self;
}

=item _loadEntityData( $entityId )

 Load entity data
 
 Data must be loaded into the '_data' attribute.

 Param int $entityId Entity unique identifier
 Return void

=cut

sub _loadEntityData
{
    my ($self) = @_;

    die( sprintf( 'The %s module must implements the _loadEntityData( ) method', ref $self ));
}

=item _getEntityData( $action )

 Return entity data for i-MSCP servers and packages

 Param string $action Action being executed <pre|post>?<action><entityType> on servers/packages
 Return hashref Reference to a hash containing data, die on failure

=cut

sub _getEntityData
{
    my ($self, $action) = @_;

    $self->{'_data'}->{'action'} = $action;
    $self->{'_data'};
}

=item _add( )

 Execute the 'add' action on servers, packages

 Should be executed for entities with 'toadd|tochange|toenable' status.

 Return void, die on failure

=cut

sub _add
{
    $_[0]->_execActions( 'add' );
}

=item delete( )

 Execute the 'delete' action on servers, packages

 Should be executed for entities with 'todelete' status.

 Return void, die on failure

=cut

sub _delete
{
    $_[0]->_execActions( 'delete' );
}

=item restore( )

 Execute the 'restore' action on servers, packages

 Should be executed for entities with 'torestore' status.

 Return void, die on failure

=cut

sub _restore
{
    $_[0]->_execActions( 'restore' );
}

=item disable( )

 Execute the 'disable' action on servers, packages

 Should be executed for entities with 'todisable' status.

 Return void, die on failure

=cut

sub _disable
{
    $_[0]->_execActions( 'disable' );
}

=item _execActions( $action )

 Execute the pre$action, $action, post$action action on servers and packages

 Param string $action Action to execute on servers, packages (add|delete|restore|disable)
 Return void, die on failure

=cut

sub _execActions
{
    my ($self, $action) = @_;

    my $entityType = $self->getEntityType();

    if ( $action =~ /^(?:add|restore)$/ ) {
        for my $actionPrefix( 'pre', '', 'post' ) {
            my $method = "$actionPrefix$action$entityType";
            my $moduleData = $self->_getModuleData( $method );

            debug( sprintf( "Executing %s action on i-MSCP servers...", $method ));
            $_->factory()->$method( $self ) for iMSCP::Servers->getInstance()->getListWithFullNames();

            debug( sprintf( "Executing %s action on i-MSCP packages...", $method ));
            for my $package( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
                ( my $subref = $package->can( $method ) ) or next;
                $subref->( $package->getInstance( eventManager => $self->{'eventManager'} ), $moduleData );
            }
        }

        return;
    }

    for my $actionPrefix( 'pre', '', 'post' ) {
        my $method = "$actionPrefix$action$entityType";
        my $moduleData = $self->_getModuleData( $method );

        debug( sprintf( "Executing %s action on i-MSCP packages...", $method ));
        for my $package( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
            ( my $subref = $package->can( $method ) ) or next;
            $subref->( $package->getInstance( eventManager => $self->{'eventManager'} ), $moduleData );
        }

        debug( sprintf( "Executing %s action on i-MSCP servers...", $method ));
        for my $server( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
            $server->factory()->$method( $moduleData );
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
