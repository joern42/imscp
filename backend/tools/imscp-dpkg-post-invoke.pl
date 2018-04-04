#!/usr/bin/perl

=head1 NAME

 imscp-dpkg-post-invoke.pl [OPTION]... - Process dpkg post invoke tasks

=head1 SYNOPSIS

 imscp-dpkg-post-invoke [options]...

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
use lib "/var/www/imscp/backend/PerlLib"; # FIXME: shouldn't be hardcoded
use File::Basename;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug error newDebug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Servers;
use iMSCP::Packages;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, 'C.UTF-8' );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-dpkg-post-invoke.log' );

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Process dpkg post invoke tasks

OPTIONS:
 -d,    --debug         Enable debug mode.
 -v,    --verbose       Enable verbose mode.},
    'debug|d'   => \&iMSCP::Getopt::debug,
    'verbose|v' => \&iMSCP::Getopt::verbose
);

# Set execution context
# We need the installer context as some dpkgPostInvokeTasks() could want
# update configuration parameters. In backend mode, configuration files are
# opened readonly.
iMSCP::Getopt->context( 'installer' );

exit unless iMSCP::Bootstrapper->getInstance()->getInstance()->boot( {
    config_readonly => 1,
    nolock          => 1
} )->lock( "$::imscpConfig{'LOCK_DIR'}/imscp-dpkg-post-invoke.lock", 'nowait' );

debug( 'Executing servers dpkg(1) post-invoke tasks' );
for my $server ( iMSCP::Servers->getInstance()->getList() ) {
    eval { $server->factory()->dpkgPostInvokeTasks(); };
    !$@ or error( $@ )
}

debug( 'Executing packages dpkg(1) post-invoke tasks' );
for my $package ( iMSCP::Packages->getInstance()->getList() ) {
    next unless my $subref = $package->can( 'dpkgPostInvokeTasks' );
    eval { $subref->( $package->getInstance( eventManager => iMSCP::EventManager->getInstance())); };
    !$@ or error( $@ )
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut


1;
__END__
