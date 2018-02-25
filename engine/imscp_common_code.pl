#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
#
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
# License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is "VHCS - Virtual Hosting Control System".
#
# The Initial Developer of the Original Code is moleSoftware GmbH.
# Portions created by Initial Developer are Copyright (C) 2001-2006
# by moleSoftware GmbH. All Rights Reserved.
#
# Portions created by the ispCP Team are Copyright (C) 2006-2010 by
# isp Control Panel. All Rights Reserved.
#
# Portions created by the i-MSCP Team are Copyright (C) 2010-2018 by
# internet Multi Server Control Panel. All Rights Reserved.

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
$::imscp_pkt_mngr = "$::root_dir/engine/imscp-pkt-mngr";
$::imscp_pkt_mngr_el = "$::log_dir/imscp-pkt-mngr.el";
$::imscp_pkt_mngr_stdout = "$::log_dir/imscp-pkt-mngr.stdout";
$::imscp_pkt_mngr_stderr = "$::log_dir/imscp-pkt-mngr.stderr";

$::imscp_sw_mngr = "$::root_dir/engine/imscp-sw-mngr";
$::imscp_sw_mngr_el = "$::log_dir/imscp-sw-mngr.el";
$::imscp_sw_mngr_stdout = "$::log_dir/imscp-sw-mngr.stdout";
$::imscp_sw_mngr_stderr = "$::log_dir/imscp-sw-mngr.stderr";

1;
__END__
