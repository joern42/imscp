=head1 NAME

 iMSCP::Ext2Attributes - Package providing access to Linux ext2 file system attributes

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

# TODO check compatibility with BSD* systems
# http://fxr.watson.org/fxr/source/fs/ext2/ioctl.c?v=linux-2.6

package iMSCP::Ext2Attributes;

use strict;
use warnings;
use Bit::Vector;
use File::Find 'finddepth';
use iMSCP::Debug qw/ debug /;
no warnings 'File::Find';
use Fcntl qw/ O_RDONLY O_NONBLOCK O_LARGEFILE /;
use parent qw( Exporter );
our @EXPORT_OK = qw(
    setSecureDeletion clearSecureDeletion isSecureDelection
    setUndelete clearUndelete isUndelete
    setCompress clearCompress isCompress
    setSynchronousUpdate cleanSynchronousUpdate isSynchronousUpdate
    setImmutable clearImmutable isImmutable
    setAppendOnly clearAppendOnly isAppendOnly
    setNoDump clearNoDump isNoDump
    setNoAtime clearNoAtime isNoAtime
    );

# Whether or not Ext2 attributes are supported
my $IS_SUPPORTED;

BEGIN
    {
        my $bitness = Bit::Vector->Long_Bits();
        my $module = "iMSCP::Ext2Attributes::Ext3Fs$bitness";

        if ( eval "require $module; 1" ) {
            $module->import();
        } else {
            $IS_SUPPORTED = 0;
            no strict 'refs';

            my $const = sub( ) {};
            for ( qw/
                EXT2_SECRM_FL EXT2_UNRM_FL EXT2_COMPR_FL EXT2_SYNC_FL EXT2_IMMUTABLE_FL EXT2_APPEND_FL EXT2_APPEND_FL EXT2_NODUMP_FL EXT2_NOATIME_FL
                EXT2_IOC_GETFLAGS EXT2_IOC_SETFLAGS
                /
            ) {
                *{$_} = $const;
            }
        }
    }

=head1 DESCRIPTION

 This library allow to handle ext2 file system attributes.

=cut

my %constants = (
    SecureDeletion    => EXT2_SECRM_FL,
    Undelete          => EXT2_UNRM_FL,
    Compress          => EXT2_COMPR_FL,
    SynchronousUpdate => EXT2_SYNC_FL,
    Immutable         => EXT2_IMMUTABLE_FL,
    AppendOnly        => EXT2_APPEND_FL,
    NoDump            => EXT2_NODUMP_FL,
    NoAtime           => EXT2_NOATIME_FL
);

=head1 FUNCTIONS

=over 4

=item setSecureDeletion( $name [, $recursive ] )

 This function takes a filename and attempts to set its secure deletion flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearSecureDeletion( $name [, $recursive ] )

 This function takes a filename and removes the secure deletion flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isSecureDeletion( $name )

This function takes a filename and returns true if the secure deletion flag is set and false if it isn't.

=item setUndelete( $name [, $recursive ] )

 This function takes a filename and attempts to set its undelete flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearUndelete( $name [, $recursive ] )

 This function takes a filename and removes the undelete flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isUndelete

This function takes a filename and returns true if the undelete flag is set and false if it isn't.

=item setCompress( $name [, $recursive ] )

 This function takes a filename and attempts to set its compress flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearCompress( $name [, $recursive ] )

 This function takes a filename and removes the compress flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isCompress( $name )

This function takes a filename and returns true if the compress flag is set and false if it isn't.

=item setSynchronousUpdate( $name [, $recursive ] )

 This function takes a filename and attempts to set its synchronous updates flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearSynchronousUpdate( $name [, $recursive ] )

 This function takes a filename and removes the synchronous updates flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isSynchronousUpdate( $name )

This function takes a filename and returns true if the synchronous updates flag is set and false if it isn't.

=item setImmutable( $name [, $recursive ] )

 This function takes a filename and attempts to set its immutable flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearImmutable( $name [, $recursive ] )

 This function takes a filename and removes the immutable flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isImmutable

This function takes a filename and returns true if the immutable flag is set and false if it isn't.

=item setAppendOnly( $name [, $recursive ] )

 This function takes a filename and attempts to set its appendable flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item clearAppendOnly( $name [, $recursive ] )

 This function takes a filename and removes the appendable flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isAppendOnly( $name )

 This function takes a filename and returns true if the append only flag is set and false if it isn't.

