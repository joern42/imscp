=head1 NAME

 iMSCP::Dialog::Whiptail - FrontEnd for user interface based on WHIPTAIL(1)

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

package iMSCP::Dialog::Whiptail;

use strict;
use warnings;
use Carp 'croak';
use iMSCP::Boolean;
use iMSCP::Execute 'execute';
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use iMSCP::Dialog::TextFormatter qw/ wrap width /;
use parent qw/ iMSCP::Dialog::FrontEndInterface iMSCP::Common::Singleton /;

=head1 DESCRIPTION

 FrontEnd for user interface based on WHIPTAIL(1).

=head1 PUBLIC METHODS/FUNCTIONS

=over 4

=item select( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 See iMSCP::Dialog::FrontEndInterface::select()

=cut

sub select
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $showTags //= FALSE;

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );
    defined $choices && ref $choices eq 'HASH' or croak( '\%choices parameter is undefined or invalid.' );
    !defined $defaultTag || ref \$defaultTag eq 'SCALAR' or croak( '$defaultTag parameter is invalid.' );

    my @init;
    if ( $showTags || $self->_getWhiptailVersion() > '05218' ) {
        push @init, $_, $choices->{$_}, $_ eq $defaultTag ? 'on' : 'off' for sort keys %{ $choices };
    } else {
        # The --notags option isn't working despite what the manpage say. This
        # is a bug which has been fixed in newt library version 0.52.19.
        # See https://bugs.launchpad.net/ubuntu/+source/newt/+bug/1647762
        # We workaround the issue by using items as tags and by providing
        # empty items. Uniqueness of items is assumed here.
        push @init, $choices->{$_}, '', $_ eq $defaultTag ? 'on' : 'off' for sort keys %{ $choices };
    }

    local $self->{'_opts'}->{'notags'} = '' unless $showTags;
    my ( $ret, $tag ) = $self->_showDialog( 'radiolist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );

    unless ( $self->_getWhiptailVersion() > '05218' ) {
        # See the above comment for the explanation
        # We need retrieve tag associated with selected item
        my %choices = reverse( %{ $choices } );
        $tag = $choices{$tag};
    }

    wantarray ? ( $ret, $tag ) : $tag;
}

=item multiselect( $text, \%choices [, \@defaultTags = [] [, $showTags =  FALSE ] ] )

 See iMSCP::Dialog::FrontEndInterface::multiselect()

=cut

sub multiselect
{
    my ( $self, $text, $choices, $defaultTags, $showTags ) = @_;
    $defaultTags //= [];

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );
    defined $choices && ref $choices eq 'HASH' or croak( '\%choices parameter is undefined or invalid.' );
    ref $defaultTags eq 'ARRAY' or croak( '\@defaultTags parameter is invalid.' );

    my @init;
    if ( $showTags || $self->_getWhiptailVersion() > '05218' ) {
        for my $tag ( sort keys %{ $choices } ) {
            push @init, $tag, $choices->{$tag}, grep ( $tag eq $_, @{ $defaultTags }) ? 'on' : 'off';
        }
    } else {
        # The --notags option isn't working despite what the manpage say. This
        # is a bug which has been fixed in newt library version 0.52.19.
        # See https://bugs.launchpad.net/ubuntu/+source/newt/+bug/1647762
        # We workaround the issue by using items as tags and by providing
        # empty items. Uniqueness of items is assumed here.
        for my $tag ( sort keys %{ $choices } ) {
            push @init, $choices->{$tag}, '', grep ( $tag eq $_, @{ $defaultTags } ) ? 'on' : 'off';
        }
    }

    local @{ $self->{'_opts'} }{qw/ separate-output notags /} = ( '', $showTags ? undef : '' );
    my ( $ret, $tags ) = $self->_showDialog( 'checklist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
    my @tags = split /\n/, $tags;

    unless ( $self->_getWhiptailVersion() > '05218' ) {
        # See the above comment for the explanation
        # We need retrieve tags associated with selected items
        my %choices = reverse( %{ $choices } );
        @tags = map { $choices{$_} } @tags;
    }

    wantarray ? ( $ret, \@tags ) : \@tags;
}

