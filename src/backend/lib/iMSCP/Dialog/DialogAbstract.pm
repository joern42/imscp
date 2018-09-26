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
use iMSCP::Execute 'execute';
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'iMSCP::Common::SingletonClass';

BEGIN {
    local $@;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Display dialog boxes

=head1 PUBLIC METHODS

=over 4

=item radiolist( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 Show radiolist DIALOG(1) box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param string $default Default selected tag
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both the DIALOG(1) exit code and an array containing checked tags

=cut

sub radiolist
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $defaultTag //= '';

    my @init;

    if ( $showTags ) {
        push @init, $_, $choices->{$_}, $defaultTag eq $_ ? 'on' : 'off' for sort keys %{ $choices };
    } else {
        my %choices = reverse( %{ $choices } );
        push @init, $choices{$_}, $_, $defaultTag eq $choices{$_} ? 'on' : 'off' for sort keys %choices;
    }

    local $self->{'_opts'}->{'no-tags'} = '' unless $showTags;
    $self->_execute( 'radiolist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
}

=item checklist( $text, \%choices [, \@defaults = [] [, $showTags =  FALSE ] ] )

 Show checklist DIALOG(1) box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param arrayref \@default Default tag(s)
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both DIALOG(1) exit code and an array containing checked tags

=cut

sub checklist
{
    my ( $self, $text, $choices, $defaultTags, $showTags ) = @_;
    $defaultTags //= [];

    my @init;

    if ( $showTags ) {
        for my $tag ( sort keys %{ $choices } ) {
            push @init, $tag, $choices->{$tag}, grep ( $tag eq $_, @{ $defaultTags }) ? 'on' : 'off';
        }
    } else {
        my %choices = reverse( %{ $choices } );
        for my $item ( sort keys %choices ) {
            push @init, $choices{$item}, $item, grep ( $choices{$item} eq $_, @{ $defaultTags } ) ? 'on' : 'off';
        }
    }

    local $self->{'_opts'}->{'separate-output'} = '';
    local $self->{'_opts'}->{'no-tags'} = '' unless $showTags;
    my ( $ret, $tags ) = $self->_execute( 'checklist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
    wantarray ? ( $ret, [ split /\n/, $tags ] ) : [ split /\n/, $tags ];
}

=item yesno( $text [, $defaultno =  FALSE [, $backbutton = FALSE ] ] )

 Show yesno DIALOG(1) box

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
    my ( $self, $text, $defaultno, $backbutton ) = @_;

    unless ( $backbutton ) {
        local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
        local $ENV{'DIALOG_CANCEL'} = TRUE;
        return ( $self->_execute( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
    }

    local $ENV{'DIALOG_EXTRA'} = TRUE;
    local $self->{'_opts'}->{'default-button'} = $defaultno ? 'extra' : undef;
    local $self->{'_opts'}->{'ok-label'} = 'Yes';
    local $self->{'_opts'}->{'extra-label'} = 'No';
    local $self->{'_opts'}->{'extra-button'} = '';
    ( $self->_execute( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item msgbox( $text )

 Show message DIALOG(1) box

 Param string $text Text to show in message dialog box
 Return int 0 (Ok), 50 (ESC), other on failure

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ( $self->_execute( 'msgbox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item infobox( $text )

 Show info DIALOG(1) box (same as msgbox but exit immediately)

 Param string $text Text to show
 Return int 0, other on failure

=cut

sub infobox
{
    my ( $self, $text ) = @_;

    local $self->{'_opts'}->{'clear'} = undef;
    ( $self->_execute( 'infobox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item inputbox( $text [, $default = '' ] )

 Show input DIALOG(1) dialog box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Input string or a list containing both DIALOG(1) exit code and input string

=cut

sub inputbox
{
    my ( $self, $text, $default ) = @_;

    $self->_execute( 'inputbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item passwordbox( $text [, $default = '' ] )

 Show password DIALOG(1) dialog box

 Param string $text Text to show
 Param string $default Default value
 Return string|list Password string or a list containing both DIALOG(1) exit code and password string

=cut

sub passwordbox
{
    my ( $self, $text, $default ) = @_;

    local $self->{'_opts'}->{'insecure'} = '';
    $self->_execute( 'passwordbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item startGauge( $text [, $percent = 0 ] )

 Start gauge

 Param string $text Text to show
 Param int $percent Initial percentage show in the meter
 Return void

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    defined $_[0] or die( '$text parameter is undefined' );

    return 0 if iMSCP::Getopt->noprompt || $self->hasGauge();

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions(), '--gauge',
        ref $self eq 'iMSCP::Dialog::Whiptail' ? $self->_stripFormats( $text ) : $text,
        $self->{'lines'}, $self->{'columns'},
        $percent // 0 or die( "Couldn't start gauge" );

    $self->{'_gauge'}->autoflush( TRUE );
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
    my ( $self, $percent, $text ) = @_;

    unless ( defined $self->{'_gauge'} ) {
        $self->startGauge( $text, $percent );
        return;
    }

    print { $self->{'_gauge'} } sprintf(
        "XXX\n%d\n%s\nXXX\n",
        $percent,
        ref $self eq 'iMSCP::Dialog::Whiptail' ? $self->_stripFormats( $text ) : $text
    );
}

=item endGauge( )

 Terminate gauge

 Return void

=cut

sub endGauge
{
    my ( $self ) = @_;

    return unless $self->{'_gauge'};

    $self->{'_gauge'}->close();
    undef $self->{'_gauge'};
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

my $ExecuteDialogsFirstCall = TRUE;
my $ExecuteDialogsBackupContext = FALSE;

sub executeDialogs
{
    my ( $self, $dialogs ) = @_;

    ref $dialogs eq 'ARRAY' or die( 'Invalid $dialog parameter. Expect an array of dialog subroutines ' );

    my $dialOuter = $ExecuteDialogsFirstCall;
    $ExecuteDialogsFirstCall = FALSE if $dialOuter;

    my ( $ret, $state, $countDialogs ) = ( 0, 0, scalar @{ $dialogs } );
    while ( $state < $countDialogs ) {
        local $self->{'_opts'}->{'nocancel'} = $state || !$dialOuter ? undef : '';
        $ret = $dialogs->[$state]->( $self );
        last if $ret == 50 || ( $ret == 30 && $state == 0 );

        if ( $state && ( $ret == 30 || $ret == 20 && $ExecuteDialogsBackupContext ) ) {
            $ExecuteDialogsBackupContext = TRUE if $ret == 30;
            $state--;
            next;
        }

        $ExecuteDialogsBackupContext = FALSE if $ExecuteDialogsBackupContext;
        $state++;
    }

    $ret;
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

    $self->{'_bin'} = $self->_findBin();

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

=item _findBin( )

 Return string DIALOG(1) program binary path, die if DIALOG(1) binary is not found

=cut

sub _findBin
{
    my $self = @_;

    die( sprintf( "The '%s' class must implement the '_findBin' method", ref $self ));
}

=item _getCommonOptions( )

 Get DIALOG(1) common options

 Return List DIALOG(1) common options

=cut

sub _getCommonOptions
{
    my ( $self ) = @_;

    die( sprintf( "The '%s' class must implement the '_getCommonOptions' method", ref $self ));
}

=item _execute( $boxType, @boxOptions )

 Execute DIALOG(1) command

 Param string $boxType DIALOG(1) Box type
 Param list @boxOptions DIALOG(1) Box options 
 Return string|array DIALOG(1) output or array containing both DIALOG(1) exit code and output

=cut

sub _execute
{
    my ( $self, $boxType, @boxOptions ) = @_;

    $self->endGauge();

    if ( iMSCP::Getopt->noprompt ) {
        unless ( grep ( $boxType eq $_, 'infobox', 'msgbox' ) ) {
            iMSCP::Debug::error( sprintf( 'Failed dialog: %s', $self->_stripFormats( $boxOptions[0] )));
            exit 5
        }

        return wantarray ? ( 0, '' ) : '';
    }

    $boxOptions[0] = $self->_stripFormats( $boxOptions[0] ) if ref $self eq 'iMSCP::Dialog::Whiptail';

    my $ret = execute( [ $self->{'_bin'}, $self->_getCommonOptions(), "--$boxType", @boxOptions ], undef, \my $output );
    # For the input and password boxes, we do not want lose previous value when
    # backing up
    # TODO radiolist, checklist and yesno dialog boxes
    $output = pop @boxOptions if $ret == 30 && grep ( $boxType eq $_, 'inputbox', 'passwordbox' );
    wantarray ? ( $ret, $output ) : $output;
}

=item _stripFormats( $string )

 Strip out any DIALOG(1) embedded "\Z" sequences

 Param string $string String from which DIALOG(1) embedded "\Z" sequences must be stripped
 Return string String stripped out of any DIALOG(1) embedded "\Z" sequences

=cut

sub _stripFormats
{
    $_[1] =~ s/\\Z[0-7brun]//gimr;
}

=item DESTROY()

 Destroy dialog object

=cut

sub DESTROY
{
    $_[0]->endGauge();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
