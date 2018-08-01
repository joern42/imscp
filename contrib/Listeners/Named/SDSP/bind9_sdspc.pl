#!/usr/bin/env perl

# i-MSCP Slave DNS Server Provisioning client (SDSPC)
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

# This script is meant to be used on a slave DNS server as a client of the
# i-MSCP slave DNS server provisioning service (SDSPS) which is provided by
# the i-MSCP 10_bind9_sdsps.pl listener file. It allows to pull new DNS zone
# definitions from an i-MSCP server and update the slave DNS server
# configuration accordingly.
#
# This script creates and maintains state files to prevent unnecessary updates
# of the slave DNS server configuration. There is exactly one state file per
# i-MSCP server. It also remove DB zone files when necessary.
#
# HOWTO SETUP
#
# Master DNS server side (Slave DNS server provisioning service (SDSPS))
#
# 1. Install the 10_bind9_sdsps.pl listener file:
#    # cp <imscp_archive_dir>/contrib/Listeners/Named/SDSP/10_bind9_sdsps.pl /etc/imscp/listeners.d/
# 2. Edit the /etc/imscp/listener.d/10_bind9_sdsps.pl listener file and fill the configuration
#    variables
# 3. Trigger an i-MSCP reconfiguration to activate the service:
#    # perl /var/www/imscp/engine/setup/imscp-reconfigure -dsnv 
#
# Slave DNS server side (Slave DNS server provisioning client (SDSPC))
#
# 1. Install the required packages:
#    # apt-get update
#    # apt-get --no-install-recommends install cron bind9 libdigest-md5-file-perl libwww-perl
# 2. Copy this script into the /usr/local/sbin directory with permissions root:root 0750
#    # cp ./bind9_sdspc.pl /usr/local/sbin
#    # chown root:root /usr/local/sbin/bind9_sdspc.pl
#    # chmod 0750 /usr/local/sbin/bind9_sdspc.pl
# 3. Add a cron task in the crontab(1) file of the root user such as:
#    */5 * * * * bind9_sdspc.pl <NAME> <SRV_URI> [<HTUSER> <HTPASSWORD>]
#
# where:
#
# <NAME> must be an unique server name, that is the hostname (hostname -f) of an i-MSCP server
# <SRV_URI> must be the URI of the slave provisioning service such as https://<panel.domain.tld>:8443/sdsp/sdsps.php
#
# Only if the slave server provisioning service is protected via basic authentication:
# <HTUSER>, Htuser as set in the 10_bind9_sdsps.pl listener file on the i-MSCP server
# <HTPASSWORD> Htpassword as set in the 10_bind9_sdsps.pl listener file on the i-MSCP server
# 
# for instance:
#  */5 * * * * bind9_sdspc.pl srv01.bbox.nuxwin.com https://panel.bbox.nuxwin.com:8443/sdsp/sdsps.php username password
#
# If you have many i-MSCP servers for which you want make that server the slave
# DNS server, you need just repeat the above steps. You need one cron task per
# i-MSCP server.

use strict;
use warnings;
use Digest::MD5::File qw/ md5_hex file_md5_hex /;
use File::Copy;
use File::Path qw/ make_path /;
use File::Temp;
use HTTP::Request::Common;
use JSON;
use LWP::UserAgent;

my $NAME = shift or die( 'You must provide an unique server name as first argument' );
my $SRV_URI = shift or die( 'You must provide the URL for the slave DNS provisioning service as second argument' );
my ( $HTUSER, $HTPASSWD ) = @ARGV;
my $BIND_CONFDIR = '/etc/bind';
my $BIND_LOCAL_CONFFILE = "$BIND_CONFDIR/named.conf.local";
my $BIND_DB_DIR = '/var/cache/bind/sdsp';
my $STATEDIR = '/var/local/imscp';

$SIG{'__WARN__'} = sub { die $_[0] };

sub readFile
{
    my ( $file ) = @_;

    open my $fh, '<', $file or die(
        sprintf( "Couldn't open the '%s' file for reading: %s", $file, $! )
    );
    local $/;
    my $fileContent = <$fh>;
    $fh->close();
    \$fileContent;
}

