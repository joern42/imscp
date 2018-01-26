#!/usr/bin/perl

=head1 NAME

 imscp-info.pl [OPTION]... - Display information about current i-MSCP instance

=head1 SYNOPSIS

 perl imscp-info.pl

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq {

Show i-MSCP version and servers info.

OPTIONS:
 -v,    --version-only  Show i-MSCP version info only.
 -s,    --system-only   Show i-MSCP system info only.
 -j,    --json          Show output in JSON format},
    'version-only|v' => \my $versionOnly,
    'server-only|s'  => \my $serverOnly,
    'json|j'         => \my $json,
);

iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
} );

iMSCP::Getopt->debug( 0 );

if ( $versionOnly && $serverOnly ) {
    print "\nThe --version-only and --system-only options are mutually exclusive\n";
    iMSCP::Getopt->showUsage();
}

$json = {} if $json;

unless ( $serverOnly ) {
    if ( defined $json ) {
        $json->{'build_date'} = $main::imscpConfig{'BuildDate'} || 'Unreleased';
        $json->{'version'} = $main::imscpConfig{'Version'};
        $json->{'codename'} = $main::imscpConfig{'CodeName'};
        $json->{'plugin_api'} = $main::imscpConfig{'PluginApi'};
    } else {
        print <<'EOF';

#################################################################
###                    i-MSCP Version Info                    ###
#################################################################

EOF
        print output "Build date                       : @{ [ $main::imscpConfig{'BuildDate'} || 'Unreleased' ] }", 'info';
        print output "Version                          : $main::imscpConfig{'Version'}", 'info';
        print output "Codename                         : $main::imscpConfig{'CodeName'}", 'info';
        print output "Plugin API                       : $main::imscpConfig{'PluginApi'}", 'info';
    }
}

if ( $versionOnly ) {
    print to_json( $json, { utf8 => 1, pretty => 1 } );
    exit;
}

unless ( defined $json ) {
    print <<'EOF';

#################################################################
###                    i-MSCP System Info                     ###
#################################################################

EOF

    print output "Daemon type for backend requests : $main::imscpConfig{'DAEMON_TYPE'}", 'info';
    print "\n";
}

for ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    my $srvInstance = $_->factory();

    if ( $json ) {
        $json->{'servers'}->{$_} = {
            implementation => ref $srvInstance,
            version        => $srvInstance->getImplVersion(),
            internal_name  => $srvInstance->getServerName(),
            human_name     => $srvInstance->getHumanServerName(),
            priority       => $srvInstance->getPriority()
        };
        next;
    }

    print output "Server                           : $_", 'info';
    print output "Server implementation            : @{ [ ref $srvInstance ] }", 'info';
    print output "Server implementation version    : @{ [ $srvInstance->getImplVersion() ] }", 'info';
    print output "Server name for internal use     : @{ [ $srvInstance->getServerName() ] }", 'info';
    print output "Server human name                : @{ [ $srvInstance->getHumanServerName() ] }", 'info';
    print output "Server priority for processing   : @{ [ $srvInstance->getPriority() ] }", 'info';
    print "\n";
}

print to_json( $json, { utf8 => 1, pretty => 1 } ) if defined $json;

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
