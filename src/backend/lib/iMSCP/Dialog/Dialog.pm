=head1 NAME

 iMSCP::Dialog::Dialog - FrontEnd for user interface based on DIALOG(1)

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
use iMSCP::ProgramFinder;
use parent 'iMSCP::Dialog::Whiptail';

=head1 DESCRIPTION

 FrontEnd for user interface based on DIALOG(1)

=head1 PUBLIC METHODS

=over 4

=item select( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 See iMSCP::Dialog::Whiptail::select()

=cut

sub select
{
    my ( $self, $text, $choices, $defaultTag, $showTags ) = @_;
    $showTags //= FALSE;

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    defined $choices && ref $choices eq 'HASH' or die( '\%choices parameter is undefined or invalid.' );
    !defined $defaultTag || ref \$defaultTag eq 'SCALAR' or die( '$defaultTag parameter is invalid.' );

    my @init;
    push @init, $_, $choices->{$_}, $defaultTag eq $_ ? 'on' : 'off' for sort keys %{ $choices };

    local $self->{'_opts'}->{'notags'} = '' unless $showTags;
    $self->_showDialog( 'radiolist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
}

=item multiselect( $text, \%choices [, \@defaultTags = [] [, $showTags =  FALSE ] ] )

 See iMSCP::Dialog::Whiptail::multiselect()

=cut

sub multiselect
{
    my ( $self, $text, $choices, $defaultTags, $showTags ) = @_;
    $defaultTags //= [];

    ref \$text eq 'SCALAR' && length $text or die( '$text parameter is undefined or invalid.' );
    defined $choices && ref $choices eq 'HASH' or die( '\%choices parameter is undefined or invalid.' );
    ref $defaultTags eq 'ARRAY' or die( '\@defaultTags parameter is invalid.' );

    my @init;
    for my $tag ( sort keys %{ $choices } ) {
        push @init, $tag, $choices->{$tag}, grep ( $tag eq $_, @{ $defaultTags }) ? 'on' : 'off';
    }

    local @{ $self->{'_opts'} }{qw/ separate-output notags /} = ( '', !$showTags ? '' : undef );
    my ( $ret, $tags ) = $self->_showDialog( 'checklist', $text, $self->{'lines'}, $self->{'columns'}, scalar keys %{ $choices }, @init );
    wantarray ? ( $ret, [ split /\n/, $tags ] ) : [ split /\n/, $tags ];
}

=item boolean( $text [, $defaultno =  FALSE [, $backup = FALSE ] ] )

 See iMSCP::Dialog::Whiptail::boolean()

 The code used for 'Yes' and 'No' buttons match those used for the 'Ok' and
 'Cancel' buttons. See dialog man page. We do not want this behavior. To
 workaround, we process as follows:

  - If not 'Back' button is needed:
    We temporary change code of the 'Cancel' button to 1 (default is 30).
    So 'Yes' = 0, 'No' = 1, ESC = 30
 
  - If a 'Back' button is needed:
    We make use of the extra button (code 1) which replace the default 'No' button.
    We change default labels
    So: 'Yes' = 0, 'No' = 1, 'Back' = 30, ESC = 30

=cut

sub boolean
{
    my ( $self, $text, $defaultno, $backup ) = @_;

    unless ( $backup ) {
        local $ENV{'DIALOG_CANCEL'} = TRUE;
        local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
        return ( $self->_showDialog( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
    }

    local $ENV{'DIALOG_EXTRA'} = TRUE;
    local @{ $self->{'_opts'} }{qw/ default-button ok-button extra-label extra-button /} = ( $defaultno ? 'extra' : undef, 'Yes', 'No', '' );
    ( $self->_showDialog( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item password( $text [, $default = '' ] )

 See iMSCP::Dialog::Whiptail::password()

=cut

sub password
{
    my ( $self, $text, $default ) = @_;

    local $self->{'_opts'}->{'insecure'} = '';
    $self->_showDialog( 'passwordbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item startGauge( $text [, $percent = 0 ] )

 See iMSCP::Dialog::Whiptail::startGauge()

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    defined $text or die( '$text parameter is undefined' );

    return 0 if $self->hasGauge();

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions( 'gauge' ), '--gauge', $text, $self->{'lines'}, $self->{'columns'},
        $percent // 0 or die( "Couldn't start gauge" );

    $self->{'_gauge'}->autoflush( TRUE );
}

=item setGauge( $percent, $text )

 See iMSCP::Dialog::Whiptail::setGauge()

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

    unless ( defined $self->{'_gauge'} ) {
        $self->startGauge( $text, $percent );
        return;
    }

    print { $self->{'_gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, $text );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Dialog::Whiptail::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();

    # Force usage of graphic lines (UNICODE values) when using putty (See #540)
    $ENV{'NCURSES_NO_UTF8_ACS'} = TRUE;
    # Map exit code to expected iMSCP::Dialog::FrontEndInterface::* retval
    # We need return 30 when user hit escape or cancel (back up capability)
    @ENV{qw/ DIALOG_ESC DIALOG_CANCEL /} = 30;

    # Only relevant options are listed.
    @{ $self->{'_opts'} }{qw/ extra-button extra-label /} = ( undef, undef, );

    $self;
}

=item _findBin( )

 Return string DIALOG(1) binary path, die if DIALOG(1) binary is not found

=cut

sub _findBin
{
    iMSCP::ProgramFinder::find( 'dialog' ) or die( "Couldn't find DIALOG(1) binary" );
}

=item _getCommonOptions( $boxType )

 See iMSCP::Dialog::Whiptail::_getCommonOptions()

=cut

sub _getCommonOptions
{
    my ( $self, $boxType ) = @_;

    my %options = %{ $self->{'_opts'} };

    # Delete unwanted options
    if ( $boxType eq 'yesno' ) {
        delete @options{qw/ ok-button nocancel /};
    } elsif ( $boxType eq 'gauge' ) {
        delete @options{qw/ ok-button nocancel yes-button no-button defaultno /};
    } elsif ( grep ( $boxType eq $_, 'inputbox', 'passwordbox') ) {
        delete @options{qw/ yes-button no-button extra-button extra-label /};
    } elsif ( grep ( $boxType eq $_, 'radiolist', 'checklist') ) {
        delete @options{qw/ yes-button no-button defaultno extra-button extra-label /};
    }

    ( map { defined $options{$_} ? ( '--' . $_, ( $options{$_} eq '' ? () : $options{$_} ) ) : () } keys %options ), (
        $boxType ne 'gauge' ? ( '--colors', '--cr-wrap', '--no-collapse' ) : ()
    );
}

=item _showDialog( $boxType, @boxOptions )

 See iMSCP::Dialog::Whiptail::_showDialog()

=cut

sub _showDialog
{
    my ( $self, $boxType, @boxOptions ) = @_;

    $self->endGauge();

    my $ret = execute( [ $self->{'_bin'}, $self->_getCommonOptions( $boxType ), "--$boxType", @boxOptions ], undef, \my $output );
    # For the input and password boxes, we do not want lose previous value when
    # backing up
    # TODO radiolist, checklist and yesno dialog boxes
    #$output = pop @boxOptions if $ret == 30 && grep ( $boxType eq $_, 'inputbox', 'passwordbox' );
    wantarray ? ( $ret, $output ) : $output;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