sub writeFile
{
    my ( $file, $content ) = @_;

    open my $fh, '>', $file or die(
        sprintf( "Couldn't open the '%s' file for writing: %s", $file, $! )
    );
    print $fh $content;
    $fh->close();
}

sub doRequest
{
    my $request = GET $SRV_URI;
    $request->authorization_basic( $HTUSER, $HTPASSWD ) if defined $HTUSER && defined $HTPASSWD;

    my $ua = LWP::UserAgent->new();
    $ua->timeout( 10 );
    $ua->agent( 'SDSPC/1.0 (+https://i-mscp.net/)' );
    $ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 ); # handle case of a self-signed SSL certificate
    $ua->default_header( Accept => 'application/json' );
    $ua->default_header( 'Accept-Encoding' => 'gzip, deflate' );
    $ua->default_header( 'Accept-Charset' => 'utf-8' );

    my $response = $ua->request( $request );
    $response->is_success or die( sprintf( "Request failure for %s: %s\n", $NAME, $response->status_line ));

    json_decode( $response->decoded_content ) or die( sprintf( "Couldn't decode JSON response: %s ", $! ));
}

# Main

my $zones = doRequest();
my $zoneFile = File::Temp->new();

for my $zone ( keys %{ $zones } ) {
    print $zoneFile <<"EOF";
zone "$zone" {
  type slave;
  notify no;
  file "$BIND_DB_DIR/$NAME/$zone.db";
  masterfile-format text;
  masters { @{ [ join '; ', $zones->{$zone}->{'masters'} ] }; };
  allow-notify { @{ [ join '; ', $zones->{$zone}->{'allow-notify'} ] }; };
};
EOF
}

$zoneFile->flush();

my $stateFile = $NAME;
my $stateFileMD5SUM = file_md5_hex( $zoneFile ) . "\n";
my $zoneDefinitionsFile = "$BIND_CONFDIR/$NAME.local";

if ( -f $zoneDefinitionsFile && -f $stateFile && $stateFileMD5SUM eq ${ readFile( $stateFile ) } ) {
    printf( "The '%s' zone definitions file is already synced. Skipping...\n", $zoneDefinitionsFile );
    exit;
}

eval { make_path( "$BIND_DB_DIR/$NAME", { owner => 'bind', group => 'bind', mode => 0750 } ); };
!$@ or die( sprintf( " Couldn't create the '%s' db directory: %s", "$BIND_DB_DIR/$NAME", $@ ));

copy( "$zoneFile", $zoneDefinitionsFile ) or die( sprintf( "Couldn't install/update the '%s' zone definitions file: %s", $zoneDefinitionsFile, $! ));
undef $zoneFile;

eval { make_path( $STATEDIR ) };
!$@ or die( sprintf( " Couldn't create the '%s' state directory: %s", $STATEDIR, $@ ));

writeFile( $stateFile, $stateFileMD5SUM );

my $localConffile = File::Temp->new();
copy( $BIND_LOCAL_CONFFILE, $localConffile ) or die( sprintf( "Couldn't make a copy of the '%s file: %s", $BIND_LOCAL_CONFFILE, $! ));

my $localConffileContent = ${ readFile( $localConffile ) };
$localConffileContent =~ s%^include\s+"\Q$zoneDefinitionsFile\E";\n%%gim;
$localConffileContent .= "include \"$zoneDefinitionsFile\";\n";

writeFile( $localConffile, $localConffileContent );
undef $localConffileContent;

copy( $localConffile, $BIND_LOCAL_CONFFILE ) or die( $! );
undef $localConffile;

# Zones deletion
opendir( my $dh, "$BIND_DB_DIR/$NAME" ) or die( sprintf( "Couldn't open the '%s' directory for readding: %s", "$BIND_DB_DIR/$NAME", $! ));
while ( my $file = readdir $dh ) {
    next if $file =~ /^\.{1,2}\z/s || exists $zones->{ $file =~ s/\.db//r };
    unlink( "$BIND_DB_DIR/$NAME/$file" ) or die( sprintf( "Couldn't delete the '%s' DB zone file: %s", "$BIND_DB_DIR/$NAME/$file", $! ));
}
closedir( $dh );

system( 'service bind9 reload' );

1;
__END__
