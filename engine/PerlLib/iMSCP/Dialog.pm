=head1 NAME

 iMSCP::Dialog - i-MSCP Dialog

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

package iMSCP::Dialog;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Debug qw/ error /;
use iMSCP::Execute;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Class that wrap dialog and cdialog programs.

=head1 PUBLIC METHODS

=over 4

=item set( $option, $value )

 Set dialog option

 Param string $param Option name
 Param string $value Option value
 Return mixed Old option value, croak if the given option is not known

=cut

sub set
{
    my ( $self, $option, $value ) = @_;

    defined $option && exists $self->{'opts'}->{$option} or croak( 'Unknown dialog option' );

    my $oldValue = $self->{'opts'}->{$option};
    $self->{'opts'}->{$option} = $value;
    $oldValue;
}

=item resetLabels( )

 Reset labels to their default values

 Return void

=cut

sub resetLabels
{
    @{ $_[0]->{'opts'} }{qw/ exit-label ok-label yes-label no-label cancel-label help-label extra-label /} = (
        'Abort', 'Ok', 'Yes', 'No', 'Back', 'Help', undef
    );
}

=item fselect( $file )

 Show file selection dialog

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

 Show radio list dialog
 
 eg: dialog --no-tags --radiolist 'text' 0 0 0 'first' 'First option' on 'second' 'Second option' 0

 Param string $text Text to show
 Param array \%choices List of choices where keys are tags and values are items.
 Param string $default OPTIONAL Default selected tag
 Param bool $showTags OPTIONAL Flag indicating whether or not tags must be showed in dialog box
 Return list|string Selected tag or list containing both the dialog exit code and selected tag

=cut

sub radiolist
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $defaultTag //= '';

    my @init;
    my %choices = reverse( %{ $choices } );
    for my $item ( sort keys %choices ) {
        push @init, escapeShell( $choices{$item} ), escapeShell( $item ), $defaultTag eq $choices{$item} ? 'on' : 'off';
    }

    local $self->{'opts'}->{'no-tags'} = '' unless $showTags;
    my ( $ret, $tag ) = $self->_textbox( $text, 'radiolist', "@{ [ scalar keys %{ $choices } ] } @init" );
    wantarray ? ( $ret, $tag ) : $tag;
}

=item checkbox( $text, \%choices [, @defaults = ( ) ] )

 Show check list dialog

 Param string $text Text to show
 Param array \%choices List of choices where keys are tags and values are items.
 Param array @default Default tag
 Return List A list containing array of selected tags or a list containing both the dialog exit code and array of selected tags

=cut

sub checkbox
{
    my ( $self, $text, $choices, @defaultTags ) = @_;

    my @init;
    my %choices = reverse( %{ $choices } );
    for my $item ( sort keys %choices ) {
        push @init, escapeShell( $choices{$item} ), escapeShell( $item ), grep ( $choices{$item} eq $_, @defaultTags ) ? 'on' : 'off';
    }

    local $self->{'opts'}->{'no-tags'} = ''; # Don't display tags in dialog
    my ( $ret, $tags ) = $self->_textbox( $text, 'checklist', "@{ [ scalar keys %{ $choices } ] } @init" );
    wantarray ? ( $ret, [ split /\n/, $tags ] ) : [ split /\n/, $tags ];
}

=item tailbox( $file )

 Show tail dialog

 Param string $file File path
 Return int Dialog exit code

=cut

sub tailbox
{
    my ( $self, $file ) = @_;

    ( $self->_execute( $file, undef, 'tailbox' ) )[0];
}

=item editbox( $file )

 Show edit dialog

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

 Show message dialog

 Param string $text Text to show in message dialog box
 Return int Dialog exit code

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ( $self->_textbox( $text, 'msgbox' ) )[0];
}

=item yesno( $text [, $defaultno =  FALSE [, $backbutton = FALSE ] ] )

 Show boolean dialog box

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
 Param bool $defaultno If TRUE, set the default value of the box to 'No'
 Param bool $backbutton Whether or not a back button must be added in the dialog box
 Return int Dialog exit code

=cut

sub yesno
{
    my ( $self, $text, $defaultno, $backbutton ) = @_;

    unless ( $backbutton ) {
        local $self->{'opts'}->{'defaultno'} = $defaultno ? '' : undef;
        local $ENV{'DIALOG_CANCEL'} = 1;
        return ( $self->_textbox( $text, 'yesno' ) )[0];
    }

    local $ENV{'DIALOG_EXTRA'} = 1;
    local $self->{'opts'}->{'default-button'} = $defaultno ? 'extra' : undef;
    local $self->{'opts'}->{'ok-label'} = 'Yes';
    local $self->{'opts'}->{'extra-label'} = 'No';
    local $self->{'opts'}->{'extra-button'} = '';
    ( $self->_textbox( $text, 'yesno' ) )[0];
}

