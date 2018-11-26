=head1 NAME

 iMSCP::Dialog::NonInteractive - Non-interactive FrontEnd

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

package iMSCP::Dialog::NonInteractive;

use strict;
use warnings;
use parent qw/ iMSCP::Common::Singleton iMSCP::Dialog::FrontEndInterface /;

=head1 DESCRIPTION

 Non-interactive FrontEnd for user interface.

=head1 PRIVATE METHODS/FUNCTIONS

=over 4

=item AUTOLOAD

 Implement AUTOLOADING

=cut

sub AUTOLOAD
{
    ( my $method = $iMSCP::Dialog::NonInteractive::AUTOLOAD ) =~ s/.*:://;

    grep ( $method eq $_, qw/ select multiselect boolean error note text string password startGauge setGauge endGauge hasGauge / ) or die(
        sprintf( 'Unknown %s method', $iMSCP::Dialog::NonInteractive::AUTOLOAD )
    );

    no strict 'refs';
    *{ $iMSCP::Dialog::NonInteractive::AUTOLOAD } = grep ( $method eq $_, 'setGauge', 'endGauge', 'hasGauge', 'note', 'text' ) ? sub { 0 } : sub {
        die( sprintf(
            "Bad configuration parameter detected. Please retry without the --non-interactive option.\n\nDialog was:\n\n%s",
            _stripEmbeddedSequences( $_[1] )
        ));
    };

    goto &{ $iMSCP::Dialog::NonInteractive::AUTOLOAD };
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _stripEmbeddedSequences( $string )

 Strip out any DIALOG(1) embedded "\Z" sequences

 Param string $string String from which DIALOG(1) embedded "\Z" sequences must be stripped
 Return string String stripped out of any DIALOG(1) embedded "\Z" sequences

=cut

sub _stripEmbeddedSequences
{
    $_[0] =~ s/\\Z[0-7bBrRuUn]//gmr;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
