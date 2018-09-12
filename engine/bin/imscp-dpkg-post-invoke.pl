#!/usr/bin/perl

=head1 NAME

 imscp-dpkg-post-invoke.pl - Process dpkg post invoke tasks

=head1 SYNOPSIS

 imscp-dpkg-post-invoke.pl [options]...

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
use warnings FATAL => 'all';
use Carp 'croak';
use File::Basename qw/ basename dirname /;
use Cwd;

{
    my $cwd;
    BEGIN {
        $cwd = getcwd();
        $> == 0 or croak( "This script must be run with the root user privileges.\n" );
        $0 = 'imscp-dpkg-post-invoke.pl';
        chdir dirname( __FILE__ ) or croak( $! );
    }

    use FindBin;
    use lib "$FindBin::Bin/../PerlLib", "$FindBin::Bin/../PerlVendor";
    chdir $cwd or croak( $! );
}

use iMSCP::Boolean;
use iMSCP::Debug qw/ debug newDebug /;
use iMSCP::Bootstrapper;
use iMSCP::Getopt;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, 'C.UTF-8' );

@{ENV}{qw/ LANG IMSCP_INSTALLER / } = ( 'C.UTF-8', TRUE );

newDebug( 'imscp-dpkg-post-invoke.log' );

iMSCP::Getopt->parse( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Process dpkg post invoke tasks

OPTIONS:
 -v,  --verbose       Enable verbose mode.},
    'verbose|v' => \&iMSCP::Getopt::verbose
);

# Set execution context
iMSCP::Getopt->context( 'installer' );

my $bootstrapper = iMSCP::Bootstrapper->getInstance();
$bootstrapper->lock( '/var/lock/imscp-dpkg-post-invoke.lock' );
$bootstrapper->boot( {
    config_readonly => TRUE,
    mode            => 'backend',
    nolock          => TRUE
} );

for my $server ( iMSCP::Servers->getInstance()->getList() ) {
    $server->factory()->dpkgPostInvokeTasks();
}

for my $package ( iMSCP::Packages->getInstance()->getList() ) {
    $package->getInstance()->dpkgPostInvokeTasks();
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
