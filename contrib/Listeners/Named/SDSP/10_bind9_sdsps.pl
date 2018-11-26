# i-MSCP Slave DNS server Provisioning Service (SDSPS)
# Copyright (C) 2018 Laurent Declercq <l.declercq@nuxwin.com>
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

# Listener providing Slave DNS server Provisioning Service (SDSPS)
# The service provided by this listener must be consumed by the SDSPC client.

# HOWTO SETUP
#
# 1. Install the 10_bind9_sdsps.pl listener file:
#    # cp <imscp_archive_dir>/contrib/Listeners/Named/SDSP/10_bind9_sdsps.pl /etc/imscp/listeners.d/
# 2. Edit the /etc/imscp/listener.d/10_bind9_sdsps.pl listener file and fill the configuration
#    variables
# 3. Trigger an i-MSCP reconfiguration to activate the service:
#    # perl /var/www/imscp/engine/bin/imscp-installer -dsnv 

package Listener::Named::SDSPS;

use strict;
use warnings;
use Carp 'croak';
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;

# Configuration parameters

# HTTP Basic authentication parameters
# These parameters are used to protect access to the provisioning script
# which is made available through HTTP(s)
#
# Authentication username
# Leave empty to disable authentication
my $HTUSER = '';
# Authentication password
# Either an hashed or plain password
# If an hashed password, don't forget to set the $IS_HTPASSWD_HASHED
# parameter value to 1
my $HTPASSWD = '';
# Tells whether or not the provided authentication password is hashed
my $IS_HTPASSWD_HASHED = 0;
# Realm, default to 'SDSPS' (Slave DNS Server Provisioning Service)
my $REALM = 'SDSPS';

# Please don't edit anything below this line

sub createHtpasswdFile
{
    $HTUSER =~ /:/ or croak( "htpasswd: username contains illegal character ':'" );

    require iMSCP::Crypt;
    iMSCP::File
        ->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/sdsp/.htpasswd" )
        ->set( "$HTUSER:" . ( $IS_HTPASSWD_HASHED ? $HTPASSWD : iMSCP::Crypt::htpasswd( $HTPASSWD ) ))
        ->save()
        ->owner( "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}", "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}" )
        ->mode( 0640 );
}

iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub
{
    my ( $tplContent, $tplName ) = @_;

    return unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    my $locationSnippet = <<"EOF";
    location ^~ /sdsp/ {
        root /var/www/imscp/gui/public;
        location ~ \\.php\$ {
            include imscp_fastcgi.conf;
            satisfy any;
            deny all;
            auth_basic "$REALM";
            auth_basic_user_file $::imscpConfig{'GUI_PUBLIC_DIR'}/sdsp/.htpasswd;
        }
    }
EOF
    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . "$locationSnippet\n"
            . "    # SECTION custom END.\n",
        $tplContent
    );
} ) if $HTUSER ne '' && $HTPASSWD ne '';

iMSCP::EventManager->getInstance()->register( 'afterFrontEndInstall', sub
{
    # Make sure to start with a clean directory
    iMSCP::Dir
        ->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/sdsp" )
        ->remove()
        ->make( {
            user  => "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}",
            group => "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}",
            mode  => 0550
        } );

    createHtpasswdFile() if length $HTUSER && length $HTPASSWD;

    iMSCP::File
        ->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/sdsp/sdsps.php" )
        ->set( do { local $/, scalar readline( DATA ) } )
        ->save()
        ->owner( "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}", "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}" )
        ->mode( 0640 );
} );

1;
__DATA__
<?php
use iMSCP_Registry as Registry;

try {
  chdir(__DIR__);
  require '../../library/imscp-lib.php';

  $config = Registry::get('config');

  $zones[$config['BASE_SERVER_VHOST']] = [
    'masters' => [ $config['BASE_SERVER_PUBLIC_IP'] ],
    'allow-notify' => [ $config['BASE_SERVER_IP'] ]
  ];

  $stmt = exec_query(
    "
      SELECT domain_name FROM domain WHERE domain_status <> 'todelete'
      UNION ALL
      SELECT alias_name FROM domain_aliasses WHERE alias_status <> 'todelete'
    "
  );

  while($zone = $stmt->fetchRow(\PDO::FETCH_COLUMN)) {
   $zones[$zone] = [
     'masters' => [ $config['BASE_SERVER_PUBLIC_IP'] ],
     'allow-notify' => [ $config['BASE_SERVER_IP'] ]
   ];
  }

  $zones = json_encode($zones);
} catch( Exception $e ) {
  $zones = '{}
  http_response_code(500);
}

header('Content-Type: application/json');
header('Content-Length: ' . mb_strlen($zones)');
echo $zones;
session_destroy();
