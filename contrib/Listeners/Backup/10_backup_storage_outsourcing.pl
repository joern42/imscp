# i-MSCP Listener::Backup::Storage::Outsourcing listener file
# Copyright (C) 2017-2018 Laurent Declercq <l.declercq@nuxwin.com>
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

package Listener::Backup::Storage::Outsourcing;

# Outsource core client backup directories
#
# Howto setup and activate
# 1. Upload that listener file into the /etc/imscp/listeners.d directory
# 2. Edit the uploaded file and set the $BACKUP_ROOT_DIR configuration
#    variable to the new backup root directory location
# 3. Trigger an i-MSCP reconfiguration: imscp-installer -danv

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::EventManager;
use iMSCP::Ext2Attributes qw/ setImmutable clearImmutable /;
use iMSCP::Dir;
use iMSCP::Getopt;
use iMSCP::Mount qw/ addMountEntry removeMountEntry mount umount /;

#  Configuration variables

# Outsourced client backups root directory
# For instance /srv/imscp/backups would mean that client backup
# directories would be outsourced as follows:
# - /srv/imscp/backups/<client1>
# - /srv/imscp/backups/<client2>
# - ...
#
# Warning: Be sure to have enough space in the specified location.
my $BACKUP_ROOT_DIR = '';

# Please don't edit anything below this line

# Don't register event listeners if not needed
return 1 unless length $BACKUP_ROOT_DIR;

# Create/Update outsourced backup root directory
iMSCP::EventManager->getInstance()->register( 'onBoot', sub
{
    iMSCP::Dir->new( dirname => $BACKUP_ROOT_DIR )->make( {
        user           => $::imscpConfig{'ROOT_USER'},
        group          => $::imscpConfig{'ROOT_GROUP'},
        mode           => 0750,
        fixpermissions => iMSCP::Getopt->fixpermissions
    } );
} );

# When files are being copied by the i-MSCP httpd server, we must first
# umount the outsourced client backup directory if any
iMSCP::EventManager->getInstance()->register( 'beforeHttpdAddFiles', sub
{
    return unless $_[0]->{'DOMAIN_TYPE'} eq 'dmn' && -d "$_[0]->{'WEB_DIR'}/backups";
    umount( "$_[0]->{'WEB_DIR'}/backups" );
} );

# Create outsourced client backup directory and mount it on core
# client backup directory
iMSCP::EventManager->getInstance()->register( 'afterHttpdAddFiles', sub
{
    return unless $_[0]->{'DOMAIN_TYPE'} eq 'dmn';

    my $dir = iMSCP::Dir->new( dirname => "$_[0]->{'WEB_DIR'}/backups" );

    unless ( $dir->isEmpty() ) {
        clearImmutable( $_[0]->{'WEB_DIR'} );

        unless ( -d "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'}" ) {
            # Move client backup into oursourced client backup directory
            $dir->copy( "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'}", preverve => TRUE );
        }

        # Make sure that the core client backup directory is free of any
        # garbage (should never occurs)
        $dir->clear();
        setImmutable( $_[0]->{'WEB_DIR'} ) if $_[0]->{'WEB_FOLDER_PROTECTION'} eq 'yes';
    } else {
        # Create empty outsourced client backup directory
        iMSCP::Dir->new( dirname => "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'}" )->make( {
            user           => $_[0]->{'USER'},
            group          => $_[0]->{'GROUP'},
            mode           => 0750,
            fixpermissions => iMSCP::Getopt->fixpermissions
        } );
    }

    # Mount outsourced client backup diretory on core client backup directory
    mount( {
        fs_spec    => "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'}",
        fs_file    => "$_[0]->{'WEB_DIR'}/backups",
        fs_vfstype => 'none',
        fs_mntops  => 'bind,slave'
    } );
    addMountEntry( "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'} $_[0]->{'WEB_DIR'}/backups none bind,slave" );
} );

# Umount outsourced client backup directory and remove it
iMSCP::EventManager->getInstance()->register( 'beforeHttpdDelDmn', sub
{
    return unless $_[0]->{'DOMAIN_TYPE'} eq 'dmn';

    my $fsFile = "$_[0]->{'WEB_DIR'}/backups";
    removeMountEntry( qr%.*?[ \t]+\Q$fsFile\E(?:/|[ \t]+)[^\n]+% );
    umount( $fsFile );

    iMSCP::Dir->new( dirname => "$BACKUP_ROOT_DIR/$_[0]->{'DOMAIN_NAME'}" )->remove();
} );

1;
__END__
