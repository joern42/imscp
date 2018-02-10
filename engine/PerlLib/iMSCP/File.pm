=head1 NAME

 iMSCP::File - Perform common operations on files

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
use Fcntl qw/ :mode /;
use File::Basename ();
use File::Copy ();
use File::Spec ();
use iMSCP::Boolean;
use iMSCP::Umask;
use Lchown;
use overload '""' => \&__toString, fallback => 1;
use parent 'iMSCP::Common::Object';

# Upper limit for file slurping (2MiB)
# If really needed caller can always change default value
our $SLURP_SIZE_LIMIT = 1024 * 1024 * 2;

=head1 DESCRIPTION

 Perform common operations on files

=head1 PUBLIC METHODS

=over 4

=item get( )

 Get content of this file

 Warning: File slurped in memory. This method is not intented to be used on
 large files.

 Return string File content, die on failure

=cut

sub get
{
    my ($self) = @_;

    return $self->{'file_content'} if defined $self->{'file_content'};

    my (@sst) = stat $self->{'filename'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'filename'}, $! ));
    S_ISREG( $sst[2] ) or die( sprintf( "Failed to get '%s' content: Not a file", $self->{'filename'} ));
    -s _ < $SLURP_SIZE_LIMIT or croak( sprintf( "Failed to get '%s' content: File too big", $self->{'filename'} ));

    open( my $fh, '<', $self->{'filename'} ) or die( sprintf( "Failed to open '%s' for reading: %s", $self->{'filename'}, $! ));
    local $/;
    $self->{'file_content'} = <$fh>;
    close( $fh );
    $self->{'file_content'};
}

=item

 Get file content this file as a scalar reference

 Warning: File is slurped in memory. This method is not intented to be used on
 large files.

 Return scalarref Reference to scalar containing file content, die on failure

=cut

sub getAsRef
{
    my ($self) = @_;

    $self->get() unless defined $self->{'file_content'};
    \ $self->{'file_content'};
}

=item set( $content )

 Set content of this file

 Param string $content New file content
 Return self

=cut

sub set
{
    my ($self, $content) = @_;

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
    my ($self, $umask) = @_;

    # Change the default umask temporarily if requested by caller
    local $UMASK = $umask if defined $umask;
    open my $fh, '>', $self->{'filename'} or die( sprintf( "Failed to open '%s' for writing: %s", $self->{'filename'}, $! ));
    print { $fh } $self->{'file_content'} // '';
    close( $fh );
    $self;
}

=item remove( )

 Remove this file
 
 At this time, only symlinks and regular files are considered. Other files are
 silently ignored.

 Return self, die on failure

=cut

