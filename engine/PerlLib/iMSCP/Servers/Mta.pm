=head1 NAME

 iMSCP::Servers::Mta - Factory and abstract implementation for the i-MSCP mta servers

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

package iMSCP::Servers::Mta;

use strict;
use warnings;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP mta servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    100;
}

=back

=head1 PUBLIC METHODS

=over 4

=item addDomain( \%moduleData )

 Process addDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddDomain( \%moduleData )
  - after<SNAME>AddDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData
 Return int 0 on success, other on failure

=cut

sub addDomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the addDomain() method', ref $self ));
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableDomain( \%moduleData )
  - after<SNAME>DisableDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub disableDomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableDomain() method', ref $self ));
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteDomain( \%moduleData )
  - after<SNAME>DeleteDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Domain data
 Return int 0 on success, other on failure

=cut

sub deleteDomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the deleteDomain() method', ref $self ));
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddSubdomain( \%moduleData )
  - after<SNAME>AddSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub addSubdomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the addSubdomain() method', ref $self ));
}

=item disableSubdomain( \%moduleData )

 Process disableSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub disableSubdomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableSubdomain() method', ref $self ));
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteSubdomain( \%moduleData )
  - after<SNAME>DeleteSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Subdomain data
 Return int 0 on success, other on failure

=cut

sub deleteSubdomain
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the deleteSubdomain() method', ref $self ));
}

=item addMail( \%moduleData )

 Process addMail tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddMail( \%moduleData )
  - after<SNAME>AddMail( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Mail data
 Return int 0 on success, other on failure

=cut

sub addMail
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the addMail() method', ref $self ));
}

=item disableMail( \%moduleData )

 Process disableMail tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableMail( \%moduleData )
  - after<SNAME>DisableMail( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Mail data
 Return int 0 on success, other on failure

=cut

sub disableMail
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableMail() method', ref $self ));
}

=item deleteMail( \%moduleData )

 Process deleteMail tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteMail( \%moduleData )
  - after<SNAME>DeleteMail( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getEventServerName() method.

 Param hashref \%moduleData Mail data
 Return int 0 on success, other on failure

=cut

sub deleteMail
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the deleteMail() method', ref $self ));
}

=item getTraffic( \%trafficDb )

 Get SMTP traffic

 Param hashref \%trafficDb Traffic database
 Return void, croak on failure

=cut

sub getTraffic
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the getTraffic() method', ref $self ));
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
