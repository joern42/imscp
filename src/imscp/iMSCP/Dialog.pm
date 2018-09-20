=head1 NAME

 iMSCP::Dialog - i-MSCP Dialog

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

package iMSCP::Dialog;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Execute qw/ execute escapeShell /;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'iMSCP::Common::SingletonClass';

BEGIN {
    local $@;
    no warnings 'redefine';
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Class that wrap dialog and cdialog programs.

=head1 PUBLIC METHODS

=over 4

=item resetLabels( )

 Reset labels to their default values

 Return void

=cut

sub resetLabels
{
    @{ $_[0]->{'_opts'} }{qw/ exit-label ok-label yes-label no-label cancel-label help-label extra-label /} = (
        'Abort', 'Ok', 'Yes', 'No', 'Back', 'Help', undef
    );
    0;
}

=item fselect( $file )

 Show file selection dialog box

 Param string $file File path
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub fselect
{
    my ( $self, $file ) = @_;

    local $self->{'lines'} = $self->{'lines'}-8;
    my ( $ret, $output ) = $self->_execute( $file, undef, 'fselect' );
    wantarray ? ( $ret, $output ) : $output;
}

=item radiolist( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 Show radiolist dialog box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param string $default OPTIONAL Default selected tag
 Param bool $showTags OPTIONAL Flag indicating whether or not tags must be showed in dialog box
 Return list|string Selected tag or list containing both the dialog exit code and selected tag

=cut

sub radiolist
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $defaultTag //= '';

    my @init;
    if ( $showTags ) {
        for my $tag ( sort keys %{ $choices } ) {
            push @init, escapeShell( $tag ), escapeShell( $choices->{$tag} ), $defaultTag eq $tag ? 'on' : 'off';
        }
    } else {
        my %choices = reverse( %{ $choices } );
        for my $item ( sort keys %choices ) {
            push @init, escapeShell( $choices{$item} ), escapeShell( $item ), $defaultTag eq $choices{$item} ? 'on' : 'off';
        }
    }

    local $self->{'_opts'}->{'no-tags'} = '' unless $showTags;
    my ( $ret, $tag ) = $self->_textbox( $text, 'radiolist', "@{ [ scalar keys %{ $choices } ] } @init" );
    wantarray ? ( $ret, $tag ) : $tag;
}

=item checklist( $text, \%choices [, \@defaults = [] [, $showTags =  FALSE ] ] )

 Show checklist dialog box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param arrayref \@default Default tag(s)
 Param bool $showTags OPTIONAL Flag indicating whether or not tags must be showed in dialog box
 Return List A list containing array of selected tags or a list containing both the dialog exit code and array of selected tags

=cut

sub checklist
{
    my ( $self, $text, $choices, $defaultTags, $showTags ) = @_;
    $defaultTags //= [];

    my @init;
    if ( $showTags ) {
        for my $tag ( sort keys %{ $choices } ) {
            push @init, escapeShell( $tag ), escapeShell( $choices->{$tag} ), grep ( $tag eq $_, @{ $defaultTags }) ? 'on' : 'off';
        }
    } else {
        my %choices = reverse( %{ $choices } );
        for my $item ( sort keys %choices ) {
            push @init, escapeShell( $choices{$item} ), escapeShell( $item ), grep ( $choices{$item} eq $_, @{ $defaultTags } ) ? 'on' : 'off';
        }
    }

    local $self->{'_opts'}->{'no-tags'} = '' unless $showTags;
    my ( $ret, $tags ) = $self->_textbox( $text, 'checklist', "@{ [ scalar keys %{ $choices } ] } @init" );
    wantarray ? ( $ret, [ split /\n/, $tags ] ) : [ split /\n/, $tags ];
}

=item tailbox( $file )

 Show tail dialog box

 Param string $file File path
 Return int Dialog exit code

=cut

sub tailbox
{
    my ( $self, $file ) = @_;

    ( $self->_execute( $file, undef, 'tailbox' ) )[0];
}

=item editbox( $file )

 Show edit dialog box

 Param string $file File path
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub editbox
{
    my ( $self, $file ) = @_;

    $self->_execute( $file, undef, 'editbox' );
}

=item dselect( $directory )

 Show directory select dialog box

 Param string $directory
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub dselect
{
    my ( $self, $directory ) = @_;

    local $self->{'lines'} = $self->{'lines'}-8;
    my ( $ret, $output ) = $self->_execute( $directory, undef, 'dselect' );
    wantarray ? ( $ret, $output ) : $output;
}

=item msgbox( $text )

 Show message dialog box

 Param string $text Text to show in message dialog box
 Return int Dialog exit code

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ( $self->_textbox( $text, 'msgbox' ) )[0];
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
 Return int Dialog exit code

=cut

sub yesno
{
    my ( $self, $text, $defaultno, $backbutton ) = @_;

    unless ( $backbutton ) {
        local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
        local $ENV{'DIALOG_CANCEL'} = 1;
        return ( $self->_textbox( $text, 'yesno' ) )[0];
    }

    local $ENV{'DIALOG_EXTRA'} = 1;
    local $self->{'_opts'}->{'default-button'} = $defaultno ? 'extra' : undef;
    local $self->{'_opts'}->{'ok-label'} = 'Yes';
    local $self->{'_opts'}->{'extra-label'} = 'No';
    local $self->{'_opts'}->{'extra-button'} = '';
    ( $self->_textbox( $text, 'yesno' ) )[0];
}

=item inputbox( $text [, $init = '' ] )

 Show input dialog box

 Param string $text Text to show
 Param string $init Default string value
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub inputbox
{
    my ( $self, $text, $init ) = @_;

    $init //= '';
    $self->_textbox( $text, 'inputbox', escapeShell( $init ));
}

=item passwordbox( $text [, $init = '' ])

 Show password dialog box

 Param string $text Text to show
 Param string $init Default password value
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub passwordbox
{
    my ( $self, $text, $init ) = @_;
    $init //= '';

    local $self->{'_opts'}->{'insecure'} = '';
    $self->_textbox( $text, 'passwordbox', escapeShell( $init ));
}

=item infobox( $text )

 Show info dialog box

 Param string $text Text to show
 Return int Dialog exit code

=cut

sub infobox
{
    my ( $self, $text ) = @_;

    local $self->{'_opts'}->{'clear'} = undef;
    ( $self->_textbox( $text, 'infobox' ) )[0];
}

=item startGauge( $text [, $percent = 0 ] )

 Start a gauge

 Param string $text Text to show
 Param int $percent OPTIONAL Initial percentage show in the meter
 Return void

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    return 0 if iMSCP::Getopt->noprompt || defined $self->{'gauge'};

    defined $_[0] or die( '$text parameter is undefined' );

    open $self->{'gauge'}, '|-',
        $self->_findBin(), $self->_buildCommonCommandOptions( 'noEscape' ),
        '--gauge', $text,
        $self->{'autosize'} ? 0 : $self->{'lines'},
        $self->{'autosize'} ? 0 : $self->{'columns'},
        $percent // 0 or die( "Couldn't start gauge" );

    $self->{'gauge'}->autoflush( 1 );
}

