#!/usr/bin/perl -T

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
#    # perl /var/www/imscp/engine/bin/imscp-reconfigure -dsnv 
#
# Slave DNS server side (Slave DNS server provisioning client (SDSPC))
#
# 1. Install the required packages:
#    # apt-get update
#    # apt-get --no-install-recommends install cron bind9 libdigest-md5-file-perl libwww-perl libjson-perl libjson-xs-perl
# 2. Copy this script into the /usr/local/sbin directory with permissions root:root 0750
#    # cp ./imscp_bind9_sdspc.pl /usr/local/sbin
#    # chown root:root /usr/local/sbin/imscp_bind9_sdspc.pl
#    # chmod 0750 /usr/local/sbin/imscp_bind9_sdspc.pl
# 3. Create the /etc/imscp-sdspc.conf configuration file with permissions root:root 0750
#    # touch /etc/imscp-sdspc.conf
#    # chmod 0750 /etc/imscp-sdspc.conf
# 4. Add a configuration line for each i-MSCP server in the /etc/imscp-sdspc.conf configuration file such as:
#    <NAME> <SRV_URI> [<HTUSER> <HTPASSWORD>]
#    where:
#     <NAME> must be an unique server name, that is the hostname (hostname -f) of an i-MSCP server
#     <SRV_URI> must be the URI of the slave provisioning service such as https://<panel.domain.tld>:8443/sdsp/sdsps.php
#     Only if the SDSP service is protected via basic authentication:
#     <HTUSER>, Htuser as set in the 10_bind9_sdsps.pl listener file on the i-MSCP server
#     <HTPASSWORD> Htpassword as set in the 10_bind9_sdsps.pl listener file on the i-MSCP server
#    for instance:
#     srv01.bbox.nuxwin.com https://panel1.bbox.nuxwin.com:8443/sdsp/sdsps.php username password
#     srv02.bbox.nuxwin.com https://panel2.bbox.nuxwin.com:8443/sdsp/sdsps.php username password
#     srv03.bbox.nuxwin.com https://panel3.bbox.nuxwin.com:8443/sdsp/sdsps.php username password
# 4. Add a cron task in the crontab(1) file of the root user:
#    */5 * * * * imscp_bind9_sdspc.pl
#
# HOWTO remove an i-MSCP server
#
# For each server you want to remove, you need in order:
#
# 1. Remove the cron task from the crontab(1) file of the root user
# 2. Edit the /etc/bind/named.conf.local file to remove the include stanza for the the server
# 3. Remove the /etc/bind/<NAME>.conf file
# 4. Remove the /var/cache/bind/imscp-sdsp/<NAME> directory
# 5. Remove the /var/local/imscp-sdsp/<NAME> file
#
# where:
#
# <NAME> is the unique server name, that is the hostname (hostname -f) of the i-MSCP server

use strict;
use warnings;
use Digest::MD5::File qw/ md5_hex file_md5_hex /;
use File::Copy;
use File::Path 'make_path';
use File::Temp;
use HTTP::Request::Common;
use JSON;
use LWP::UserAgent;

my $SDSPC_CONFFILE = '/etc/imscp-sdspc.conf';
my $SDSPC_STATEDIR = '/var/local/imscp-sdsp';
my $BIND_SNAME = 'bind9';
my $BIND_SERVICE_PATTERN = '/usr/sbin/named';
my $BIND_OWNER = 'bind';
my $BIND_GROUP = 'bind';
my $BIND_CONFDIR = '/etc/bind';
my $BIND_DB_DIR = '/var/cache/bind/imscp-sdsp';
my $BIND_LOCAL_CONFFILE = "$BIND_CONFDIR/named.conf.local";
my $BIND_DB_FILE_FORMAT = 'text';

$SIG{'__WARN__'} = sub { die $_[0] };

sub readConfig
{
    unless ( -f $SDSPC_CONFFILE ) {
        printf( "No '%s' configuration file found. Aborting...\n", $SDSPC_CONFFILE );
        exit;
    }

    my %config = ();
    open my $fh, '<', $SDSPC_CONFFILE or die( sprintf( "Couldn't open the '%s' file for reading: %s", $SDSPC_CONFFILE, $! ));
    while ( my $line = $fh ) {
        next if $line =~ /^(?:#|$)/; # Ignore comment and empty lines
        chomp $line;
        my ( $name, $uri, $htuser, $htpasswd ) = split /\s+/, $line;
        $config{$name} = {
            name     => $name,
            uri      => $uri,
            htuser   => $htuser,
            htpasswd => $htpasswd
        };
    }
    close( $fh );

    \%config;
}

sub readFile
{
    my ( $file ) = @_;

    open my $fh, '<', $file or die( sprintf( "Couldn't open the '%s' file for reading: %s", $file, $! ));
    local $/;
    my $fileC = <$fh>;
    $fh->close();
    \$fileC;
}

sub writeFile
{
    my ( $file, $content ) = @_;

    open my $fh, '>', $file or die( sprintf( "Couldn't open the '%s' file for writing: %s", $file, $! ));
    print $fh $content;
    $fh->close();
}

sub doRequest
{
    my ( $name, $uri, $htuser, $htpasswd ) = @_;

    my $request = GET $uri;
    $request->authorization_basic( $htuser, $htpasswd ) if defined $htuser && defined $htpasswd;

    my $ua = LWP::UserAgent->new();
    $ua->timeout( 10 );
    $ua->agent( 'SDSPC/1.0 (+https://i-mscp.net/)' );
    $ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 ); # handle case of a self-signed SSL certificate
    $ua->default_header( Accept => 'application/json' );
    $ua->default_header( 'Accept-Encoding' => 'gzip, deflate' );
    $ua->default_header( 'Accept-Charset' => 'utf-8' );

    my $response = $ua->request( $request );
    $response->is_success or die( sprintf( "Request failure for %s: %s\n", $name, $response->status_line ));

    json_decode( $response->decoded_content ) or die( sprintf( "Couldn't decode JSON response: %s ", $! ));
}

