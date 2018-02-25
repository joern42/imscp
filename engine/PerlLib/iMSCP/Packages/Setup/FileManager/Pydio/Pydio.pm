=head1 NAME

 iMSCP::Packages::Setup::FileManager::Pydio::Pydio - i-MSCP Pydio package

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

package iMSCP::Packages::Setup::FileManager::Pydio::Pydio;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::Packages::Setup::FileManager::Pydio::Installer iMSCP::Packages::Setup::FileManager::Pydio::Uninstaller /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP Pydio package.

 Pydio ( formely AjaXplorer ) is a software that can turn any web server into a powerfull file management system and an
 alternative to mainstream cloud storage providers.

 Project homepage: https://pyd.io/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ($self) = @_;

    iMSCP::Packages::Setup::FileManager::Pydio::Installer->getInstance( eventManager => $self->{'eventManager'} )->preinstall();
}

=item install( )

 Process install tasks

 Return void, die on failure

=cut

sub install
{
    my ($self) = @_;

    iMSCP::Packages::Setup::FileManager::Pydio::Installer->getInstance( eventManager => $self->{'eventManager'} )->install();
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ($self) = @_;

    iMSCP::Packages::Setup::FileManager::Pydio::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
