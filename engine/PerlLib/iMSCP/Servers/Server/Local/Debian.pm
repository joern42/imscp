=head1 NAME

 iMSCP::Servers::Server::Local::Debian - i-MSCP (Debian) Local server implementation

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

package iMSCP::Servers::Server::Local::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::File /;
use parent 'iMSCP::Servers::Server::Local::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Local server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Local::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_cleanup();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' )
        && -f "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp";

    iMSCP::File->new( filename => "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp" )->delFile();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