sub deleteZones
{
    my ( $name, $zones ) = @_;

    opendir( my $dh, "$BIND_DB_DIR/$name" ) or die( sprintf( "Couldn't open the '%s' directory for readding: %s", "$BIND_DB_DIR/$name", $! ));
    while ( my $file = readdir $dh ) {
        next if $file =~ /^\.{1,2}\z/s || exists $zones->{ $file =~ s/\.db//r };
        unlink( "$BIND_DB_DIR/$name/$file" ) or die( sprintf( "Couldn't delete the '%s' DB zone file: %s", "$BIND_DB_DIR/$name/$file", $! ));
    }
    closedir( $dh );
}

sub IsNamedRunning
{
    open my $fh, '-|', 'ps -ef' or croak( sprintf( "Couldn't pipe to %s: %s", 'ps -ef', $! ));
    while ( my $line = <$fh> ) {
        next unless $line =~ /$BIND_SERVICE_PATTERN/;
        return ( split /\s+/, $line =~ s/^\s+//r )[1];
    }

    undef;
}

# Main

my $config = readConfig();

for my $name ( sort keys %{ $config } ) {
    eval {
        my $zones = doRequest( $name, $config->{$name}->{'uri'}, $config->{$name}->{'htuser'}, $config->{$name}->{'htpasswd'} );
        my $zoneFile = File::Temp->new();

        for my $zone ( keys %{ $zones } ) {
            print $zoneFile <<"EOF";
zone "$zone" {
  type slave;
  notify no;
  file "$BIND_DB_DIR/$name/$zone.db";
  masterfile-format $BIND_DB_FILE_FORMAT;
  masters { @{ [ join '; ', $zones->{$zone}->{'masters'} ] }; };
  allow-notify { @{ [ join '; ', $zones->{$zone}->{'allow-notify'} ] }; };
};
EOF
        }

        $zoneFile->flush();

        my $stateFile = "$SDSPC_STATEDIR/$name";
        my $stateFileMD5SUM = file_md5_hex( $zoneFile ) . "\n";
        my $zoneDefinitionsFile = "$BIND_CONFDIR/$name.local";

        if ( -f $zoneDefinitionsFile && -f $stateFile && $stateFileMD5SUM eq ${ readFile( $stateFile ) } ) {
            printf( "The zone definitions file for '%s' is already synced. Skipping...\n", $zoneDefinitionsFile );
            return;
        }

        eval { make_path( "$BIND_DB_DIR/$name", { owner => $BIND_OWNER, group => $BIND_GROUP, mode => 0750 } ); };
        !$@ or die( sprintf( " Couldn't create the '%s' db directory: %s", "$BIND_DB_DIR/$name", $@ ));

        copy( "$zoneFile", $zoneDefinitionsFile ) or die( sprintf( "Couldn't install the new '%s' zone definitions file: %s", $zoneDefinitionsFile, $! ));
        undef $zoneFile;

        eval { make_path( $SDSPC_STATEDIR ) };
        !$@ or die( sprintf( " Couldn't create the '%s' state directory: %s", $SDSPC_STATEDIR, $@ ));
        writeFile( $stateFile, $stateFileMD5SUM );

        my $localConffile = File::Temp->new();
        copy( $BIND_LOCAL_CONFFILE, $localConffile ) or die( sprintf( "Couldn't make a copy of the '%s file: %s", $BIND_LOCAL_CONFFILE, $! ));

        my $localConffileContent = ${ readFile( $localConffile ) };
        $localConffileContent =~ s%^include\s+"\Q$zoneDefinitionsFile\E";\n%%gim;
        $localConffileContent .= <<"EOF";
include "$zoneDefinitionsFile";
EOF

        writeFile( $localConffile, $localConffileContent );
        undef $localConffileContent;

        copy( $localConffile, $BIND_LOCAL_CONFFILE ) or die( $! );
        undef $localConffile;

        deleteZone( $name, $zones );
    };
    if ( $@ ) {
        print STDERR $@;
    }
}

system( "service $BIND_SNAME @{ [ IsNamedRunning() ? 'reload' : 'start' ] }" );

1;
__END__