=item setNoAtime( $name )

 This function takes a filename and attempts to set its noatime flag.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=item isNoAtime( $name )

 This function takes a filename and returns true if the noatime flag is set and false if it isn't.

=item clearNoAtime( $name [, $recursive ] )

 This function takes a filename and removes the only noatime flag if it is present.
 If a second arguement is passed with true value, and $name is a directory, this function will operate recursively.

=cut

for my $fname ( keys %constants ) {
    my $set = sub {
        my ($name, $recursive) = @_;

        return unless _isSupported();

        if ( $recursive ) {
            debug( sprintf( 'Adding %s flag on %s recursively', $fname, $name ));
            File::Find::finddepth(
                sub {
                    _getAttributes( $_, \my $flags ) != -1 or die( sprintf( 'Failed to read flags on %s: %s', $name, $! ));
                    _setAttributes( $_, $flags | $constants{$fname} ) if defined $flags;
                },
                $name
            );
            return;
        }

        debug( sprintf( 'Adding %s flag on %s', $fname, $name ));
        _getAttributes( $name, \my $flags ) != -1 or die( sprintf( 'Failed to read flags on %s: %s', $name, $! ));
        _setAttributes( $name, $flags | $constants{$fname} ) if defined $flags;
    };

    my $clear = sub {
        my ($name, $recursive) = @_;

        return unless _isSupported();

        if ( $recursive ) {
            debug( sprintf( 'Removing %s flag on %s recursively', $fname, $name ));
            File::Find::finddepth(
                sub {
                    _getAttributes( $_, \my $flags ) != -1 or die( sprintf( 'Failed to read reading flags on %s:', $name, $! ));
                    _setAttributes( $_, $flags & ~$constants{$fname} ) if defined $flags;
                },
                $name
            );
            return;
        }

        debug( sprintf( 'Removing %s flag on %s', $fname, $name ));
        _getAttributes( $name, \my $flags ) != -1 or die( sprintf( 'Failed to read flags on %s: %s', $name, $! ));
        _setAttributes( $name, $flags & ~$constants{$fname} ) if defined $flags;
    };

    my $is = sub {
        my ($name) = @_;
        return unless _isSupported();
        _getAttributes( $name, \my $flags ) != -1 or die( sprintf( 'Failed to read flags on %s: %s', $name, $! ));
        ( defined $flags && $flags & $constants{$fname} );
    };

    no strict 'refs';
    *{__PACKAGE__ . '::set' . $fname } = $set;
    *{__PACKAGE__ . '::clear' . $fname } = $clear;
    *{__PACKAGE__ . '::is' . $fname } = $is;
}

=item _getAttributes( $name, \$flags )

 Get file attributes

 Param string $name Filename
 Param scalar_ref $flags Flags
 Return int -1 on failure, other on success

=cut

sub _getAttributes
{
    my ($name, $flags) = @_;

    my ($fd, $r, $f, $errno) = ( undef, 0, pack( 'i', 0 ), 0 );

    return -1 unless sysopen( $fd, $name, O_RDONLY | O_NONBLOCK | O_LARGEFILE );

    $r = sprintf '%d', ioctl( $fd, EXT2_IOC_GETFLAGS, $f ) || -1;
    $errno = $! if $r == -1;
    ${$flags} = unpack 'i', $f;
    close $fd;
    $! = $errno if $errno;
    $r;
}

=item _setAttributes( $name, $flags )

 Set file attributes

 Param string $name Filename
 Param scalar $flags Flags
 Return int -1 on failure, other on success

=cut

sub _setAttributes
{
    my ($name, $flags) = @_;

    my ($fd, $r, $f, $errno) = ( undef, 0, pack( 'i', $flags ), 0 );

    return -1 unless sysopen( $fd, $name, O_RDONLY | O_NONBLOCK | O_LARGEFILE );

    $r = sprintf '%d', ioctl( $fd, EXT2_IOC_SETFLAGS, $f ) || -1;
    $errno = $! if $r == -1;
    close $fd;
    $! = $errno if $errno;
    $r;
}

=item _isSupported( )

 Check whether or not Ext2 attribute are supported

=cut

sub _isSupported
{
    $IS_SUPPORTED //= _getAttributes( $main::imscpConfig{'USER_WEB_DIR'} ) == -1 ? 0 : 1;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
