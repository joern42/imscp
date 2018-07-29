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

package Listener::Named::Slave::Provisioning;

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

iMSCP::EventManager->getInstance()->register( 'afterFrontEndBuildConfFile', sub {
    my ( $tplContent, $tplName ) = @_;

    return 0 unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    my $locationSnippet = <<"EOF";
    location ^~ /provisioning/ {
        root /var/www/imscp/gui/public;

        location ~ \\.php\$ {
            include imscp_fastcgi.conf;
            satisfy any;
            deny all;
            auth_basic "$REALM";
            auth_basic_user_file $main::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning/.htpasswd;
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
    my $fileContent = <<'EOF';
<?php
use iMSCP_Registry as Registry;

require '../../library/imscp-lib.php';

$config = Registry::get('config');

if(Registry::isRegistered('bufferFilter')) {
    $filter = Registry::get('bufferFilter');
    $filter->compressionInformation = false;
}

print <<<"EOT"
zone "{$config['BASE_SERVER_VHOST']}" {
  type slave;
  file "/var/cache/bind/{$config['BASE_SERVER_VHOST']}.db";
  masters { {$config['BASE_SERVER_PUBLIC_IP']}; };
  allow-notify { {$config['BASE_SERVER_PUBLIC_IP']}; };
};

EOT;

$stmt = exec_query(
    "
        SELECT domain_name FROM domain WHERE domain_status <> 'todelete'
        UNION ALL
        SELECT alias_name FROM domain_aliasses WHERE alias_status <> 'todelete'
    "
);

while ($row = $stmt->fetchRow()) {
    if($row['domain_name'] == $config['BASE_SERVER_VHOST']) {
        continue;
    }

print <<<"EOT"

zone "{$row['domain_name']}" {
  type slave;
  file "/var/cache/bind/{$row['domain_name']}.db";
  masters { {$config['BASE_SERVER_PUBLIC_IP']}; };
  allow-notify { {$config['BASE_SERVER_PUBLIC_IP']}; };
};

EOT;

}
EOF
    my $rs = eval {
        iMSCP::Dir->new( dirname => "$main::imscpConfig{'GUI_PUBLIC_DIR'}/provisioning" )->make( {
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
    $file->set( $fileContent );

    $rs = $file->save();
    $rs ||= $file->owner(
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}",
        "$main::imscpConfig{'SYSTEM_USER_PREFIX'}$main::imscpConfig{'SYSTEM_USER_MIN_UID'}"
    );
    $rs ||= $file->mode( 0640 );
} );

1;
__END__
