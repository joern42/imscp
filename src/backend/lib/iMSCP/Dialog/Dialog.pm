=head1 NAME

 iMSCP::Dialog::Dialog - Display dialog boxes using DIALOG(1)

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

package iMSCP::Dialog::Dialog;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Execute 'execute';
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'iMSCP::Dialog::DialogAbstract';

BEGIN {
    local $@;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Display dialog boxes using DIALOG(1)

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

    local $self->{'_opts'}->{'notags'} = '' unless $showTags;
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
    local $self->{'_opts'}->{'notags'} = '' unless $showTags;
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
    local $self->{'_opts'}->{'ok-button'} = 'Yes';
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

=item resetLabels( )

 Reset DIALOG(1) labels to their default values

 Return void

=cut

sub resetLabels
{
    @{ $_[0]->{'_opts'} }{qw/ ok-button yes-button no-button cancel-button extra-label /} = ( 'Ok', 'Yes', 'No', 'Cancel', undef );
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

    # Return specific exit status when ESC is pressed
    $ENV{'DIALOG_ESC'} = 50;
    # We want get 30 as exit code when CANCEL button is pressed
    $ENV{'DIALOG_CANCEL'} = 30;

    # First line: DIALOG(1) boolean options
    # Second line: DIALOG(1) value options
    # Only relevant options are listed.
    @{ $self->{'_opts'} }{qw/
        clear defaultno nocancel extra-button notags
        ok-button yes-button no-button cancel-button extra-label title backtitle
    /} = (
        undef, undef, undef, undef, undef,
        'Ok', 'Yes', 'No', 'Cancel', undef, undef, 'i-MSCP™ - internet Multi Server Control Panel'
    );

    $self->SUPER::_init();
    $self;
}

=item _findBin( )

 Return string DIALOG(1) program binary path, die if DIALOG(1) binary is not found

=cut

sub _findBin
{
    iMSCP::ProgramFinder::find( 'dialog' ) or die( "Couldn't find DIALOG(1) binary" );
}

=item _getCommonOptions( )

 Get DIALOG(1) common options

 Return List DIALOG(1) common options

=cut

sub _getCommonOptions
{
    my ( $self ) = @_;

    ( map {
        defined $self->{'_opts'}->{$_} ? ( '--' . $_, ( $self->{'_opts'}->{$_} eq '' ? () : $self->{'_opts'}->{$_} ) ) : () }
        keys %{ $self->{'_opts'} }
    ), '--colors', '--cr-wrap', '--no-collapse';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
