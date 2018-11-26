# i-MSCP Listener::Named::Slave::Provisioning listener file
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

# Provides slave DNS server provisioning service.
# This listener file requires i-MSCP 1.2.12 or newer.
# Slave provisioning service will be available at:
# - http://<panel.domain.tld>:8080/provisioning/slave_provisioning.php
# - https://<panel.domain.tld>:4443/provisioning/slave_provisioning.php
#
# Please don't use that listener file with the i-MSCP SDSP client.

package Listener::Named::Slave::Provisioning;

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
my $REALM = 'Slave DNS server provisioning service';

# Slave DNS zone file format
# Possible values: text, raw
# See NAMED-CHECKZONE(8)
my $DB_FILE_FORMAT = 'raw';

# Please don't edit anything below this line

sub createHtpasswdFile
{
    $HTUSER =~ /:/ or croak( "htpasswd: username contains illegal character ':'" );

    require iMSCP::Crypt;
    iMSCP::File
        ->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/.htpasswd" )
        ->set( "$HTUSER:" . ( $IS_HTPASSWD_HASHED ? $HTPASSWD : iMSCP::Crypt::htpasswd( $HTPASSWD ) ))
        ->save()
        ->owner( "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}", "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}"
    )->mode( 0640 );
}

iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub
{
    my ( $tplContent, $tplName ) = @_;

    return unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    my $locationSnippet = <<"EOF";
    location ^~ /provisioning/ {
        root /var/www/imscp/gui/public;
        location ~ \\.php\$ {
            include imscp_fastcgi.conf;
            satisfy any;
            deny all;
            auth_basic "$REALM";
            auth_basic_user_file $::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/.htpasswd;
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
        ->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning" )
        ->remove()
        ->make( {
        user  => "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}",
        group => "$::imscpConfig{'USER_PREFIX'}$::imscpConfig{'USER_MIN_UID'}",
        mode  => 0550
    } );

    createHtpasswdFile() if length $HTUSER && length $HTPASSWD;

    iMSCP::File
        ->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/slave_provisioning.php" )
        ->set( do { local $/, ( scalar readline( DATA ) =~ s/\{DB_FILE_FORMAT\}/$DB_FILE_FORMAT/gmr ) } )
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

  if(Registry::isRegistered('bufferFilter')) {
    $filter = Registry::get('bufferFilter');
    $filter->compressionInformation = false;
  }

  $zones = $stmt = exec_query(
    "
      SELECT domain_name FROM domain WHERE domain_status <> 'todelete'
      UNION ALL
      SELECT alias_name FROM domain_aliasses WHERE alias_status <> 'todelete'
    "
  )->fetchAll(\PDO::FETCH_COLUMN);

  $config = Registry::get('config');
  if(!in_array($config['BASE_SERVER_VHOST'], $zones) {
    $zones[] = $config['BASE_SERVER_VHOST'];
  }

  foreach($zones as $zone) {
    echo <<<"EOT"
zone "{$row['domain_name']}" {
  type slave;
  notify no;
  file "/var/cache/bind/{$row['domain_name']}.db";
  masterfile-format {DB_FILE_FORMAT};
  masters { {$config['BASE_SERVER_PUBLIC_IP']}; };
  allow-notify { {$config['BASE_SERVER_IP']}; };
};

EOT;
  }
} catch(Exception $e) {
    http_response_code(500);
}

session_destroy();
