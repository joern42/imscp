=head1 NAME

 iMSCP::Package::Installer::PostfixAddon - i-MSCP Postfix addon package collection

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

package iMSCP::Package::Installer::PostfixAddon;

use strict;
use warnings;
use parent 'iMSCP::Package::AbstractCollection';

=head1 DESCRIPTION

 i-MSCP Postfix addon package collection.

=head1 CLASS METHODS

=over 4


=item checkRequirements

 See iMSCP::Package::Abstract::checkRequirements

=cut

sub checkRequirements
{
    my ( $class ) = @_;

    $::imscpConfig{'MTA_SERVER'} eq 'postfix';
}

=back

=head1 PUBLIC METHODS

=over 4

=item getType( )

 See iMSCP::Package::AbstractCollection::getType()

=cut

sub getType
{
    my ( $self ) = @_;

    'PostfixAddon';
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

=item _askForPackages( $dialog )

 See iMSCP::Package::AbstractCollection::_askForPackages()

=cut

sub _askForPackages
{
    my ( $self, $dialog ) = @_;

    my $packageType = $self->getType();
    my $ucPackageType = uc $packageType;

    @{ $self->{'SELECTED_PACKAGES'} } = split ',', ::setupGetQuestion( $ucPackageType . '_PACKAGES' );
    my %choices = map { $_ => ucfirst $_ } @{ $self->{'AVAILABLE_PACKAGES'} };

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ lc $packageType, 'all' ] ) || !@{ $self->{'SELECTED_PACKAGES'} }
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $self->{'SELECTED_PACKAGES'} }
    ) {
        ( my $rs, $self->{'SELECTED_PACKAGES'} ) = $dialog->checklist(
            <<"EOF", \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $self->{'SELECTED_PACKAGES'} } ] );

Please select the $packageType packages you want to install:

You shouldn't select one of the PolicydWeight, Postgrey or SPF package if you select the Rspamd package.
Instead you should select the counterpart Rspamd modules which are: RBL, Greylisting and SPF.
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $self->{'SELECTED_PACKAGES'} } = grep ( $_ ne 'none', @{ $self->{'SELECTED_PACKAGES'} } );
    ::setupSetQuestion( $ucPackageType . '_PACKAGES', @{ $self->{'SELECTED_PACKAGES'} } ? join( ',', @{ $self->{'SELECTED_PACKAGES'} } ) : 'none' );

    my $dialogs = [];
    for my $package ( @{ $self->getSelectedPackages() } ) {
        my $rs = $package->registerInstallerDialogs( $dialogs );
        return $rs if $rs;
    }

    $dialog->executeDialogs( $dialogs )
}

=item _loadAvailablePackages()

 Load list of available packages for this collection

 Return void, die on failure

=cut

sub _loadAvailablePackages
{
    my ( $self ) = @_;

    s/\.pm$// for @{ $self->{'AVAILABLE_PACKAGES'} } = iMSCP::Dir->new(
        dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Installer/" . $self->getType()
    )->getFiles();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
