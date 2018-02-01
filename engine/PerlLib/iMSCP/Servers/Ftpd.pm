=head1 NAME

 iMSCP::Servers::Ftpd - Factory and abstract implementation for the i-MSCP ftpd servers

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

package iMSCP::Servers::Ftpd;

use strict;
use warnings;
use Carp qw/ croak /;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP ftpd servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    150;
}

=back

=head1 PUBLIC METHODS

=over 4

=item addUser( \%moduleData )

 Process addUser tasks

 The following event *MUST* be triggered:
  - before<SNAME>AddFtpUser( \%moduleData )
  - after<SNAME>AddFtpUser( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Modules::User module
 Return void, die on failure

=cut

sub addUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addUser() method', ref $self ));
}

=item addFtpUser( \%moduleData )

 Add FTP user

 The following event *MUST* be triggered:
  - before<SNAME>AddFtpUser( \%moduleData )
  - after<SNAME>AddFtpUser( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Modules::FtpUser module
 Return void, die on failure

=cut

sub addFtpUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addFtpUser() method', ref $self ));
}

=item disableFtpUser( \%moduleData )

 Disable FTP user

 The following event *MUST* be triggered:
  - before<SNAME>DisableFtpUser( \%moduleData )
  - after<SNAME>DisableFtpUser( \%moduleData )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Modules::FtpUser module
 Return void, die on failure

=cut

sub disableFtpUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the disableFtpUser() method', ref $self ));
}

=item deleteFtpUser( \%moduleData )

 Delete FTP user

 The following event *MUST* be triggered:
  - before<SNAME>DeleteFtpUser( \%moduleData )
  - after<SNAME>DeleteFtpUser( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Modules::FtpUser module
 Return void, die on failure

=cut

sub deleteFtpUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteFtpUser() method', ref $self ));
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 Get ftpd server traffic data

 Param hashref \%trafficDb Traffic database
 Param string $logFile Path to ftpd traffic log file (only when self-called)
 Param hashref \%trafficIndexDb Traffic index database (only when self-called)
 Return void, die on failure

=cut

sub getTraffic
{
    my ($self) = @_;

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
