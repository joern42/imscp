#!/usr/bin/perl
# Copyright (C) 2016-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

use strict;
use warnings;
use lib '/var/www/imscp/engine/PerlLib';
use iMSCP::Bootstrapper;
use iMSCP::Getopt;
use iMSCP::Debug;
use iMSCP::Mount qw/ umount /;

iMSCP::Getopt->context( 'backend' );
iMSCP::Getopt->debug( 0 );
iMSCP::Getopt->verbose( 1 );

exit unless iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => 1,
    nodatabase      => 1,
    nokeys          => 1
} )->lock( "$main::imscpConfig{'LOCK_DIR'}/imscp-mountall.lock", 'nowait' );

umount( $main::imscpConfig{'USER_WEB_DIR'} );

1;
__END__
