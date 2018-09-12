#!/usr/bin/perl

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

=head1 NAME

 set-engine-permissions Set i-MSCP GUI permission

=head1 SYNOPSIS

 set-engine-permissions [options]...

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib", "$FindBin::Bin/../PerlVendor";
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, 'C.UTF-8' );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-set-gui-permissions.log' );

iMSCP::Getopt->parse( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Set i-MSCP gui permissions.

OPTIONS
 -i   --installer     Set installer context.
 -v,  --verbose       Enable verbose mode.
 -x,  --fix-permissions Fix permissions recursively.},
    'installer|s'   => sub { iMSCP::Getopt->context( 'installer' ); },
    'verbose|v' => \&iMSCP::Getopt::verbose,
    'fix-permissions|x' => \&iMSCP::Getopt::fixPermissions
);

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
    push @items, [ $server, sub { $server->factory()->setGuiPermissions(); } ];
}

for my $package ( iMSCP::Packages->getInstance()->getList() ) {
    push @items, [ $package, sub { $package->getInstance()->setGuiPermissions(); } ];
}

iMSCP::EventManager->getInstance()->trigger( 'beforeSetGuiPermissions' );

my $totalItems = scalar @items;
my $count = 1;
for ( @items ) {
    debug( sprintf( 'Setting %s frontEnd permissions', $_->[0] ));
    printf( "Setting %s frontEnd permissions\t%s\t%s\n", $_->[0], $totalItems, $count ) if iMSCP::Getopt->context() eq 'installer';
    $rs |= $_->[1]->();
    $count++;
}

iMSCP::EventManager->getInstance()->trigger( 'afterSetGuiPermissions' );

exit $rs;

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
