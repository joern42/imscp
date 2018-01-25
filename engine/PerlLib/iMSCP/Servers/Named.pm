=head1 NAME

 iMSCP::Servers::Named - Factory and abstract implementation for the i-MSCP named servers

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

package iMSCP::Servers::Named;

use strict;
use warnings;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP named servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    300;
}

=back

=head1 PUBLIC METHODS

=over

=item addDomain( \%moduleData )

 Process addDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddDomain( \%moduleData )
  - after<SNAME>AddDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub addDomain
{
    my ($self) = @_;

    0;
}

=item postaddDomain( \%moduleData )

 Process postaddDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostAddDomain( \%moduleData )
  - after<SNAME>PostAddDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub postaddDomain
{
    my ($self) = @_;

    0;
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddDomain( \%moduleData )
  - after<SNAME>AddDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub disableDomain
{
    my ($self) = @_;

    0;
}

=item postdisableDomain( \%moduleData )

 Process postdisableDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostDisableDomain( \%moduleData )
  - after<SNAME>PostDisableDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub postdisableDomain
{
    my ($self) = @_;

    0;
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteDomain( \%moduleData )
  - after<SNAME>DeleteDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%data Domain data
 Return int 0 on success, other on failure

=cut

sub deleteDomain
{
    my ($self) = @_;

    0;
}

=item postdeleteDomain( \%moduleData )

 Process postdeleteDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostDeleteDomain( \%moduleData )
  - after<SNAME>PostDeleteDomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub postdeleteDomain
{
    my ($self) = @_;

    0;
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddSubdomain( \%moduleData )
  - after<SNAME>AddSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub addSubdomain
{
    my ($self) = @_;

    0;
}

=item postaddSubdomain( \%moduleData )

 Process postaddSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostAddSubdomain( \%moduleData )
  - after<SNAME>PostAddSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub postaddSubdomain
{
    my ($self) = @_;

    0;
}

=item disableSubdomain( \%moduleData )

 Process disableSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub disableSubdomain
{
    my ($self) = @_;

    0;
}

=item postdisableSubdomain( \%moduleData )

 Process postdisableSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostDisableSubdomain( \%moduleData )
  - after<SNAME>PostDisableSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub postdisableSubdomain
{
    my ($self) = @_;

    0;
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteSubdomain( \%moduleData )
  - after<SNAME>DeleteSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub deleteSubdomain
{
    my ($self) = @_;

    0;
}

=item postdeleteSubdomain( \%moduleData )

 Process postdeleteSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>PostDeleteSubdomain( \%moduleData )
  - after<SNAME>PostDeleteSubdomain( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub postdeleteSubdomain
{
    my ($self) = @_;

    0;
}

=item addCustomDNS( \%moduleData )

 Process addCustomDNS tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddCustomDNS( \%moduleData )
  - after<SNAME>AddCustomDNS( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Custom DNS data
 Return int 0 on success, other on failure

=cut

sub addCustomDNS
{
    my ($self) = @_;

    0;
}

=back

=head1 PRIVATE METHODS

=over

=item _init( )

 See iMSCP::Servers::Abstract::_init()

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->SUPER::_init();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
