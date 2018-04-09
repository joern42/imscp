# i-MSCP iMSCP::Listener::Nginx::HSTS listener file
# Copyright (C) 2017-2018 Laurent Declercq <l.declercq@nuxwin.com>
# Copyright (C) 2015-2017 Rene Schuster <mail@reneschuster.de>
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
## Activates HTTP Strict Transport Security (HSTS).
#

package iMSCP::Listener::Nginx::HSTS;

our $VERSION = '1.0.2';

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::EventManager;
use iMSCP::Template::Processor qw/ processBlocByRef /;
use version;

#
## Please, don't edit anything below this line
#

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.6.0' ) or die(
    sprintf( "The 10_nginx_hsts.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub
{
    my ( $tplContent, $tplName ) = @_;

    return unless $tplName eq '00_master_ssl.nginx' && $::imscpConfig{'PANEL_SSL_ENABLED'} eq 'yes';

    processBlocByRef( $tplContent, '# SECTION custom BEGIN.', '# SECTION custom ENDING.', <<'EOF', TRUE );
    add_header Strict-Transport-Security "max-age=31536000";
EOF
} );

1;
__END__
