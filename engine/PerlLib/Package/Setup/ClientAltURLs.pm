=head1 NAME

 Package::Setup::ClientAltURLs - i-MSCP Client alternative URLs

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

package Package::Setup::ClientAltURLs;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringInList /;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP client alternative URLs.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->askForClientAltURLs( @_ ) };
        0;
    } );
}

=item askForClientAltURLs( $dialog )

 Ask for alternative URL feature

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForClientAltURLs
{
    my ( undef, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'CLIENT_DOMAIN_ALT_URLS' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'client_alt_url', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want to enable the alternative URLs feature for the clients?

This feature make the clients able to access their websites through alternative URLs such as http://dmn1.panel.domain.tld
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    ::setupSetQuestion( 'CLIENT_DOMAIN_ALT_URLS', $value );
    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
