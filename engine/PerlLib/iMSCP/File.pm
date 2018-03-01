=head1 NAME

 iMSCP::File - Class representing a file in abstract way.

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

package iMSCP::File;

use strict;
use warnings;
use Carp qw/ croak /;
use Cwd ();
use English;
use Errno qw/ EPERM EINVAL ENOENT /;
use Fcntl qw/ :mode O_RDONLY O_WRONLY O_CREAT O_TRUNC O_BINARY O_EXCL O_NOFOLLOW /;
use File::Basename;
use File::Copy ();
use File::Spec ();
use iMSCP::Boolean;
use iMSCP::Debug qw/ error getMessageByType /;
use iMSCP::H2ph;
use iMSCP::Umask;
use POSIX qw/ mkfifo lchown /;
use overload '""' => \&__toString, fallback => 1;
use parent 'iMSCP::Common::Object';

# Upper limit for file slurping (2MiB)
our $SLURP_SIZE_LIMIT = 1024 * 1024 * 2;

# All the mode bits that can be affected by chmod.
use constant CHMOD_MODE_BITS => S_ISUID | S_ISGID | S_ISVTX | S_IRWXU | S_IRWXG | S_IRWXO;

# Commonly used file permission combination.
use constant MODE_RW_UGO => S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH;
use constant S_IRWXUGO => S_IRWXU | S_IRWXG | S_IRWXO;

=head1 DESCRIPTION

 This class represents a file in an abstract way. It provides common
 file operations such as creation, deletion, copy, move, and attribute
 modification...

=head1 PUBLIC METHODS

=over 4

=item get( )

 Get content of this file

 Warning: The whole file content is read in memory (File slurp). Therefore this
 method shouldn't be used on a large file. By default there is file size limit
 (2 MiB). If the file size is bigger than that limit, an error is raised.
 
 If the caller really need to slurp a bigger file, default limit can be changed
 through the $iMSCP::File::SLURP_SIZE_LIMIT variable. It is recommended to
 change the limit locally, that is, as follows:

 {
   my $file = iMSCP::File->new( filename => '/path/to/file' );
   local $iMSCP::File::SLURP_SIZE_LIMIT variable = -s $file;
   my $fileContentRef = $file->getAsRef();
   ...
 }
 
 It is best avoided to call this method directly as this load the whole file
 content in memory, and return a shallow copy of the loaded content, meaning
 that for a file of 2 MiB, more than 4 MiB memory are consumed. You can avoid
 that by making use of the getAsRef() method which return a reference pointing
 to the loaded file's content.
 
 Note that file content is loaded only once. Subsequent calls return shallow
 copy of loaded content.

 Return string Shallow copy of loaded file's content, die on failure

=cut

sub get
{
    my ( $self ) = @_;

    return $self->{'file_content'} if length $self->{'file_content'};

    my ( @sst ) = stat $self->{'filename'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'filename'}, $! ));
    S_ISREG( $sst[2] ) or die( sprintf( "Failed to get '%s' content: not a regular file", $self->{'filename'} ));
    -s _ <= $SLURP_SIZE_LIMIT or croak( sprintf( "Failed to get '%s' content: file too big", $self->{'filename'} ));

    sysopen( my $fh, $self->{'filename'}, O_RDONLY | O_BINARY ) or die( sprintf( "Failed to open '%s' for reading: %s", $self->{'filename'}, $! ));

    local $/;
    $self->{'file_content'} = <$fh>;
    close( $fh );
    $self->{'file_content'};
}

=item getAsRef( $skipLoad = FALSE )

 Return scalar reference poiting to content of this file

 This is the preferable way to access file's content as this avoid consuming
 too much memory and also improve execution time as the data are not copied
 each time you get the file content.

 See also: iMSCP::File::get()

 Param bool $skipLoad If TRUE, loading of file's content in memory is skipped
 Return scalarref Reference to scalar containing file content, die on failure

=cut

sub getAsRef
{
    my ( $self, $skipLoad ) = @_;

    $self->get() unless $skipLoad || length $self->{'file_content'};
    \$self->{'file_content'};
}

