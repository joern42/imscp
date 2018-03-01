=head1 NAME

 iMSCP::Servers::Sqld - Factory and abstract implementation for the i-MSCP sqld servers

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

package iMSCP::Servers::Sqld;

use strict;
use warnings;
use Carp qw/ croak /;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP sqld servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 See iMSCP::Servers::Abstract::getPriority()

=cut

sub getPriority
{
    400;
}

=back

=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, $self->getHumanServerName() ];
            0;
        },
        $self->getPriority()
    );

    0;
}

=item getVendor( )

 Get SQL server vendor

 Return string MySQL server vendor

=cut

sub getVendor
{
    my ( $self ) = @_;

    $self->{'config'}->{'SQLD_VENDOR'};
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'SQLD_VERSION'};
}

=item createUser( $user, $host, $password )

 Create the given SQL user if it doesn't already exist, update it password otherwise

 Param $string $user SQL username
 Param string $host SQL user host
 Param $string $password SQL user password
 Return void, die on failure

=cut

sub createUser
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the createUser() method', ref $self ));
}

=item dropUser( $user, $host )

 Drop the given SQL user if exists

 Param $string $user SQL username
 Param string $host SQL user host
 Return void, die on failure

=cut

sub dropUser
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the dropUser() method', ref $self ));
}

=item restoreDomain ( \%moduleData )

 Restore all databases that belong to the given domain account

  Process restoreDomain tasks
 
  The following events *MUST* be triggered:
  - before<SNAME>RestoreDomain( \%moduleData )
  - after<SNAME>RestoreDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Domain module
 Return void, die on failure

=cut

sub restoreDomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the restoreDomain() method', ref $self ));
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
