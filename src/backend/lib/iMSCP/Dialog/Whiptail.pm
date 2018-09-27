=head1 NAME

 iMSCP::Whiptail - FrontEnd for user interface based on WHIPTAIL(1)

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

package iMSCP::Dialog::Whiptail;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Execute 'execute';
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'iMSCP::Dialog::FrontEndInterface';

=head1 DESCRIPTION

 FrontEnd for user interface based on WHIPTAIL(1)

=head1 PUBLIC METHODS/FUNCTIONS

=over 4

=item select( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 See iMSCP::Dialog::FrontEndInterface::select()

=cut

sub select
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $showTags //= FALSE;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    defined $choices && ref $choices eq 'HASH' or die( '\%choices parameter is undefined or invalid.' );
    !defined $defaultTag || ref \$defaultTag eq 'SCALAR' or die( '$defaultTag parameter is invalid.' );

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

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    defined $choices && ref $choices eq 'HASH' or die( '\%choices parameter is undefined or invalid.' );
    ref $defaultTags eq 'ARRAY' or die( '\@defaultTags parameter is invalid.' );

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

    local @{ $self->{'_opts'} }{qw/ separate-output notags /} = ( '', !$showTags ? '' : undef );
    my ( $ret, $tags ) = $self->_showDialog( 'checklist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
    my @tags = split /\n/, $tags;

    unless ( $self->_getWhiptailVersion() > '05218' ) {
        # See the above comment for the explanation
        # We need retrieve tags associated with selected items
        my %choices = reverse( %{ $choices } );
        @tags = map { $choices{$_} } split /\n/, $tags;
    }

    wantarray ? ( $ret, \@tags ) : \@tags;
}

=item boolean( $text [, $defaultno =  FALSE ] )

 See iMSCP::Dialog::FrontEndInterface::boolean()

=cut

sub boolean
{
    my ( $self, $text, $defaultno ) = @_;
    $defaultno //= FALSE;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
    ( $self->_showDialog( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item msgbox( $text )

 See iMSCP::Dialog::FrontEndInterface::msgbox()

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    ( $self->_showDialog( 'msgbox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item infobox( $text )

 See iMSCP::Dialog::FrontEndInterface::infobox()

=cut

sub infobox
{
    my ( $self, $text ) = @_;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    local $self->{'_opts'}->{'clear'} = undef;
    ( $self->_showDialog( 'infobox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item string( $text [, $default = '' ] )

 See iMSCP::Dialog::FrontEndInterface::string()

=cut

sub string
{
    my ( $self, $text, $default ) = @_;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    $self->_showDialog( 'inputbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item password( $text [, $default = '' ])

 See iMSCP::Dialog::FrontEndInterface::password()

=cut

sub password
{
    my ( $self, $text, $default ) = @_;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    $self->_showDialog( 'passwordbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item startGauge( $text [, $percent = 0 ] )

 See iMSCP::Dialog::FrontEndInterface::startGauge()

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    defined $text or die( '$text parameter is undefined' );

    return 0 if $self->hasGauge();

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions( 'gauge' ), '--gauge', _stripEmbeddedSequences( $text ),
        $self->{'lines'}, $self->{'columns'}, $percent // 0 or die( "Couldn't start gauge" );
    $self->{'_gauge'}->autoflush( TRUE );
}

=item setGauge( $percent, $text )

 See iMSCP::Dialog::FrontEndInterface::setGauge()

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

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

    # Terminal lines and columns (determined at runtime)
    # Display attributes
    @{ $self }{qw/ lines columns /} = ( 0, 0 );

    $self->_resize();
    $SIG{'WINCH'} = sub { $self->_resize(); };

    # Only relevant options are listed there.
    @{ $self->{'_opts'} }{qw/ clear scrolltext defaultno nocancel yes-button no-button ok-button cancel-button title backtitle /} = (
        undef, undef, undef, undef, 'Yes', 'No', 'Ok', 'Back', undef, 'i-MSCP™ - internet Multi Server Control Panel'
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
 Return string|list Dialog STDERR output in scalar context, an array containing both dialog return code and STDERR output in list context

=cut

sub _showDialog
{
    my ( $self, $boxType, @boxOptions ) = @_;

    $self->endGauge();
    $boxOptions[0] = _stripEmbeddedSequences( $boxOptions[0] );
    my $retval = execute( [ $self->{'_bin'}, $self->_getCommonOptions( $boxType ), "--$boxType", '--', @boxOptions ], undef, \my $output );
    # Map exit code to expected iMSCP::Dialog::FrontEndInterface::* retval
    # We need return 30 when user hit escape or cancel (back up capability)
    $retval = 30 if $retval == 255 || ( $retval == 1 && $boxType ne 'yesno' );
    # For the input and password boxes, we do not want lose previous value when
    # backing up
    # TODO radiolist, checklist and yesno dialog boxes
    #$output = pop @boxOptions if $ret == 30 && grep ( $boxType eq $_, 'inputbox', 'passwordbox' );
    wantarray ? ( $retval, $output ) : $output;
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

=item _stripEmbeddedSequences( $string )

 Strip out any DIALOG(1) embedded "\Z" sequences

 Param string $string String from which DIALOG(1) embedded "\Z" sequences must be stripped
 Return string String stripped out of any DIALOG(1) embedded "\Z" sequences

=cut

sub _stripEmbeddedSequences
{
    $_[0] =~ s/\\Z[0-7brun]//gimr;
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
