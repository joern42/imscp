=head1 NAME

 iMSCP::SystemGroup - i-MSCP library for management of UNIX groups

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

package iMSCP::SystemGroup;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ debug /;
use iMSCP::Execute qw/ execute /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 iMSCP::SystemGroup - i-MSCP library for management of UNIX groups.

=head1 PUBLIC METHODS

=over 4

=item addSystemGroup( $groupname [, systemgroup = FALSE ] )

 Add group

 Param string $groupname Group name
 Param bool systemgroup Flag indication whether or not $groupname must be created as a system group
 Return self, die on failure

=cut

sub addSystemGroup
{
    my ($self, $groupname, $systemgroup) = @_;

    defined $groupname or croak( 'Missing $groupname parameter' );
    $groupname ne $main::imscpConfig{'ROOT_GROUP'} or croak( sprintf( '%s group is prohibited', $main::imscpConfig{'ROOT_GROUP'} ));

    my $rs = execute( [ 'groupadd', '-f', ( $systemgroup ? '-r' : () ), $groupname ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    $self;
}

=item delSystemGroup( $groupname )

 Delete group

 Param string $groupname Group name
 Return self, die on failure

=cut

sub delSystemGroup
{
    my (undef, $groupname) = @_;

    defined $groupname or croak( '$groupname parameter is not defined' );
    $groupname ne $main::imscpConfig{'ROOT_GROUP'} or croak( sprintf( '%s group deletion is prohibited', $main::imscpConfig{'ROOT_GROUP'} ));

    my $rs = execute( [ 'groupdel', $groupname ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    grep( $_ == $rs, 0, 6 ) or die( $stderr || 'Unknown error' );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