sub remove
{
    my ($self) = @_;

    my (@st) = lstat $self->{'filename'};

    @st || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $self->{'filename'}, $! ));

    return $self unless @st;

    !S_ISDIR( $st[2] ) or croak( sprintf( "Failed to remove '%s': Not a file", $self->{'filename'} ));

    # Files other than symlinks and regular files are ignored silently.
    return $self unless S_ISLNK( $st[2] ) || S_ISREG( $st[2] );

    unlink $self->{'filename'} or die( sprintf( "Failed to remove '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item mode( $mode )

 Set mode of this file

 Param int $mode New file mode (octal number)
 Return self, die on failure

=cut

sub mode
{
    my ($self, $mode) = @_;

    defined $mode or croak( '$mode parameter is missing.' );
    chmod $mode, $self->{'filename'} or die( sprintf( "Failed to set permissions for '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item owner( $owner = -1, $group = -1 )

 Set ownership of this file

 Symlinks are never dereferenced.

 Param int|string $owner Either an user name or user ID
 Param int|string $group Either a group name or group ID
 Return self, die on failure

=cut

sub owner
{
    my ($self, $owner, $group) = @_;

    defined $owner or croak( '$owner parameter is missing.' );
    defined $group or croak( '$group parameter is missing.' );

    my $uid = ( ( $owner =~ /^\d+$/ ) ? $owner : getpwnam( $owner ) ) // -1;
    my $gid = ( ( $group =~ /^\d+$/ ) ? $group : getgrnam( $group ) ) // -1;
    lchown $uid, $gid, $self->{'filename'} or die ( sprintf( "Failed to set ownership for '%s': %s", $self->{'filename'}, $! ));
    $self;
}

=item copy( $dest [, \%options = { umask => UMASK(2),  preserve => FALSE, no-target-directory = FALSE } ] )

 Copy this file to the given destination

 At this time, only regular and symlink files are considered. Other files are
 silently ignored. Access Control List (ACL) are not preserved (to be fixed using Linux::ACL module).

 The behavior is nearly the same as the cp(1) command:
  - symlinks are never dereferenced (same as the cp(1) --no-dereference option)
  - If the 'preserve' option is TRUE (same as the cp(1) --preserve=ownership,mode option), source file's permission bits and ownership are preserved.
    Set-UID and Set-GID bit are preserved only if the copy of both owner and group succeeded.
  - If the 'preserve' option is FALSE, ownership and permission of existent files are left untouched. The following rules apply for new files:
     - Permission will be same as original file (excluding setuid/setgid bits) with caller or current UMASK(2) applied on them.
     - Owner is set to EUID while the group set depends on a range of factors:
       - If the fs is mounted with -o grpid, the group is made the same as that of the parent dir.
       - If the fs is mounted with -o nogrpid and the setgid bit is disabled on the parent dir, the group will be set to EGID
       - If the fs is mounted with -o nogrpid and the setgid bit is enabled on the parent dir, the group is made the same as that of the parent dir.
       As at Linux 2.6.25, the -o grpid and -o nogrpid mount options are supported by ext2, ext3, ext4, and XFS. Filesystems that don't support these
       mount options follow the -o nogrpid rules.
  - If the 'no-target-directory' option is TRUE (same as cp(1) --no-target-directory), $target is treated as normal file, that is, copying
    /tmp/dir1 to / will copy content from /tmp/dir1 into / instead of copying /tmp/dir1 into /dir1. Be in mind that copying /tmp/file.txt to / will
    raise and error as it is not possible to overwrite a directory with a non-directory.

    See http://man7.org/linux/man-pages/man1/cp.1.html for further details.

 Param string $dest Depending on passed-in options, can be either a file path or directory path
 Param hash \%options OPTIONAL options:
  - umask               : OPTIONAL UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: SRC_MODE & ~0027 .
                          This option is only relevant when the preserve option is not TRUE.
  - preserve            : If set to TRUE preserve ownership and permissions (default FALSE).
  - no-target-directory : If set to TRUE, treat $dest as a normal file    (default FALSE).
 Return self, die on failure

=cut

sub copy
{
    my ($self, $dest, $options) = @_;
    $options //= {};

    ref $options eq 'HASH' or croak( '$options parameter is not valid. Hash expected' );
    defined $dest or croak( '$dest parameter is missing.' );

    my (@sst) = lstat $self->{'filename'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'filename'}, $! ));
    my (@dst) = lstat $dest;
    @dst || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $dest, $! ));

    !S_ISDIR( $sst[2] ) or croak( sprintf( "Failed to copy '%s' to '%s': '%s' is a directory", $self->{'filename'}, $dest, $self->{'filename'} ));

    # At this moment, only regular files and symlinks are copied.
    # Other are ignored silently.
    return $self unless S_ISLNK( $sst[2] ) || S_ISREG( $sst[2] );

    if ( @dst ) {
        # Make sure that we don't try copy on ourself.
        if ( $sst[1] == $dst[1] && $sst[2] == $dst[2] ) {
            croak( sprintf( "Failed to copy. '%s' and '%s' are the same file", $self->{'filename'}, $dest ));
        }

        if ( $options->{'no-target-directory'} && S_ISDIR( $dst[2] ) ) {
            die( sprintf( "Failed to copy '%s' to '%s': cannot overwrite directory with a non-directory", $self->{'filename'}, $dest ));
        } elsif ( S_ISDIR( $dst[2] ) ) {
            # Append the last component of $self->{'filename'} to $dest.
            $dest = File::Spec->catfile( $dest, File::Basename::basename( $self->{'filename'} ));
        }
    }

    if ( S_ISLNK( $sst[2] ) ) {
        # symlink() call fails if the file already exists.
        unlink $dest;
        symlink( readlink( $self->{'filename'} ), $dest ) or die( sprintf( "Failed to copy '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));
    } else {
        File::Copy::copy( $self->{'filename'}, $dest ) or die( sprintf( "Failed to copy '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));
    }

    # Preserve ownership. CHOWN(2) turns off set[ug]id bits for non-root, so do
    # the CHMOD(2) last.
    my $ownershipFailed = FALSE;
    if ( $options->{'preserve'} && !lchown( $sst[4], $sst[5], $dest ) ) {
        # If a non-root user pass the preserve option when copying file, it's ok
        # if we can't preserve ownership. But root probably wants to know, e.g.
        # if NFS disallows it, or if the target system doesn't support file ownership.
        ( $! == EPERM || $! == EINVAL ) && $EUID != 0 or die sprintf( "Failed to preserve ownership for '%s': %s", $dest, $! );

        # Failing to preserve ownership is OK. Still, try to preserve
        # the group, but ignore the possible error.
        lchown( -1, $sst[5], $dest );

        $ownershipFailed = TRUE;
    }

    # We do not want call CHMOD(2) on symlinks
    return $self if S_ISLNK( $sst[2] );

    # We do not want preserve permissions and $dest was an existent file.
    # In such a case, file must be left untouched.
    return $self if !$options->{'preserve'} && @dst;

    my $mode;
    if ( $options->{'preserve'} ) {
        # we do want preserve permissions
        $mode = $sst[2];
        # If preserving owner and group was not possible the setuid and/or
        # setgid bits must be cleared.
        $mode &= ~06000 if $ownershipFailed;
    } else {
        # We do not want preserve permissions and $dest was not an existent file.
        # In such case, we set original permissions (excluding setuid/setgid bits),
        # applying caller or current umask on them.
        $mode = ( $sst[2] & ~( $options->{'umask'} // $UMASK ) ) & ~06000;
    }

    chmod S_IMODE( $mode ), $dest or die( sprintf( "Failed to set permissions for '%s': %s", $dest, $! ));
    $self;
}

=item move( $dest )

 Move this file to the given destination

 At this time, only regular and symlink files are considered. Other files are
 silently ignored.
 
 A specific treatment is applied on symlinks as thir target paths can be
 relative to their current location. if so, those are simply recreated from
 using their new location as base directory for generating a new relative
 target path. If the target path is an absolute path, these are treaded as
 regular files.

 Note that even if File::Copy::move() is able to move directories, we raise an
 error in case $self->{'filename'} refers to a directory. If you need to move
 a directory, make use of iMSCP::Dir::move() instead.

 Param string $dest Destination
 Return self, die on failure

=cut

sub move
{
    my ($self, $dest) = @_;

    defined $dest or croak( '$dest parameter is missing.' );

    my (@sst) = lstat $self->{'filename'} or croak( sprintf( "Failed to stat '%s': %s", $self->{'filename'}, $! ));
    !S_ISDIR( $sst[2] ) or die( sprintf( "Failed to move '%s' to '%s': Not a file", $self->{'filename'}, $dest, $self->{'filename'} ));

    # Files other than symlinks and regular files are ignored silently.
    return $self unless S_ISLNK( $sst[2] ) || S_ISREG( $sst[2] );

    my (@dst) = stat $dest;
    @dst || $! == ENOENT or die( sprintf( "Failed to access '%s': %s", $dest, $! ));

    if ( S_ISLNK( $sst[2] ) && !File::Spec->file_name_is_absolute( readlink $self->{'filename'} ) ) {
        # Turn target relative path into absolute path
        my $lnkTgtAbs = Cwd::abs_path( $self->{'filename'} );
        # Guess base directory for new symlink location
        my $lnkDir = @dst && S_ISDIR( $dst[2] ) ? $dest : File::Basename::dirname( $dest );
        # Generate new target relative path
        my $lnkTgtRel = File::Spec->abs2rel( $lnkTgtAbs, $lnkDir );

        $dest = File::Spec->catfile( $dest, File::Basename::basename( $self->{'filename'} )) if @dst && S_ISDIR( $dst[2] );

        symlink $lnkTgtRel, $dest or die( sprintf( "Failed to move '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));
        unlink $self->{'filename'};

        # Update $self->{'filename'}' to make us able to continue working with this file regardless of its new location.
        $self->{'filename'} = $dest;
        return $self;
    }

    File::Copy::mv( $self->{'filename'}, $dest ) or die( sprintf( "Failed to move '%s' to '%s': %s", $self->{'filename'}, $dest, $! ));

    # Update $self->{'filename'}' to make us able to continue working with this file regardless of its new location.
    $self->{'filename'} = @dst && S_ISDIR( $dst[2] ) ? File::Spec->catfile( $dest, File::Basename::basename( $self->{'filename'} )) : $dest;
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
    my ($self) = @_;

    defined $self->{'filename'} or croak( 'filename attribute is not defined.' );
    $self->{'filename'} = File::Spec->canonpath( $self->{'filename'} );
    $self->{'file_content'} = undef;
    $self;
}

=item __toString()

 Return string representation of this object, that is the value of $self->{'filename'}

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
