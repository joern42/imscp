=head1 NAME

 iMSCP::Dialog::FrontEndInterface - Interface for dialog frontEnds

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

package iMSCP::Dialog::FrontEndInterface;

use strict;
use warnings;
use parent 'iMSCP::Common::SingletonClass';

=head1 DESCRIPTION

 Interface for dialog frontEnds

=head1 PUBLIC METHODS

=over 4

=item select( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 Show select box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param string $default Default selected tag
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both dialog return code and checked tag

=cut

=item multiselect( $text, \%choices [, \@defaultTags = [] [, $showTags =  FALSE ] ] )

 Show multiselect box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param arrayref \@default Default tags
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both dialog return code and an array containing checked tags

=cut

=item boolean( $text [, $defaultno =  FALSE [, $backbutton = FALSE ] ] )

 Show boolean box

 Param string $text Text to show
 Param string bool defaultno Set the default value of the box to 'No'
 Return int 0 (Yes), 1 (No), 30 (Back)

=cut

=item msgbox( $text )

 Show message box

 Param string $text Text to show in message dialog box
 Return int 0 (Ok), 30 (Back)

=cut

=item infobox( $text )

 Show info box

 Param string $text Text to show
 Return int 0, other on failure

=cut

=item inputbox( $text [, $default = '' ] )

 Show string box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Input string or a list containing both DIALOG(1) exit code and input string

=cut

=item password( $text [, $default = '' ] )

 Show password box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Password string or a list containing both DIALOG(1) exit code and password string

=cut

=item startGauge( $text [, $percent = 0 ] )

 Start gauge

 Param string $text Text to show
 Param int $percent Initial percentage show in the meter
 Return void

=cut

=item setGauge( $percent, $text )

 Update gauge percent and text

 If no gauge is currently running, a new one will be created

 Param int $percent New percentage to show in gauge dialog box
 Param string $text New text to show in gauge dialog box
 Return void

=cut

=item endGauge( )

 Terminate gauge

 Return void

=cut

=item hasGauge( )

 Is a gauge currently running?

 Return boolean TRUE if a gauge is running FALSE otherwise

=cut

sub AUTOLOAD
{
    my $self = shift;
    ( my $method = $iMSCP::Dialog::FrontEndInterface::AUTOLOAD ) =~ s/.*:://;

    grep ( $method eq $_, qw/ select multiselect boolean msgbox infobox string password startGauge setGauge endGauge hasGauge executeDialogs / ) or die(
        sprintf( 'Unknown %s method', $iMSCP::Dialog::FrontEndInterface::AUTOLOAD )
    );

    die( sprintf( "The '%s' class must implement the '%s' method", ref $self, $method ));
}

=item DESTROY

 Needed due to AUTOLOAD

=cut

sub DESTROY
{

}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
