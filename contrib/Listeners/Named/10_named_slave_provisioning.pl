# i-MSCP iMSCP::Listener::Named::Slave::Provisioning listener file
# Copyright (C) 2016-2018 Laurent Declercq <l.declercq@nuxwin.com>
# Copyright (C) 2015 UncleJ, Arthur Mayer <mayer.arthur@gmail.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

# FIXME: Provide better implementation, using more robust method such as metaslave
# See http://jpmens.net/2013/02/13/automatic-provisioning-of-slave-dns-servers/

#
## Provides slave DNS server(s) provisioning service.
## Slave provisioning service will be available at:
##   - http://<panel.domain.tld>:8080/provisioning/slave_provisioning.php
##   - https://<panel.domain.tld>:4443/provisioning/slave_provisioning.php (if you use ssl)
#

package iMSCP::Listener::Named::Slave::Provisioning;

our $VERSION = '1.0.6';

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use iMSCP::Crypt qw/ htpasswd /;
use version;

#
## Configuration parameters
#

# HTTP (Basic) authentication parameters
# These parameters are used to restrict access to the provisioning script which
# is available through HTTP(s)

# Authentication username
# Leave empty to disable authentication
my $AUTH_USERNAME = '';

# Authentication password
# Either an hashed or plain password.
# In case of an hashed password, don't forget to set the
# $AUTH_PASSWORD_IS_HASHED parameter value to 1
# Plain password are automatically hashed using APR1 MD5 algorithm.
my $AUTH_PASSWORD = '';

# Tells whether or not the provided authentication password is hashed.
my $AUTH_PASSWORD_IS_HASHED = 0;

# Protected area identifier
my $realm = 'i-MSCP provisioning service for slave DNS servers';

#
## Please, don't edit anything below this line
#

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.6.0' ) or die(
    sprintf( "The 10_named_slave_provisionning.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

# Routine that create the .htpasswd file for HTTP (Basic) authentication
sub createHtpasswdFile
{
    index( $AUTH_USERNAME, ':' ) == -1 or die( "htpasswd: username contains illegal character ':'" );

    iMSCP::File
        ->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/provisioning/.htpasswd" )
        ->set( "$AUTH_USERNAME:" . ( $AUTH_PASSWORD_IS_HASHED ? $AUTH_PASSWORD : htpasswd( $AUTH_PASSWORD ) ))
        ->save()
        ->owner(
            "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}",
            "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}" )
        ->mode( 0640 );
}

#
## Event listeners
#

# Listener that is responsible to add authentication configuration
iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub
{
    my ( $tplContent, $tplName ) = @_;

    return unless ( $tplName eq '00_master.nginx' && ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) ne 'https://' )
        || $tplName eq '00_master_ssl.nginx';

    my $locationSnippet = <<"EOF";
    location ^~ /provisioning/ {
        root /var/www/imscp/frontend/public;

        location ~ \\.php\$ {
            include imscp_fastcgi.conf;
            satisfy any;
            deny all;
            auth_basic "$realm";
            auth_basic_user_file $::imscpConfig{'FRONTEND_ROOT_DIR'}/public/provisioning/.htpasswd;
        }
    }
EOF
    replaceBlocByRef( '# SECTION custom BEGIN.', '# SECTION custom ENDING.', <<"EOF", $tplContent, TRUE );
@{ [ getBlocByRef( '# SECTION custom BEGIN.', '# SECTION custom ENDING.', $tplContent ) ] }
    $locationSnippet
EOF
} ) if defined $AUTH_USERNAME;

# Event listener that create the provisioning script
iMSCP::EventManager->getInstance()->register( 'afterFrontEndInstall', sub
{
    my $fileContent = <<'EOF';
<?php

use iMSCP::Registry as Registry;

require '../../library/imscp-lib.php';
$config = Registry::get('config');
$masterDnsServerIp = $config['BASE_SERVER_PUBLIC_IP'];
echo "// CONFIGURATION FOR MAIN DOMAIN\n";
echo "zone \"$config->BASE_SERVER_VHOST\" {\n";
echo "\ttype slave;\n";
echo "\tfile \"/var/cache/bind/$config->BASE_SERVER_VHOST.db\";\n";
echo "\tmasters { $masterDnsServerIp; };\n";
echo "\tallow-notify { $masterDnsServerIp; };\n";
echo "};\n";
echo "// END CONFIGURATION FOR MAIN DOMAIN\n\n";
$stmt = execute_query('SELECT domain_id, domain_name FROM domain');
$rowCount = $stmt->rowCount();
if ($rowCount > 0) {
    echo "// $rowCount HOSTED DOMAINS LISTED ON $config->SERVER_HOSTNAME [$masterDnsServerIp]\n";

    while ($row = $stmt->fetch()) {
        echo "zone \"{$row['domain_name']}\" {\n";
        echo "\ttype slave;\n";
        echo "\tfile \"/var/cache/bind/{$row['domain_name']}.db\";\n";
        echo "\tmasters { $masterDnsServerIp; };\n";
        echo "\tallow-notify { $masterDnsServerIp; };\n";
        echo "};\n";
    }

    echo "// END DOMAINS LIST\n\n";
}
$stmt = execute_query('SELECT alias_id, alias_name FROM domain_aliases');
$rowCount = $stmt->rowCount();
if ($rowCount > 0) {
    echo "// $rowCount HOSTED ALIASES LISTED ON $config->SERVER_HOSTNAME [$masterDnsServerIp]\n";
    while ($row = $stmt->fetch()) {
        echo "zone \"{$row['alias_name']}\" {\n";
        echo "\ttype slave;\n";
        echo "\tfile \"/var/cache/bind/{$row['alias_name']}.db\";\n";
        echo "\tmasters { $masterDnsServerIp; };\n";
        echo "\tallow-notify { $masterDnsServerIp; };\n";
        echo "};\n";
    }
    echo "// END ALIASES LIST\n";
}
EOF

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/provisioning" )->make( {
        user  => "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        group => "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        mode  => 0550
    } );

    createHtpasswdFile() if defined $AUTH_USERNAME;

    iMSCP::File->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/provisioning/slave_provisioning.php" )
        ->set( $fileContent )
        ->save()
        ->owner(
        "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        "$::imscpConfig{'SYSTEM_USER_PREFIX'}$::imscpConfig{'SYSTEM_USER_MIN_UID'}"
    )->mode( 0640 );
} );

1;
__END__
