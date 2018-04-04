#!/usr/bin/perl

=head1 NAME

 installer.pl Install/Update/Reconfigure i-MSCP

=head1 SYNOPSIS

 installer.pl [OPTION]...

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

BEGIN { $0 = 'imscp-installer'; }

use strict;
use warnings;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/installer", "$FindBin::Bin/backend/PerlLib";
use iMSCP::Boolean;
use iMSCP::Installer::Functions qw/ loadConfig build install /;
use iMSCP::Debug qw/ newDebug /;
use iMSCP::Getopt;
use iMSCP::Requirements;
use POSIX qw/ locale_h /;

setlocale( LC_MESSAGES, 'C.UTF-8' );

$ENV{'LANG'} = 'C.UTF-8';

# Ensure that this script is run by super user
iMSCP::Requirements->new()->user();

newDebug( 'imscp-installer.log' );

# Set execution context
iMSCP::Getopt->context( 'installer' );

# Parse installer options
iMSCP::Getopt->parse( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{
 -b,    --build-only              Process build steps only.
 -s,    --skip-distro-packages    Do not install/update distribution packages.},
    'build-only|b'           => \&iMSCP::Getopt::buildonly,
    'skip-distro-packages|s' => \&iMSCP::Getopt::skippackages
);

if ( iMSCP::Getopt->preseed ) {
    # The preseed option supersede the reconfigure option
    iMSCP::Getopt->reconfigure( 'none' );
    # The preseed option involves the noprompt option
    iMSCP::Getopt->noprompt( TRUE );
}

# Inhibit verbose mode if we are not in non-interactive mode
iMSCP::Getopt->verbose( FALSE ) unless iMSCP::Getopt->noprompt;

loadConfig();
build();
exit if iMSCP::Getopt->buildonly;
install();

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
