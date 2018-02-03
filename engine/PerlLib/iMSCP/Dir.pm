=head1 NAME

 iMSCP::Dir - Perform common operations on directories

=cut

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

package iMSCP::Dir;

use strict;
use warnings;
use 5.012;
use Carp qw/ croak /;
use File::Copy ();
use File::Path qw/ make_path remove_tree /;
use File::Spec;
use iMSCP::File;
use iMSCP::Umask;
use overload '""' => "STRINGIFY", fallback => 1;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Perform common operations on directories

=head1 PUBLIC METHODS

=over 4

=item getFiles( [ $regexp = NONE, [ $inverseMatching = FALSE ] ] )

 Get list of files inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $inverseMatching Flag allowing to inverse $regexp matching 
 Return List of files, die on failure

=cut

sub getFiles
{
    my ($self, $regexp, $inverseMatching) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( 'Invalid $regexp parameter. Expects a Regexp ' );

    opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));
    my $dotReg = qr/^\.{1,2}\z/s;
    my @files = grep {
        !/$dotReg/ && ( !defined $regexp || ( $inverseMatching ? !/$regexp/ : /$regexp/ ) ) && -f "$self->{'dirname'}/$_"
    } readdir( $dh );
    closedir( $dh );
    @files;
}

=item getDirs( [ $regexp = NONE, [ $inverseMatching = FALSE ] ] )

 Get list of directories inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $inverseMatching Flag allowing to inverse $regexp matching 
 Return List of directories, die on failure

=cut

sub getDirs
{
    my ($self, $regexp, $inverseMatching) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( 'Invalid $regexp parameter. Expects a Regexp ' );

    opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));
    my $dotReg = qr/^\.{1,2}\z/s;
    my @dirs = grep {
        !/$dotReg/ && ( !defined $regexp || ( $inverseMatching ? !/$regexp/ : /$regexp/ ) ) && !-l "$self->{'dirname'}/$_" && -d _
    } readdir( $dh );
    closedir( $dh );
    @dirs;
}

=item getAll( [ $regexp = NONE, [ $inverseMatching = FALSE ] ] )

 Get list of files and directories inside this directory

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $inverseMatching Flag allowing to inverse $regexp matching 
 Return List of files and directories, die on failure

=cut

sub getAll
{
    my ($self, $regexp, $inverseMatching) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( 'Invalid $regexp parameter. Expects a Regexp ' );

    opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));
    my $dotReg = qr/^\.{1,2}\z/s;
    my @files = grep { !/$dotReg/ && ( !defined $regexp || ( $inverseMatching ? !/$regexp/ : /$regexp/ ) ) } readdir( $dh );
    closedir( $dh );
    @files;
}

=item isEmpty()

 Is directory empty?

 Return bool TRUE if the given directory is empty, FALSE otherwise, die on failure

=cut

sub isEmpty
{
    my ($self) = @_;

    my $dotReg = qr/^\.{1,2}\z/s;
    opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));
    while ( readdir $dh ) {
        next if /$dotReg/;
        closedir $dh;
        return 0;
    }
    closedir $dh;
    1;
}

=item clear( [ $regexp = NONE, [ $inverseMatching = FALSE ] ] )

 Clear full content of this directory or the first depth entries of the directory that match the given regexp

 Symlinks are not dereferenced, that is, not followed.

 Param Regexp $regexp OPTIONAL regexp for directory content matching
 Param bool OPTIONAL $inverseMatching Flag allowing to inverse $regexp matching 
 Return self, die on failure

=cut

sub clear
{
    my ($self, $regexp, $inverseMatching ) = @_;

    !defined $regexp || ref $regexp eq 'Regexp' or croak( 'Invalid $regexp parameter. Expects a Regexp ' );

    if ( defined $regexp ) {
        opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));
        my $dotReg = qr/^\.{1,2}\z/s;
        while ( readdir $dh ) {
            next if /$dotReg/;
            next unless $inverseMatching ? !/$regexp/ : /$regexp/;

            my $entry = $self->{'dirname'} . '/' . $_;

            if ( -l $entry || !-d _ ) {
                unlink $entry or die( sprintf( 'Failed to remove %s: %s', $entry, $! ));
                next;
            }

            eval { remove_tree( $self->{'dirname'}, { safe => 1 } ); };
            !$@ or die( sprintf( 'Failed to remove %s: %s', $entry, $@ ));
        }

        closedir $dh;
        return $self;
    }

    eval { remove_tree( $self->{'dirname'}, { keep_root => 1, safe => 1 } ); };
    !$@ or die( sprintf( 'Failed to clear %s: %s', $self->{'dirname'}, $@ ));
    $self;
}

=item mode( $mode )

 Set directory mode

 Param string $mode Directory mode
 Param string $dirname OPTIONAL Directory (default $self->{'dirname'})
 Return self, die on failure

=cut

sub mode
{
    my ($self, $mode) = @_;

    defined $mode or croak( '$mode parameter is missing.' );

    chmod $mode, $self->{'dirname'} or die( sprintf( 'Failed to set permissions for %s: %s', $self->{'dirname'}, $! ));
    $self;
}

=item owner( $owner, $group )

 Set directory owner and group

 Param string $owner Owner
 Param string $group Group
 Return self, die on failure

=cut

