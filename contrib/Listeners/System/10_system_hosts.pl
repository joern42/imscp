# i-MSCP iMSCP::Listener::System::Hosts listener file
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

#
## Allows to add host entries in the system hosts file (eg. /etc/hosts).
#

package iMSCP::Listener::System::Hosts;

our $VERSION = '1.0.3';

use strict;
use warnings;
use iMSCP::EventManager;

#
## Configuration variables
#
# Parameter which allow to add one or many host entries in the system hosts file
# Please replace the entries below by your own entries
my @hostsFileEntries = (
    '192.168.1.10	foo.mydomain.org	foo',
    '192.168.1.13	bar.mydomain.org	bar'
);

#
## Please don't edit anything below this line
#

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.5.1' ) or die(
    sprintf( "The 10_system_hosts.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

# Listener responsible to add host entries in the system hosts file, once it was built by i-MSCP
iMSCP::EventManager->getInstance()->register(
    'afterLocalServerBuildConfFile',
    sub {
        my ($cfgTpl, $cfgTplName) = @_;

        return unless $cfgTplName eq 'hosts';

        ${$cfgTpl} .= join( "\n", @hostsFileEntries ) . "\n";
    }
) if index( $::imscpConfig{'iMSCP::Servers::Server'}, '::Local::' ) != -1;

1;
__END__