=item setGauge( $percent, $text )

 Set new percentage and optionaly new text to show

 If no gauge is currently running, a new one will be created

 Param int $percent New percentage to show in gauge dialog box
 Param string $text New text to show in gauge dialog box
 Return void

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

    unless ( defined $self->{'gauge'} ) {
        $self->startGauge( $text, $percent );
        return;
    }

    print { $self->{'gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, $text );
}

=item endGauge( )

 Terminate gauge dialog box

 Return void

=cut

sub endGauge
{
    return unless $_[0]->{'gauge'};

    $_[0]->{'gauge'}->close();
    undef $_[0]->{'gauge'};
}

=item hasGauge( )

 Does a gauge is currently running?

 Return int 1 if gauge is running 0 otherwise

=cut

sub hasGauge
{
    my ( $self ) = @_;

    !!$self->{'gauge'}
}

=item set( $option, $value )

 Set dialog option

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
        local $self->{'_opts'}->{'no-cancel'} = $state || !$dialOuter ? undef : '';

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

 Initialize instance

 Return iMSCP::Dialog::Dialog, die on failure

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

    # Return specific exit status when ESC is pressed
    $ENV{'DIALOG_ESC'} = 50;
    # We want get 30 as exit code when CANCEL button is pressed
    $ENV{'DIALOG_CANCEL'} = 30;
    # Force usage of graphic lines (UNICODE values) when using putty (See #540)
    $ENV{'NCURSES_NO_UTF8_ACS'} = '1';

    $self->{'autosize'} = undef;
    $self->{'autoreset'} = 0;
    $self->{'lines'} = undef;
    $self->{'columns'} = undef;
    $self->{'_opts'}->{'backtitle'} ||= 'i-MSCP - internet Multi Server Control Panel';
    $self->{'_opts'}->{'title'} ||= 'i-MSCP Installer Dialog';
    $self->{'_opts'}->{'colors'} = '';
    $self->{'_opts'}->{'ok-label'} ||= 'Ok';
    $self->{'_opts'}->{'yes-label'} ||= 'Yes';
    $self->{'_opts'}->{'no-label'} ||= 'No';
    $self->{'_opts'}->{'cancel-label'} ||= 'Back';
    $self->{'_opts'}->{'exit-label'} ||= 'Abort';
    $self->{'_opts'}->{'help-label'} ||= 'Help';
    $self->{'_opts'}->{'extra-label'} ||= undef;
    $self->{'_opts'}->{'extra-button'} //= undef;
    $self->{'_opts'}->{'help-button'} //= undef;
    $self->{'_opts'}->{'defaultno'} ||= undef;
    $self->{'_opts'}->{'default-item'} ||= undef;
    $self->{'_opts'}->{'no-cancel'} ||= undef;
    $self->{'_opts'}->{'no-ok'} ||= undef;
    $self->{'_opts'}->{'clear'} ||= undef;
    $self->{'_opts'}->{'column-separator'} = undef;
    $self->{'_opts'}->{'cr-wrap'} = '';
    $self->{'_opts'}->{'no-collapse'} = '';
    $self->{'_opts'}->{'trim'} = undef;
    $self->{'_opts'}->{'date-format'} = undef;
    $self->{'_opts'}->{'help-status'} = undef;
    $self->{'_opts'}->{'insecure'} = undef;
    $self->{'_opts'}->{'item-help'} = undef;
    $self->{'_opts'}->{'max-input'} = undef;
    $self->{'_opts'}->{'no-shadow'} = undef;
    $self->{'_opts'}->{'shadow'} = '';
    $self->{'_opts'}->{'single-quoted'} = undef;
    $self->{'_opts'}->{'tab-correct'} = undef;
    $self->{'_opts'}->{'tab-len'} = undef;
    $self->{'_opts'}->{'timeout'} = undef;
    $self->{'_opts'}->{'height'} = undef;
    $self->{'_opts'}->{'width'} = undef;
    $self->{'_opts'}->{'aspect'} = undef;
    $self->{'_opts'}->{'separate-output'} = undef;
    $self->{'_opts'}->{'no-tags'} = undef;
    $self->_resize();
    $SIG{'WINCH'} = sub { $self->_resize(); };
    $self;
}

