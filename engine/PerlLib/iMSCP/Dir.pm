=head1 NAME

 iMSCP::Dir - Class representing a directory in abstract way.

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

package iMSCP::Dir;

use strict;
use warnings;
use Carp qw/ croak /;
use English;
use Errno qw/ EPERM EINVAL ENOENT /;
use Fcntl qw/ :mode O_RDONLY O_WRONLY O_CREAT O_TRUNC O_BINARY O_EXCL O_NOFOLLOW /;
use File::Copy ();
use File::Basename;
use File::Path qw/ remove_tree /;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Debug qw/ error getMessageByType /;
use iMSCP::H2ph;
use iMSCP::Umask;
use POSIX qw/ mkfifo lchown /;
use overload '""' => \&__toString, fallback => 1;
use parent 'iMSCP::Common::Object';

# All the mode bits that can be affected by chmod.
use constant CHMOD_MODE_BITS => S_ISUID | S_ISGID | S_ISVTX | S_IRWXU | S_IRWXG | S_IRWXO;

# Commonly used file permission combination.
use constant MODE_RW_UGO => S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH;
use constant S_IRWXUGO => S_IRWXU | S_IRWXG | S_IRWXO;

=head1 DESCRIPTION

 This class represents a directory in an abstract way. It provides common
 directory operations such as creation, deletion, copy, move, and attribute
 modification.

=head1 PUBLIC METHODS

=over 4

=item getFiles( [ $regexp = NONE [, $invertMatching = FALSE ] ] )
 
 Get list of the first-depth files inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $invertMatching Flag allowing to inverse $regexp matching
 Return List of files, die on failure
 FIXME: Make use of an iterator instead: http://search.cpan.org/~roode/Iterator-0.03/Iterator.pm

=cut

sub getFiles
{
    my ( $self, $regexp, $invertMatching ) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( '$regexp parameter is invalid' );

    opendir my $dh, $self->{'dirname'} or die( "Failed to open dir '%s': %s", $self->{'dirname'}, $! );

    my @files;

    unless ( defined $regexp ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || ( !-l $self->{'dirname'} . '/' . $dentry && -d _ );
            push @files, $dentry;
        }
    } elsif ( !$invertMatching ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry !~ /$regexp/ || ( !-l $self->{'dirname'} . '/' . $dentry && -d _ );
            push @files, $dentry;
        }
    } else {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry =~ /$regexp/ || ( !-l $self->{'dirname'} . '/' . $dentry && -d _ );
            push @files, $dentry;
        }
    }

    closedir $dh;
    @files;
}

=item getDirs( [ $regexp = NONE [, $invertMatching = FALSE ] ] )

 Get list of the first-depth directories inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $invertMatching Flag allowing to inverse $regexp matching
 Return List of directories, die on failure
 FIXME: Make use of an iterator instead: http://search.cpan.org/~roode/Iterator-0.03/Iterator.pm

=cut

sub getDirs
{
    my ( $self, $regexp, $invertMatching ) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( '$regexp parameter is invalid' );

    opendir my $dh, $self->{'dirname'} or die( "Failed to open dir '%s': %s", $self->{'dirname'}, $! );

    my @files;

    unless ( defined $regexp ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || -l $self->{'dirname'} . '/' . $dentry || !-d _;
            push @files, $dentry;
        }
    } elsif ( !$invertMatching ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry !~ /$regexp/ || -l $self->{'dirname'} . '/' . $dentry || !-d _;
            push @files, $dentry;
        }
    } else {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry =~ /$regexp/ || -l $self->{'dirname'} . '/' . $dentry || !-d _;
            push @files, $dentry;
        }
    }

    closedir $dh;
    @files;
}

=item getAll( [ $regexp = NONE [, $invertMatching = FALSE ] ] )

 Get list of files and directories inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $invertMatching Flag allowing to invert $regexp matching
 Param bool OPTIONAL $returnIterator Flag indicating whether iterator must be returned in place of list of files/directories
 Return List of files and directories, die on failure
 FIXME: Make use of an iterator instead: http://search.cpan.org/~roode/Iterator-0.03/Iterator.pm

=cut

sub getAll
{
    my ( $self, $regexp, $invertMatching ) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( '$regexp parameter is invalid' );

    opendir my $dh, $self->{'dirname'} or die( "Failed to open '%s': %s", $self->{'dirname'}, $! );

    my @files;

    unless ( defined $regexp ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s;
            push @files, $dentry;
        }
    } elsif ( !$invertMatching ) {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry !~ /$regexp/;
            push @files, $dentry;
        }
    } else {
        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s || $dentry =~ /$regexp/;
            push @files, $dentry;
        }
    }

    closedir $dh;
    @files;
}

