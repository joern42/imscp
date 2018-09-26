=head1 NAME

 iMSCP::Dialog::DialogAbstract - Abstract class for dialog classes

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

package iMSCP::Dialog::DialogAbstract;

use strict;
use warnings;
use iMSCP::Boolean;
use parent 'iMSCP::Common::SingletonClass';

=head1 DESCRIPTION

 Display dialog boxes

=head1 PUBLIC METHODS

=over 4

=item radiolist( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 Show radiolist dialog box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param string $default Default selected tag
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both exit code and an array containing checked tags

=cut

sub radiolist
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item checklist( $text, \%choices [, \@defaults = [] [, $showTags =  FALSE ] ] )

 Show checklist dialog box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param arrayref \@default Default tag(s)
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both exit code and an array containing checked tags

=cut

sub checklist
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item yesno( $text [, $defaultno =  FALSE [, $backbutton = FALSE ] ] )

 Show yesno dialog box

 For the 'yesno' dialog box, the code used for 'Yes' and 'No' buttons match
 those used for the 'Ok' and 'Cancel'. See dialog man page. We do not want this behavior. To
 workaround, we process as follow:

  - If not 'Back' button is needed:
    We temporary change code of the 'Cancel' button to 1 (default is 30).
    So 'Yes' = 0, 'No' = 1, ESC = 50
 
  - If a "Back" button is needed:
    We make use of the extra button (code 1) which replace the default 'No' button.
    We change default labels
    So: 'Yes' = 0, 'No' = 1, 'Back' = 30, ESC = 50

 Param string $text Text to show
 Param string bool defaultno Set the default value of the box to 'No'
 Return int 0 (Yes), 1 (No), 30 (Back), 50 (ESC), other on failure

=cut

sub yesno
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item msgbox( $text )

 Show message dialog box

 Param string $text Text to show in message dialog box
 Return int 0 (Ok), 50 (ESC), other on failure

=cut

sub msgbox
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item infobox( $text )

 Show info dialog box

 Param string $text Text to show
 Return int 0, other on failure

=cut

sub infobox
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item inputbox( $text [, $default = '' ] )

 Show input dialog box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Input string or a list containing both DIALOG(1) exit code and input string

=cut

sub inputbox
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item passwordbox( $text [, $default = '' ] )

 Show password dialog box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Password string or a list containing both DIALOG(1) exit code and password string

=cut

sub passwordbox
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item startGauge( $text [, $percent = 0 ] )

 Start gauge

 Param string $text Text to show
 Param int $percent Initial percentage show in the meter
 Return void

=cut

sub startGauge
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'startGauge' method", ref $self ));
}

=item setGauge( $percent, $text )

 Update gauge percent and text

 If no gauge is currently running, a new one will be created

 Param int $percent New percentage to show in gauge dialog box
 Param string $text New text to show in gauge dialog box
 Return void

=cut

sub setGauge
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'setGauge' method", ref $self ));
}

=item endGauge( )

 Terminate gauge

 Return void

=cut

sub endGauge
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'endGauge' method", ref $self ));
}

=item hasGauge( )

 Is a gauge currently running?

 Return int 1 if gauge is running 0 otherwise

=cut

sub hasGauge
{
    my ( $self ) = @_;

    !!$self->{'_gauge'}
}

=item resetLabels( )

 Reset DIALOG(1) labels to their default values

 Return void

=cut

sub resetLabels
{
    my ( $self ) = @_;

    die( sprintf( "The '%s'' class must implement the 'resetLabels' method", ref $self ));
}

=item set( $option, $value )

 Set DIALOG(1) option

 Param string $param Option name
 Param string $value Option value
 Return string|undef Old option value if exists, undef otherwise

=cut

sub set
{
    my ( $self, $option, $value ) = @_;

    return undef unless $option && exists $self->{'_opts'}->{$option};

    my $return = $self->{'_opts'}->{$option};
    $self->{'_opts'}->{$option} = $value;
    $return;
}

=item executeDialogs( \@dialogs )

 Execute the given stack of dialogs

 Implements a simple state machine (backup capability)
  - Dialog subroutines SHOULD not fail. However, they can die() on unrecoverable errors
  - On success, 0 (NEXT) MUST be returned
  - On skip, 20 (SKIP) MUST be returned (e.g. when no dialog is to be shown)
  - On back up, 30 (BACK) MUST be returned. For grouped dialogs, goto previous dialog.
  - On escape, 50 (ESC) MUST be returned

 @param $dialogs \@dialogs Dialogs stack
 @return int 0 (SUCCESS), 30 (BACK), 50 (ESC)

=cut

sub executeDialogs
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the 'executeDialogs' method", ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::SingletonClass::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    # These environment variable screws up at least whiptail with the
    # way we call it. Posix does not allow safe arg passing like
    # whiptail needs.
    delete $ENV{'POSIXLY_CORRECT'} if exists $ENV{'POSIXLY_CORRECT'};
    delete $ENV{'POSIX_ME_HARDER'} if exists $ENV{'POSIX_ME_HARDER'};

    # Detect all the ways people have managed to screw up their
    # terminals (so far...)
    if ( !exists $ENV{'TERM'} || !defined $ENV{'TERM'} || length $ENV{'TERM'} eq 0 ) {
        die( 'TERM is not set, so the dialog frontend is not usable.' );
    } elsif ( $ENV{'TERM'} =~ /emacs/i ) {
        die( 'Dialog frontend is incompatible with emacs shell buffers' );
    } elsif ( $ENV{'TERM'} eq 'dumb' || $ENV{'TERM'} eq 'unknown' ) {
        die( 'Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.' );
    }

    # Force usage of graphic lines (UNICODE values) when using putty (See #540)
    $ENV{'NCURSES_NO_UTF8_ACS'} = TRUE;

    # Terminal max lines (determined at runtime)
    $self->{'lines'} = 0;
    # Terminal max columns (determined at runtime)
    $self->{'columns'} = 0;

    $self->_resize();
    $SIG{'WINCH'} = sub { $self->_resize(); };
    $self;
}

=item _resize( )

 This method is called whenever the tty is resized, and probes to determine the new screen size

 return void

=cut

sub _resize
{
    my ( $self ) = @_;

    my $lines;
    if ( exists $ENV{'LINES'} ) {
        $self->{'lines'} = $ENV{'LINES'};
    } else {
        ( $lines ) = `stty -a 2>/dev/null` =~ /rows (\d+)/s;
        $lines ||= 24;
    }

    my $cols;
    if ( exists $ENV{'COLUMNS'} ) {
        $cols = $ENV{'COLUMNS'};
    } else {
        ( $cols ) = `stty -a 2>/dev/null` =~ /columns (\d+)/s;
        $cols ||= 80;
    }

    $lines > 23 && $cols > 79 or die( 'A screen at least 24 lines tall and 80 columns wide is required. Please enlarge your screen.' );
    $self->{'lines'} = $lines-10;
    $self->{'columns'} = $cols-4;
    $self->endGauge();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
