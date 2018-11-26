=head1 NAME

 iMSCP::Mount - Library for mounting/unmounting file systems

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

package iMSCP::Mount;

use strict;
use warnings;
use Carp qw/ croak /;
use Errno qw/ EINVAL ENOENT /;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::File;
use iMSCP::H2ph;
use Scalar::Defer;
use parent 'Exporter';

our @EXPORT_OK = qw/ addMountEntry getMounts isMountpoint mount setPropagationFlag removeMountEntry umount /;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

# Mount options
# MT_INVERT -> &~
my %MOUNT_FLAGS = (
    defaults      => sub { 0 },

    ro            => sub { $_[0] | &iMSCP::H2ph::MS_RDONLY },
    rw            => sub { $_[0] &~ &iMSCP::H2ph::MS_RDONLY },
    exec          => sub { $_[0] & ~&iMSCP::H2ph::MS_NOEXEC },
    noexec        => sub { $_[0] | &iMSCP::H2ph::MS_NOEXEC },
    suid          => sub { $_[0] & ~&iMSCP::H2ph::MS_NOSUID },
    nosuid        => sub { $_[0] | &iMSCP::H2ph::MS_NOSUID },
    dev           => sub { $_[0] & ~&iMSCP::H2ph::MS_NODEV },
    nodev         => sub { $_[0] | &iMSCP::H2ph::MS_NODEV },

    sync          => sub { $_[0] | &iMSCP::H2ph::MS_SYNCHRONOUS },
    async         => sub { $_[0] & ~&iMSCP::H2ph::MS_SYNCHRONOUS },

    dirsync       => sub { $_[0] | &iMSCP::H2ph::MS_DIRSYNC },
    remount       => sub { $_[0] | &iMSCP::H2ph::MS_REMOUNT },
    bind          => sub { $_[0] | &iMSCP::H2ph::MS_BIND },
    rbind         => sub { $_[0] | &iMSCP::H2ph::MS_BIND | &iMSCP::H2ph::MS_REC },

    sub           => defined( &iMSCP::H2ph::MS_NOSUB ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_NOSUB } : sub { $_[0] },
    nosub         => defined( &iMSCP::H2ph::MS_NOSUB ) ? sub { $_[0] | &iMSCP::H2ph::MS_NOSUB } : sub { $_[0] },

    silent        => defined( &iMSCP::H2ph::MS_SILENT ) ? sub { $_[0] | &iMSCP::H2ph::MS_SILENT } : sub { $_[0] },
    loud          => defined( &iMSCP::H2ph::MS_SILENT ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_SILENT } : sub { $_[0] },

    mand          => defined( &iMSCP::H2ph::MS_MANDLOCK ) ? sub { $_[0] | &iMSCP::H2ph::MS_MANDLOCK } : sub { $_[0] },
    nomand        => defined( &iMSCP::H2ph::MS_MANDLOCK ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_MANDLOCK } : sub { $_[0] },

    atime         => defined( &iMSCP::H2ph::MS_NOATIME ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_NOATIME } : sub { $_[0] },
    noatime       => defined( &iMSCP::H2ph::MS_NOATIME ) ? sub { $_[0] | &iMSCP::H2ph::MS_NOATIME } : sub { $_[0] },

    iversion      => defined( &iMSCP::H2ph::MS_I_VERSION ) ? sub { $_[0] | &iMSCP::H2ph::MS_I_VERSION } : sub { $_[0] },
    noiversion    => defined( &iMSCP::H2ph::MS_I_VERSION ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_I_VERSION } : sub { $_[0] },

    diratime      => defined( &iMSCP::H2ph::MS_NODIRATIME ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_NODIRATIME } : sub { $_[0] },
    nodiratime    => defined( &iMSCP::H2ph::MS_NODIRATIME ) ? sub { $_[0] | &iMSCP::H2ph::MS_NODIRATIME } : sub { $_[0] },

    relatime      => defined( &iMSCP::H2ph::MS_RELATIME ) ? sub { $_[0] | &iMSCP::H2ph::MS_RELATIME } : sub { $_[0] },
    norelatime    => defined( &iMSCP::H2ph::MS_RELATIME ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_RELATIME } : sub { $_[0] },

    strictatime   => defined( &iMSCP::H2ph::MS_STRICTATIME ) ? sub { $_[0] | &iMSCP::H2ph::MS_STRICTATIME } : sub { $_[0] },
    nostrictatime => defined( &iMSCP::H2ph::MS_STRICTATIME ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_STRICTATIME } : sub { $_[0] },

    lazytime      => defined( &iMSCP::H2ph::MS_LAZYTIME ) ? sub { $_[0] | &iMSCP::H2ph::MS_LAZYTIME } : sub { $_[0] },
    nolazytime    => defined( &iMSCP::H2ph::MS_LAZYTIME ) ? sub { $_[0] & ~&iMSCP::H2ph::MS_LAZYTIME } : sub { $_[0] },

    move          => sub { $_[0] | &iMSCP::H2ph::MS_MOVE }
);

