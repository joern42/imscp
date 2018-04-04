=head1 NAME

 iMSCP::Packages::Setup::AntiRootkits - i-MSCP AntiRootkits package

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

package iMSCP::Packages::Setup::AntiRootkits;

use strict;
use warnings;
use File::Basename qw/ dirname /;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use parent 'iMSCP::Packages::AbstractCollection';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP AntiRootkits package.

 Handles AntiRootkits packages.

=head1 CLASS METHODS

=over 4

=back

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Packages::AbstractCollection::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my @distroPackages = ();
    for my $package ( @{ $self->{'AVAILABLE_PACKAGES'} } ) {
        next if grep $package eq $_, @{ $self->{'SELECTED_PACKAGES'} };
        $package = "iMSCP::Packages::Setup::AntiRootkits::${package}";
        eval "require $package" or die( $@ );

        debug( sprintf( 'Executing uninstall action on %s', $package ));
        $package->getInstance()->uninstall();

        debug( sprintf( 'Executing getDistroPackages action on %s', $package ));
        push @distroPackages, $package->getInstance()->getDistroPackages();
    }

    $self->_uninstallPackages( @distroPackages );

    @distroPackages = ();
    for ( $self->getCollection() ) {
        debug( sprintf( 'Executing preinstall action on %s', ref $_ ));
        $_->preinstall();

        debug( sprintf( 'Executing getDistroPackages action on %s', ref $_ ));
        push @distroPackages, $_->getDistroPackages();
    }

    $self->_installPackages( @distroPackages );
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'AntiRootkits';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'i-MSCP AntiRootkits packages (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $self->getPackageImplVersion();
}

=item getCollection()

 See iMSCP::Packages::AbstractCollection::getCollection()

=cut

sub getCollection
{
    my ( $self ) = @_;

    @{ $self->{'_package_instances'} } = sort { $b->getPackagePriority() <=> $a->getPackagePriority() } map {
        my $package = "iMSCP::Packages::Setup::@{ [ $self->getPackageName() ] }::${_}";
        eval "require $package; 1" or die( $@ );
        $package->getInstance();
    } @{ $self->{'SELECTED_PACKAGES'} } unless $self->{'_package_instances'};
    @{ $self->{'_package_instances'} };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadAvailablePackages()

 See iMSCP::Packages::AbstractCollection::_loadAvailablePackages()

=cut

sub _loadAvailablePackages
{
    my ( $self ) = @_;

    s/\.pm$// for @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new( dirname => dirname( __FILE__ ) . '/' . $self->getPackageName())->getFiles();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
