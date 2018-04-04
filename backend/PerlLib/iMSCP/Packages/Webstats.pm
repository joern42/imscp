=head1 NAME

 iMSCP::Packages::Webstats - i-MSCP Webstats package

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

package iMSCP::Packages::Webstats;

use strict;
use warnings;
use iMSCP::Debug qw/ debug /;
use parent 'iMSCP::Packages::AbstractCollection';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP Webstats package.

 Handles Webstats packages.

=head1 PUBLIC METHODS

=over 4

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Webstats';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    'i-MSCP Webstats packages';
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $self->getPackageImplVersion();
}

=item addUser( \%moduleData )

 Process addUser tasks

 Param hashref \%moduleData Data as provided by User module
 Return void, die on failure

=cut

sub addUserDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing addUser action on %s', ref $_ ));
        $_->addUser( $moduleData );
    }
}

=item preaddDomain( \%moduleData )

 Process preaddDomain tasks

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return int 0 on success, other on failure

=cut

sub preaddDomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing preaddDomain action on %s', ref $_ ));
        $_->preaddDomain( $moduleData );
    }
}

=item addDomain( \%moduleData )

 Process addDomain tasks

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return void, die on failure

=cut

sub addDomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing addDomain action on %s', ref $_ ));
        $_->addDomain( $moduleData );
    }
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return void, die on failure

=cut

sub deleteDomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing deleteDomain action on %s', ref $_ ));
        $_->deleteDomain( $moduleData );
    }
}

=item preaddSubdomain(\%moduleData)

 Process preaddSubdomain tasks

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return void, die on failure

=cut

sub preaddSubdomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing preaddSubdomain action on %s', ref $_ ));
        $_->preaddSubdomain( $moduleData );
    }
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return void, die on failure

=cut

sub addSubdomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing addSubdomain action on %s', ref $_ ));
        $_->addSubdomain( $moduleData );
    }
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return void, die on failure

=cut

sub deleteSubdomainDisabled
{
    my ( $self, $moduleData ) = @_;

    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing deleteSubdomain action on %s', ref $_ ));
        $_->deleteSubdomain( $moduleData );
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
