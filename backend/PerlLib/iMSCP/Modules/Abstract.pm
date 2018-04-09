=head1 NAME

 iMSCP::Modules::Abstract - Abstract implementation for i-MSCP modules

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
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Abstract implementation for i-MSCP modules.

=head1 PUBLIC METHODS

=over 4

=item getModulePriority( )

 Get module priority

 Not used yet. Will be when the modules responsibility will be extended:
  Installer -- *Modules -- *Servers -- *InstallationRoutines
  Installer -- *Servers -- *InstallationRoutines (current)

 Return int Module priority

=cut

sub getModulePriority
{
    my ( $self ) = @_;

    0;
}

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    my ( $self ) = @_;

    die( sprintf( 'The %s module must implements the getEntityType() method', ref $self ));
}

=item handleEntity( )

 Handle the given entity according its current status

 Return void, die on failure

=cut

sub handleEntity
{
    my ( $self ) = @_;

    die( sprintf( 'The %s module must implements the handleEntity() method', ref $self ));
}

=back

=head1 PRIVATES METHODS

=over 4

=item _init( )

 See iMSCP::Common::Singleton::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'_dbh'} = iMSCP::Database->getInstance();
    $self->{'_data'} = {};
    $self;
}

=item _loadEntityData( $entityId )

 Load entity data
 
 Data must be loaded into the '_data' property.

 Param int $entityId Entity unique identifier
 Return void, die on failure

=cut

sub _loadEntityData
{
    my ( $self ) = @_;

    die( sprintf( 'The %s module must implements the _loadEntityData( ) method', ref $self ));
}

=item _getEntityData( $action )

 Return entity data for i-MSCP servers and packages

 Param string $action Action being executed <pre|post>?<action><entityType> on servers and packages
 Return hashref Reference to a hash containing entity data, die on failure

=cut

sub _getEntityData
{
    my ( $self, $action ) = @_;

    $self->{'_data'}->{'ACTION'} = $action;
    $self->{'_data'};
}

=item _add( )

 Execute the 'add' action on servers, packages

 Return void, die on failure

=cut

sub _add
{
    $_[0]->_execActions( 'add' );
}

=item delete( )

 Execute the 'delete' action on servers, packages

 Return void, die on failure

=cut

sub _delete
{
    $_[0]->_execActions( 'delete' );
}

=item restore( )

 Execute the 'restore' action on servers, packages

 Return void, die on failure

=cut

sub _restore
{
    $_[0]->_execActions( 'restore' );
}

=item disable( )

 Execute the 'disable' action on servers, packages

 Return void, die on failure

=cut

sub _disable
{
    $_[0]->_execActions( 'disable' );
}

=item _execActions( $action )

 Execute the pre$action, $action and post$action actions on servers and packages

 Param string $action Action to execute on servers and packages
 Return void, die on failure

=cut

sub _execActions
{
    my ( $self, $action ) = @_;

    my $entityType = $self->getEntityType();

    if ( $action =~ /^(?:add|restore)$/ ) {
        for ( 'pre', '', 'post' ) {
            my $method = "$_$action$entityType";
            my $moduleData = $self->_getEntityData( $method );

            debug( sprintf( 'Executing %s action on i-MSCP servers...', $method ));
            $_->factory()->$method( $moduleData ) for iMSCP::Servers->getInstance()->getList();

            debug( sprintf( 'Executing %s action on i-MSCP packages...', $method ));
            $_->getInstance()->$method( $moduleData ) for iMSCP::Packages->getInstance()->getList();
        }

        return;
    }

    for ( 'pre', '', 'post' ) {
        my $method = "$_$action$entityType";
        my $moduleData = $self->_getEntityData( $method );

        debug( sprintf( 'Executing %s action on i-MSCP packages...', $method ));
        $_->getInstance()->$method( $moduleData ) for iMSCP::Packages->getInstance()->getList();

        debug( sprintf( 'Executing %s action on i-MSCP servers...', $method ));
        $_->factory()->$method( $moduleData ) for iMSCP::Servers->getInstance()->getList();
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
