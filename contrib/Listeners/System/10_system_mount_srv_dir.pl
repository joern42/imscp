# i-MSCP Listener::System::Mount::SrvDir listener file
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
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

# This listener make it possible to store i-MSCP client Web data in custom
# location on the filesystem, for instance into /home/virtual.
#
# Note that with this listener, you must not add the mount entry in the system
# /etc/fstab file.
#
# Listener file compatible with i-MSCP >= 1.3.4

package Listener::System::Mount::SrvDir;

use strict;
use warnings;
use iMSCP::EventManager;
use iMSCP::Mount qw/ mount umount addMountEntry /;

# Configuration parameters

# Path to your custom directory for storage of i-MSCP clients Web data
my $SRV_DIR = '';

## Please don't edit anything below this line

# Don't register listener if not needed
return 1 unless length $SRV_DIR;

iMSCP::EventManager->getInstance()->register( 'afterInstallDistributionFiles', sub {
    return unless -d $SRV_DIR;

    # Make sure that nothing is already mounted on $::imscpConfig{'SRV_DIR'}
    umount( $::imscpConfig{'SRV_DIR'} );

    # Mount $SRV_DIR on $::imscpConfig{'SRV_DIR'}
    mount( {
        fs_spec    => $SRV_DIR,
        fs_file    => $::imscpConfig{'SRV_DIR'},
        fs_vfstype => 'none',
        fs_mntops  => 'rbind,rslave'
    } );
    addMountEntry( "$SRV_DIR $::imscpConfig{'SRV_DIR'} none rbind,rslave" );
} );

1;
__END__
