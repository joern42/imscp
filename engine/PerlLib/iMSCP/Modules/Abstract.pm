=head1 NAME

 iMSCP::Modules::Abstract - Abstract class for i-MSCP modules

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
use Carp 'confess';
use iMSCP::Boolean;
use iMSCP::Database;
use iMSCP::Debug qw/ debug getMessageByType /;
use iMSCP::EventManager;
use iMSCP::Packages;
use iMSCP::Servers;
use parent 'Common::Object';

=head1 DESCRIPTION

 Abstract class for i-MSCP modules.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 Get module type

 Return string Module type

=cut

sub getType
{
    my ( $self ) = @_;

    confess( sprintf( 'The %s module must implement the getType() method ', ref $self ));
}

=item process( )

 Process add|delete|restore|disable action according item status.

 Return void, die on failure

=cut

sub process
{
    my ( $self ) = @_;

    confess( sprintf( 'The %s module must implement the process() method ', ref $self ));
}

=item add( )

 Execute the 'add' action on servers and packages

 Should be executed for entities with status 'toadd|tochange|toenable'.

 Return void, die on failure

=cut

sub add
{
    my ( $self ) = @_;

    $self->_executeActionOnServers( 'add' );
    $self->_executeActionOnPackages( 'add' );
}

=item delete( )

 Execute the 'delete' action on servers and packages

 Should be executed for entities with status 'todelete'.

 Return void, die on failure

=cut

sub delete
{
    my ( $self ) = @_;

    $self->_executeActionOnPackages( 'delete' );
    $self->_executeActionOnServers( 'delete' );
}

=item restore( )

 Execute the 'restore' action on servers, packages

 Should be executed for entities with status 'torestore'.

 Return void, die on failure

=cut

sub restore
{
    my ( $self ) = @_;

    $self->_executeActionOnServers( 'restore' );
    $self->_executeActionOnPackages( 'restore' );
}

=item disable( )

 Execute the 'disable' action on servers, packages

 Should be executed for entities with status 'todisable'.

 Return void, die on failure

=cut

sub disable
{
    my ( $self ) = @_;

    $self->_executeActionOnPackages( 'disable' );
    $self->_executeActionOnServers( 'disable' );
}

=back

=head1 PRIVATES METHODS

=over 4

=item _init( )

 See Common::SingletonClass::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or confess( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'dbh'} = iMSCP::Database->factory()->getRawDb();
    $self;
}

=item _executeActionOnServers( $moduleAction )

 Execute the given module action on i-MSCP server

 Param string $moduleAction Module action to execute on servers and packages
 Return void, die on failure

=cut

sub _executeActionOnServers
{
    my ( $self, $moduleAction ) = @_;

    my ( $moduleType, $moduleData ) = ( $self->getType(), $self->_getData( $moduleAction ) );

    for my $action ( "pre$moduleAction$moduleType", "$moduleAction$moduleType", "post$moduleAction$moduleType" ) {
        debug( sprintf( 'Executing the %s module action on i-MSCP servers...', $action ));
        for my $server ( iMSCP::Servers->getInstance()->getList() ) {
            $server->factory()->$action( $moduleData ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        }
    }
}

=item _executeActionOnPackages( $moduleAction )

 Execute the given module action on i-MSCP packages

 Param string $moduleAction Module action to execute on i-MSCP packages
 Return void, die on failure

=cut

sub _executeActionOnPackages
{
    my ( $self, $moduleAction ) = @_;

    my ( $moduleType, $moduleData ) = ( $self->getType(), $self->_getData( $moduleAction ) );

    for my $action ( "pre$moduleAction$moduleType", "$moduleAction$moduleType", "post$moduleAction$moduleType" ) {
        debug( sprintf( 'Executing the %s module action on i-MSCP packages...', $action ));
        for my $packages ( iMSCP::Packages->getInstance()->getList() ) {
            $packages->getInstance()->$action( $moduleData ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        }
    }
}

=item _getData( $action )

 Data provider method for i-MSCP servers and packages

 Param string $action Module action being executed (<add|delete|change|restore|enable|disable>) on servers, packages
 Return hashref Reference to a hash containing data, die on failure

=cut

sub _getData
{
    $_[0]->{'_data'} ||= {};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
