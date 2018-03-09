=head1 NAME

 iMSCP::Servers::Httpd - Factory and abstract implementation for the i-MSCP httpd servers

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

package iMSCP::Servers::Httpd;

use strict;
use warnings;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP httpd servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 See iMSCP::Servers::Abstract::getPriority()

=cut

sub getPriority
{
    200;
}

=back

=head1 PUBLIC METHODS

=over 4

=item addUser( \%moduleData )

 Process addUser tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddUser( \%moduleData )
  - after<SNAME>AddUser( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the User module
 Return void, die on failure

=cut

sub addUser
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addUser() method', ref $self ));
}

=item deleteUser( \%moduleData )

 Process deleteUser tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteUser( \%moduleData )
  - after<SNAME>DeleteUser( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the User module
 Return void, die on failure

=cut

sub deleteUser
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteUser() method', ref $self ));
}

=item addDomain( \%moduleData )

 Process addDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddDomain( \%moduleData )
  - after<SNAME>AddDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return void, die on failure

=cut

sub addDomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addDomain() method', ref $self ));
}

=item restoreDomain( \%moduleData )

 Process restoreDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>RestoreDomain( \%moduleData )
  - after<SNAME>RestoreDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return void, die on failure

=cut

sub restoreDomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the restoreDomain() method', ref $self ));
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableDomain( \%moduleData )
  - after<SNAME>DisableDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return void, die on failure

=cut

sub disableDomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableDomain() method', ref $self ));
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteDomain( \%moduleData )
  - after<SNAME>DeleteDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return void, die on failure

=cut

sub deleteDomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteDomain() method', ref $self ));
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub addSubdomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addSubdomain() method', ref $self ));
}

=item restoreSubdomain( \%moduleData )

 Process restoreSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>RestoreSubdomain( \%moduleData )
  - after<SNAME>RestoreSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub restoreSubdomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the restoreSubdomain() method', ref $self ));
}

=item disableSubdomain( \%moduleData )

 Process disableSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub disableSubdomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableSubdomain() method', ref $self ));
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteSubdomain( \%moduleData )
  - after<SNAME>DeleteSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub deleteSubdomain
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteSubdomain() method', ref $self ));
}

=item addHtpasswd( \%moduleData )

 Process addHtpasswd tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtpasswd( \%moduleData )
  - after<SNAME>AddHtpasswd( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htpasswd module
 Return void, die on failure

=cut

sub addHtpasswd
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addHtpasswd() method', ref $self ));
}

=item deleteHtpasswd( \%moduleData )

 Process deleteHtpasswd tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteHtpasswd( \%moduleData )
  - after<SNAME>DeleteHtpasswd( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htpasswd module
 Return void, die on failure

=cut

sub deleteHtpasswd
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteHtpasswd() method', ref $self ));
}

=item addHtgroup( \%moduleData )

 Process addHtgroup tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtgroup( \%moduleData )
  - after<SNAME>AddHtgroup( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htgroup module
 Return void, die on failure

=cut

sub addHtgroup
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addHtgroup() method', ref $self ));
}

=item deleteHtgroup( \%moduleData )

 Process deleteHtgroup tasks

 The following events *MUST* be triggered:
  - before<SNAME>deleteHtgroup( \%moduleData )
  - after<SNAME>deleteHtgroup( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htgroup module
 Return void, die on failure

=cut

sub deleteHtgroup
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteHtgroup() method', ref $self ));
}

=item addHtaccess( \%moduleData )

 Process addHtaccess tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtaccess( \%moduleData )
  - after<SNAME>AddHtaccess( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htaccess module
 Return void, die on failure

=cut

sub addHtaccess
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the addHtaccess() method', ref $self ));
}

=item deleteHtaccess( \%moduleData )

 Process deleteHtaccess tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteHtaccess( \%moduleData )
  - after<SNAME>DeleteHtaccess( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the Htaccess module
 Return void, die on failure

=cut

sub deleteHtaccess
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the deleteHtaccess() method', ref $self ));
}

=item getTraffic( \%trafficDb )

 Get httpd traffic data

 Param hashref \%trafficDb Traffic database
 die on failure

=cut

sub getTraffic
{
    my ( $self, $trafficDb ) = @_;

    die( sprintf( 'The %s class must implement the getTraffic() method', ref $self ));
}

=item getRunningUser( )

 Get user name under which the httpd server is running

 Return string User name under which the httpd server is running

=cut

sub getRunningUser
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getRunningUser() method', ref $self ));
}

=item getRunningGroup( )

 Get group name under which the httpd server is running

 Return string Group name under which the httpd server is running

=cut

sub getRunningGroup
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getRunningGroup() method', ref $self ));
}

=item enableSites( @sites )

 Enable the given sites
 
 Param list @sites List of sites to enable
 Return void, die on failure

=cut

sub enableSites
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the enableSites() method', ref $self ));
}

=item disableSites( @sites )

 Disable the given sites

 If a site doesn't exist, no error *MUST* be raised.

 Param list @sites List of sites to disable
 Return void, die on failure

=cut

sub disableSites
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableSites() method', ref $self ));
}

=item removeSites( @sites )

 Remove the given sites

 If a site doesn't exist, no error *MUST* be raised.

 Param list @sites List of sites to remove
 Return void, die on failure

=cut

sub removeSites
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeSites() method', ref $self ));
}

=item enableConfs( @confs )

 Enable the given configurations
 
 Param list @confs List of configurations to enable
 Return void, die on failure

=cut

sub enableConfs
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the enableConfs() method', ref $self ));
}

=item disableConfs( @confs )

 Disable the given configurations

 If a configuration doesn't exist, no error *MUST* be raised.

 Param list @confs List of configurations to disable
 Return void, die on failure

=cut

sub disableConfs
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableConfs() method', ref $self ));
}

=item removeConfs( @confs )

 Remove the given configurations

 If a configuration doesn't exist, no error *MUST* be raised.

 Param list @confs List of configurations to remove
 Return void, die on failure

=cut

sub removeConfs
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeConfs() method', ref $self ));
}

=item enableModules( @mods )

 Enable the given modules
 
 Any dependency module *SHOULD* be also enabled.
 
 Param list @mods List of modules to enable
 Return void, die on failure

=cut

sub enableModules
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the enableModules() method', ref $self ));
}

=item disableModules( @mods )

 Disable the given modules
 
 If a module doesn't exist, no error *MUST* be raised.
 
 Param list @mods List of modules to disable
 Return void, die on failure

=cut

sub disableModules
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableModules() method', ref $self ));
}

=item removeModules( @mods )

 Remove the given modules

 If a module doesn't exist, no error *MUST* be raised.
 Any depending module *SHOULD* be pre-disabled.

 Param list @mods List of modules to remove
 Return void, die on failure

=cut

sub removeModules
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the removeModules() method', ref $self ));
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

    ref $self ne __PACKAGE__ or die( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->SUPER::_init();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
