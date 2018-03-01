=head1 NAME

 iMSCP::File::Attributes - Provide an interface to ioctl() operations for inode flags-attributes

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

package iMSCP::File::Attributes;

use strict;
use warnings;
use Errno qw/ ENOTTY /;
use File::Find 'find';
no warnings 'File::Find';
use Fcntl qw/ O_RDONLY O_NONBLOCK /;
use iMSCP::Boolean;
use iMSCP::H2ph;
use parent 'Exporter';

our @EXPORT_OK = qw/
    setAppendOnly clearAppendOnly isAppendOnly
    setCompress clearCompress isCompress
    setDirSync clearDirSync isDirSync
    setImmutable clearImmutable isImmutable
    setJournalData clearJournalData isJournalData
    setNoAtime clearNoAtime isNoAtime
    setNoCow clearNoCow isNoCow
    setNoDump clearNoDump isNoDump
    setNoTail clearNoTail isNoTail
    setProjInherit clearProjInherite isProjInherit
    setSecureDeletion clearSecureDeletion isSecureDelection
    setSyncUpdate cleanSyncUpdate isSyncUpdate
    setTopDir clearTopDir isTopDir
    setUndelete clearUndelete isUndelete
    setExtent clearExtent isExtent
    clearAll
/;

our %EXPORT_TAGS = (
    all            => \@EXPORT_OK,
    append         => [ qw/ setAppendOnly clearAppendOnly isAppendOnly / ],
    compress       => [ qw/ setCompress clearCompress isCompress / ],
    dirsync        => [ qw/ setDirSync clearDirSync isDirSync / ],
    immutable      => [ qw/ setImmutable clearImmutable isImmutable / ],
    journaldata    => [ qw/ setJournalData clearJournalData isJournalData / ],
    noatime        => [ qw/ setNoAtime clearNoAtime isNoAtime / ],
    nocow          => [ qw/ setNoCow clearNoCow isNoCow / ],
    nodump         => [ qw/ setNoDump clearNoDump isNoDump / ],
    notail         => [ qw/ setNoTail clearNoTail isNoTail / ],
    projinherit    => [ qw/ setProjInherit clearProjInherite isProjInherit / ],
    securedeletion => [ qw/ setSecureDeletion clearSecureDeletion isSecureDelection / ],
    syncupdate     => [ qw/ setSyncUpdate cleanSyncUpdate isSyncUpdate / ],
    topdir         => [ qw/ setTopDir clearTopDir isTopDir / ],
    undelete       => [ qw/ setUndelete clearUndelete isUndelete / ],
    extent         => [ qw/ setExtent clearExtent isExtent / ]
);

=head1 DESCRIPTION
 
 Various Linux filesystems support the notion of inode flags—attributes that
 modify the semantics of files and directories. These flags can be retrieved
 and modified using the functions exported by this package.

 The functions are made to abort silently if the target filesystem doesn't
 support inode flags-attributes.

 See also: IOCTL_IFLAGS(2) 

=cut

