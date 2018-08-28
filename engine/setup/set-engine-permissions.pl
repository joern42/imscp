#!/usr/bin/perl

=head1 NAME

 set-engine-permissions Set i-MSCP engine permission

=head1 SYNOPSIS

 set-engine-permissions [options]...

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
use lib "$FindBin::Bin/../PerlLib", "$FindBin::Bin/../PerlVendor";
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::Getopt;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Servers;
use iMSCP::Packages;

$ENV{'LANG'} = 'C.UTF-8';
$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

newDebug( 'imscp-set-engine-permissions.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Set i-MSCP engine permissions.

OPTIONS:
 -i,    --installer       Set installer context.
 -d,    --debug           Enable debug mode.
 -v,    --verbose         Enable verbose mode.
 -x,    --fix-permissions Fix permissions recursively.},
    'setup|s'           => sub { iMSCP::Getopt->context( 'installer' ); },
    'debug|d'           => \&iMSCP::Getopt::debug,
    'verbose|v'         => \&iMSCP::Getopt::verbose,
    'fix-permissions|x' => \&iMSCP::Getopt::fixPermissions
);

setVerbose( iMSCP::Getopt->verbose );

my $bootstrapper = iMSCP::Bootstrapper->getInstance();
exit unless $bootstrapper->lock( '/var/lock/imscp-set-engine-permissions.lock', 'nowait' );

$bootstrapper->boot( {
    mode            => iMSCP::Getopt->context(),
    nolock          => TRUE,
    nodatabase      => TRUE,
    nokeys          => TRUE,
    config_readonly => TRUE
} );

my $rs = 0;
my @items = ();

for my $server ( iMSCP::Servers->getInstance()->getList() ) {
    push @items, [ $server, sub { $server->factory()->setEnginePermissions(); } ];
}

for my $package ( iMSCP::Packages->getInstance()->getList() ) {
    push @items, [ $package, sub { $package->getInstance()->setEnginePermissions(); } ];
}

my $totalItems = scalar @items+1;
my $count = 1;

debug( 'Setting base (engine) permissions' );
printf( "Setting base (engine) permissions\t%s\t%s\n", $totalItems, $count ) if iMSCP::Getopt->context() eq 'installer';

# e.g: /etc/imscp
$rs = setRights( $::imscpConfig{'CONF_DIR'}, {
    user      => $::imscpConfig{'ROOT_USER'},
    group     => $::imscpConfig{'IMSCP_GROUP'},
    dirmode   => '0750',
    filemode  => '0640',
    recursive => TRUE
} );
# e.g: /var/www/imscp
$rs |= setRights( $::imscpConfig{'ROOT_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'ROOT_GROUP'},
    mode  => '0755'
} );
# e.g: /var/www/imscp/daemon
$rs |= setRights( "$::imscpConfig{'ROOT_DIR'}/daemon", {
    user      => $::imscpConfig{'ROOT_USER'},
    group     => $::imscpConfig{'IMSCP_GROUP'},
    mode      => '0750',
    recursive => TRUE
} );
# e.g: /var/www/imscp/engine
$rs |= setRights( "$::imscpConfig{'ROOT_DIR'}/engine", {
    user      => $::imscpConfig{'ROOT_USER'},
    group     => $::imscpConfig{'IMSCP_GROUP'},
    mode      => '0750',
    recursive => TRUE
} );
# e.g: /var/www/virtual
$rs |= setRights( $::imscpConfig{'USER_WEB_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'ROOT_GROUP'},
    mode  => '0755'
} );
# e.g: /var/log/imscp
$rs |= setRights( $::imscpConfig{'LOG_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'IMSCP_GROUP'},
    mode  => '0750'
} );

$count++;

for ( @items ) {
    debug( sprintf( 'Setting %s engine permissions', $_->[0] ));
    printf( "Setting %s engine permissions\t%s\t%s\n", $_->[0], $totalItems, $count ) if iMSCP::Getopt->context() eq 'installer';
    $rs |= $_->[1]->();
    $count++;
}

exit $rs;

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
