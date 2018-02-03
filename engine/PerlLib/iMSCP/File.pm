=head1 NAME

 iMSCP::File - Perform common operations on files

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by internet Multi Server Control Panel
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

package iMSCP::File;

use strict;
use warnings;
use English qw/ -no_match_vars /;
use Errno qw/ EPERM EINVAL /;
use File::Basename;
use File::Copy ();
use File::Spec;
use iMSCP::Umask;
use Lchown;
use overload '""' => "STRINGIFY", fallback => 1;
use parent 'iMSCP::Common::Object';

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

    open( my $fh, '<', $self->{'filename'} ) or die( sprintf( 'Failed to open %s for reading: %s', $self->{'filename'}, $! ));
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

    \$self->get();
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

    local $UMASK = $umask if defined $umask;
    open my $fh, '>', $self->{'filename'} or die( sprintf( 'Failed to open %s for writing: %s', $self->{'filename'}, $! ));
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
    my ($self) = @_;

    return $self unless -f $self->{'filename'};

    unlink $self->{'filename'} or die( sprintf( 'Failed to delete %s: %s', $self->{'filename'}, $! ));
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
    chmod $mode, $self->{'filename'} or die( sprintf( 'Failed to set permissions for %s: %s', $self->{'filename'}, $! ));
    $self;
}

=item owner( $owner, $group )

 Set ownership of this file

 Symlinks are not dereferenced, that is, not followed.

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
    lchown $uid, $gid, $self->{'filename'} or die ( sprintf( 'Failed to set ownership for %s: %s', $self->{'filename'}, $! ));
    $self;
}

=item copy( $target [, \%options = { preserve => FALSE } ] )

 Copy this file to the given target

 Warning: At this moment, only regular and symlink files are copied. Other
 files are silently ignored.

 Behavior:
  Without the preserve option (default):
   The behavior for newly created files is nearly the same as the cp(1) command with the --no-dereference option:
     - Symlinks are not dereferenced, that is, not followed.
     - Source file's permission bits are not preserved, that is, default permissions are used: 0666 & ~UMASK(2).
     - Owner is set to EUID while the group set depends on a range of factors:
        - If the fs is mounted with -o grpid, the group is made the same as that of the parent dir.
        - If the fs is mounted with -o nogrpid and the setgid bit is disabled on the parent dir, the group will be set to EGID
        - If the fs is mounted with -o nogrpid and the setgid bit is enabled on the parent dir, the group is made the same as that of the parent dir.
        As at Linux 2.6.25, the -o grpid and -o nogrpid mount options are supported by ext2, ext3, ext4, and XFS. Filesystems that don't support these
        mount options follow the -o nogrpid rules.
  With the preserve option:
   The behavior is nearly the same as the cp(1) command with the -no-dereference  and --preserve=mode,ownership options, excluding ACL:
    - Symlinks are not dereferenced, that is, not followed.
    - Source file's permission bits and ownership are preserved as much as possible.

 Param string $target Target path
 Param hash \%options OPTIONAL options:
  - preserve: If set to TRUE preserve ownership and permissions (default FALSE)
 Return self, die on failure

=cut

sub copy
{
    my ($self, $target, $options) = @_;
    $options //= {};

    ref $options eq 'HASH' or croak( '$options parameter is not valid. Hash expected' );
    defined $target or croak( '$target parameter is missing.' );

    ( my (@srcstat) = lstat $self->{'filename'} ) or die sprintf( 'Failed to stat %s: %s', $self->{'filename'}, $! );

    # At this moment, only regular files and symlinks are considered.
    return $self unless ( my $isSymlink = -l _ ) || -f _;

    # Copy the symlink or file. At this stage, permissions and ownership are
    # not preserved
    ( $isSymlink && symlink( readlink( $self->{'filename'} ), $target ) ) || File::Copy::copy( $self->{'filename'}, $target ) or die(
        sprintf( 'Failed to copy %s to %s: %s', $self->{'filename'}, $target, $! )
    );

    return $self unless $options->{'preserve'};

    # Preserve ownership. CHOWN(2) turns off set[ug]id bits for non-root, so do
    # the CHMOD(2) last.

    unless ( lchown( $srcstat[4], $srcstat[5], $target ) ) {
        # If a non-root user pass the preserve flag when copying file, it's ok
        # if we can't preserve ownership. But root probably wants to know, e.g.
        # if NFS disallows it, or if the target system doesn't support file ownership.
        ( $!{'EPERM'} || $!{'EINVAL'} ) && $EUID != 0 or die sprintf( 'Failed to preserve ownership for %s: %s', $target, $! );

        # Failing to preserve ownership is OK. Still, try to preserve
        # the group, but ignore the possible error.
        lchown( -1, $srcstat[5], $target );

        # As with the cp(1) --preserve=mode,owwership command, if preserving owner or group is not possible
        # the setuid and setgid bit are cleared
        # TODO
    }

    # We do not want call CHMOD(2) on symlinks
    return $self if $isSymlink;

    my $mode = $srcstat[2];
    my (@tgtstat) = stat $target;
    $mode &= 07777;

    # If there are setuid/setgid bits set on source file, we
    # preserve them only if the following conditions are met:
    # - setuid bit owner match. This should be always the case when EUID == 0
    #   because we also preserve the ownership.  But for a non-root user, owner
    #   will not always match.
    # - setgid bit: EUID == 0 or group match and group is one of EGID.
    if ( $mode & 06000 ) {
        @tgtstat or die( sprintf( 'Failed to check setuid/setgid bits for %s:', $target, $! ));
        $mode &= ~06000 if $mode & 04000 && $srcstat[4] != $tgtstat[4];
        $mode &= ~06000 if $mode & 02000 && $EUID != 0 && ( $srcstat[5] != $tgtstat[5] || !grep ($_ == $srcstat[5], split /\s+/, $EGID) );
    }

    if ( @tgtstat ) {
        # Don't call CHMOD(2) when that is not needed (identical permissions)
        return $self if $mode == ( $tgtstat[2] & 07777 ) || chmod $mode, $target;
    }

    die( sprintf( 'Failed to preserve permissions for %s: %s', $target, $! ));
}

=item move( $target )

 Move this file to the given target

 Param string target Target
 Return self, die on failure

=cut

sub move
{
    my ($self, $target) = @_;

    defined $target or croak( '$target parameter is missing.' );

    if ( File::Copy::mv( $self->{'filename'}, $target ) ) {
        # Update the 'filename' attribute to make us able to continue working with
        # this file regardless of its new location.
        $self->{'filename'} = -d $target ? File::Spec->catfile( $target, basename( $self->{'filename'} )) : $target;
        return $self;
    };

    die( sprintf( 'Failed to move %s to %s: %s', $self->{'filename'}, $target, $! ));
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

=item STRINGIFY()

 Return string representation of this object, that is the filename.

=cut

sub STRINGIFY
{
    $_[0]->{'filename'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
