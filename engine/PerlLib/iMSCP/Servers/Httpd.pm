=head1 NAME

 iMSCP::Servers::Httpd - Factory and abstract implementation for the i-MSCP httpd servers

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

package iMSCP::Servers::Httpd;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Find qw/ find /;
use File::Spec;
use iMSCP::Debug qw/ debug error warning getMessageByType /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Getopt;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP httpd servers..

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

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

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::User module
 Return int 0 on success, other on failure

=cut

sub addUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addUser() method', ref $self ));
}

=item deleteUser( \%moduleData )

 Process deleteUser tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteUser( \%moduleData )
  - after<SNAME>DeleteUser( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::User module
 Return int 0 on success, other on failure

=cut

sub deleteUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteUser() method', ref $self ));
}

=item addDomain( \%moduleData )

 Process addDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddDomain( \%moduleData )
  - after<SNAME>AddDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub addDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addDomain() method', ref $self ));
}

=item restoreDomain( \%moduleData )

 Process restoreDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>RestoreDomain( \%moduleData )
  - after<SNAME>RestoreDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub restoreDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the restoreDmn() method', ref $self ));
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableDomain( \%moduleData )
  - after<SNAME>DisableDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub disableDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the disableDomain() method', ref $self ));
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteDomain( \%moduleData )
  - after<SNAME>DeleteDomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub deleteDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteDomain() method', ref $self ));
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub addSubdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addSubdomain() method', ref $self ));
}

=item restoreSubdomain( \%moduleData )

 Process restoreSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>RestoreSubdomain( \%moduleData )
  - after<SNAME>RestoreSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub restoreSubdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the restoreSubdomain() method', ref $self ));
}

=item disableSubdomain( \%moduleData )

 Process disableSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DisableSubdomain( \%moduleData )
  - after<SNAME>DisableSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub disableSubdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the disableSubdomain() method', ref $self ));
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteSubdomain( \%moduleData )
  - after<SNAME>DeleteSubdomain( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub deleteSubdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteSubdomain() method', ref $self ));
}

=item addHtpasswd( \%moduleData )

 Process addHtpasswd tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtpasswd( \%moduleData )
  - after<SNAME>AddHtpasswd( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htpasswd module
 Return int 0 on success, other on failure

=cut

sub addHtpasswd
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addHtpasswd() method', ref $self ));
}

=item deleteHtpasswd( \%moduleData )

 Process deleteHtpasswd tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteHtpasswd( \%moduleData )
  - after<SNAME>DeleteHtpasswd( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htpasswd module
 Return int 0 on success, other on failure

=cut

sub deleteHtpasswd
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteHtpasswd() method', ref $self ));
}

=item addHtgroup( \%moduleData )

 Process addHtgroup tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtgroup( \%moduleData )
  - after<SNAME>AddHtgroup( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htgroup module
 Return int 0 on success, other on failure

=cut

sub addHtgroup
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addHtgroup() method', ref $self ));
}

=item deleteHtgroup( \%moduleData )

 Process deleteHtgroup tasks

 The following events *MUST* be triggered:
  - before<SNAME>deleteHtgroup( \%moduleData )
  - after<SNAME>deleteHtgroup( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htgroup module
 Return int 0 on success, other on failure

=cut

sub deleteHtgroup
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteHtgroup() method', ref $self ));
}

=item addHtaccess( \%moduleData )

 Process addHtaccess tasks

 The following events *MUST* be triggered:
  - before<SNAME>AddHtaccess( \%moduleData )
  - after<SNAME>AddHtaccess( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htaccess module
 Return int 0 on success, other on failure

=cut

sub addHtaccess
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the addHtaccess() method', ref $self ));
}

=item deleteHtaccess( \%moduleData )

 Process deleteHtaccess tasks

 The following events *MUST* be triggered:
  - before<SNAME>DeleteHtaccess( \%moduleData )
  - after<SNAME>DeleteHtaccess( \%moduleData )

 where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Htaccess module
 Return int 0 on success, other on failure

=cut

sub deleteHtaccess
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the deleteHtaccess() method', ref $self ));
}