sub owner
{
    my ($self, $owner, $group) = @_;

    defined $owner or croak( '$owner parameter is missing.' );
    defined $group or croak( '$group parameter is missing.' );

    my $uid = $owner =~ /^\d+$/ ? $owner : getpwnam( $owner ) // -1;
    my $gid = $group =~ /^\d+$/ ? $group : getgrnam( $group ) // -1;
    chown $uid, $gid, $self->{'dirname'} or die( sprintf( 'Failed to set ownership for %s: %s', $self->{'dirname'}, $! ));
    $self
}

=item make( [ \%options ] )

 Create a directory

 Setting ownership and permissions on created parent directories can lead to several
 permission issues. Starting with version 1.5.0, the ownership and permissions on
 created parent directories are set as EUID:EGID 0777 & ~(UMASK(2) || 0).

 Param hash \%options OPTIONAL options:
  - umask          : UMASK(2) for a new diretory. For instance if the given umask is 0027, mode will be: 0777 & ~0027 = 0750 (in octal)
  - user           : File owner (default: EUID for a new file, no change for existent directory unless fixpermissions is TRUE)
  - group          : File group (default: EGID for a new file, no change for existent directory unless fixpermissions is TRUE)
  - mode           : File mode (default: 0666 & ~(UMASK(2) || 0) for a new file, no change for existent directory unless fixpermissions is TRUE)
  - fixpermissions : If TRUE, set ownership and permissions even for existent directory
 Return self, die on failure

=cut

sub make
{
    my ($self, $options) = @_;
    $options //= {};

    ref $options eq 'HASH' or croak( '$options parameter is not valid. Hash expected' );

    local $UMASK = $options->{'umask'} if exists $options->{'umask'};

    my $countCreated = eval { make_path $self->{'dirname'}; };
    !$@ or die( sprintf( 'Failed to create %s: %s', $self->{'dirname'}, $@ ));

    return $self unless $countCreated || $options->{'fixpermissions'};

    if ( defined $options->{'user'} || defined $options->{'group'} ) {
        $self->owner( $options->{'user'} // -1, $options->{'group'} // -1, $self->{'dirname'} );
    }

    $self->mode( $options->{'mode'} ) if defined $options->{'mode'};
    $self;
}

=item remove()

 Remove a directory recusively

 Return self, die on failure

=cut

sub remove
{
    my ($self) = @_;

    eval { remove_tree $self->{'dirname'}, { safe => 1 }; };
    !$@ or die( sprintf( 'Failed to remove %s: %s', $self->{'dirname'}, $@ ));
    $self;
}

=item copy( $target [, \%options = { preserve => FALSE } ] )

 Copy the content of this directory into the given target

 Warning: At this moment, only directory, regular and symlink files are
 copied. Other files are silently ignored.

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
 
 If target doesn't already exist, it will be created.
 Symlinks are not deferenced.

 Param string $target Target directory
 Param hash \%options OPTIONAL options:
  - preserve: If set to TRUE preserve ownership and permissions (default FALSE)
 Return self, die on failure

=cut

sub copy
{
    my ($self, $target, $options) = @_;
    $options //= {};

    defined $target or croak( '$target parameter is missing.' );
    ref $options eq 'HASH' or croak( '$options parameter is not valid. Hash expected' );

    $target = File::Spec->canonpath( $target );

    my $opts = {};
    if ( $options->{'preserve'} ) {
        @{$opts}{ qw / mode user group /} = ( stat( $self->{'dirname'} ) )[2, 4, 5];
        defined $opts->{'mode'} or die( sprinf( 'Failed to stat %s: %s', $self->{'dirname'}, $! ));
        $opts->{'mode'} &= 07777;
    }

    iMSCP::Dir->new( dirname => $target )->make( $opts );

    opendir my $dh, $self->{'dirname'} or die( sprintf( 'Failed to open %s: %s', $self->{'dirname'}, $! ));

    my $dotReg = qr/^\.{1,2}\z/s;
    while ( readdir $dh ) {
        next if /$dotReg/;

        my $src = $self->{'dirname'} . '/' . $_;
        my $tgt = $target . '/' . $_;

        if ( -l $src || !-d _ ) {
            iMSCP::File->new( filename => $src )->copy( $tgt, { preserve => $options->{'preserve'} } );
            next;
        }

        iMSCP::Dir->new( dirname => $src )->copy( $tgt, $options );
    }

    closedir $dh;
    $self;
}

=item move( $target )

 Move this directory to the given target

 Param string $target Target directory
 Return self, die on failure

=cut

sub move
{
    my ($self, $target) = @_;

    defined $target or croak( '$target parameter is missing.' );

    File::Copy::mv $self->{'dirname'}, $target or die( sprintf( 'Failed to  move %s to %s: %s', $self->{'dirname'}, $target, $! ));
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize iMSCP::Dir object

 iMSCP::Dir, die on failure

=cut

sub _init
{
    my ($self) = @_;

    defined $self->{'dirname'} or die( 'dirname attribute is not defined.' );

    $self->{'dirname'} = File::Spec->canonpath( $self->{'dirname'} );
    $self;
}

=item STRINGIFY()

 Return string representation of this object, that is the dirname

=cut

sub STRINGIFY
{
    $_[0]->{'dirname'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
