#!/usr/bin/perl

=head1 NAME

 set-gui-permissions Set i-MSCP GUI permission

=head1 SYNOPSIS

 set-gui-permissions [options]...

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
use lib "$FindBin::Bin/../PerlLib";
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-set-gui-permissions.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

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
    config_readonly => TRUE,
    nodatabase      => TRUE,
    nokeys          => TRUE,
    nolock          => TRUE

} )->lock( "$::imscpConfig{'LOCK_DIR'}/imscp-set-gui-permissions.lock", 'nowait' );

my @items = ();
for my $server ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    push @items, [ $server, sub { $server->factory()->setGuiPermissions(); } ];
}
for my $package ( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
    ( my $subref = $package->can( 'setGuiPermissions' ) ) or next;
    push @items, [ $package, sub { $subref->( $package->getInstance( eventManager => iMSCP::EventManager->getInstance())); } ];
}

iMSCP::EventManager->getInstance()->trigger( 'beforeSetGuiPermissions' );

my $totalItems = @items;
my $count = 1;
for my $item ( @items ) {
    debug( sprintf( 'Setting %s frontEnd permissions', $item->[0] ));
    printf( "Setting %s frontEnd permissions\t%s\t%s\n", $item->[0], $totalItems, $count++ ) if iMSCP::Getopt->context() eq 'installer';
    $item->[1]->();
}

iMSCP::EventManager->getInstance()->trigger( 'afterSetGuiPermissions' );

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