=item getTraffic( \%trafficDb )

 Get httpd traffic data

 Param hashref \%trafficDb Traffic database
 Croak on failure

=cut

sub getTraffic
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the getTraffic() method', ref $self ));
}

=item getRunningUser( )

 Get user name under which the httpd server is running

 Return string User name under which the httpd server is running

=cut

sub getRunningUser
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the getRunningUser() method', ref $self ));
}

=item getRunningGroup( )

 Get group name under which the httpd server is running

 Return string Group name under which the httpd server is running

=cut

sub getRunningGroup
{
    my ($self) = @_;

    die( sprintf( 'The %s class must implement the getRunningGroup() method', ref $self ));
}

=item enableSites( @sites )

 Enable the given sites
 
 Default implementation that *SHOULD* met requirements for both Apache and Nginx servers.
 
 Param list @sites List of sites to enable
 Return int 0 on success, other on failure

=cut

sub enableSites
{
    my ($self, @sites) = @_;

    my $ret = 0;
    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( @sites ) {
            my $site = basename( $_, '.conf' ); # Support input with .conf suffix too
            my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
            my $link = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

            unless ( -e $tgt ) {
                warning( sprintf( '%s is a dangling symlink', $link ), $caller ) if -l $link && !-e $link;

                if ( iMSCP::Getopt->context() eq 'uninstaller' ) {
                    $self->_switchMarker( 'site', 'enable', $site );
                    next; # we do not report error. We are uninstalling anyway
                }

                error( sprintf( "Site %s doesn't exist", $site ), $caller );
                $ret ||= 1;
                next;
            }

            my $check = $self->_checkLink( $tgt, $link );
            if ( $check eq 'ok' ) {
                debug( sprintf( 'Site %s already enabled', $site ), $caller );
            } elsif ( $check eq 'missing' ) {
                debug( sprintf( 'Enabling site %s', $site ), $caller );
                my $rs = $self->_addLink( $tgt, $link );
                $rs ||= $self->_switchMarker( 'site', 'enable', $site );
                $ret ||= $rs if $rs;
            } else {
                error( sprintf( "Site %s isn't properly enabled: %s", $check ), $caller );
                $ret ||= 1;
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $ret;
}

=item disableSites( @sites )

 Disable the given sites
 
 Default implementation that *SHOULD* met requirements for both Apache and Nginx servers.
 
 Param list @sites List of sites to disable
 Return int 0 on success, other on failure

=cut

sub disableSites
{
    my ($self, @sites) = @_;

    my ($ret, $conflink) = ( 0 );
    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( @sites ) {
            my $site = basename( $_, '.conf' ); # Support input with .conf suffix too
            my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
            my $link = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

            unless ( -e $tgt ) {
                if ( -l $link && !-e $link ) {
                    debug( sprintf( 'Removing dangling symlink: %s', $link ), $caller );
                    unlink( $link ) or die( sprintf( "Couldn't remove the %s link: %s", $link, $! ));

                    # force a .conf path. It may exist as dangling link, too
                    $conflink = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";
                    if ( -l $conflink && !-e $conflink ) {
                        debug( sprintf( 'Removing dangling symlink: %s', $conflink ), $caller );
                        unlink( $conflink ) or die( sprintf( "Couldn't remove the %s link: %s", $link, $! ));
                    }

                    next;
                }

                $self->_switchMarker( 'site', 'disable', $site ) if iMSCP::Getopt->context() eq 'uninstaller';

                # Unlike Debian a2dissite script behavior, we do not want report
                # error when a site that we try to disable doesn't exist.
                debug( sprintf( "Site %s doesn't exist. Skipping...", $site ), $caller );
                next;
            }

            if ( -e $link || -l $link ) {
                debug( sprintf( 'Disabling site %s', $site ), $caller );
                $self->_removeLink( $link );
                $self->_removeLink( $conflink ) if $conflink && -e $conflink;
                $self->_switchMarker( 'site', 'disable', $site );
            } elsif ( $conflink && -e $conflink ) {
                debug( sprintf( 'Disabling stale config file %s.conf ', $site ), $caller );
                $self->_removeLink( $conflink );
            } else {
                debug( sprintf( 'Site %s already disabled', $site ), $caller );
                $self->_switchMarker( 'site', 'disable', $site ) if iMSCP::Getopt->context() eq 'uninstlaler';
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $ret;
}

=item enableModules( @modules )

 Enable the given modules
 
 Param list @modules List of modules to enable
 Return int 0 on success, other on failure

=cut

sub enableModules
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the enableModules() method', ref $self ));
}

=item disableModules( @modules )

 Disable the given modules
 
 Param list @modules List of modules to disable
 Return int 0 on success, other on failure

=cut

sub disableModules
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableModules() method', ref $self ));
}

=item enableConfs( @conffiles )

 Enable the given configuration files
 
 Param list @conffiles List of configuration files to enable
 Return int 0 on success, other on failure

=cut

sub enableConfs
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the enableConfs() method', ref $self ));
}

=item disableConfs( @conffiles )

 Disable the given configuration files
 
 Param list @conffiles List of configuration files to disable
 Return int 0 on success, other on failure

=cut

sub disableConfs
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableConfs() method', ref $self ));
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

=item _checkLink( $tgt, $link )

 Check the given symlink
 
 Param $string $link Link target
 Param $string $link Link path
 return int 0 on success, die on failure

=cut

sub _checkLink
{
    my ($self, $tgt, $link) = @_;

    if ( !-e $link ) {
        if ( -l $link ) {
            debug( sprintf( 'Removing dangling link %s', $link ));
            unlink $link or die( sprintf( "Couldn't remove the %s link: %s", $link, $! ));
        }

        return 'missing';
    }

    return sprintf( '%s is a real file, not touching it', $link ) if -e $link && !-l $link;
    return sprintf( "The %s link exists but doesn't point to %s, not touching it", $link, $tgt ) if realpath( $link ) ne realpath( $tgt );
    'ok';
}

=item _addLink( $tgt, $link )

 Create the given link
 
 Param $string $link Link target
 Param $string $link Link path
 return int 0 on success, die on failure

=cut

sub _addLink
{
    my ($self, $tgt, $link) = @_;

    symlink( File::Spec->abs2rel( $tgt, dirname( $link )), $link ) or die( sprintf( "Couldn't create %s: $!" ));
    $self->{'reload'} ||= 1;
    0;
}

=item _removeLink( $link )

 Remove the given link
 
 Param $string $link Link path
 Return int 0 on success, die on failure

=cut

sub _removeLink
{
    my ($self, $link) = @_;

    if ( -l $link ) {
        unlink $link or die( sprintf( "Couldn't remove the %s link: %s", $link, $! ));
    } elsif ( -e $link ) {
        error( sprintf( "%s isn't a symbolic link, not deleting", $link ));
        return 1;
    }

    $self->{'reload'} ||= 1;
    0;
}

=item _switchMarker()

 Create or delete marker for the given object

 Debian OS Apache2 specific (see a2enmod script for further details)
 
 Param string $which (conf|module|site)
 Param string $what (enable|disable)
 param $string $name Name
 Return int 0 on succes, other on failure

=cut

sub _switchMarker
{
    my ($self, $which, $what, $name) = @_;

    return 0 unless $main::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && $self->getServerName eq 'Apache';

    my $stateMarkerDir = "$self->{'config'}->{'HTTPD_STATE_DIR'}/$which/${what}d_by_admin";
    my $stateMarker = "$stateMarkerDir/$name";

    unless ( -d $stateMarkerDir ) {
        eval { iMSCP::Dir->new( dirname => $stateMarkerDir )->make( { umask => 0022 } ); };
        if ( $@ ) {
            error( sprintf( "Failed to create the %s marker directory:", $stateMarkerDir, $@ ));
            return 1;
        }
    }

    eval {
        find(
            sub {
                return unless $_ eq $name && -f;
                unlink or die sprintf( "Failed to remove old %s marker: %s", $File::Find::name, $! );
            },
            $self->{'config'}->{'HTTPD_STATE_DIR'}
        );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    return 0 if iMSCP::Getopt->context() eq 'uninstaller';

    my $rs = iMSCP::File->new( filename => $stateMarker )->save();
    error( sprintf(
        "Failed to create the %s marker: %s", $stateMarker, getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    )) if $rs;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
