# i-MSCP iMSCP::Listener::Courier::Connections listener file
# Copyright (C) 2017-2018 Laurent Declercq <l.declercq@nuxwin.com>
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
## Allows to increase the maximum number of connections to accept from the same IP address
#

package iMSCP::Listener::Courier::Connections;

our $VERSION = '1.0.0';

use strict;
use warnings;
use iMSCP::EventManager;
use version;

#
## Configuration parameters
#

# Max connection per IP
my $MAX_CONNECTION_PER_IP = 20;

#
## Please, don't edit anything below this line
#

version->parse( "$main::imscpConfig{'PluginApi'}" ) >= version->parse( '1.5.1' ) or die(
    sprintf( "The 20_courier_connections.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

iMSCP::EventManager->getInstance()->register(
    'onCourierBuildLocalConf',
    sub {
        my ($serviceName, $conffile) = @_;

        return 0 unless grep( $serviceName eq $_, 'pop3d', 'imapd' );

        $conffile->{'MAXPERIP'} = $MAX_CONNECTION_PER_IP;
        0;
    }
);

1;
__END__
