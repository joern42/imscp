=head1 NAME

 iMSCP::Packages - Library for loading and retrieval of i-MSCP packages

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

package iMSCP::Packages;

use strict;
use warnings;
use File::Basename qw/ dirname /;
use iMSCP::Cwd;
use iMSCP::Getopt;
use parent 'Common::SingletonClass';

# Only for BC reasons with 3rd-party such as plugins
#use Package::Alias 'Package::FrontEnd', 'Package::Installer::FrontEnd';

=head1 DESCRIPTION

 Library for loading and retrieval of i-MSCP packages.

=head1 PUBLIC METHODS

=over 4

=item getList( )

 Get list of packages sorted in descending order of priority

 Return list of packages

=cut

sub getList
{
    @{ $_[0]->{'_packages'} };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance
 
 Return iMSCP::Packages

=cut

sub _init
{
    my ( $self ) = @_;

    local $CWD = dirname( __FILE__ ) . '/../Package';

    s%(.*)\.pm$%iMSCP::Package::$1% for @{ $self->{'_packages'} } = grep !/^Abstract(?:Collection)?\.pm$/, <*.pm>;

    # In installer/uninstaller contexts, also load setup packages
    if ( grep ( $_ eq iMSCP::Getopt->context(), 'installer', 'uninstaller' ) ) {
        local $CWD = $CWD . '/Installer';
        push @{ $self->{'_packages'} }, map { s%(.*)\.pm$%iMSCP::Package::Installer::$1%r } <*.pm>;
    }

    eval "require $_; 1" or die( sprintf( "Couldn't load the '%s' package: %s", $_, $@ )) for @{ $self->{'_packages'} };
    @{ $self->{'_packages'} } = sort { $b->getPriority() <=> $a->getPriority() } grep $_->checkRequirements(), @{ $self->{'_packages'} };
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