=item isEmpty()

 Is this directory empty?

 Return bool TRUE if the given directory is empty, FALSE otherwise, die on failure

=cut

sub isEmpty
{
    my ( $self ) = @_;

    opendir my $dh, $self->{'dirname'} or die( sprintf( "Failed to open '%s': %s", $self->{'dirname'}, $! ));

    while ( my $dentry = readdir $dh ) {
        next if $dentry =~ /^\.{1,2}\z/s;
        closedir $dh;
        return 0;
    }

    closedir $dh;
    1;
}

=item clear( [ $regexp = NONE [, $invertMatching = FALSE ] ] )

 Clear full content of this directory or the first depth entries of the directory that match the given regexp

 Symlinks are not dereferenced.

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $invertMatching Flag allowing to inverse $regexp matching 
 Return self, die on failure

=cut

sub clear
{
    my ( $self, $regexp, $invertMatching ) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( '$regexp parameter is invalid' );

    if ( defined $regexp ) {
        opendir my $dh, $self->{'dirname'} or die( sprintf( "Failed to open '%s': %s", $self->{'dirname'}, $! ));

        while ( my $dentry = readdir $dh ) {
            next if $dentry =~ /^\.{1,2}\z/s;
            next unless $invertMatching ? $dentry !~ /$regexp/ : $dentry =~ /$regexp/;

            $dentry = $self->{'dirname'} . '/' . $dentry;

            if ( -l $dentry || !-d _ ) {
                unlink $dentry or die( sprintf( "Failed to remove '%s': %s", $dentry, $! ));
                next;
            }

            eval { remove_tree( $dentry, { safe => 1 } ); };
            !$@ or die( sprintf( "Failed to remove '%s': %s", $dentry, $@ ));
        }

        closedir $dh;
        return $self;
    }

    eval { remove_tree( $self->{'dirname'}, { keep_root => 1, safe => 1 } ); };
    !$@ or die( sprintf( "Failed to clear '%s': %s", $self->{'dirname'}, $@ ));
    $self;
}

=item mode( [ $mode = S_IRWXUGO & ~( UMASK(2) ) ] )

 Set mode of this directory

 Param int $mode OPTIONAL New directory mode (octal number), default to 0777 & ~( UMASK(2) )
 Return self, die on failure

=cut

sub mode
{
    my ( $self, $mode ) = @_;
    $mode //= S_IRWXUGO & ~$UMASK;

    length $mode or croak( '$mode parameter is invalid' );
    chmod $mode, $self->{'dirname'} or die( sprintf( "Failed to set permissions for '%s': %s", $self->{'dirname'}, $! ));
    $self;
}

=item owner( $owner, $group )

 Set ownership of this directory

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

    lchown $uid, $gid, $self->{'dirname'} or die( sprintf( "Failed to set ownership for '%s': %s", $self->{'dirname'}, $! ));
    $self;
}

=item make( [ \%options = { umask => UMASK(2), user => -1, group => -1, mode => 0777 & ~(umask || 0), fixpermissions => FALSE } ] )

 Create this directory

 Setting ownership and permissions on created parent directories can lead to several
 permission issues. Starting with version 1.5.0, the ownership and permissions on
 created parent directories are set as EUID:EGID 0777 & ~(UMASK(2) || 0). If other
 permissions are expected for those directories, caller must either pre-create them,
 either fix permissions once after.

 Param hashref \%options OPTIONAL options:
  - umask          : UMASK(2) for a new diretory. For instance if the given umask is 0027, mode will be: 0777 & ~0027 = 0750 (in octal)
  - user           : File owner (default: EUID for a new file, no change for existent directory unless fixpermissions is TRUE)
  - group          : File group (default: EGID for a new file, no change for existent directory unless fixpermissions is TRUE)
  - mode           : File mode (default: 0777 & ~(UMASK(2) || 0) for a new file, no change for existent directory unless fixpermissions is TRUE)
  - fixpermissions : If TRUE, set ownership and permissions even for existent $self->{'directory'}
 Return self, die on failure

=cut