my %constants = (
    # The file can be opened only with the O_APPEND flag. (This restriction
    # applies even to the superuser.) Only a privileged process
    # (CAP_LINUX_IMMUTABLE) can set or clear this attribute.
    AppendOnly     => &iMSCP::H2ph::FS_APPEND_FL,                                                       # 'a'

    # Store the file in a compressed format on disk. This flag is not supported
    # by most of the mainstream filesystem implementations; one exception is
    # btrfs(5).
    Compress       => &iMSCP::H2ph::FS_COMPR_FL,                                                        # 'c'

    # (since Linux 2.6.0)
    #  Write  directory  changes  synchronously to disk. This flag provides
    # semantics equivalent to the mount(2) MS_DIRSYNC option, but on
    # a per-directory basis.  This flag can be applied only to directories.
    DirSync        => defined( &iMSCP::H2ph::FS_DIRSYNC_FL ) ? &iMSCP::H2ph::FS_DIRSYNC_FL : 0,         # 'D'

    # The file is immutable: no changes are permitted to the file contents or
    # metadata (permissions, timestamps, ownership, link count and so on).
    # (This restriction applies even to the superuser.) Only a privileged
    # process (CAP_LINUX_IMMUTABLE) can set or clear this attribute.
    Immutable      => &iMSCP::H2ph::FS_IMMUTABLE_FL,                                                    # 'i'

    # Enable journaling of file data on ext3(5) and ext4(5) filesystems. On a
    # filesystem that is journaling in ordered or writeback mode, a privileged
    # (CAP_SYS_RESOURCE) process can set this flag to enable journaling of data
    # updates on a per-file basis.
    JournalData    => &iMSCP::H2ph::FS_JOURNAL_DATA_FL,                                                 # 'j'

    # Don't update the file last access time when the file is accessed. This
    # can provide I/O performance benefits for applications that do not care
    # about the accuracy of this timestamp.  This flag provides functionality
    # similar to the mount(2) MS_NOATIME flag, but on a per-file basis.
    NoAtime        => &iMSCP::H2ph::FS_NOATIME_FL,                                                      # 'A'

    # (since Linux 2.6.39)
    # The file will not be subject to copy-on-write updates. This flag has an
    # effect only on filesystems that support copy-on-write semantics, such as
    # Btrfs. See chattr(1) and btrfs(5).
    NoCow          => defined( &iMSCP::H2ph::FS_NOCOW_FL ) ? &iMSCP::H2ph::FS_NOCOW_FL : 0,             # 'C'

    # Don't include this file in backups made using dump(8).
    NoDump         => &iMSCP::H2ph::FS_NODUMP_FL,                                                       # 'd'

    # This flag is supported only on Reiserfs. It disables the Reiserfs
    # tail-packing feature, which tries to pack small files (and the final
    # fragment of larger files) into the same disk block as the file metadata.
    NoTail         => &iMSCP::H2ph::FS_NOTAIL_FL,                                                       # 't'

    # (since Linux 4.5)
    # Inherit the quota project ID. Files and subdirectories will inherit the
    # project ID of the directory. This flag can be applied only to directories.
    ProjInherit    => defined( &iMSCP::H2ph::FS_PROJINHERIT_FL ) ? &iMSCP::H2ph::FS_PROJINHERIT_FL : 0, # 'p'

    # Mark the file for secure deletion. This feature is not implemented by
    # any filesystem, since the task of securely erasing a file from a
    # recording medium is surprisingly difficult.
    SecureDeletion => &iMSCP::H2ph::FS_SECRM_FL,                                                        # 's'

    # Make file updates synchronous. For files, this makes all writes
    # synchronous (as though all opens of the file were with the O_SYNC flag).
    # For directories, this has the same  effect as the FS_DIRSYNC_FL flag.
    SyncUpdate     => &iMSCP::H2ph::FS_SYNC_FL,                                                         # 'S'

    # Mark a directory for special treatment under the Orlov block-allocation
    # strategy. See chattr(1) for details. This flag can be applied only to
    # directories and has an effect only for ext2, ext3, and ext4.
    TopDir         => &iMSCP::H2ph::FS_SYNC_FL,                                                         # 'T'

    # Allow the file to be undeleted if it is deleted. This feature is not
    # implemented by any filesystem, since it is possible to implement
    # file-recovery mechanisms outside the kernel.
    Undelete       => &iMSCP::H2ph::FS_UNRM_FL,                                                         # 'u'

    # Ext4 extent
    Extent         => &iMSCP::H2ph::FS_EXTENT_FL,                                                       # 'e'
);

=head1 FUNCTIONS

=over 4

=item setAppendOnly( $name [, $recursive ] )

 Takes a filename and attempts to set its append only inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearAppendOnly( $name [, $recursive ] )

 Takes a filename and removes the append only inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isAppendOnly( $name )

 Takes a filename and returns true if the append only inode flag is set and false if it isn't.

=item setCompress( $name [, $recursive ] )

 Takes a filename and attempts to set its compress inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearCompress( $name [, $recursive ] )

 Takes a filename and removes the compress inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isCompress( $name )

 Takes a filename and returns true if the compress inode flag is set and false if it isn't.

=item setDirSync( $name [, $recursive ] )

 Takes a filename and attempts to set its dirsync inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearDirSync( $name [, $recursive ] )

 Takes a filename and removes the dirsync inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isDirSync( $name )

 Takes a filename and returns true if the dirsync inode flag is set and false if it isn't.

=item setImmutable( $name [, $recursive ] )

 Takes a filename and attempts to set its immutable inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearImmutable( $name [, $recursive ] )

 Takes a filename and removes the immutable inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isImmutable

 Takes a filename and returns true if the immutable inode flag is set and false if it isn't.

