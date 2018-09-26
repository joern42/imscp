=head1 NAME

 iMSCP::Whiptail - Display dialog boxes using WHIPTAIL(1)

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
use iMSCP::ProgramFinder;
use parent 'iMSCP::Dialog::DialogAbstract';

BEGIN {
    local $@;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Display dialog boxes using WHIPTAIL(1)

=head1 PUBLIC METHODS

=over 4

=item radiolist( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 Show radiolist WHIPTAIL(1) box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param string $default Default selected tag
 Param bool $showTags Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both the WHIPTAIL(1) exit code and an array containing checked tags

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

 Show checklist WHIPTAIL(1) box

 Param string $text Text to show
 Param hashref \%choices List of choices where keys are tags and values are items.
 Param arrayref \@default Default tag(s)
 Param bool $showTags OPTIONAL Flag indicating whether or not tags must be showed in dialog box
 Return Array containing checked tags or a list containing both WHIPTAIL(1) exit code and an array containing checked tags

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

 Show yesno WHIPTAIL(1) box

 Param string $text Text to show
 Param string bool defaultno Set the default value of the box to 'No'
 Return int 0 (Yes), 1 (No), -1 (ESC or failure)

=cut

sub yesno
{
    my ( $self, $text, $defaultno ) = @_;

    local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
    ( $self->_execute( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item msgbox( $text )

 Show message WHIPTAIL(1) box

 Param string $text Text to show in message dialog box
 Return int 0 (Ok), -1 (ESC or failure)

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ( $self->_execute( 'msgbox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item infobox( $text )

 Show info WHIPTAIL(1) box (same as msgbox but exit immediately)

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

 Show input WHIPTAIL(1) box

 Param string $text Text to show
 Param string $default Default value
 Return string|array Input string or an array containing both WHIPTAIL(1) exit code and input string

=cut

sub inputbox
{
    my ( $self, $text, $default ) = @_;

    $self->_execute( 'inputbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item passwordbox( $text [, $default = '' ])

 Show password WHIPTAIL(1) dialog box

 Param string $text Text to show
 Param string $default Default value
 Return string|array Password string or an array containing both WHIPTAIL(1) exit code and input string

=cut

sub passwordbox
{
    my ( $self, $text, $default ) = @_;

    $self->_execute( 'passwordbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item resetLabels( )

 Reset WHIPTAIL(1) labels to their default values

 Return void

=cut

sub resetLabels
{
    @{ $_[0]->{'_opts'} }{qw/ yes-button no-button ok-button cancel-button /} = ( 'Yes', 'No', 'Ok', 'Cancel' );
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

    # First line: WHIPTAIL(1) boolean option
    # Second line: WHIPTAIL(1) value options
    # Only relevant options are listed there. Other available options are simply ignored.
    @{ $self->{'_opts'} }{qw/
        clear defaultno nocancel noitem notags
        default-item yes-button no-button ok-button cancel-button output-fd title backtitle
    /} = (
        undef, undef, undef, undef, undef,
        undef, 'Yes', 'No', 'Ok', 'Cancel', undef, undef, 'i-MSCP™ - internet Multi Server Control Panel'
    );

    $self->SUPER::_init();
    $self;
}

=item _findBin( $variant )

 Return string WHIPTAIL(1) program binary path, die if WHIPTAIL(1) binary is not found

=cut

sub _findBin
{
    iMSCP::ProgramFinder::find( 'whiptail' ) or die( "Couldn't find WHIPTAIL(1) binary" );
}

=item _getCommonOptions( )

 Get DIALOG(1) common options

 Return List DIALOG(1) common options

=cut

sub _getCommonOptions
{
    my ( $self ) = @_;

    ( map {
        defined $self->{'_opts'}->{$_} ? ( '--' . $_, ( $self->{'_opts'}->{$_} eq '' ? () : $self->{'_opts'}->{$_} ) ) : ()
    } keys %{ $self->{'_opts'} }
    ), '--fb'
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
