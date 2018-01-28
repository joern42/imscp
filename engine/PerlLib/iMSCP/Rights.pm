=head1 NAME

 iMSCP::Rights - Package providing function for setting file ownership and permissions.

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

package iMSCP::Rights;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug;
use File::Find;
use Lchown qw/ lchown /;
use parent 'Exporter';

our @EXPORT = qw/ setRights /;

=head1 DESCRIPTION

 Package providing function for setting file ownership and permissions.

=head1 PUBLIC FUNCTIONS

=over 4

=item setRights( $target, \%attrs )

 Depending on the given attributes, set owner, group and permissions on the given target

 Param string $target Target file or directory
 Param hash \%attrs:
  mode      : OPTIONAL Set mode on the given directory/file
  dirmode   : OPTIONAL Set mode on directories
  filemode  : OPTIONAL Set mode on files
  user      : OPTIONAL Set owner on the given file
  group     : OPTIONAL Set group for the given file
  recursive : OPTIONAL Whether or not operations must be processed recursively

 Return int 0 on success, 1 on failure

=cut

sub setRights
{
    my ($target, $attrs) = @_;

    eval {
        defined $target or croak( '$target parameter is not defined' );
        ref $attrs eq 'HASH' && %{$attrs} or croak( 'attrs parameter is not defined or is not a hashref' );

        # Return early if none of accepted attributes is set. This is the
        # case when that function is used dynamically, and when setting of
        # permissions/ownership is made optional.
        return 0 unless defined $attrs->{'mode'} || defined $attrs->{'dirmode'} || defined $attrs->{'filemode'} || defined $attrs->{'user'}
            || defined $attrs->{'group'};

        if ( defined $attrs->{'mode'} && ( defined $attrs->{'dirmode'} || defined $attrs->{'filemode'} ) ) {
            croak( '`mode` attribute and the dirmode or filemode attributes are mutally exclusive' );
        }

        my $uid = $attrs->{'user'} ? getpwnam( $attrs->{'user'} ) : -1;
        my $gid = $attrs->{'group'} ? getgrnam( $attrs->{'group'} ) : -1;
        defined $uid or croak( sprintf( 'user attribute refers to inexistent user: %s', $attrs->{'user'} ));
        defined $gid or croak( sprintf( 'group attribute refers to inexistent group: %s', $attrs->{'group'} ));

        my $mode = defined $attrs->{'mode'} ? oct( $attrs->{'mode'} ) : undef;
        my $dirmode = defined $attrs->{'dirmode'} ? oct( $attrs->{'dirmode'} ) : undef;
        my $filemode = defined $attrs->{'filemode'} ? oct( $attrs->{'filemode'} ) : undef;

        if ( $attrs->{'recursive'} ) {
            local $SIG{'__WARN__'} = sub { croak @_ };
            find(
                {
                    wanted   => sub {
                        if ( $attrs->{'user'} || $attrs->{'group'} ) {
                            lchown $uid, $gid, $_ or croak( sprintf( "Couldn't set user/group on %s: %s", $_, $! ));
                        }

                        # We do not call chmod on symkink targets
                        return if -l;

                        # It is OK to reuse the previous lstat structure below
                        # because we know that we have a real file.

                        if ( $mode ) {
                            chmod $mode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                        } elsif ( $dirmode && -d _ ) {
                            chmod $dirmode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                        } elsif ( $filemode && !-d _ ) {
                            chmod $filemode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                        }
                    },
                    no_chdir => 1
                },
                $target
            );

            return 0;
        }

        if ( $attrs->{'user'} || $attrs->{'group'} ) {
            lchown $uid, $gid, $target or die( sprintf( "Couldn't set user/group on %s: %s", $target, $! ));
        }

        unless ( -l $target ) { # We do not call chmod on symkink targets
            if ( $mode ) {
                chmod $mode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
            } elsif ( $dirmode && -d _ ) {
                chmod $dirmode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
            } elsif ( $filemode && !-d _ ) {
                chmod $filemode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
