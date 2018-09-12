=head1 NAME

 iMSCP::Package::Installer::SqlManager - i-MSCP SqlManager package collection

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package iMSCP::Package::Installer::SqlManager;

use strict;
use warnings;
use iMSCP::Cwd '$CWD';
use parent 'iMSCP::Package::AbstractCollection';

=head1 DESCRIPTION

 i-MSCP FileManager package collection.

=head1 PUBLIC METHODS

=over 4

=item getType( )

 See iMSCP::Package::AbstractCollection::getType()

=cut

sub getType
{
    my ( $self ) = @_;

    'SqlManager';
}

=item getSelectedPackages( )

 See iMSCP::Package::AbstractCollection::getSelectedPackages()

=cut

sub getSelectedPackages
{
    my ( $self ) = @_;

    $self->{'SELECTED_PACKAGE_INSTANCES'} ||= do {
        [
            sort { $b->getPriority() <=> $a->getPriority() } map {
                my $package = "iMSCP::Package::Installer::@{ [ $self->getType() ] }::${_}";
                eval "require $package; 1" or die( sprintf( "Couldn't load the '%s' package: %s", $_, $@ ));
                $package->getInstance()
            } @{ $self->{'SELECTED_PACKAGES'} }
        ]
    };
}

=item getUnselectedPackages( )

 See iMSCP::Package::AbstractCollection::getUnselectedPackages()

=cut

sub getUnselectedPackages
{
    my ( $self ) = @_;

    $self->{'UNSELECTED_PACKAGE_INSTANCES'} ||= do {
        my @unselectedPackages;
        for my $package ( $self->{'AVAILABLE_PACKAGES'} ) {
            next if grep ( $package eq $_, @{ $self->{'SELECTED_PACKAGES'} } );
            push @unselectedPackages, $package;
        }

        [
            sort { $b->getPriority() <=> $a->getPriority() } map {
                my $package = "iMSCP::Package::Installer::@{ [ $self->getType() ] }::${_}";
                eval "require $package; 1" or die( sprintf( "Couldn't load the '%s' package: %s", $_, $@ ));
                $package->getInstance();
            } @unselectedPackages
        ]
    };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadAvailablePackages()

 Load list of available packages for this collection

 Return void, die on failure

=cut

sub _loadAvailablePackages
{
    my ( $self ) = @_;

    local $CWD = $::imscpConfig{'PACKAGES_DIR'} . '/Installer/' . $self->getType();
    s/\.pm$// for @{ $self->{'AVAILABLE_PACKAGES'} } = <*.pm>;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