=item set( $content )

 Set content of this file

 Param string $content New file content
 Return self

=cut

sub set
{
    my ( $self, $content ) = @_;

    $self->{'file_content'} = $content // '';
    $self;
}

=item save( [ $umask = UMASK(2) ])

 Save this file

 Param int $umask OPTIONAL UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal) 
 Return self, die on failure

=cut

sub save
{
    my ( $self, $umask ) = @_;

    my ( @dst ) = lstat $self->{'filename'};
    @dst || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $self->{'filename'}, $! ));

    # Change the default umask temporarily if requested by caller
    local $UMASK = $umask if defined $umask;
    sysopen( my $fh, $self->{'filename'}, O_WRONLY | ( @dst ? O_TRUNC : O_CREAT | O_EXCL ) | O_BINARY ) or die(
        sprintf( "Failed to open '%s' for writing: %s", $self->{'filename'}, $! )
    );
    print { $fh } $self->{'file_content'} // '';
    close( $fh );
    $self;
}

=item remove( )

 Remove this file

 Return self, die on failure

=cut

sub remove
{
    my ( $self ) = @_;

    my ( @st ) = lstat $self->{'filename'};

    @st || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $self->{'filename'}, $! ));
    return $self unless @st;

    !S_ISDIR( $st[2] ) or croak( sprintf( "Failed to remove '%s': not a file", $self->{'filename'} ));

    unlink $self->{'filename'} or die( sprintf( "Failed to remove '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item mode( [ $mode = MODE_RW_UGO & ~( UMASK(2) ) ] )

 Set mode of this file

 Param int $mode OPTIONAL New file mode (octal number), default to 0666 & ~( UMASK(2) )
 Return self, die on failure

=cut

sub mode
{
    my ( $self, $mode ) = @_;
    $mode //= MODE_RW_UGO & ~$UMASK;

    length $mode or croak( '$mode parameter is invalid' );
    chmod $mode, $self->{'filename'} or die( sprintf( "Failed to set permissions for '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item owner( $owner = -1, $group = -1 )

 Set ownership of this file

 Symlinks are not dereferenced.

 Param int|string $owner Either an user name or user ID
 Param int|string $group Either a group name or group ID
 Return self, die on failure

=cut

sub owner
{
    my ( $self, $owner, $group ) = @_;

    my ( $uid ) = defined $owner
        ? ( $owner =~ /^(?:-1|\d+)$/ ? $owner : getpwnam( $owner ) // die( sprintf( "Couldn't find user '%s'", $owner )) ) : -1;
    my ( $gid ) = defined $group
        ? ( $group =~ /^(?:-1|\d+)$/ ? $group : getgrnam( $group ) // die( sprintf( "Couldn't find group '%s'", $group )) ) : -1;

    lchown $uid, $gid, $self->{'filename'} or die( sprintf( "Failed to set ownership for '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item copy( $dest [, \%options = { umask => UMASK(2), preserve => undef, no_target_directory = FALSE } ] )

 Copy this file to the given destination
 
 The file can be of any type but directory.

 The behavior is nearly the same as the cp(1) command:
  - symlinks are not dereferenced. This is nearly same as executing: cp(1) --no-dereference file1 file2

  - If the 'preserve' option is set to TRUE, source file's ownership and permissions are preserved. Non-permission bits set(UID|GID) and sticky bit
    are preserved only if the copy of both owner and group succeeded. This is nearly same as executing: cp(1) --preserve=ownership,mode file1 file2

  - If the 'preserve option is not explicitely set to FALSE, ownership and permissions of existent files are left untouched and the following
    rules apply for new files:
     - Permissions set are those from source file on which UMASK(2) is applied. Non-permission bits are not preserved.
     - Owner is set to EUID while the group set depends on a range of factors:
       - If the fs is mounted with -o grpid, the group is made the same as that of the parent dir.
       - If the fs is mounted with -o nogrpid and the setgid bit is disabled on the parent dir, the group will be set to EGID
       - If the fs is mounted with -o nogrpid and the setgid bit is enabled on the parent dir, the group is made the same as that of the parent dir.
       As at Linux 2.6.25, the -o grpid and -o nogrpid mount options are supported by ext2, ext3, ext4, and XFS. Filesystems that don't support these
       mount options follow the -o nogrpid rules.   
       This is nearly same as executing: cp(1) file1 file2

  - If the 'preserve' option is explicitely set to FALSE, the ownership is set same as when the 'preserve' option is not explicitely set to FALSE.
    The permissions are set to default mode 0666 on which UMASK(2) is applied.
    This is nearly same as executing: cp(1) --no-preserve=mode  file1 file2

  - If the 'no_target_directory' option is TRUE, $dest is treated as normal file.
    This is nearly same as executing: cp(1) --no-target-directory file1 file2

  - Access Control List (ACL), timestamps, security context and extended attributes are not preserved.

 Param string $dest Destination path
 Param hash \%options OPTIONAL options:
  - umask               : OPTIONAL UMASK(2). See above for it usage cases. This option is only relevant when the preserve option is FALSE.
  - preserve            : See above for the behavior.
  - no_target_directory : If set to TRUE, treat $dest as a normal file
 Return self, die on failure

=cut

sub copy
{
    my ( $self, $dest, $options ) = @_;
    $options //= {};

    length $dest or croak( '$dest parameter is missing or invalid' );
    ref $options eq 'HASH' or croak( '$options parameter is invalid' );

    $options->{'_require_preserve'} = $options->{'preserve'} ? TRUE : FALSE;
    $options->{'no_target_directory'} //= TRUE;

    # Locally change the current UMASK(2) if requested by caller
    local $UMASK = $options->{'umask'} if defined $options->{'umask'};

    my ( $newDst, $isDirDst, $ret ) = ( FALSE, FALSE, FALSE );

    if ( my @dst = stat( $dest ) ) {
        $isDirDst = S_ISDIR( $dst[2] );
    } elsif ( $! != ENOENT ) {
        error( sprintf( "Failed to access '%s': %s", $dest, $! ));
        goto endCopy;
    } else {
        $newDst = TRUE;
    }

    if ( $options->{'no_target_directory'} || !$isDirDst ) {
        $ret = _copyInternal( $self->{'filename'}, $dest, FALSE, $options );
    } else {
        $dest .= '/' . basename( $self->{'filename'} );
        $ret = _copyInternal( $self->{'filename'}, $dest, $newDst, $options );
    }

    endCopy:
    $ret or die( sprintf( "Failed to copy '%s' to '%s': %s", $self->{'filename'}, $dest, getMessageByType( 'error', { remove => TRUE } )));
    $self;
}

=item move( $dest [, $options = { update_link_target = TRUE } ] )

 Move this file to the given destination

 At this time, only regular and symlink files are considered. Other files are
 silently ignored.
 
 By default, a specific treatment is applied to symlinks as their target paths
 can be relative to their current location. if so, those are simply re-created
 using their new location as base directory for generating a new relative
 target path. If the target path is an absolute path, these are treaded as
 regular files, that is, moved without further treatment. You can inhibit this
 behavior by setting the update_link_target option to FALSE.

 Param string $dest Destination
 Param hashref\%options OPTIONAL options
  - update_link_target : If TRUE (default) update link target when target is a relative path
 Return self, die on failure

=cut

sub move
{
    my ( $self, $dest, $options ) = @_;
    $options //= {};

    length $dest or croak( '$dest parameter is missing or invalid' );
    ref $options eq 'HASH' or croak( '$options parameter is not valid' );

    my ( @sst ) = lstat $self->{'filename'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'filename'}, $! ));
    !S_ISDIR( $sst[2] ) or die( sprintf( "Failed to move '%s' to '%s': not a file", $self->{'filename'}, $dest, $self->{'filename'} ));

    # Files other than symlinks and regular files are ignored silently.
    return $self unless S_ISLNK( $sst[2] ) || S_ISREG( $sst[2] );

    # We need dereference $dest as we want be able to move through symlinks
    my ( @dst ) = stat $dest;
    @dst || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $dest, $! ));

    # When the file is a symlink which target path is relative, we recreate it,
    # using it new location as base directory for generating the new relative
    # target path, otherwise, we simply the file as for regular files.
    if ( S_ISLNK( $sst[2] ) ) {
        $self->{'update_link_target'} //= true;

        if ( $self->{'update_link_target'} && !File::Spec->file_name_is_absolute( readlink $self->{'filename'} ) ) {
            # Turn current target relative path into absolute path
            my $lnkTgtAbs = Cwd::abs_path( $self->{'filename'} );
            # Guess base directory for new symlink location
            my $lnkDir = @dst && S_ISDIR( $dst[2] ) ? $dest : dirname( $dest );
            # Generate new target relative path
            my $lnkTgtRel = File::Spec->abs2rel( $lnkTgtAbs, $lnkDir );
            # Generate new symlink location
            $dest = File::Spec->catfile( $dest, basename( $self->{'filename'} )) if @dst && S_ISDIR( $dst[2] );
            # Create the new symlink and delete the older
            symlink $lnkTgtRel, $dest or die( sprintf( "Failed to move '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));
            unlink $self->{'filename'};

            # Update this file to make us able to continue working with it regardless of its new location.
            $self->{'filename'} = $dest;
            return $self;
        }
    }

    File::Copy::mv( $self->{'filename'}, $dest ) or die( sprintf( "Failed to move '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));

    # Update this file to make us able to continue working with it regardless of its new location.
    $self->{'filename'} = @dst && S_ISDIR( $dst[2] ) ? File::Spec->catfile( $dest, basename( $self->{'filename'} )) : $dest;
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize iMSCP::File object

 Return iMSCP::File, croak if the filename attribute is not set

=cut

sub _init
{
    my ( $self ) = @_;

    length $self->{'filename'} or croak( 'filename attribute is not defined or invalid' );
    $self->{'filename'} = File::Spec->canonpath( $self->{'filename'} );
    $self->{'file_content'} = '';
    $self;
}

=item _copyInternal( $srcName, $dstName, $newDst, $options )

 Copy the given file to the given destination
 
 The file can be of any type but directory. $newDst should be FALSE if the file
 $dstName might already exist.
 
 Param $string $srcName Source file path
 Param $string $dstName  Destination file path
 Param $bool $newDst Flag indicating whether or not $dstName might already exist. 
 Return TRUE on success, FALSE on failure with error set through error()

=cut

sub _copyInternal
{
    my ( $srcName, $dstName, $newDst, $options ) = @_;

    my ( @sst, @dst );
    my ( $haveDstLstat, $copiedAsRegular, $dstIsSymlink ) = ( FALSE, FALSE, FALSE );

    unless ( @sst = lstat $srcName ) {
        error( sprintf( "cannot stat '%s': %s", $srcName, $! ));
        return FALSE;
    }

    my $srcMode = $sst[2];

    if ( S_ISDIR( $srcMode ) ) {
        error( sprintf( "not a file: '%s'", $srcName ));
        return FALSE;
    }

    unless ( $newDst ) {
        # Regular files can be created by writing through symlinks, but other
        # file cannot. So use stat() on the destination when copying a regular
        # file, and lstat() otherwise.
        my $useStat = S_ISREG( $srcMode );

        unless ( @dst = $useStat ? stat( $dstName ) : lstat( $dstName ) ) {
            if ( $! != ENOENT ) {
                error( sprintf( "failed to stat '%s': %s", $dstName, $! ));
                return FALSE;
            }

            $newDst = TRUE;
        } else {
            # Here, we know that $dstName exists, at least to the point
            # that it is stat'able or lstat'able
            $haveDstLstat = !$useStat;

            if ( _sameInode( \@sst, \@dst ) ) {
                error( sprintf( "'%s' and '%s' are the same file", $srcName, $dstName ));
                return FALSE;
            }

            if ( S_ISDIR( $dst[2] ) ) {
                error( sprintf( "cannot overwrite directory '%s' with non-directory '%s'", $dstName, $srcName ));
                return FALSE;
            }

            # Files other than regular files must be pre-removed, else we won't be
            # able to copy them as they are simply re-created from scratch
            if ( !S_ISREG( $dst[2] ) ) {
                unless ( unlink( $dstName ) ) {
                    if ( $! != ENOENT ) {
                        error( sprintf( "cannot remove %s: %s", $srcName, $dstName, $dstName, $! ));
                        return FALSE;
                    }

                    $newDst = TRUE;
                }
            }
        }
    }

    # If the ownership might change, omit some permissions at first, so
    # unauthorized users cannot nip in before the file is ready.
    my $dstModeBits = $srcMode & CHMOD_MODE_BITS;
    my $omittedPerms = $dstModeBits & ( $options->{'preserve'} ? S_IRWXG | S_IRWXO : 0 );

    if ( S_ISREG( $srcMode ) ) {
        $copiedAsRegular = TRUE;

        # POSIX says the permission bits of the source file must be used as the
        # 3rd argument in the open call. Historical practice passed all the
        # source mode bits to 'open', but the extra bits were ignored, so it
        # should be the same either way.
        #
        # This call uses DST_MODE_BITS, not SRC_MODE. These are normally the
        # same.
        if ( !_copyReg( $srcName, $dstName, $options, $dstModeBits & S_IRWXUGO, $omittedPerms, \$newDst, \@sst ) ) {
            return FALSE;
        }
    } elsif ( S_ISFIFO( $srcMode ) ) {
        if ( mkfifo( $dstName, $srcMode & ~S_IFIFO & ~$omittedPerms ) != 0 ) {
            error( sprintf( "failed to create fifo '%s' : %s", $dstName, $! ));
            return FALSE;
        }
    } elsif ( ( S_ISBLK( $srcMode ) || S_ISCHR( $srcMode ) || S_ISSOCK( $srcMode ) ) ) {
        if ( _mknod( $dstName, $srcMode & ~$omittedPerms, $sst[6] ) != 0 ) {
            error( sprintf( "failed to create special file '%s': %s", $dstName, $! ));
            return FALSE;
        }
    } elsif ( S_ISLNK( $srcMode ) ) {
        my $lnkVal;
        $dstIsSymlink = TRUE;

        unless ( defined( $lnkVal = readlink( $srcName )) ) {
            error( sprintf( "failed to read symbolic link '%s'", $srcName, $! ));
            return FALSE;
        }

        unless ( symlink( $lnkVal, $dstName ) ) {
            error( sprintf( "failed to create symbolic link '%s'", $dstName, $! ));
            return FALSE;
        }

        if ( $options->{'preserve'} && !lchown( $sst[4], $sst[5], $dstName ) && !_chownOrChmodFailureOk() ) {
            error( sprintf( "failed to preserve ownership for '%s': %s", $dstName, $! ));
            return FALSE;
        };
    } else {
        error( sprintf( "unknown file type %s", $srcName, $dstName, $srcName ));
        return FALSE;
    }

    return TRUE if $copiedAsRegular;

    $srcMode = S_IMODE( $srcMode );

    # Avoid calling chown if we know it's not necessary
    if ( !$dstIsSymlink && $options->{'preserve'} && ( $newDst || !_sameOwnerAndGroup( \@sst, \@dst ) ) ) {
        my $ret = _setOwnerSafe( $options, $dstName, undef, \@sst, $newDst, \@dst );
        return FALSE if $ret == -1;

        # If preserving owner and group was not possible,
        # clear the non-permission bits
        $srcMode &= ~( S_ISUID | S_ISGID | S_ISVTX ) if $ret == 0;
    }

    # The operations beyond this point may dereference a symlink.
    return TRUE if $dstIsSymlink;

    if ( $options->{'preserve'} ) {
        unless ( chmod $srcMode, $dstName ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            return FALSE;
        }
    } elsif ( defined $options->{'preserve'} && !$options->{'preserve'} ) { # no preserve (explicit)
        # In cp1() command (corutils between v8.20 and v8.29 inclusive )
        # Wrong default perms where applied.
        # See https://debbugs.gnu.org/cgi/bugreport.cgi?bug=30534
        # We follow the proposed patch.
        unless ( chmod( ( S_ISSOCK( $srcMode ) ? S_IRWXUGO : MODE_RW_UGO ) & ~$UMASK, $dstName ) ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            return FALSE;
        }
    } else {
        my $restoreDstMode = FALSE;
        my $dstMode;

        if ( $omittedPerms ) {
            $omittedPerms &= ~$UMASK;

            if ( $omittedPerms && !$restoreDstMode ) {
                # Permissions were deliberately omitted when the file was
                # created due to security concerns. See whether they need to be
                # re-added now. It'd be faster to omit the lstat, but deducing
                # the current destination mode is tricky in the presence of
                # implementation-defined rules for special mode bits.
                if ( $newDst && ( @dst = lstat( $dstName ) ) ) {
                    error( sprintf( "cannot stat '%s': %s", $dstName, $! ));
                    return FALSE;
                }

                $dstMode = $dst[2];
                $restoreDstMode = TRUE if $omittedPerms & ~$dstMode;
            }
        }

        if ( $restoreDstMode && !chmod( $dstMode | $omittedPerms, $dstName ) ) {
            error( sprintf( "preserving permissions for %s '%s': %s", $dstName, $! ));
            return FALSE if $options->{'_require_preserve'};
        }
    }

    TRUE;
}

=item _copyReg( $srcName, $dstName, \%options, $dstMode, $omittedPerms, \$newDst, \@sst )

 Copy a regular file

 Param string $srcName Source file path
 Param string $dstName Destination file path
 Param hashref \%options Copy options
 Param int $dstMode Destination file mode
 Param int $omittedPerms Omitted permissions
 Param scalarref \$newDst Whether or not $dest is a new destination
 Param arrayref \@sst Source file stat() info
 Return TRUE on success, FALSE on failure with error set through error()

=cut

sub _copyReg
{
    my ( $srcName, $dstName, $options, $dstMode, $omittedPerms, $newDst, $sst ) = @_;

    my ( $srcFH, $dstFH, $destErrno, @sstOpen, @dstOpen );
    my $srcMode = S_IMODE $sst->[2];
    my $retVal = TRUE;

    unless ( sysopen( $srcFH, $srcName, O_RDONLY | O_BINARY | O_NOFOLLOW ) ) {
        error( sprintf( "cannot open '%s' for reading: %s", $srcName, $! ));
        return FALSE;
    }

    unless ( @sstOpen = stat( $srcFH ) ) {
        error( sprintf( "cannot fstat '%s': %s", $srcName, $! ));
        $retVal = FALSE;
        goto closeSrc;
    }

    unless ( _sameInode( $sst, \@sstOpen ) ) {
        error( sprintf( "file '%s' was replaced while being copied", $srcName ));
        $retVal = FALSE;
        goto closeSrc;
    }

    unless ( ${ $newDst } ) {
        $destErrno = $! unless sysopen( $dstFH, $dstName, O_WRONLY | O_BINARY | O_TRUNC );
    }

    open_with_O_CREAT:
    if ( ${ $newDst } ) {
        sysopen( $dstFH, $dstName, O_WRONLY | O_BINARY | O_CREAT | O_EXCL, $dstMode & ~$omittedPerms );
        $destErrno = $!;
    } else {
        $omittedPerms = 0;
    }

    # Retrieve file descriptor of the destination filehandle
    my $dstFd = fileno $dstFH;

    unless ( $dstFd ) {
        # If we have just failed due to ENOENT for an ostensibly preexisting
        # destination ($$newDst was FALSE), that's a bit of contractiction/race:
        # The prior stat/lstat said the file existed ($$newDst was FALSE), yet
        # the subsequent open-existing-file failed with ENOENT. With NFS, the
        # race window is wider still, since its meta-data caching tends to make
        # the stat succeed for a just-removed remote file, while the more-definitive
        # initial open call will fail with ENOENT. When this situation arises, we
        # attempt top open again, but this time with O_CREAT.
        if ( $destErrno == ENOENT && !${ $newDst } ) {
            ${ $newDst } = 1;
            goto open_with_O_CREAT;
        }

        # Otherwise, it's an error...
        error( sprintf( "cannot create regular file '%s': $!", $dstName, $destErrno ));
        $retVal = FALSE;
        goto closeSrc;
    }

    unless ( @dstOpen = stat( $dstFH ) ) {
        error( sprintf( "cannot fstat '%s': %s", $dstName, $! ));
        $retVal = FALSE;
        goto closeSrcAndDst;
    }

    unless ( File::Copy::copy( $srcFH, $dstFH ) ) {
        error( sprintf( "cannot copy regular file '%s'", $! ));
        $retVal = FALSE;
        goto closeSrcAndDst;
    }

    if ( $options->{'preserve'} && !_sameOwnerAndGroup( $sst, \@dstOpen ) ) {
        my $ret = _setOwnerSafe( $options, $dstName, $dstFH, $sst, $newDst, \@dstOpen );
        if ( $ret == -1 ) {
            $retVal = FALSE;
            goto closeSrcAndDst
        }

        # If preserving owner and group was not possible,
        # clear the non-permission bits
        $srcMode &= ~( S_ISUID | S_ISGID | S_ISVTX ) if $ret == 0;
    }

    if ( $options->{'preserve'} ) {
        unless ( chmod $srcMode, $dstFH ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            $retVal = FALSE;
        }
    } elsif ( defined $options->{'preserve'} && !$options->{'preserve'} ) { # no preserve (explicit)
        unless ( chmod( MODE_RW_UGO & ~$UMASK, $dstFH ) ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            $retVal = FALSE;
        }
    } elsif ( $omittedPerms ) {
        $omittedPerms &= ~$UMASK;
        unless ( !$omittedPerms || chmod $dstMode, $dstFH ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            $retVal = FALSE if $options->{'_require_preserve'};
        }
    }

    closeSrcAndDst:
    unless ( close( $srcFH ) ) {
        error( sprintf( "failed to close '%s'", $srcName ));
        $retVal = FALSE;
    }

    closeSrc:
    unless ( close( $dstFH ) ) {
        error( sprintf( "failed to close '%s'", $dstName ));
        $retVal = FALSE;
    }

    $retVal;
}

=item _mknod($pathname, $mode, $dev)

 Create a special or ordinary file
 
 It is assumed here that MKNOD(2) syscall is supported.
 
 Param string $pathname Path name
 Param int $mode File mode
 Param int $dev  Major and minor numbers
 Return int 0 on success, -1 on error (in which case, errno is set appropriately)

=cut

sub _mknod
{
    my ( $pathname, $mode, $dev ) = @_;

    syscall( &iMSCP::H2ph::SYS_mknod, $pathname, $mode, $dev );
}

=item _chownOrChmodFailureOk()
 
 Return TRUE if it's OK for CHOWN(2) or CHMOD(2) and similar operations to
 fail, where $! is the error number that chown failed with.
 
 CHOWN(2):
  If a non-root user pass the preserve option when copying a file, it's ok
  if we can't preserve ownership. But root probably wants to know, e.g.
  if NFS disallows it, or if the target system doesn't support file
  ownership.

 Return bool

=cut

sub _chownOrChmodFailureOk
{
    ( $! == EPERM || $! == EINVAL ) && $UID != 0;
}

=item _sameOwner( \@ast, \@bst )

 Return TRUE if owner in both arrays is identical

 Param \@ast array An array as returned by stat() and similars
 Param \@bst array An array as returned by stat() and similars
 Return bool TRUE if owner in both arrays is identical, FALSE otherwise

=cut

sub _sameOwner
{
    my ( $ast, $bst ) = @_;

    $ast->[4] == $bst->[4];
}

=item _isSameGroup( \@ast, \@bst )

 Return TRUE if group in both arrays is identical

 Param \@ast array An array as returned by stat() and similars
 Param \@bst array An array as returned by stat() and similars
 Return bool TRUE if group in both arrays is identical, FALSE otherwise

=cut

sub _isSameGroup
{
    my ( $ast, $bst ) = @_;

    $ast->[5] == $bst->[5];
}

=item _sameOwnerAndGroup( \@ast, \@bst )

 Return TRUE if owner and group in both arrays are identical

 Param \@ast array An array containing elements as returned by stat() and similars
 Param \@bst array An array containing elements as returned by stat() and similars
 Return bool TRUE if owner and group in both arrays are identical, FALSE otherwise

=cut

sub _sameOwnerAndGroup
{
    my ( $ast, $bst ) = @_;

    _sameOwner( $ast, $bst ) && _isSameGroup( $ast, $bst );
}

=item _setOwnerSafe( \%options, $dstName, $dstFH, \@sst, $newDst, \@dst )

 Set the owner and the owning group of $dstName to the UID/GID fields of $sst.
 If $dstFH is undefined, set the owner and owning group of DST_NAME instead.
 For safety, prefer lchown since no symbolic links should be involved. $dstFH
 must refer to the same file as $dstName if defined. Upon failure to set both
 UID/GID, try to set only the GID. $newDst is TRUE if the file was newly
 created; otherwise $dst is the status of

 Param \%options Copy options
 Param string $dstName Destination file path
 Param GLOB|undef $dstFH Destination file handle
 Param \@sst array An array as returned by stat() and similars
 Param bool $newDst Flag indicating whether $dstName is a new file
 Param \@dst array An array as returned by stat() and similars
 Return 1 if the initial syscall succeeds, 0 if it fails but it's OK not to preserve ownership, -1 otherwise and error set through error()

=cut

sub _setOwnerSafe
{
    my ( $options, $dstName, $dstFH, $sst, $newDst, $dst ) = @_;

    # Naively changing the ownership of an existent file before changing its
    # permissions would create a window of vulnerability if the file's old
    # permissions are too generous for the new owner and group. Avoid the
    # window by first changing to a restrictive temporary mode if necessary.
    # It is assumed that correct permissions will be set after.
    if ( $newDst && $options->{'preserve'} ) {
        my $oldMode = $dst->[2];
        my $newMode = $sst->[2];
        my $restrictiveTmpMode = $oldMode & $newMode & S_IRWXU;

        if ( ( $oldMode & CHMOD_MODE_BITS
            & ( ~$newMode | S_ISUID | S_ISGID | S_ISVTX ) )
            && !chmod( $restrictiveTmpMode, $dstFH // $dstName )
        ) {
            error( sprintf( "clearing permissions for '%s': %s", $dstName )) unless _chownOrChmodFailureOk();
            return -$options->{'_require_preserve'};
        }
    }

    if ( defined $dstFH ) {
        return 1 if chown( $sst->[4], $sst->[5], $dstFH );

        if ( $! == EPERM || $! == EINVAL ) {
            # We've failed to set *both*. Now, try to set just the group
            # ID, but ignore any failure here, and don't change errno.
            local $!;
            chown( -1, $sst->[5], $dstFH );
        }
    } else {
        return 1 if lchown $sst->[4], $sst->[5], $dstName;

        if ( $! == EPERM || $! == EINVAL ) {
            # We've failed to set *both*. Now, try to set just the group
            # ID, but ignore any failure here, and don't change errno.
            local $!;
            lchown -1, $sst->[5], $dstName;
        }
    }

    if ( !_chownOrChmodFailureOk() ) {
        error( sprintf( "failed to preserve onwership for '%s': %s", $dstName, $! ));
        return -1 if $options->{'preserve'};
    }

    0;
}

=item _sameInode( \@ast, \@bst )

 Return TRUE if ino/dev in both arrays are identical

 Param \@ast array An array containing elements as returned by stat() and similars
 Param \@bst array An array containing elements as returned by stat() and similars
 Return bool TRUE if owner and group in both arrays are identical, FALSE otherwise

=cut

sub _sameInode
{
    my ( $ast, $bst ) = @_;

    $ast->[0] == $bst->[0] && $ast->[1] == $bst->[1];
}

=item __toString()

 Return string representation of this object, that is the value of the
 $self->{'filename'} attribute.

=cut

sub __toString
{
    $_[0]->{'filename'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
