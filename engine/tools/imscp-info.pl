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
use Carp::Always;

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq {

Show i-MSCP version and servers info.

OPTIONS:
 -v,    --version-only  Show i-MSCP version info only.
 -s,    --server-only   Show i-MSCP servers info only.},
    'version-only|v'   => \my $versionOnly,
    'server-only|s'   => \my $serverOnly,
);

iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
} );

iMSCP::Getopt->debug( 0 );

if($versionOnly && $serverOnly) {
    print "\nThe --version-only and --server-only options are mutually exclusive\n";
    iMSCP::Getopt->showUsage();
}

unless($serverOnly) {
    print <<'EOF';

#################################################################
###                    i-MSCP Version Info                    ###
#################################################################

EOF

    print output "Build date                            : @{ [ $main::imscpConfig{'BuildDate'} || 'Unreleased' ] }", 'info';
    print output "Version                               : $main::imscpConfig{'Version'}", 'info';
    print output "Codename                              : $main::imscpConfig{'CodeName'}", 'info';
    print output "Plugin API                            : $main::imscpConfig{'PluginApi'}", 'info';

}

exit if $versionOnly;

print <<'EOF';

#################################################################
###                    i-MSCP Servers Info                    ###
#################################################################

EOF

for ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    my $srvInstance = $_->factory();

    print output "Server abstract implementation        : $_", 'info';
    print output "Server croncrete implementation       : @{ [ ref $srvInstance ] }", 'info';
    print output "Server implementation version         : @{ [ $srvInstance->getImplVersion() ] }", 'info';
    print output "Server name for event names construct : @{ [ $srvInstance->getEventServerName() ] }", 'info';
    print output "Server human name                     : @{ [ $srvInstance->getHumanServerName() ] }", 'info';
    print output "Server priority                       : @{ [ $srvInstance->getPriority() ] }", 'info';
    print "\n";
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
