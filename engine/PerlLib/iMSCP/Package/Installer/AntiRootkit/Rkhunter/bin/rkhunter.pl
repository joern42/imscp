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

use strict;
use warnings;
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../../../../../../../PerlLib", "$FindBin::Bin/../../../../../../../PerlVendor";
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug newDebug setVerbose /;
use iMSCP::Execute qw/ executeNoWait /;
use iMSCP::File;
use POSIX qw/ strftime locale_h /;

sub output
{
    chomp @_;
    debug( @_, '' )
}

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-rkhunter-package.log' );

iMSCP::Getopt->parseNoDefault( sprintf( "Usage: perl %s [OPTION]...", basename( $0 )) . qq{

Performs the rkhunter(8) checks in non-interactive mode.

OPTIONS:
 -d,    --debug         Enable debug mode.
 -v,    --verbose       Enable verbose mode.},
    'debug|d'   => \&iMSCP::Getopt::debug,
    'verbose|v' => \&iMSCP::Getopt::verbose
);

setVerbose( iMSCP::Getopt->verbose );

my $bootstrapper = iMSCP::Bootstrapper->getInstance();
exit unless $bootstrapper->lock( '/var/lock/imscp-rkhunter-package.lock', 'nowait' );

$bootstrapper->boot( {
    nolock          => TRUE,
    nokeys          => TRUE,
    nodatabase      => TRUE,
    config_readonly => TRUE
} );

my $logFile = $::{'RKHUNTER_LOG'} || '/var/log/rkhunter.log';

executeNoWait(
    [
        'nice', '-n', '0',
        'rkhunter', '--check', '--nocolors', '--skip-keypress', '--no-mail-on-warning', '--no-verbose-logging', '--noappendlog', '--logfile', $logFile
    ],
    \&output,
    \&output
);

if ( -f $logFile ) {
    my $file = iMSCP::File->new( filename => $logFile );
    my $rs = $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'IMSCP_GROUP'} );
    exit( $rs || $file->mode( 0640 ));
}

1;
__END__
