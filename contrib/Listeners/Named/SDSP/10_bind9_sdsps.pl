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
#
# The service provided by this listener must be consumed by the SDSPC client.

# HOWTO SETUP
#
# 1. Install the 10_bind9_sdsps.pl listener file:
#    # cp <imscp_archive_dir>/contrib/Listeners/Named/SDSP/10_bind9_sdsps.pl /etc/imscp/listeners.d/
# 2. Edit the /etc/imscp/listener.d/10_bind9_sdsps.pl listener file and fill the configuration
#    variables
# 3. Trigger an i-MSCP reconfiguration to activate the service:
#    # perl /var/www/imscp/engine/setup/imscp-reconfigure -dsnv 

package Listener::Named::SDSPS;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::TemplateParser;

#
## Configuration parameters
#

## HTTP Basic authentication parameters
## These parameters are used to protect access to the provisioning script
## which is made available through HTTP(s)
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

#
## Please don't edit anything below this line
#

sub createHtpasswdFile
{
    if ( $HTUSER =~ /:/ ) {
        error( "htpasswd: username contains illegal character ':'" );
        return 1;
    }

    require iMSCP::Crypt;
    my $file = iMSCP::File->new( filename => "$main::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/.htpasswd" );
    $file->set( "$HTUSER:" . ( $IS_HTPASSWD_HASHED ? $HTPASSWD : iMSCP::Crypt::htpasswd( $HTPASSWD ) ));

    my $rs = $file->save();
    $rs ||= $file->owner(
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}"
    );
    $rs ||= $file->mode( 0640 );
}

iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub
{
    my ( $tplContent, $tplName ) = @_;

    return 0 unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    my $locationSnippet = <<"EOF";
    location ^~ /sdsps/ {
        root /var/www/imscp/gui/public;
        location ~ \\.php\$ {
            include imscp_fastcgi.conf;
            satisfy any;
            deny all;
            auth_basic "$REALM";
            auth_basic_user_file $main::imscpConfig{'GUI_PUBLIC_DIR'}/sdsps/.htpasswd;
        }
    }
EOF
    ${ $tplContent } = replaceBloc( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", "    # SECTION custom BEGIN.\n"
        . getBloc( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", ${ $tplContent } )
        . "$locationSnippet\n"
        . "    # SECTION custom END.\n",
        ${ $tplContent }
    );
    0;
} ) if $HTUSER ne '';

iMSCP::EventManager->getInstance()->register( 'afterFrontEndInstall', sub
{
    my $rs = eval {
        # Make sure to start with a clean directory
        my $dir = iMSCP::Dir->new( dirname => "$main::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning" );
        $dir->remove();
        $dir->make( {
            user  => "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}",
            group => "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}",
            mode  => 0550
        } );
    };
    if ( $@ ) {
        error( $@ );
        $rs = 1;
    }

    $rs ||= createHtpasswdFile() if $HTUSER ne '';
    return $rs if $rs;

    my $file = iMSCP::File->new( filename => "$main::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/slave_provisioning.php" );
    $file->set( <DATA> );
    $rs = $file->save();
    $rs ||= $file->owner(
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}"
    );
    $rs ||= $file->mode( 0640 );
} );

__END__
<?php
use iMSCP_Registry as Registry;

try {
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

  header('Content-Type: application/json');
  echo json_encode($zones);
} catch( Exception \$e ) {
  http_response_code(500);
  header('Content-Type: application/json');
  echo '[]';
}