=item boolean( $text [, $defaultno =  FALSE ] )

 See iMSCP::Dialog::FrontEndInterface::boolean()

=cut

sub boolean
{
    my ( $self, $text, $defaultno ) = @_;

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );

    ( $text, my $boxHeight, my $boxWidth ) = $self->_formatText( $text );

    local @{ $self->{'_opts'} }{qw/ defaultno scrolltext / } = ( $defaultno ? '' : undef );

    if ( $boxHeight > ( my $maxBoxHeight = $self->{'screenHeight'}-$self->{'screenPaddingHeight'} ) ) {
        $boxHeight = $maxBoxHeight;
        $self->{'_opts'}->{'scrolltext'} = '';
    }

    ( $self->_showDialog( 'yesno', $text, $boxHeight, $boxWidth ) )[0];
}

=item error( $text )

 See iMSCP::Dialog::FrontEndInterface::error()

=cut

sub error
{
    my ( $self, $text ) = @_;

    $self->_showText( $text );
}

=item note( $text )

 See iMSCP::Dialog::FrontEndInterface::note()

=cut

sub note
{
    my ( $self, $text ) = @_;

    $self->_showText( $text );
}

=item text( $text )

 See iMSCP::Dialog::FrontEndInterface::text()

=cut

sub text
{
    my ( $self, $text ) = @_;

    $self->_showText( $text );
}

=item string( $text [, $default = '' ] )

 See iMSCP::Dialog::FrontEndInterface::string()

=cut

sub string
{
    my ( $self, $text, $default ) = @_;
    $default //= '';

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );
    ref \$default eq 'SCALAR' or croak( '$default parameter is invalid.' );

    ( $text, my $boxHeight, my $boxWidth ) = $self->_formatText( $text );

    local $self->{'_opts'}->{'scrolltext'};
    if ( $boxHeight > ( my $maxBoxHeight = $self->{'screenHeight'}-$self->{'screenPaddingHeight'} ) ) {
        $boxHeight = $maxBoxHeight;
        $self->{'_opts'}->{'scrolltext'} = '';
    }

    $self->_showDialog( 'inputbox', $text, $boxHeight+$self->{'spacer'}, $boxWidth, $default );
}

=item password( $text [, $default = '' ] )

 See iMSCP::Dialog::FrontEndInterface::password()

=cut

sub password
{
    my ( $self, $text, $default ) = @_;
    $default //= '';

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );
    ref \$default eq 'SCALAR' or croak( '$default parameter is invalid.' );

    ( $text, my $boxHeight, my $boxWidth ) = $self->_formatText( $text );

    local $self->{'_opts'}->{'scrolltext'};
    if ( $boxHeight > ( my $maxBoxHeight = $self->{'screenHeight'}-$self->{'screenPaddingHeight'} ) ) {
        $boxHeight = $maxBoxHeight;
        $self->{'_opts'}->{'scrolltext'} = '';
    }

    my ( $retval, $output ) = $self->_showDialog( 'passwordbox', $text, $boxHeight+$self->{'spacer'}, $boxWidth );

    # The password isn't passed in, so if nothing is entered, use the default.
    $output = $default if $retval == 0 && $output eq '';

    wantarray ? ( $retval, $output ) : $output;
}

=item startGauge( $text [, $percent = 0 ] )

 See iMSCP::Dialog::FrontEndInterface::startGauge()

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    return 0 if $self->hasGauge();

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );
    ref \$percent eq 'SCALAR' && $percent =~ /^[\d]+$/ or croak( '$text parameter is invalid.' );

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions( 'gauge' ), '--gauge', _stripEmbeddedSequences( $text ),
        $self->{'lines'}, $self->{'columns'}, $percent // 0 or croak( "Couldn't start gauge" );
    $self->{'_gauge'}->autoflush( TRUE );
}

