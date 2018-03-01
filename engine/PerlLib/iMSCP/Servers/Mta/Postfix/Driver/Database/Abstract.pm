=head1 NAME

 iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract - i-MSCP abstract class for Postfix database drivers

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

package iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract;

use strict;
use warnings;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 i-MSCP abstract class for Postfix database drivers

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Perform pre-installation tasks 

 This method *SHOULD* be implemented by any database driver requiring
 pre-installation tasks.

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;
}

=item install( )

 Perform installation tasks

 This method *SHOULD* be implemented by any database driver requiring
 installation tasks.

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;
}

=item postinstall( )

 Perform post-installation tasks

 This method *SHOULD* be implemented by any database driver requiring
 post-installation tasks.

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;
}

=item uninstall( )

 Perform uninstallation tasks

 This method *SHOULD* be implemented by any database driver requiring
 uninstallation tasks.

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;
}

=item setEnginePermissions( )

 Set engine permissions

 This method *SHOULD* be implemented by any database driver requiring
 specific file permissions.

 Return void, die on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;
}

=item add( $database [, $key [, $value = 'OK' [, $storagePath = $self->{'mta'}->{'config'}->{'MTA_DB_DIR'} ] ] ] )

 Add the given entry into the given database

 Without $key passed-in, the database *SHOULD* be created.
 
 This method *MUST* be implemented by any database driver that rely on files.

 Param string $database Database name
 Param string $key OPTIONAL Database entry key
 Param string $value OPTIONAL Database entry value
 Param string $storagePath OPTIONAL Storage path
 Return self, die on failure

=cut

sub add
{
    my ( $self ) = @_;

    $self;
}

=item delete( $database [, $key [, $storagePath = $self->{'mta'}->{'config'}->{'MTA_DB_DIR'} ] ] )

 Delete the given entry from the given database
 
 Without $key passed-in, the database *SHOULD* be deleted.
 
 This method *MUST* be implemented by any database driver that rely on files

 Param string database Database name
 Param string $key OPTIONAL Database entry key
 Param string $storagePath OPTIONAL Storage path
 Return self, die on failure

=cut

sub delete
{
    my ( $self ) = @_;

    $self;
}

=item getDbType( )

 Return Database type supported by this driver

 Return string

=cut

sub getDbType
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getDbType() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::Object

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));
    $self->SUPER::_init();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
