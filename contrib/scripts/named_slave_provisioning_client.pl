#!/usr/bin/env perl

# i-MSCP Slave Server Provisioning client
# Copyright (C) 2016-2018 Laurent Declercq <l.declercq@nuxwin.com>
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

# This script is meant to be used on a slave DNS server as a client of the
# i-MSCP  slave DNS server provisioning service which is provided by the
# i-MSCP 10_named_slave_provisioning listener file. It allows to pull new DNS
# zone definitions from an i-MSCP server and update the slave DNS server
# configuration accordingly.
#
# This script creates and maintains state files to prevent unnecessary updates
# of the slave DNS server configuration. There is exactly one state file per
# i-MSCP server.
#
# HOWTO SETUP
#
# Master DNS server side (i-MSCP server)
#
# 1. Install the 10_named_slave_provisioning.pl listener file which is provided in
#    the ./contrib/Listeners/Named directory of the i-MSCP archive:
#    # cp <imscp_archive_dir>/contrib/Listeners/Named/10_named_slave_provisioning.pl /etc/imscp/listeners.d/
# 2. Edit the /etc/imscp/listener.d/10_named_slave_provisioning.pl listener file and fill the configuration
#    variables
# 3. Trigger an i-MSCP reconfiguration to activate the slave DNS server provisioning service:
#    # perl /var/www/imscp/engine/setup/imscp-reconfigure -dsnv 
#
# Slave DNS server side
#
# 1. Install the required packages:
#    apt-get update && apt-get --no-install-recommends install cron bind9 libdigest-md5-file-perl libwww-perl
# 2. Copy this script into the /usr/local/sbin/named_slave_provisioning.pl 
#    directory with permissions root:root 0750
# 3. Add a cron task in the crontab(1) file of the root user such as:
#    */5 * * * * named_slave_provisioning.pl <NAME> <SRV_URI> [<HTUSER> <HTPASSWORD>]
#
# where:
#
# <NAME> must be an unique server name, that is the hostname (hostname -f) of an i-MSCP server
# <SRV_URI> must be the URI of the slave provisioning service such as https://<panel.domain.tld>:8443/provisioning/slave_provisioning.php
# Only if the slave server provisioning service is protected via basic authentication:
# <HTUSER>, Htuser as set in the 10_named_slave_provisioning.pl listener file on the i-MSCP server
# <HTPASSWORD> Htpassword as set in the 10_named_slave_provisioning.pl listener file on the i-MSCP server
# 
# for instance:
#  */5 * * * * named_slave_provisioning.pl srv01.bbox.nuxwin.com https://panel.bbox.nuxwin.com:8443/provisioning/slave_provisioning.php username password
#
# If you have many i-MSCP servers for which you want make that server the slave
# DNS server, you need just repeat the above steps. You need one cron task per
# i-MSCP server.

use strict;
use warnings;
use Digest::MD5::File qw/ md5_hex file_md5_hex /;
use File::Temp;
use File::Copy;
use HTTP::Request::Common;
use LWP::UserAgent;

my $NAME = shift or die( 'You must provide an unique name as first argument' );
my $SRV_URI = shift or die( 'You must provide the slave DNS service provisioning URL as second argument' );
my ( $HTUSER, $HTPASSWD ) = @ARGV;
my $BIND_CONFDIR = '/etc/bind';
my $BIND_LOCAL_CONFFILE = "$BIND_CONFDIR/named.conf.local";
my $STATEDIR = '/var/local/imscp';

sub readFile
{
    my ( $file ) = @_;

    open my $fh, '<', $file or die( sprintf( "Couldn't open the '%s' file for reading: %s", $file, $! ));
    local $/;
    my $fileContent = <$fh>;
    $fh->close();
    \$fileContent;
}

sub writeFile
{
    my ( $file, $content ) = @_;

    open my $fh, '>', $file or die( sprintf( "Couldn't open the '%s' file for writing: %s", $file, $! ));
    print { $fh } $content;
    $fh->close();
}

## Main

my $request = GET $SRV_URI;
$request->authorization_basic( $HTUSER, $HTPASSWD );

my $ua = LWP::UserAgent->new();
$ua->timeout( 5 );
$ua->agent( 'i-MSCP/1.0 (+https://i-mscp.net/)' );
$ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 ); # handle case of self-signed SSL certificate;

my $response = $ua->request( $request );
$response->is_success or die( sprintf( "Couldn't pull the DNS zone definitions for %s: %s", $NAME, $response->status_line ));

my $zoneFile = File::Temp->new();
print { $zoneFile } $response->decoded_content;
$zoneFile->flush();

my $stateFile = $STATEDIR . '/' . md5_hex( $SRV_URI );
my $stateFileMD5SUM = file_md5_hex( $zoneFile ) . "\n";
my $zoneDefinitionsFile = "$BIND_CONFDIR/$NAME.local";

if ( -f $zoneDefinitionsFile && -f $stateFile && $stateFileMD5SUM eq ${ readFile( $stateFile ) } ) {
    printf( "The %s zone definitions file is already up-to-date. Aborting...\n", $zoneDefinitionsFile );
    exit 0;
}

copy( "$zoneFile", $zoneDefinitionsFile ) or die( sprintf( "Couldn't install the '%s' zone definitions file: %s", $zoneDefinitionsFile, $! ));
mkdir( $STATEDIR, 0027 ) or die( sprintf( " Couldn't create the '%s' state directory: %s", $STATEDIR, $! )) unless -d $STATEDIR;
writeFile( $stateFile, $stateFileMD5SUM );

my $localConffile = File::Temp->new();
copy( $BIND_LOCAL_CONFFILE, $localConffile ) or die( sprintf( "Couldn't copy the current bind9 local configuration file: %s", $! ));

my $localConffileContent = ${ readFile( $localConffile ) };
$localConffileContent =~ s%^include\s+"\Q$zoneDefinitionsFile\E";\n%%gim;
$localConffileContent .= "include \"$zoneDefinitionsFile\";\n";

writeFile( $localConffile, $localConffileContent );
copy( $localConffile, $BIND_LOCAL_CONFFILE ) or die( $! );
system( 'service bind9 reload' );

1;
__END__
