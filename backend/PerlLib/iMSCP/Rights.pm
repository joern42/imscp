=head1 NAME

 iMSCP::Rights - Package providing function for setting file ownership and permissions.

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

package iMSCP::Rights;

use strict;
use warnings;
use Carp qw/ croak /;
use File::Find;
use POSIX qw/ lchown /;
use iMSCP::Boolean;
use parent 'Exporter';

our @EXPORT = qw/ setRights /;

=head1 DESCRIPTION

 Package providing function for setting file ownership and permissions.

=head1 PUBLIC FUNCTIONS

=over 4

=item setRights( $target, \%attrs )

 Depending on the given attributes, set owner, group and permissions on the given target

 Symlinks are not dereferenced, that is, not followed.
 
 FIXME: When only CHOWN(2) is involved, should we restablish any clearedoff setuid/setgid bits or should that task left to caller?

 Param string $target Target file or directory
 Param hashref \%attrs:
  mode      : OPTIONAL Set mode on the given target
  dirmode   : OPTIONAL Set mode on directories
  filemode  : OPTIONAL Set mode on files
  user      : OPTIONAL Set owner on the given target
  group     : OPTIONAL Set group for the given target
  recursive : OPTIONAL Whether or not operations must be processed recursively

 Return void, die on failure

=cut

sub setRights
{
    my ( $target, $attrs ) = @_;

    defined $target or croak( '$target parameter is not defined' );
    ref $attrs eq 'HASH' && %{ $attrs } or croak( "'attrs' parameter is not defined or is not a hashref" );

    # Return early if none of accepted attributes is defined. This is the case
    # when that function is used dynamically, and when setting of permissions
    # and ownership is made optional by caller.
    return unless defined $attrs->{'mode'} || defined $attrs->{'dirmode'} || defined $attrs->{'filemode'} || defined $attrs->{'user'}
        || defined $attrs->{'group'};

    if ( defined $attrs->{'mode'} && ( defined $attrs->{'dirmode'} || defined $attrs->{'filemode'} ) ) {
        croak( "'mode' attribute and the dirmode or filemode attributes are mutally exclusive" );
    }

    my $uid = $attrs->{'user'} ? getpwnam( $attrs->{'user'} ) : -1;
    my $gid = $attrs->{'group'} ? getgrnam( $attrs->{'group'} ) : -1;
    defined $uid or croak( sprintf( "'user' attribute refers to inexistent user: %s", $attrs->{'user'} ));
    defined $gid or croak( sprintf( "'group' attribute refers to inexistent group: %s", $attrs->{'group'} ));

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

                    # We do not call chmod on symkinks
                    return if -l;

                    # We need call CHMOD(2) last as CHOWN(2) can clearoff the setuid and setgid mode bits

                    if ( defined $mode ) {
                        chmod $mode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                    } elsif ( defined $dirmode && -d _ ) {
                        chmod $dirmode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                    } elsif ( defined $filemode && !-d _ ) {
                        chmod $filemode, $_ or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
                    }
                },
                no_chdir => TRUE
            },
            $target
        );

        return;
    }

    if ( defined $attrs->{'user'} || defined $attrs->{'group'} ) {
        lchown $uid, $gid, $target or die( sprintf( "Couldn't set user/group on %s: %s", $target, $! ));
    }

    unless ( -l $target ) { # We do not call CHMOD(2) on symkinks
        # We need call CHMOD(2) last as CHOWN(2) can clearoff the setuid and setgid mode bits
        if ( defined $mode ) {
            chmod $mode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
        } elsif ( defined $dirmode && -d _ ) {
            chmod $dirmode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
        } elsif ( defined $filemode && !-d _ ) {
            chmod $filemode, $target or die( sprintf( "Couldn't set mode on %s: %s", $_, $! ));
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