=item inputbox( $text [, $init = '' ] )

 Show input dialog

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

 Show password dialog

 Param string $text Text to show
 Param string $init Default password value
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub passwordbox
{
    my ( $self, $text, $init ) = @_;
    $init //= '';

    local $self->{'opts'}->{'insecure'} = '';
    $self->_textbox( $text, 'passwordbox', escapeShell( $init ));
}

=item infobox( $text )

 Show info dialog

 Param string $text Text to show
 Return int Dialog exit code

=cut

sub infobox
{
    my ( $self, $text ) = @_;

    local $self->{'opts'}->{'clear'} = undef;
    ( $self->_textbox( $text, 'infobox' ) )[0];
}

=item startGauge( $text [, $percent = 0 ] )

 Start a gauge

 Param string $text Text to show
 Param int $percent OPTIONAL Initial percentage show in the meter
 Return void, die on failure

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    return if iMSCP::Getopt->noprompt || $self->{'gauge'};

    defined $text or croak( '$text parameter is undefined' );

    open $self->{'gauge'}, '|-',
        $self->{'bin'}, $self->_buildCommonCommandOptions( 'noEscape' ),
        '--gauge', $text,
        ( ( $self->{'autosize'} ) ? 0 : $self->{'lines'} ),
        ( ( $self->{'autosize'} ) ? 0 : $self->{'columns'} ),
        $percent // 0 or die( "Couldn't start gauge" );

    $self->{'gauge'}->autoflush( 1 );
}

