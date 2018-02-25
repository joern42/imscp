# i-MSCP iMSCP::Listener::Dovecot::Service::Login listener file
# Copyright (C) 2017-2018 Laurent Declercq <l.declercq@nuxwin.com>
# Copyright (C) 2016-2017 Sven Jantzen <info@svenjantzen.de>
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
## Allows to modify default service-login configuration options.
## This listener file requires dovecot version 2.1.0 or newer.
#

package iMSCP::Listener::Dovecot::Service::Login;

our $VERSION = '1.0.1';

use strict;
use warnings;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Servers::Po;
use version;

#
## Configuration parameters
#

# Service ports
# Note: Setting a port to 0 will close it
my $POP3_PORT = 110;
my $POP3_SSL_PORT = 995;
my $IMAP_PORT = 143;
my $IMAP_SSL_PORT = 993;

# Space separated list of IP addresses/hostnames to listen on.
# For instance:
# - with 'localhost' as value the service-login will listen on localhost only
# - with '*' as value, the service-login will listen on all IPv4 addresses
# - with '::' as value, the servicel-login will listen on all IPv6 addresses
# - with '*, ::' as value, the service-login will listen on all IPv4/IPv6 addresses
my $IMAP_LISTEN_ADDR = '* ::';
my $IMAP_SSL_LISTEN_ADDR = '* ::';
my $POP3_LISTEN_ADDR = '* ::';
my $POP3_SSL_LISTEN_ADDR = '* ::';

# Number of connections to handle before starting a new process. Typically
# the only useful values are 0 (unlimited) or 1. 1 is more secure, but 0
# is faster.
my $IMAP_SERVICE_COUNT = 0;
my $POP3_SERVICE_COUNT = 0;

#
## Please, don't edit anything below this line
#

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.5.1' ) or die(
    sprintf( "The 60_dovecot_service_login.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

iMSCP::EventManager->getInstance()->registerOne(
    'afterDovecotConfigure',
    sub {
        my $dovecotConfdir = iMSCP::Servers::Po->factory()->{'config'}->{'PO_CONF_DIR'};
        iMSCP::File->new( filename => "$dovecotConfdir/imscp.d/60_dovecot_service_login_listener.conf" )->set( <<"EOT" )->save();
service imap-login {
    inet_listener imap {
        port = $IMAP_PORT
        address = $IMAP_LISTEN_ADDR
    }

    inet_listener imaps {
        port = $IMAP_SSL_PORT
        address = $IMAP_SSL_LISTEN_ADDR
        ssl = yes
    }

    service_count = $IMAP_SERVICE_COUNT
}

service pop3-login {
    inet_listener pop3 {
        port = $POP3_PORT
        address = $POP3_LISTEN_ADDR
    }

    inet_listener pop3s {
        port = $POP3_SSL_PORT
        address = $POP3_SSL_LISTEN_ADDR
        ssl = yes
    }

    service_count = $POP3_SERVICE_COUNT
}
EOT
    }
) if index( $::imscpConfig{'iMSCP::Servers::Po'}, '::Dovecot::' ) != -1;;

1;
__END__