sub make
{
    my ( $self, $options ) = @_;
    $options //= {};

    ref $options eq 'HASH' or croak( '$options parameter is invalid' );

    my ( @dst ) = stat $self->{'dirname'};
    @dst || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $self->{'dirname'}, $! ));
    !@dst || S_ISDIR( $dst[2] ) or die( sprintf( "Failed to create '%s': file exists and is not a directory", $self->{'dirname'} ));

    unless ( @dst ) {
        my $parent = dirname( $self->{'dirname'} );
        unless ( -d $parent ) {
            local $self->{'dirname'} = $parent;
            # Parent directories are always created with default perms: 0777 & ~(UMASK(2) || 0)
            $self->make();
        }

        # Change the default umask temporarily if requested by caller
        local $UMASK = $options->{'umask'} if defined $options->{'umask'};
        mkdir $self->{'dirname'} or die( sprintf( "Failed to create '%s': %s", $self->{'dirname'}, $! ));
    }

    return $self unless !@dst || $self->{'fixpermissions'};

    if ( defined $options->{'user'} || defined $options->{'group'} ) {
        $self->owner( $options->{'user'} // -1, $options->{'group'} // -1, $self->{'dirname'} );
    }

    # $self->{'directory'} was an existent symlink
    # We do not want call CHMOD(2) on symlinks
    return $self if @dst && -l $self->{'dirname'};

    $self->mode( $options->{'mode'} ) if defined $options->{'mode'};
    $self;
}

=item remove()

 Remove a directory recusively

 Return self, die on failure

=cut

sub remove
{
    my ( $self ) = @_;

    eval { remove_tree $self->{'dirname'}, { safe => 1 }; };
    !$@ or die( sprintf( 'Failed to remove %s: %s', $self->{'dirname'}, $@ ));
    $self;
}

=item copy( $dest [, \%options = { umask => UMASK(2), preserve => undef, no_target_directory = TRUE } ] )

 Copy this directory recursively into the given destination

 The behavior is nearly the same as the cp(1) command:
  - symlinks are not dereferenced. This is nearly same as executing: cp(1) --recursive --no-dereference dir dest

  - If the 'preserve' option is set to TRUE, source file's ownership and permissions are preserved. Non-permission bits set(UID|GID) and sticky bit
    are preserved only if the copy of both owner and group succeeded.
    This is nearly same as executing: cp(1) --recursive --preserve=ownership,mode dir dest

  - If the 'preserve option is not explicitely set to FALSE, ownership and permissions of existent files are left untouched and the following
    rules apply for new files:
     - Permissions set are those from source file on which UMASK(2) is applied. Non-permission bits are not preserved.
     - Owner is set to EUID while the group set depends on a range of factors:
       - If the fs is mounted with -o grpid, the group is made the same as that of the parent dir.
       - If the fs is mounted with -o nogrpid and the setgid bit is disabled on the parent dir, the group will be set to EGID
       - If the fs is mounted with -o nogrpid and the setgid bit is enabled on the parent dir, the group is made the same as that of the parent dir.
       As at Linux 2.6.25, the -o grpid and -o nogrpid mount options are supported by ext2, ext3, ext4, and XFS. Filesystems that don't support these
       mount options follow the -o nogrpid rules.   
       This is nearly same as executing: cp(1) --recursive dir dest

  - If the 'preserve' option is explicitely set to FALSE, the ownership is set same as when the 'preserve' option is not explicitely set to FALSE.
    The permissions are set to default mode (0666|0777) on which UMASK(2) is applied.
    This is nearly same as executing: cp(1) --recursive --no-preserve=mode dir dest

  - If the 'no_target_directory' option is TRUE, $dest is treated as normal file.
    This is nearly same as executing: cp(1) --recursive --no-target-directory dir dest

  - Access Control List (ACL), timestamps, security context and extended attributes are not preserved.

 Param string $dest Destination path
 Param hashref \%options OPTIONAL options:
  - umask               : OPTIONAL UMASK(2). See above for it usage cases. This option is only relevant when the preserve option is FALSE.
  - preserve            : See above for the behavior.
  - no_target_directory : If set to TRUE (default), treat $dest as a normal file
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

    # FIXME: Should we follow symlinks?
    my @sst;
    unless ( @sst = lstat $self->{'dirname'} ) {
        error( sprintf( "cannot stat '%s': %s", $self->{'dirname'}, $! ));
        goto endCopy;
    }

    if ( !S_ISDIR( $sst[2] ) ) {
        error( sprintf( "not a directory: '%s'", $self->{'dirname'} ));
        goto endCopy;
    }

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
        $ret = _copyInternal( $self->{'dirname'}, $dest, FALSE, $options );
    } else {
        $dest .= '/' . basename( $self->{'dirname'} );
        $ret = _copyInternal( $self->{'dirname'}, $dest, $newDst, $options );
    }

    endCopy:
    $ret or die( sprintf( "Failed to copy '%s' to '%s': %s", $self->{'dirname'}, $dest, scalar getMessageByType( 'error', { remove => TRUE } )));
    $self;
}

