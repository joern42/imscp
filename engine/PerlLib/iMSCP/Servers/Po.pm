=head1 NAME

 iMSCP::Servers::Po - Factory and abstract implementation for the i-MSCP po servers

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

package iMSCP::Servers::Po;

use strict;
use warnings;
use Carp qw/ croak /;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP po servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 See iMSCP::Servers::Abstract::getPriority()

=cut

sub getPriority
{
    50;
}

=back

=head1 PUBLIC METHODS

=over 4

=item addMail( \%moduleData )

 Process addMail tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddMail( \%moduleData )
  - after<SNAME>AddMail( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Mail module
 Return void, die on failure

=cut

sub addMail
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableDomain() method', ref $self ));
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 Get IMAP/POP3 traffic data

 Param hashref \%trafficDb Traffic database
 Param string $logFile Path to SMTP log file (only when self-called)
 Param hashref \%trafficIndexDb Traffic index database (only when self-called)
 Return void, die on failure

=cut

sub getTraffic
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getTraffic() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over

=item _init( )

 See iMSCP::Servers::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->SUPER::_init();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