=item setJournalData( $name [, $recursive ] )

 Takes a filename and attempts to set its journal data inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearJournalData( $name [, $recursive ] )

 Takes a filename and removes the journal data inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isJournalData

 Takes a filename and returns true if the journal data inode flag is set and false if it isn't.

=item setNoAtime( $name )

 Takes a filename and attempts to set its noatime inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearNoAtime( $name [, $recursive ] )

 Takes a filename and removes the only noatime inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isNoAtime( $name )

 Takes a filename and returns true if the noatime inode flag is set and false if it isn't.

=item setNoCow( $name )

 Takes a filename and attempts to set its nocow inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearNoCow( $name [, $recursive ] )

 Takes a filename and removes the only nocow inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isNoCow( $name )

 Takes a filename and returns true if the nocow inode flag is set and false if it isn't.

=item setNoDump( $name )

 Takes a filename and attempts to set its nodump inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearNoDump( $name [, $recursive ] )

 Takes a filename and removes the only nodump inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isNoDump( $name )

 Takes a filename and returns true if the nodump inode flag is set and false if it isn't.

=item setNoTail( $name )

 Takes a filename and attempts to set its notail inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearNoTail( $name [, $recursive ] )

 Takes a filename and removes the only notail inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isNoTail( $name )

 Takes a filename and returns true if the notail inode flag is set and false if it isn't.

=item setProjInherit( $name )

 Takes a filename and attempts to set its projinherit inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearProjInherit( $name [, $recursive ] )

 Takes a filename and removes the only projinherit inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isNoProjInherit( $name )

 Takes a filename and returns true if the projinherit inode flag is set and false if it isn't.

=item setSecureDeletion( $name [, $recursive ] )

 Takes a filename and attempts to set its secure deletion inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearSecureDeletion( $name [, $recursive ] )

 Takes a filename and removes the secure deletion inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isSecureDeletion( $name )

 Takes a filename and returns true if the secure deletion inode flag is set and false if it isn't.

=item setSyncUpdate( $name [, $recursive ] )

 Takes a filename and attempts to set its synchronous updates inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearSyncUpdate( $name [, $recursive ] )

 Takes a filename and removes the synchronous updates inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isSyncUpdate( $name )

 Takes a filename and returns true if the sync inode flag is set and false if it isn't.

=item setTopDir( $name [, $recursive ] )

 Takes a filename and attempts to set its synchronous updates inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearTopDir( $name [, $recursive ] )

 Takes a filename and removes the topdir inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isTopDir( $name )

 Takes a filename and returns true if the topdir inode flag is set and false if it isn't.

=item setUndelete( $name [, $recursive ] )

 Takes a filename and attempts to set its undelete inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearUndelete( $name [, $recursive ] )

 Takes a filename and removes the undelete inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isUndelete

 Takes a filename and returns true if the undelete inode flag is set and false if it isn't.

=cut

=item setExtent( $name [, $recursive ] )

 Takes a filename and attempts to set its extent inode flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item clearExtent( $name [, $recursive ] )

 Takes a filename and removes the extent inode flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.
 Return void, die on failure

=item isExtent

 Takes a filename and returns true if the extent inode flag is set and false if it isn't.

=cut

