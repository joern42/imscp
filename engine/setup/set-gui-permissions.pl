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
use lib "$FindBin::Bin/../PerlLib";
use File::Basename;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw / locale_h /;

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';
$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

newDebug( 'imscp-set-gui-permissions.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq {

Set i-MSCP gui permissions.

OPTIONS
 -i,    --installer       Set installer context.
 -d,    --debug           Enable debug mode.
 -v,    --verbose         Enable verbose mode.
 -x,    --fix-permissions Fix permissions recursively.},
    'installer|i'       => sub { iMSCP::Getopt->context( 'installer' ); },
    'debug|d'           => \&iMSCP::Getopt::debug,
    'verbose|v'         => \&iMSCP::Getopt::verbose,
    'fix-permissions|x' => \&iMSCP::Getopt::fixPermissions
);

exit unless iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
    
} )->lock( "$main::imscpConfig{'LOCK_DIR'}/imscp-set-engine-permissions.lock", 'nowait' );

my @items = ();
for my $server(iMSCP::Servers->getInstance()->getListWithFullNames()) {
    push @items, [ $server, sub { $server->factory()->setGuiPermissions(); } ];
}
for my $package( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
    ( my $subref = $package->can( 'setGuiPermissions' ) ) or next;
    push @items, [ $package, sub { $subref->( $package->getInstance( eventManager => iMSCP::EventManager->getInstance())); } ];
}

iMSCP::EventManager->getInstance()->trigger( 'beforeSetGuiPermissions' );

my $totalItems = @items;
my $count = 1;
for ( @items ) {
    debug( sprintf( 'Setting %s frontEnd permissions', $_->[0] ));
    printf( "Setting %s frontEnd permissions\t%s\t%s\n", $_->[0], $totalItems, $count++ ) if iMSCP::Getopt->context() eq 'installer';
    $_->[1]->();
}

iMSCP::EventManager->getInstance()->trigger( 'afterSetGuiPermissions' );

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