# Propagation flags
my %PROPAGATION_FLAGS = (
    unbindable  => sub { $_[0] | &iMSCP::H2ph::MS_UNBINDABLE },
    runbindable => sub { $_[0] | &iMSCP::H2ph::MS_UNBINDABLE | &iMSCP::H2ph::MS_REC },
    private     => sub { $_[0] | &iMSCP::H2ph::MS_PRIVATE },
    rprivate    => sub { $_[0] | &iMSCP::H2ph::MS_PRIVATE | &iMSCP::H2ph::MS_REC },
    slave       => sub { $_[0] | &iMSCP::H2ph::MS_SLAVE },
    rslave      => sub { $_[0] | &iMSCP::H2ph::MS_SLAVE | &iMSCP::H2ph::MS_REC },
    shared      => sub { $_[0] | &iMSCP::H2ph::MS_SHARED },
    rshared     => sub { $_[0] | &iMSCP::H2ph::MS_SHARED | &iMSCP::H2ph::MS_REC }
);

# Lazy-load mount entries
my $MOUNTS = lazy
    {
        -f '/proc/self/mounts' or die( "Failed to load mount entries. File /proc/self/mounts not found." );
        open my $fh, '<', '/proc/self/mounts' or die( sprintf( "Failed to read /proc/self/mounts file: %s", $! ));
        my $entries;
        while ( my $entry = <$fh> ) {
            my $fsFile = ( split /\s+/, $entry )[1];
            $entries->{File::Spec->canonpath( $fsFile =~ s/\\040\(deleted\)$//r )}++;
        }
        close( $fh );
        $entries;
    };

# FH object to i-MSCP fstab-like file
my $iMSCP_FSTAB_FH;

=head1 DESCRIPTION

 Library for mounting/unmounting file systems.

=head1 PUBLIC FUNCTIONS

=over 4

=item getMounts( )

 Get list of mounts

 Return List of mounts (duplicate mounts are discarded)

=cut

sub getMounts
{
    reverse sort keys %{ $MOUNTS };
}

=item mount( \%fields )

 Create a new mount, or remount an existing mount, or/and change the
 propagation type of an existing mount

 Param hashref \%fields Hash describing filesystem to mount:
  - fs_spec         : Field describing the block special device or remote filesystem to be mounted
  - fs_file         : Field describing the mount point for the filesystem
  - fs_vfstype      : Field describing the type of the filesystem
  - fs_mntops       : Field describing the mount options associated with the filesystem
  - ignore_failures : Flag allowing to ignore mount operation failures
 Return void, die on failure

=cut

sub mount( $ )
{
    my ( $fields ) = @_;
    $fields = {} unless defined $fields && ref $fields eq 'HASH';

    for my $field ( qw/ fs_spec fs_file fs_vfstype fs_mntops / ) {
        defined $fields->{$field} or croak( sprintf( "%s field not defined", $field ));
    }

    force $MOUNTS; # Force loading of mount entries if not already done
    my $fsSpec = File::Spec->canonpath( $fields->{'fs_spec'} );
    my $fsFile = File::Spec->canonpath( $fields->{'fs_file'} );
    my $fsVfstype = $fields->{'fs_vfstype'};

    debug( "$fsSpec $fsFile $fsVfstype $fields->{'fs_mntops'}" );

    my ( $mflags, $pflags, $data ) = _parseOptions( $fields->{'fs_mntops'} );
    $mflags |= &iMSCP::H2ph::MS_MGC_VAL unless $mflags & &iMSCP::H2ph::MS_MGC_MSK;

    my @mountArgv;

    if ( $mflags & &iMSCP::H2ph::MS_BIND ) {
        print "here bind\n";
        # Create a bind mount or remount an existing bind mount
        push @mountArgv, [ $fsSpec, $fsFile, $fsVfstype, $mflags, $data ];

        # If MS_REMOUNT was not specified, and if there are mountflags other
        # than MS_BIND and MS_REC, schedule an additional mount(2) call to
        # change mountflags on existing mount. This is needed since mountflags
        # other than MS_BIND and MS_REC are ignored in first call.
        if ( !( $mflags & &iMSCP::H2ph::MS_REMOUNT ) && ( $mflags & ~( &iMSCP::H2ph::MS_BIND | &iMSCP::H2ph::MS_REC ) ) ) {
            push @mountArgv, [ $fsSpec, $fsFile, $fsVfstype, &iMSCP::H2ph::MS_REMOUNT | $mflags, $data ];
        }
    } elsif ( $fsSpec ne 'none' ) {
        # Create a new mount or remount an existing mount
        push @mountArgv, [ $fsSpec, $fsFile, $fsVfstype, $mflags, $data ];
    }
    
    # Change the propagation type of an existing mount
    push @mountArgv, [ 'none', $fsFile, 0, $pflags, 0 ] if $pflags;
    
    # Process the mount(2) calls
    for my $mountArg ( @mountArgv ) {
        ( syscall( &iMSCP::H2ph::SYS_mount, @{ $mountArg } ) == 0 || $fields->{'ignore_failures'} ) or die(
            sprintf( 'Error while executing mount(%s): %s', join( ', ', @{ $mountArg } ), $! || 'Unknown error' )
        );
    }

    $MOUNTS->{$fsFile}++ unless $mflags & &iMSCP::H2ph::MS_REMOUNT;
}

=item umount( $fsFile [, $recursive = TRUE ] )

 Umount the given file system

 Note: When umount operation is recursive, any mount below the given mount
 (or directory) will be umounted.

 Param string $fsFile Mount point of file system to umount
 Param bool $recursive OPTIONAL Flag indicating whether or not umount operation must be recursive
 Return void, die on failure

=cut

sub umount( $;$ )
{
    my ( $fsFile, $recursive ) = @_;

    defined $fsFile or croak( '$fsFile parameter is not defined' );

    $recursive //= 1; # Operation is recursive by default
    $fsFile = File::Spec->canonpath( $fsFile );

    return if $fsFile eq '/'; # Prevent umounting root fs

    unless ( $recursive ) {
        return unless $MOUNTS->{$fsFile};

        do {
            debug( $fsFile );

            ( syscall( &iMSCP::H2ph::SYS_umount2, $fsFile, &iMSCP::H2ph::MNT_DETACH ) == 0 || $! == EINVAL || $! == ENOENT ) or die(
                sprintf( "Error while executing umount(%s): %s", $fsFile, $! || 'Unknown error' )
            );

            ( $MOUNTS->{$fsFile} > 1 ) ? $MOUNTS->{$fsFile}-- : delete $MOUNTS->{$fsFile};
        } while $MOUNTS->{$fsFile};

        return;
    }

    for my $mount ( reverse sort keys %{ $MOUNTS } ) {
        next unless $mount =~ /^\Q$fsFile\E(\/|$)/;

        do {
            debug( $mount );

            ( syscall( &iMSCP::H2ph::SYS_umount2, $mount, &iMSCP::H2ph::MNT_DETACH ) == 0 || $! == EINVAL || $! == ENOENT ) or die(
                sprintf( "Error while executing umount(%s): %s", $mount, $! || 'Unknown error' )
            );

            ( $MOUNTS->{$mount} > 1 ) ? $MOUNTS->{$mount}-- : delete $MOUNTS->{$mount};
        } while $MOUNTS->{$mount};
    }
}

=item setPropagationFlag( $fsFile [, $flag = private|slave|shared|unbindable|rprivate|rslave|rshared|runbindable ] )

 Change the propagation type of an existing mount

 Parameter string $fsFile Mount point
 Parameter string $flag Propagation flag as string
 Return void, die on failure

=cut

sub setPropagationFlag( $;$ )
{
    my ( $fsFile, $pflag ) = @_;
    $pflag ||= 'private';

    defined $fsFile or croak( '$fsFile parameter is not defined' );

    $fsFile = File::Spec->canonpath( $fsFile );

    debug( "$fsFile $pflag" );

    ( undef, $pflag ) = _parseOptions( $pflag );
    $pflag or croak( 'Invalid propagation flags' );

    my $src = 'none';
    syscall( &iMSCP::H2ph::SYS_mount, $src, $fsFile, 0, $pflag, 0 ) == 0 or die(
        sprintf( 'Error while changing propagation flag on %s: %s', $fsFile, $! || 'Unknown error' )
    );
}

=item isMountpoint( $path )

 Is the given path a mountpoint or bind mount?
 
 See also mountpoint(1)

 Param string $path Path to test
 Return bool TRUE if $path look like a mount point, FALSE otherwise, die on failure

=cut

sub isMountpoint( $ )
{
    my ( $path ) = @_;

    defined $path or croak( '$path parameter is not defined' );

    $path = File::Spec->canonpath( $path );

    my ( @ast ) = stat( $path ) or die( sprintf( "Failed to stat '%s'", $path, $! ));

    return TRUE if $MOUNTS->{$path};

    #  Fallback. Traditional way to detect mountpoints. This way
    # is independent on /proc, but not able to detect bind mounts.
    my ( @bst ) = stat( "$path/.." );
    ( $ast[0] != $bst[0] ) || ( $ast[0] == $bst[0] && $ast[1] == $bst[1] );
}

=item addMountEntry( $entry )

 Add the given mount entry in the i-MSCP fstab-like file

 Param string $entry Fstab-like entry to add
 Return void, die on failure

=cut

sub addMountEntry( $ )
{
    my ( $entry ) = @_;

    defined $entry or croak( '$entry parameter is not defined' );

    removeMountEntry( $entry, 0 ); # Avoid duplicate entries

    my $fileContent = $iMSCP_FSTAB_FH->getAsRef();
    ${ $fileContent } .= "$entry\n";
    $iMSCP_FSTAB_FH->save();
}

=item removeMountEntry( $entry [, $saveFile = true ] )

 Remove the given mount entry from the i-MSCP fstab-like file

 Param string|regexp $entry String or regexp representing Fstab-like entry to remove
 Param boolean $saveFile Flag indicating whether or not file must be saved
 Return void, die on failure

=cut

sub removeMountEntry( $;$ )
{
    my ( $entry, $saveFile ) = @_;
    $saveFile //= TRUE;

    defined $entry or croak( '$entry parameter is not defined' );

    my $fileContent = ( $iMSCP_FSTAB_FH ||= iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/mounts/mounts.conf" ) )->getAsRef();
    $entry = quotemeta( $entry ) unless ref $entry eq 'Regexp';
    ${ $fileContent } =~ s/^$entry\n//gm;
    $iMSCP_FSTAB_FH->save() if $saveFile;
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _parseOptions( $options )

 Parse mountflags, propagation flags and data

 Param string $options String containing options, each comma separated
 Return list List containing mount flags, propagation flags and data

=cut

sub _parseOptions( $ )
{
    my ( $options ) = @_;

    # Turn options string into option list
    my @options = split /[\s,]+/, $options;

    # Parse mount flags (excluding any propagation flag)
    my ( $mflags, @roptions ) = ( 0 );
    for my $option ( @options ) {
        push( @roptions, $option ) && next unless exists $MOUNT_FLAGS{$option};
        $mflags = $MOUNT_FLAGS{$option}->( $mflags );
    }

    # Parse propagation flags
    my ( $pflags, @data ) = ( 0 );
    for my $option ( @roptions ) {
        push( @data, $option ) && next unless exists $PROPAGATION_FLAGS{$option};
        $pflags = $PROPAGATION_FLAGS{$option}->( $pflags );
    }

    ( $mflags, $pflags, ( @data ) ? join ',', @data : 0 );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