=item setGauge( $percent, $text )

 Set new percentage and optionaly new text to show

 Param int $percent New percentage to show in gauge dialog box
 Param string $text New text to show in gauge dialog box
 Return void

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

    return if iMSCP::Getopt->noprompt || !$self->{'gauge'};

    print { $self->{'gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, $text );
}

=item endGauge( )

 Terminate gauge dialog box

 Return void

=cut

sub endGauge
{
    return 0 unless $_[0]->{'gauge'};

    $_[0]->{'gauge'}->close();
    undef $_[0]->{'gauge'};
}

=item hasGauge( )

 Is a gauge set?

 Return bool TRUE if a gauge is running FALSE otherwise

=cut

sub hasGauge
{
    $_[0]->{'gauge'} ? 1 : 0;
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
    if ( !exists $ENV{'TERM'} || !defined $ENV{'TERM'} || length $ENV{'TERM'} == 0 ) {
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
    $self->{'opts'}->{'backtitle'} ||= "i-MSCP - internet Multi Server Control Panel ($::imscpConfig{'Version'})";
    $self->{'opts'}->{'title'} ||= 'i-MSCP Installer Dialog';
    $self->{'opts'}->{'colors'} = '';
    $self->{'opts'}->{'ok-label'} ||= 'Ok';
    $self->{'opts'}->{'yes-label'} ||= 'Yes';
    $self->{'opts'}->{'no-label'} ||= 'No';
    $self->{'opts'}->{'cancel-label'} ||= 'Back';
    $self->{'opts'}->{'exit-label'} ||= 'Abort';
    $self->{'opts'}->{'help-label'} ||= 'Help';
    $self->{'opts'}->{'extra-label'} ||= undef;
    $self->{'opts'}->{'extra-button'} //= undef;
    $self->{'opts'}->{'help-button'} //= undef;
    $self->{'opts'}->{'defaultno'} ||= undef;
    $self->{'opts'}->{'default-button'} ||= undef;
    $self->{'opts'}->{'default-item'} ||= undef;
    $self->{'opts'}->{'no-cancel'} ||= undef;
    $self->{'opts'}->{'no-ok'} ||= undef;
    $self->{'opts'}->{'clear'} ||= undef;
    $self->{'opts'}->{'column-separator'} = undef;
    $self->{'opts'}->{'cr-wrap'} = undef;
    $self->{'opts'}->{'no-collapse'} = undef;
    $self->{'opts'}->{'trim'} = undef;
    $self->{'opts'}->{'date-format'} = undef;
    $self->{'opts'}->{'help-status'} = undef;
    $self->{'opts'}->{'insecure'} = undef;
    $self->{'opts'}->{'item-help'} = undef;
    $self->{'opts'}->{'max-input'} = undef;
    $self->{'opts'}->{'no-shadow'} = undef;
    $self->{'opts'}->{'shadow'} = '';
    $self->{'opts'}->{'single-quoted'} = undef;
    $self->{'opts'}->{'tab-correct'} = undef;
    $self->{'opts'}->{'tab-len'} = undef;
    $self->{'opts'}->{'timeout'} = undef;
    $self->{'opts'}->{'height'} = undef;
    $self->{'opts'}->{'width'} = undef;
    $self->{'opts'}->{'aspect'} = undef;
    $self->{'opts'}->{'separate-output'} = undef;
    $self->{'opts'}->{'no-tags'} = undef;
    $self->_findBin( $^O =~ /bsd$/ ? 'cdialog' : 'dialog' );
    $self->_resize();
    $SIG{'WINCH'} = sub { $self->_resize(); };
    $self;
}

=item _resize( )

 This method is called whenever the tty is resized, and probes to determine the new screen size.

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

 Return iMSCP::Dialog::Dialog, die on failure

=cut

sub _findBin
{
    my ( $self, $variant ) = @_;

    my $bindPath = iMSCP::ProgramFinder::find( $variant ) or die( sprintf( "Couldn't find %s executable in \$PATH", $variant ));
    $self->{'bin'} = $bindPath;
    $self;
}

=item _stripFormats( $string )

 Strip out any format characters (\Z sequences) from the given string

 Param string $string String from which any format character must be stripped
 Return string String stripped out of any format character

=cut

sub _stripFormats
{
    my ( undef, $string ) = @_;

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
        defined $self->{'opts'}->{$_}
            ? ( "--$_", ( $noEscape )
            ? ( !length $self->{'opts'}->{$_} ? () : $self->{'opts'}->{$_} )
            : ( !length $self->{'opts'}->{$_} ? () : escapeShell( $self->{'opts'}->{$_} ) ) )
            : ()
    } keys %{ $self->{'opts'} };

    wantarray ? @options : "@options";
}

=item _restoreDefaults( )

 Restore default options

 Return iMSCP::Dialog::Dialog

=cut

sub _restoreDefaults
{
    my ( $self ) = @_;

    for my $prop ( keys %{ $self->{'opts'} } ) {
        $self->{'opts'}->{$prop} = undef unless $prop =~ /^(?:title|backtitle|colors)$/;
    }

    $self;
}

=item _execute( $text, $init, $type )

 Wrap execution of dialog commands (except gauge dialog commands)

 Param string $text Dialog text
 Param string $init Default value
 Param string $type Dialog box type
 Return string|array Dialog output or array containing both dialog exit code and dialog output, die on failure

=cut

sub _execute
{
    my ( $self, $text, $init, $type ) = @_;
    $init //= '';

    $self->endGauge(); # Ensure that no gauge is currently running...

    if ( iMSCP::Getopt->noprompt ) {
        unless ( grep ($type eq $_, 'infobox', 'msgbox') ) {
            if ( iMSCP::Getopt->preseed() ) {
                die( sprintf( "Missing or bad entry in your preseed file for the '%s' question", $text ));
            } else {
                die( 'Missing or bad entry found in i-MSCP configuration file. Please rerun the installer in interactive mode.' );
            }
        }

        return 0;
    }

    $text = $self->_stripFormats( $text ) unless defined $self->{'opts'}->{'colors'};
    $text = escapeShell( $text );

    $self->{'opts'}->{'separate-output'} = '' if $type eq 'checklist';

    my $command = $self->_buildCommonCommandOptions();
    my $height = ( $self->{'autosize'} ) ? 0 : $self->{'lines'};
    my $width = ( $self->{'autosize'} ) ? 0 : $self->{'columns'};

    my $ret = execute( "$self->{'bin'} $command --$type $text $height $width $init", undef, \my $output );

    $self->{'opts'}->{'separate-output'} = undef;
    $self->_init() if $self->{'autoreset'};

    wantarray ? ( $ret, $output ) : $output;
}

=item _textbox( $text, $type [, $init = '' ])

 Wrap execution of several dialog box

 Param string $text Text to show
 Param string $mode Text dialog box type (radiolist|checklist|msgbox|yesno|inputbox|passwordbox|infobox)
 Param string $init Default value
 Return string|array Dialog output or array containing both dialog exit code and dialog output

=cut

sub _textbox
{
    my ( $self, $text, $type, $init ) = @_;

    my $autosize = $self->{'autosize'};
    $self->{'autosize'} = undef;
    my ( $ret, $output ) = $self->_execute( $text, $init, $type );
    $self->{'autosize'} = $autosize;
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