=item _resize( )

 This method is called whenever the tty is resized, and probes to determine the new screen size.

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

=item _findBin( $variant )

 Find dialog variant (dialog|cdialog)

 Return string Dialog program binary path, die if dialog programm is not found

=cut

sub _findBin
{
    CORE::state $bin;

    $bin ||= iMSCP::ProgramFinder::find( $^O =~ /bsd$/ ? 'cdialog' : 'dialog' ) or die( "Couldn't find dialog program" );
}

=item _stripFormats( $string )

 Strip out any format characters (\Z sequences) from the given string

 Param string $string String from which any format character must be stripped
 Return string String stripped out of any format character

=cut

sub _stripFormats
{
    my ( $self, $string ) = @_;

    $string =~ s/\\Z[0-9bBuUrRn]//gmi;
    $string;
}

=item _buildCommonCommandOptions( [ $noEscape = false ] )

 Build common dialog command options

 Param bool $noEscape Whether or not option values must be escaped
 Return string|list Dialog command options

=cut

sub _buildCommonCommandOptions
{
    my ( $self, $noEscape ) = @_;

    my @options = map {
        defined $self->{'_opts'}->{$_}
            ? ( "--$_", $noEscape
            ? ( $self->{'_opts'}->{$_} eq '' ? () : $self->{'_opts'}->{$_} )
            : ( $self->{'_opts'}->{$_} eq '' ? () : escapeShell( $self->{'_opts'}->{$_} ) ) )
            : ()
    } keys %{ $self->{'_opts'} };

    wantarray ? @options : "@options";
}

