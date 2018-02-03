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
use lib "$FindBin::Bin/../PerlLib";
use File::Basename;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Rights;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw / locale_h /;

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';
$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

newDebug( 'imscp-set-engine-permissions.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq {

Set i-MSCP engine permissions.

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
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1,
    nolock          => 1
} )->lock( "$main::imscpConfig{'LOCK_DIR'}/imscp-set-engine-permissions.lock", 'nowait' );

my @items = ();
for my $server(iMSCP::Servers->getInstance()->getListWithFullNames()) {
    push @items, [ $server, sub { $server->factory()->setEnginePermissions(); } ];
}
for my $package( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
    ( my $subref = $package->can( 'setEnginePermissions' ) ) or next;
    push @items, [ $package, sub { $subref->( $package->getInstance( eventManager => iMSCP::EventManager->getInstance())); } ];
}

my $totalItems = @items+1;
my $count = 1;

debug( 'Setting base (engine) permissions' );
printf( "Setting base (engine) permissions\t%s\t%s\n", $totalItems, $count ) if iMSCP::Getopt->context() eq 'installer';

# e.g: /etc/imscp
setRights( $main::imscpConfig{'CONF_DIR'},
    {
        user      => $main::imscpConfig{'ROOT_USER'},
        group     => $main::imscpConfig{'IMSCP_GROUP'},
        dirmode   => '0750',
        filemode  => '0640',
        recursive => 1
    }
);
# e.g: /var/www/imscp
setRights( $main::imscpConfig{'ROOT_DIR'},
    {
        user  => $main::imscpConfig{'ROOT_USER'},
        group => $main::imscpConfig{'ROOT_GROUP'},
        mode  => '0755'
    }
);
# e.g: /var/www/imscp/engine
setRights( "$main::imscpConfig{'ROOT_DIR'}/engine",
    {
        user      => $main::imscpConfig{'ROOT_USER'},
        group     => $main::imscpConfig{'IMSCP_GROUP'},
        mode      => '0750',
        recursive => 1
    }
);
# e.g: /var/www/virtual
setRights( $main::imscpConfig{'USER_WEB_DIR'},
    {
        user  => $main::imscpConfig{'ROOT_USER'},
        group => $main::imscpConfig{'ROOT_GROUP'},
        mode  => '0755'
    }
);
# e.g: /var/log/imscp
setRights( $main::imscpConfig{'LOG_DIR'},
    {
        user  => $main::imscpConfig{'ROOT_USER'},
        group => $main::imscpConfig{'IMSCP_GROUP'},
        mode  => '0750'
    }
);

$count++;

for ( @items ) {
    debug( sprintf( 'Setting %s engine permissions', $_->[0] ));
    printf( "Setting %s engine permissions\t%s\t%s\n", $_->[0], $totalItems, $count++ ) if iMSCP::Getopt->context() eq 'installer';
    $_->[1]->();
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
