# i-MSCP iMSCP::Listener::Apache2::Tools::Proxy listener file
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
## Provides transparent access to i-MSCP tools (pma, webmail...) through customer domains. For instance:
#
#  http://customer.tld/webmail/ will be redirected to https://customer.tld/webmail/ if ssl is enabled for customer domain
#  http://customer.tld/webmail/ will proxy to i-MSCP primary webmail transparently if ssl is not enabled for customer domain
#  https://customer.tld/webmail/ will proxy to i-MSCP primary webmail transparently
#
# You can change primary Webmail, SQL manager and filemanager through configuration variable below.
#

package iMSCP::Listener::Apache2::Tools::Proxy;

our $VERSION = '1.0.2';

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::EventManager;
use iMSCP::Template::Processor qw/ processBlocByRef processVarsByRef /;
use version;

#
## Configuration variables
#

# Primary File manager (e.g. monstaftp or pydio, depending on your i-MSCP setup)
my $PRIMARY_FILEMANAGER = 'monstaftp';
# Primary File manager (e.g. roundcube or rainloop, depending on your i-MSCP setup)
my $PRIMARY_WEBMAIL = 'roundcube';
# Primary SQL manager (e.g. phpmyadmin)
my $PRIMARY_SQL_MANAGER = 'phpmyadmin';

#
## Please, don't edit anything below this line
#

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.6.0' ) or die(
    sprintf( "The 30_apache2_tools_proxy.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

iMSCP::EventManager->getInstance()->register( 'beforeApacheBuildConf', sub
{
    my ( $cfgTpl, $tplName, undef, $moduleData, $serverData ) = @_;

    return unless $tplName eq 'domain.tpl' && grep ( $_ eq $moduleData->{'VHOST_TYPE'}, ( 'domain', 'domain_ssl' ) );

    if ( $serverData->{'VHOST_TYPE'} eq 'domain' && $moduleData->{'SSL_SUPPORT'} ) {
        processBlocByRef( $cfgTpl, '# SECTION addons BEGIN.', '# SECTION addons ENDING.', <<"EOF", TRUE );
    RedirectMatch 301 ^(/(?:ftp|pma|webmail)\/?)\$ https://$moduleData->{'DOMAIN_NAME'}\$1
EOF
        return;
    }

    my $cfgProxy = ( $::imscpConfig{'PANEL_SSL_ENABLED'} eq 'yes' ? "    SSLProxyEngine On\n" : '' ) . <<"EOF";
    ProxyPass /ftp/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_FILEMANAGER/ retry=1 acquire=3000 timeout=600 Keepalive=On
    ProxyPassReverse /ftp/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_FILEMANAGER/
    ProxyPass /pma/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_SQL_MANAGER/ retry=1 acquire=3000 timeout=600 Keepalive=On
    ProxyPassReverse /pma/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_SQL_MANAGER/
    ProxyPass /webmail/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_WEBMAIL/ retry=1 acquire=3000 timeout=600 Keepalive=On
    ProxyPassReverse /webmail/ {HTTP_URI_SCHEME}{HTTP_HOST}:{HTTP_PORT}/$PRIMARY_WEBMAIL/
EOF
    processVarsByRef( \$cfgProxy, {
        HTTP_URI_SCHEME => ( $::imscpConfig{'PANEL_SSL_ENABLED'} eq 'yes' ) ? 'https://' : 'http://',
        HTTP_HOST       => $::imscpConfig{'BASE_SERVER_VHOST'},
        HTTP_PORT       => ( $::imscpConfig{'PANEL_SSL_ENABLED'} eq 'yes' )
            ? $::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'} : $::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'}
    } );
    processBlocByRef( $cfgTpl, '# SECTION addons BEGIN.', '# SECTION addons ENDING.', <<"EOF", TRUE );
    $cfgProxy
EOF
} ) if index( $::imscpConfig{'iMSCP::Servers::Httpd'}, '::Apache2::' ) != -1;

1;
__END__
