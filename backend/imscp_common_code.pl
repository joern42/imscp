#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
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
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

use strict;
use warnings;
no warnings 'once';

$::engine_debug = undef;

require 'imscp_common_methods.pl';

# Load i-MSCP configuration from the imscp.conf file
if ( -f '/usr/local/etc/imscp/imscp.conf' ) {
    $::cfg_file = '/usr/local/etc/imscp/imscp.conf';
} else {
    $::cfg_file = '/etc/imscp/imscp.conf';
}

my $rs = get_conf( $::cfg_file );
die( 'FATAL: Unable to load imscp.conf file.' ) if $rs;

# Enable debug mode if needed
if ( $::cfg{'DEBUG'} ) {
    $::engine_debug = '_on_';
}

# Load i-MSCP key and initialization vector
my $keyFile = "$::cfg{'CONF_DIR'}/imscp-db-keys.pl";
$::imscpKEY = '{KEY}';
$::imscpIV = '{IV}';

eval { require "$keyFile"; };

# Check for i-MSCP Db key and initialization vector
if ( $@
    || $::imscpKEY eq '{KEY}'
    || length( $::imscpKEY ) != 32
    || $::imscpIV eq '{IV}'
    || length( $::imscpIV ) != 16
) {
    print STDERR ( "Missing or invalid keys file. Run the imscp-reconfigure script to fix." );
    exit 1;
}

die( "FATAL: Couldn't load database parameters" ) if setup_db_vars();

# Lock file system variables
$::lock_file = '/tmp/imscp.lock';
$::fh_lock_file = undef;

$::log_dir = $::cfg{'LOG_DIR'};
$::root_dir = $::cfg{'ROOT_DIR'};
$::imscp = "$::log_dir/imscp-rqst-mngr.el";

# imscp-serv-traff variable
$::imscp_srv_traff_el = "$::log_dir/imscp-srv-traff.el";

# Software installer log variables
$::imscp_pkt_mngr = "$::root_dir/backend/imscp-pkt-mngr";
$::imscp_pkt_mngr_el = "$::log_dir/imscp-pkt-mngr.el";
$::imscp_pkt_mngr_stdout = "$::log_dir/imscp-pkt-mngr.stdout";
$::imscp_pkt_mngr_stderr = "$::log_dir/imscp-pkt-mngr.stderr";

$::imscp_sw_mngr = "$::root_dir/backend/imscp-sw-mngr";
$::imscp_sw_mngr_el = "$::log_dir/imscp-sw-mngr.el";
$::imscp_sw_mngr_stdout = "$::log_dir/imscp-sw-mngr.stdout";
$::imscp_sw_mngr_stderr = "$::log_dir/imscp-sw-mngr.stderr";

1;
__END__
