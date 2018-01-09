#!/usr/bin/perl

=head1 NAME

 imscp-info - Display information about i-MSCP installation

=head1 SYNOPSIS

 imscp-mountall [options]... start|stop

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
use lib "$FindBin::Bin/../PerlLib";
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ output /;
use iMSCP::Servers;
use iMSCP::Getopt;

iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    mode            => 'backend',
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
} );

iMSCP::Getopt->verbose( 1 );

print <<'EOF';

#################################################################
###                    iMSCP Version Info                     ###
#################################################################

EOF

print output "Build date                            : @{ [ $main::imscpConfig{'BuildDate'} || 'Unreleased' ] }", 'info';
print output "Version                               : $main::imscpConfig{'Version'}", 'info';
print output "Codename                              : $main::imscpConfig{'CodeName'}", 'info';
print output "Plugin API                            : $main::imscpConfig{'PluginApi'}", 'info';

print <<'EOF';

#################################################################
###                    iMSCP Servers Info                     ###
#################################################################

EOF

for ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    print output "Server abstract implementation        : $_", 'info';
    print output "Server croncrete implementation       : @{[ref $_->factory() ]}", 'info';
    print output "Server implementation version         : @{[ $_->factory()->getImplVersion() ]}", 'info';
    print output "Server name for event names construct : @{[ $_->factory()->getEventServerName() ]}", 'info';
    print output "Server human name                     : @{[ $_->factory()->getHumanServerName() ]}", 'info';
    print output "Server priority                       : @{[ $_->factory()->getPriority() ]}", 'info';
    print "\n";
}

iMSCP::Getopt->verbose( 0 );

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
