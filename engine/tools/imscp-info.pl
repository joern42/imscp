#!/usr/bin/perl

=head1 NAME

 imscp-info.pl - Display information about i-MSCP instance

=head1 SYNOPSIS

 perl imscp-info.pl [OPTION]...

=cut

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
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../PerlLib";
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ output /;
use iMSCP::Getopt;
use iMSCP::Servers;
use JSON qw/ to_json /;

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Display information about i-MSCP instance.

OPTIONS:
 -v,    --version-only  Display i-MSCP version info only.
 -s,    --system-only   Display i-MSCP system info only.
 -j,    --json          Display output in JSON format.},
    'version-only|v' => \&iMSCP::Getopt::versionOnly,
    'server-only|s'  => \&iMSCP::Getopt::serverOnly,
    'json|j'         => \&iMSCP::Getopt::json
);

iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
} );

iMSCP::Getopt->debug( 0 );

if ( iMSCP::Getopt->versionOnly && iMSCP::Getopt->serverOnly ) {
    print "\nThe --version-only and --system-only options are mutually exclusive\n";
    iMSCP::Getopt->showUsage();
}

my $json = {} if iMSCP::Getopt->json;

unless ( iMSCP::Getopt->serverOnly ) {
    if ( iMSCP::Getopt->json ) {
        $json->{'build_date'} = $::imscpConfig{'BuildDate'} || 'Unreleased';
        $json->{'version'} = $::imscpConfig{'Version'};
        $json->{'codename'} = $::imscpConfig{'CodeName'};
        $json->{'plugin_api'} = $::imscpConfig{'PluginApi'};
    } else {
        print <<'EOF';

#################################################################
###                    i-MSCP Version Info                    ###
#################################################################

EOF
        print output "Build date                       : @{ [ $::imscpConfig{'BuildDate'} || 'Unreleased' ] }", 'info';
        print output "Version                          : $::imscpConfig{'Version'}", 'info';
        print output "Codename                         : $::imscpConfig{'CodeName'}", 'info';
        print output "Plugin API                       : $::imscpConfig{'PluginApi'}", 'info';
    }
}

if ( iMSCP::Getopt->versionOnly ) {
    print to_json( $json, { utf8 => 1, pretty => 1 } ) if iMSCP::Getopt->json;
    exit;
}

unless ( iMSCP::Getopt->json ) {
    print <<'EOF';

#################################################################
###                    i-MSCP System Info                     ###
#################################################################

EOF

    print output "Daemon type for backend requests : $::imscpConfig{'DAEMON_TYPE'}", 'info';
    print "\n";
} else {
    $json->{'daemon_type'} = $::imscpConfig{'DAEMON_TYPE'};
}

for my $server ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    my $srvInstance = $server_->factory();

    if ( iMSCP::Getopt->json ) {
        $json->{'servers'}->{$server} = {
            implementation => ref $srvInstance,
            version        => $srvInstance->getImplVersion(),
            internal_name  => $srvInstance->getServerName(),
            human_name     => $srvInstance->getHumanServerName(),
            priority       => $srvInstance->getPriority()
        };
        next;
    }

    print output "Server                           : $server", 'info';
    print output "Server implementation            : @{ [ ref $srvInstance ] }", 'info';
    print output "Server implementation version    : @{ [ $srvInstance->getImplVersion() ] }", 'info';
    print output "Server name for internal use     : @{ [ $srvInstance->getServerName() ] }", 'info';
    print output "Server human name                : @{ [ $srvInstance->getHumanServerName() ] }", 'info';
    print output "Server priority for processing   : @{ [ $srvInstance->getPriority() ] }", 'info';
    print "\n";
}

print to_json( $json, { utf8 => 1, pretty => 1 } ) if iMSCP::Getopt->json;

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