=item _restoreDefaults( )

 Restore default options

 Return iMSCP::Dialog::Dialog

=cut

sub _restoreDefaults
{
    my ( $self ) = @_;

    for my $prop ( keys %{ $self->{'_opts'} } ) {
        $self->{'_opts'}->{$prop} = undef unless $prop =~ /^(?:title|backtitle|colors)$/;
    }

    $self;
}

=item _execute( $text, $init, $type )

 Wrap execution of dialog commands (except gauge dialog commands)

 Param string $text Dialog text
 Param string $init Default value
 Param string $type Dialog box type
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub _execute
{
    my ( $self, $text, $init, $type ) = @_;

    $self->endGauge(); # Ensure that no gauge is currently running...

    if ( iMSCP::Getopt->noprompt ) {
        if ( $type ne 'infobox' && $type ne 'msgbox' ) {
            iMSCP::Debug::error( sprintf( 'Failed dialog: %s', $text ));
            exit 5
        }

        return 0;
    }

    $text = $self->_stripFormats( $text ) unless defined $self->{'_opts'}->{'colors'};
    $self->{'_opts'}->{'separate-output'} = '' if $type eq 'checklist';

    my $command = $self->_buildCommonCommandOptions();

    $text = escapeShell( $text );
    $init //= '';

    my $height = $self->{'autosize'} ? 0 : $self->{'lines'};
    my $width = $self->{'autosize'} ? 0 : $self->{'columns'};

    # Turn off debug messages for dialog commands
    #local $iMSCP::Execute::Debug = FALSE;
    my $ret = execute( $self->_findBin() . " $command --$type $text $height $width $init", undef, \my $output );

    $self->{'_opts'}->{'separate-output'} = undef;
    $self->_init() if $self->{'autoreset'};

    wantarray ? ( $ret, $output ) : $output;
}

=item _textbox( $text, $type [, $init = 0 ])

 Wrap execution of several dialog box

 Param string $text Text to show
 Param string $mode Text dialog box type (checklist|infobox|inputbox|msgbox|passwordbox|radiolist|yesno)
 Param string $init Default value
 Return string|list Dialog output or list containing both dialog exit code and dialog output

=cut

sub _textbox
{
    my ( $self, $text, $type, $init ) = @_;

    local $self->{'autosize'} = undef;
    my ( $ret, $output ) = $self->_execute( $text, $init, $type );

    # For the radiolist, input and password boxes, we do not want lose
    # previous value when backing up
    # TODO checklist and yesno dialog boxes
    $output = $init if $ret == 30 && grep ( $type eq $_, 'checklist', 'radiolist', 'inputbox', 'passwordbox' );

    wantarray ? ( $ret, $output ) : $output;
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