=item move( $dest )

 Move this directory to the given destination

 Param string $dest Destination
 Return self, die on failure

=cut

sub move
{
    my ( $self, $dest ) = @_;

    length $dest or croak( '$dest parameter is missing or invalid' );

    my ( @st ) = lstat $self->{'dirname'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'dirname'}, $! ));

    S_ISDIR( $st[2] ) or die( sprintf( "Failed to move '%s' to '%s': not a directory", $self->{'dirname'}, $dest, $self->{'dirname'} ));

    if ( File::Copy::mv( $self->{'dirname'}, $dest ) ) {
        # Update the 'dirname' attribute to make us able to continue working with
        # this directory regardless of its new location.
        $self->{'dirname'} = $dest;
        return $self;
    };

    die( sprintf( "Failed to move '%s' to '%s': %s", $self->{'dirname'}, $dest, $! ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize iMSCP::Dir object

 Return self, croak if the 'dirname' attribute is not set

=cut

sub _init
{
    my ( $self ) = @_;

    length $self->{'dirname'} or croak( 'dirname attribute is not defined or invalid' );

    $self->{'dirname'} = File::Spec->canonpath( $self->{'dirname'} );
    $self;
}

=item _copyInternal( $srcName, $dstName, $newDst, \%options )

 Copy the given file to the given destination
 
 The file can be of any type. $newDst should be FALSE if the file $dstName
 might already exist.
 
 Param string $srcName Source file path
 Param string $dstName  Destination file path
 Param bool $newDst Flag indicating whether or not $dstName might already exist. 
 Param hashref \%options Copy options
 Return TRUE on success, FALSE on failure with error set through error()

=cut

sub _copyInternal
{
    my ( $srcName, $dstName, $newDst, $options ) = @_;

    my ( @sst, @dst );
    my ( $haveDstLstat, $copiedAsRegular, $dstIsSymlink, $restoreDstMode, $dstMode ) = ( FALSE, FALSE, FALSE, FALSE );

    unless ( @sst = lstat $srcName ) {
        error( sprintf( "cannot stat '%s': %s", $srcName, $! ));
        return FALSE;
    }

    my $srcMode = $sst[2];

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

            if ( !S_ISDIR( $dst[2] ) ) {
                if ( S_ISDIR( $srcMode ) ) {
                    error( sprintf( "cannot overwrite non-directory '%s' with directory '%s'", $dstName, $srcName ));
                    return FALSE;
                }
            }

            if ( !S_ISDIR( $srcMode ) ) {
                if ( S_ISDIR( $dst[2] ) ) {
                    error( sprintf( "cannot overwrite directory '%s' with non-directory '%s'", $dstName, $srcName ));
                    return FALSE;
                }
            }

            # Files other than regular files must be pre-removed, else we won't be
            # able to copy them as they are simply re-created from scratch
            if ( !S_ISDIR( $dst[2] ) && !S_ISREG( $dst[2] ) ) {
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

    my $delayedOk = TRUE;

    if ( S_ISDIR( $srcMode ) ) {
        if ( $newDst || !S_ISDIR( $dst[2] ) ) {
            # POSIX says mkdir's behavior is implementation-defined when
            # (src_mode & ~S_IRWXUGO) != 0. However, common practice is
            # to ask mkdir to copy all the CHMOD_MODE_BITS, letting mkdir
            # decide what to do with S_ISUID | S_ISGID | S_ISVTX.
            unless ( mkdir( $dstName, $dstModeBits & ~$omittedPerms ) ) {
                error( sprintf( "cannot create directory '%s': %s", $dstName, $! ));
                return FALSE;
            }

            # We need search and write permissions to the new directory
            # for writing the directory's contents. Check if these
            # permissions are there.
            unless ( @dst = lstat( $dstName ) ) {
                error( sprintf( "cannot stat '%s': %s", $dstName, $! ));
                return FALSE;
            }

            if ( ( $dst[2] & S_IRWXU ) != S_IRWXU ) {
                # Make the new directory searchable and writable.
                $dstMode = $dst[2];
                $restoreDstMode = TRUE;

                unless ( chmod $dstModeBits | S_IRWXU, $dstName ) {
                    error( sprintf( "setting permissions for '%s': %s", $dstName, $! ));
                    return FALSE;
                }
            }
        } else {
            $omittedPerms = 0;
        }

        # Copy the contents of the directory. Don't just return if
        # this fails -- otherwise, the failure to read a single file
        # in a source directory would cause the containing destination
        # directory not to have owner/perms set properly.
        if ( opendir my $dh, $srcName ) {
            while ( my $dentry = readdir $dh ) {
                next if $dentry =~ /^\.{1,2}\z/s;
                $delayedOk &= _copyInternal( $srcName . '/' . $dentry, $dstName . '/' . $dentry, FALSE, $options );
            }

            unless ( closedir $dh ) {
                error( sprintf( "cannot close dir '%s': %s", $srcName, $! ));
                $delayedOk = FALSE;
            }
        } else {
            error( sprintf( "cannot open dir '%s': %s", $srcName, $! ));
            $delayedOk = FALSE;
        }
    } elsif ( S_ISREG( $srcMode ) ) {
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

    return $delayedOk if $copiedAsRegular;

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
    return $delayedOk if $dstIsSymlink;

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
        unless ( chmod( ( S_ISDIR( $srcMode ) || S_ISSOCK( $srcMode ) ? S_IRWXUGO : MODE_RW_UGO ) & ~$UMASK, $dstName ) ) {
            error( sprintf( "preserving permissions for '%s': %s", $dstName, $! ));
            return FALSE;
        }
    } else {
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

    $delayedOk;
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
        error( sprintf( "cannot create regular file '%s': %s", $dstName, $destErrno ));
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
    unless ( close( $dstFH ) ) {
        error( sprintf( "failed to close '%s'", $srcName ));
        $retVal = FALSE;
    }

    closeSrc:
    unless ( close( $srcFH ) ) {
        error( sprintf( "failed to close '%s'", $dstName ));
        $retVal = FALSE;
    }

    $retVal;
}

=item _mknod( $pathname, $mode, $dev )

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

=item _chownOrChmodFailureOk( )
 
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

 Param arrayref \@ast A reference to an array as returned by stat() and similars
 Param arrayref \@bst A reference to an array as returned by stat() and similars
 Return bool TRUE if owner in both arrays is identical, FALSE otherwise

=cut

sub _sameOwner
{
    my ( $ast, $bst ) = @_;

    $ast->[4] == $bst->[4];
}

=item _isSameGroup( \@ast, \@bst )

 Return TRUE if group in both arrays is identical

 Param arrayref \@ast A reference to an array as returned by stat() and similars
 Param arrayref \@bst A reference to an array as returned by stat() and similars
 Return bool TRUE if group in both arrays is identical, FALSE otherwise

=cut

sub _isSameGroup
{
    my ( $ast, $bst ) = @_;

    $ast->[5] == $bst->[5];
}

=item _sameOwnerAndGroup( \@ast, \@bst )

 Return TRUE if owner and group in both arrays are identical

 Param arrayref \@ast A reference to an array containing elements as returned by stat() and similars
 Param arrayref \@bst A reference to an array containing elements as returned by stat() and similars
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

 Param hashref \%options Copy options
 Param string $dstName Destination file path
 Param GLOB|undef $dstFH Destination file handle
 Param arrayref \@sst A reference to an array as returned by stat() and similars
 Param bool $newDst Flag indicating whether $dstName is a new file
 Param arrayref \@dst A reference to an array as returned by stat() and similars
 Return 1 if the initial syscall succeeds, 0 if it fails but it's OK not to preserve ownership, -1 otherwise with error set through error()

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

 Param arrayref \@ast A reference to an array containing elements as returned by stat() and similars
 Param arrayref \@bst A reference to an array containing elements as returned by stat() and similars
 Return bool TRUE if owner and group in both arrays are identical, FALSE otherwise

=cut

sub _sameInode
{
    my ( $ast, $bst ) = @_;

    $ast->[0] == $bst->[0] && $ast->[1] == $bst->[1];
}

=item __toString( )

 Return string representation of this object, that is the value of the 'dirname'
 attribute.

=cut

sub __toString
{
    $_[0]->{'dirname'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
