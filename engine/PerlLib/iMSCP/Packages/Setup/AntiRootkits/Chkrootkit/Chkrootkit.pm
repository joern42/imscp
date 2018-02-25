=head1 NAME

 iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Chkrootkit - i-MSCP Chkrootkit package

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

package iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Chkrootkit;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Installer iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Uninstaller /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP Chkrootkit package.

 The chkrootkit security scanner searches the local system for signs that it is infected with a 'rootkit'. Rootkits are
 set of programs and hacks designed to take control of a target machine by using known security flaws.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ($self) = @_;

    iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Installer->getInstance( eventManager => $self->{'eventManager'} )->preinstall();
}

=item postinstall( )

 Process post install tasks

 Return void, die on failure

=cut

sub postinstall
{
    my ($self) = @_;

    iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Installer->getInstance( eventManager => $self->{'eventManager'} )->postinstall();
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ($self) = @_;

    iMSCP::Packages::Setup::AntiRootkits::Chkrootkit::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
}

=item setEnginePermissions( )

 Set engine permissions

 Return void, die on failure

=cut

sub setEnginePermissions
{
    setRights( $::imscpConfig{'CHKROOTKIT_LOG'},
        {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'IMSCP_GROUP'},
            mode  => '0640'
        }
    );
}

=item getDistroPackages( )

 Get list of Debian packages

 Return list List of packages

=cut

sub getDistroPackages
{
    'chkrootkit';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
