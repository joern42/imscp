#!/usr/bin/perl

=head1 NAME

 set-backend-permissions Set i-MSCP backend permissions

=head1 SYNOPSIS

 set-backend-permissions [options]...

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
use iMSCP::Rights;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-set-backend-permissions.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Set i-MSCP backend permissions.

OPTIONS:
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
} )->lock( "$::imscpConfig{'LOCK_DIR'}/imscp-set-backend-permissions.lock", 'nowait' );

my @items = ();
for my $server ( iMSCP::Servers->getInstance()->getListWithFullNames() ) {
    push @items, [ $server, sub { $server->factory()->setBackendPermissions(); } ];
}
for my $package ( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
    ( my $subref = $package->can( 'setBackendPermissions' ) ) or next;
    push @items, [ $package, sub { $subref->( $package->getInstance( eventManager => iMSCP::EventManager->getInstance())); } ];
}

my $totalItems = @items+1;
my $count = 1;

debug( 'Setting base (backend) permissions' );
printf( "Setting base (backend) permissions\t%s\t%s\n", $totalItems, $count ) if iMSCP::Getopt->context() eq 'installer';

# e.g: /etc/imscp
setRights( $::imscpConfig{'CONF_DIR'}, {
    user      => $::imscpConfig{'ROOT_USER'},
    group     => $::imscpConfig{'IMSCP_GROUP'},
    dirmode   => '0750',
    filemode  => '0640',
    recursive => TRUE
} );
# e.g: /var/www/imscp
setRights( $::imscpConfig{'ROOT_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'ROOT_GROUP'},
    mode  => '0755'
} );
# e.g: /var/www/imscp/backend
setRights( $::imscpConfig{'BACKEND_ROOT_DIR'}, {
    user      => $::imscpConfig{'ROOT_USER'},
    group     => $::imscpConfig{'IMSCP_GROUP'},
    mode      => '0750',
    recursive => TRUE
} );
# e.g: /var/www/virtual
setRights( $::imscpConfig{'USER_WEB_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'ROOT_GROUP'},
    mode  => '0755'
} );
# e.g: /var/log/imscp
setRights( $::imscpConfig{'LOG_DIR'}, {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'IMSCP_GROUP'},
    mode  => '0750'
} );

$count++;

for my $item ( @items ) {
    debug( sprintf( 'Setting %s backend permissions', $item->[0] ));
    printf( "Setting %s backend permissions\t%s\t%s\n", $item->[0], $totalItems, $count++ ) if iMSCP::Getopt->context() eq 'installer';
    $item->[1]->();
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