{
    no strict 'refs';

    for my $fname ( keys %constants ) {
        *{ __PACKAGE__ . '::set' . $fname } = sub
        {
            my ( $name, $recursive ) = @_;

            defined $name or die( '$name parameter is not defined' );

            if ( $recursive ) {
                local $@;
                eval {
                    find(
                        {
                            wanted   => sub {
                                sysopen( my $fh, $_, O_RDONLY | O_NONBLOCK ) or die( $! );

                                my $ret;
                                if ( $ret = _getInodeFlags( $fh, \my $flags ) ) {
                                    _setInodeFlags( $fh, $flags | $constants{$fname} );
                                }

                                close $fh;
                                $ret or die;
                            },
                            no_chdir => 1
                        },
                        $name
                    );
                };
                ENOTTY == $! or die( $! ) if $@;
                return;
            }

            sysopen( my $fh, $name, O_RDONLY | O_NONBLOCK ) or die( $! );

            if ( _getInodeFlags( $fh, \my $flags ) ) {
                _setInodeFlags( $fh, $flags | $constants{$fname} );
            }

            close $fh;
        };

        *{ __PACKAGE__ . '::clear' . $fname } = sub
        {
            my ( $name, $recursive ) = @_;

            defined $name or die( '$name parameter is not defined' );

            if ( $recursive ) {
                local $@;
                eval {
                    find(
                        {
                            wanted   => sub {
                                sysopen( my $fh, $_, O_RDONLY | O_NONBLOCK ) or die( $! );

                                my $ret;
                                if ( $ret = _getInodeFlags( $fh, \my $flags ) ) {
                                    _setInodeFlags( $fh, $flags & ~$constants{$fname} );
                                };

                                close $fh;
                                $ret or die;
                            },
                            no_chdir => 1
                        },
                        $name
                    );
                };
                ENOTTY == $! or die( $! ) if $@;
                return;
            }

            sysopen( my $fh, $name, O_RDONLY | O_NONBLOCK ) or die( $! );

            if ( _getInodeFlags( $fh, \my $flags ) ) {
                _setInodeFlags( $fh, $flags & ~$constants{$fname} );
            }

            close $fh;
        };

        *{ __PACKAGE__ . '::is' . $fname } = sub
        {
            my ( $name ) = @_;
            defined $name or die( '$name parameter is not defined' );
            sysopen( my $fh, $name, O_RDONLY | O_NONBLOCK ) or die( $! );
            my $ret = _getInodeFlags( $fh, \my $flags );
            close $fh;
            $ret && $flags & $constants{$fname};
        };
    }
}

=item clearAll( $name [, $recursive = FALSE ])

 Clear all inode flags (except extent) on the given file/directory

 Param string $name File name
 Param bool $recursive Flag indicating whether the operation must be recursive
 Return void, die on failure

=cut

sub clearAll
{
    my ( $name, $recursive ) = @_;

    if ( $recursive ) {
        local $@;
        eval {
            find(
                {
                    wanted   => sub {
                        sysopen( my $fh, $_, O_RDONLY | O_NONBLOCK ) or die( $! );

                        my $ret;
                        if ( $ret = _getInodeFlags( $fh, \my $flags ) ) {
                            _setInodeFlags( $fh, $flags & $constants{'Extent'} || 0 );
                        }

                        close $fh;
                        $ret or die;
                    },
                    no_chdir => 1
                },
                $name
            );
        };
        ENOTTY == $! or die( $! ) if $@;
        return;
    }

    sysopen( my $fh, $name, O_RDONLY | O_NONBLOCK ) or die( $! );

    if ( _getInodeFlags( $fh, \my $flags ) ) {
        _setInodeFlags( $fh, $flags & $constants{'Extent'} ? $constants{'Extent'} : 0 );
    }

    close $fh;
}

=item _getInodeFlags( $fh, \$flags )

 Get flags for inode referred to by the given file handle

 Param GLOB $fh File handle on which operate
 Param scalarref \$flags Reference to a scalar into which the unpacked inode flags will be stored
 Return TRUE on success, FALSE on ENOTTY, close $fh and die on failure

=cut

sub _getInodeFlags
{
    my ( $fh, $flags ) = @_;

    unless ( ioctl( $fh, &iMSCP::H2ph::FS_IOC_GETFLAGS, ${ $flags } = pack 'i', 0 ) ) {
        ENOTTY == $! or goto closeFhAndDie;
        return FALSE;
    }

    ${ $flags } = unpack 'i', ${ $flags };
    return TRUE;

    closeFhAndDie:
    my $errno = $!;
    close $fh;
    die( sprintf( 'Failed to get inode flags: %s', $errno ));
}

=item _setInodeFlags( $name, $flags )

 Set flags for inode referred to by the given file handle

 Param GLOB $fh File handle on which operate
 Param scalar $flags Flags
 Return TRUE on success, FALSE on ENOTTY, close $fh and die on failure

=cut

sub _setInodeFlags
{
    my ( $fh, $flags ) = @_;

    unless ( ioctl( $fh, &iMSCP::H2ph::FS_IOC_SETFLAGS, pack 'i', $flags ) ) {
        ENOTTY == $! or goto closeFhAndDie;
        return FALSE;
    }

    return TRUE;

    closeFhAndDie:
    my $errno = $!;
    close $fh;
    die( sprintf( 'Failed to set inode flags: %s', $errno ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
