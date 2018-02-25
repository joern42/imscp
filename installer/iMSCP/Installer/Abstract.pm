=head1 NAME

 iMSCP::Installer::Abstract - i-MSCP instraller abstract implementation

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

package iMSCP::Installer::Abstract;

use strict;
use warnings;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Abstract class for i-MSCP installer.

=head1 PUBLIC METHODS

=over 4

=item preBuild( \@steps )

 Process preBuild tasks

 Param array \@steps List of build steps
 Return void, die on failure

=cut

sub preBuild
{
    my ($self) = @_;
}

=item installPackages( )

 Install distribution packages

 Return void, die on failure

=cut

sub installPackages
{
    my ($self) = @_;
}

=item uninstallPackages( )

 Uninstall distribution packages no longer needed

 Return void, die on failure

=cut

sub uninstallPackages
{
    my ($self) = @_;
}

=item postBuild( )

 Process postBuild tasks

 Return void, die on failure

=cut

sub postBuild
{
    my ($self) = @_;
}

=item preInstall( \@steps )

 Process preInstall tasks

 Param array \@steps List of install steps
 Return void, die on failure

=cut

sub preInstall
{
    my ($self) = @_;
}

=item postInstall( )

 Process postInstall tasks

 Return void, die on failure

=cut

sub postInstall()
{
    my ($self) = @_;
}

=back

=head1 Author

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