=item setGauge( $percent, $text )

 See iMSCP::Dialog::FrontEndInterface::setGauge()

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

    ref \$percent eq 'SCALAR' && $percent =~ /^[\d]+$/ or croak( '$text parameter is invalid.' );
    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );

    unless ( defined $self->{'_gauge'} ) {
        $self->startGauge( $text, $percent );
        return;
    }

    print { $self->{'_gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, _stripEmbeddedSequences( $text ));
}

=item endGauge( )

 See iMSCP::Dialog::FrontEndInterface::endGauge()

=cut

sub endGauge
{
    my ( $self ) = @_;

    return unless $self->{'_gauge'};

    $self->{'_gauge'}->close();
    undef $self->{'_gauge'};
}

=item hasGauge( )

 See iMSCP::Dialog::FrontEndInterface::hasGauge()

=cut

sub hasGauge
{
    my ( $self ) = @_;

    !!$self->{'_gauge'}
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::Singleton::_init()

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

    # Display attributes
    @{ $self }{qw/ screenHeight screenPaddingHeight screenWidth screenPaddingWidth boxPaddingHeight boxPaddingWidth boxTitlePaddingWidth spacer /} = (
        0, 4, 0, 5, 8, 4, 6, 1
    );

    # Determine current screenheight/screenwidth
    $self->_resize();
    $SIG{'WINCH'} = sub {
        # There is a short period during global destruction where $self may
        # have been destroyed but the handler still operative.
        $self->_resize() if defined $self
    };

    # Whiptail options (only relevant options are listed there)
    @{ $self->{'_opts'} }{qw/ clear scrolltext defaultno nocancel yes-button no-button ok-button cancel-button title backtitle /} = (
        undef, undef, undef, undef, 'Yes', 'No', 'Ok', 'Back', undef, 'i-MSCP - internet Multi Server Control Panel'
    );

    $self;
}

=item _findBin( $variant )

 Return string WHIPTAIL(1) binary path, die if WHIPTAIL(1) binary is not found

=cut

sub _findBin
{
    iMSCP::ProgramFinder::find( 'whiptail' ) or die( "Couldn't find WHIPTAIL(1) binary" );
}

=item _getCommonOptions( $boxType )

 Get dialog common options

 Param string $boxType Box type for which common option must be build
 Return List Dialog common options

=cut

sub _getCommonOptions
{
    my ( $self, $boxType ) = @_;

    my %options = %{ $self->{'_opts'} };

    # Delete unwanted options
    if ( $boxType eq 'yesno' ) {
        delete @options{qw/ ok-button cancel-button nocancel /};
    } elsif ( $boxType eq 'gauge' ) {
        delete @options{qw/ ok-button nocancel yes-button no-button defaultno /};
    } elsif ( grep ( $boxType eq $_, 'inputbox', 'passwordbox') ) {
        delete @options{qw/ yes-button no-button /};
    } elsif ( grep ( $boxType eq $_, 'radiolist', 'checklist') ) {
        delete @options{qw/ yes-button no-button defaultno /};
    }

    ( map { defined $options{$_} ? ( '--' . $_, ( $options{$_} eq '' ? () : $options{$_} ) ) : () } keys %options ), (
        $boxType ne 'gauge' ? '--fullbuttons' : ()
    )
}

=item _showDialog( $boxType, @boxOptions )

 Display a dialog

 Note that the return code of dialog is examined, and if the user hit escape
 or cancel, it will be assumed that it wanted to back up. In that case, 30
 will be returned.

 Param string $boxType Box type
 Param list @boxOptions Box options 
 Return string|list Dialog output in scalar context, an array containing both dialog return code and dialog output in list context, croak on failure

=cut

sub _showDialog
{
    my ( $self, $boxType, @boxOptions ) = @_;

    $self->endGauge();

    my $retval = execute( [ $self->{'_bin'}, $self->_getCommonOptions( $boxType ), "--$boxType", '--', @boxOptions ], undef, \my $output );
    # Map exit code to expected iMSCP::Dialog::FrontEndInterface::* retval
    # We need return 30 when user hit escape or cancel (back up capability)
    $retval = 30 if $retval == 255 || ( $retval == 1 && $boxType ne 'yesno' );

    # Both dialog output and dialog errors goes to STDERR. We need catch errors
    !length $output or croak $output if $retval == 30;

    wantarray ? ( $retval, $output ) : $output;
}

=item _resize( )

 This method is called whenever the tty is resized, and probes to determine the new screen size

 return void

=cut

sub _resize
{
    my ( $self ) = @_;

    if ( exists $ENV{'LINES'} ) {
        $self->{'screenHeight'} = $ENV{'LINES'};
    } else {
        my ( $rows ) = `stty -a 2>/dev/null` =~ /rows (\d+)/s;
        $self->{'screenHeight'} = $rows // 25;
    }

    if ( exists $ENV{'COLUMNS'} ) {
        $self->{'screenWidth'} = $ENV{'COLUMNS'};
    } else {
        my ( $cols ) = `stty -a 2>/dev/null` =~ /columns (\d+)/s;
        $self->{'screenWidth'} = ( $cols || 80 );
    }

    # Whiptail can't deal with very small screens. Detect this and fail,
    # forcing use of some other frontend.
    if ( $self->{'screenHeight'} < 13 || $self->{'screenWidth'} < 31 ) {
        die( "A screen at least 13 lines tall and 31 columns wide is required. Please enlarge your screen.\n" );
    }

    $self->endGauge();
}

=item _stripEmbeddedSequences( $string )

 Strip out any DIALOG(1) embedded "\Z" sequences

 Param string $string String from which DIALOG(1) embedded "\Z" sequences must be stripped
 Return string String stripped out of any DIALOG(1) embedded "\Z" sequences

=cut

sub _stripEmbeddedSequences
{
    $_[0] =~ s/\\Z[0-7bBrRuUn]//gmr;
}

=item _getWhiptailVersion

 Get whiptail version

 Return string version (stripped of any dot)

=cut

sub _getWhiptailVersion
{
    my ( $self ) = @_;

    $self->{'_whiptail_version'} //= do {
        my ( $stdout, $stderr );
        execute( [ $self->{'_bin'}, '--version' ], \$stdout, \$stderr ) == 0 or die( "Couldn't get whiptail version: $stderr" );
        $stdout =~ /([\d.]+)/i or die( "Couldn't retrieve whiptail version in version string" );
        $1 =~ s/\.//gr;
    };
}

=item _formatText( $text )

 Format the given text to be displayed in a dialog box according current display properties

 Param string $text Text to format
 Return list conting formatted text and required box height and width to print the formatted text according the current display properties

=cut

sub _formatText
{
    my ( $self, $text ) = @_;

    $text = _stripEmbeddedSequences( $text );

    $iMSCP::Dialog::TextFormatter::columns = $self->{'screenWidth'}-$self->{'screenPaddingWidth'}-$self->{'boxPaddingWidth'};
    $text = wrap( '', '', $text );

    my $boxWidth = defined $self->{'_opts'}->{'title'} ? width( $self->{'_opts'}->{'title'} )+$self->{'boxTitlePaddingWidth'} : 0;
    my $nbLines = my @lines = split /\n/, $text;

    map {
        my $width = width( $_ );
        $boxWidth = $width if $width > $boxWidth
    } @lines;
    undef @lines;

    $text, $nbLines+$self->{'boxPaddingHeight'}, $boxWidth+$self->{'boxPaddingWidth'};
}

=item _showtext

 Display the given text in a dialog box
 
 If the text is too long, it will be displayed in a scrollable dialog box.

 Param string $text Text to display
 Return int 0 (Ok), 30 (Backup), croak on failure

=cut

sub _showText
{
    my ( $self, $text ) = @_;

    ref \$text eq 'SCALAR' && length $text or croak( '$text parameter is invalid.' );

    ( $text, my $boxHeight, my $boxWidth ) = $self->_formatText( $text );

    local $self->{'_opts'}->{'scrolltext'};
    if ( $boxHeight > ( my $maxBoxHeight = $self->{'screenHeight'}-$self->{'screenPaddingHeight'} ) ) {
        $boxHeight = $maxBoxHeight;
        $self->{'_opts'}->{'scrolltext'} = '';
    }

    ( $self->_showDialog( 'msgbox', $text, $boxHeight, $boxWidth ) )[0];
}

=item DESTROY()

 Destroy dialog object

=cut

sub DESTROY
{
    $_[0]->endGauge();
    $SIG{'WINCH'} = 'DEFAULT';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
