=head1 NAME

 iMSCP::Whiptail - Wrapper to WHIPTAIL(1)

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
use parent 'iMSCP::Dialog::DialogAbstract';

BEGIN {
    local $@;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Wrapper to WHIPTAIL(1)

=head1 PUBLIC METHODS

=over 4

=item radiolist( $text, \%choices [, $defaultTag = none [, $showTags = FALSE ] ] )

 See iMSCP::Dialog::DialogAbstract::radiolist()

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

 See iMSCP::Dialog::DialogAbstract::checklist()

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

=item yesno( $text [, $defaultno =  FALSE ] )

 See iMSCP::Dialog::DialogAbstract::yesno()

=cut

sub yesno
{
    my ( $self, $text, $defaultno ) = @_;

    local $self->{'_opts'}->{'defaultno'} = $defaultno ? '' : undef;
    ( $self->_execute( 'yesno', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item msgbox( $text )

 See iMSCP::Dialog::DialogAbstract::msgbox()

=cut

sub msgbox
{
    my ( $self, $text ) = @_;

    ( $self->_execute( 'msgbox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item infobox( $text )

 See iMSCP::Dialog::DialogAbstract::infobox()

=cut

sub infobox
{
    my ( $self, $text ) = @_;

    local $self->{'_opts'}->{'clear'} = undef;
    ( $self->_execute( 'infobox', $text, $self->{'lines'}, $self->{'columns'} ) )[0];
}

=item inputbox( $text [, $default = '' ] )

 See iMSCP::Dialog::DialogAbstract::inputbox()

=cut

sub inputbox
{
    my ( $self, $text, $default ) = @_;

    $self->_execute( 'inputbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item passwordbox( $text [, $default = '' ])

 See iMSCP::Dialog::DialogAbstract::passwordbox()

=cut

sub passwordbox
{
    my ( $self, $text, $default ) = @_;

    $self->_execute( 'passwordbox', $text, $self->{'lines'}, $self->{'columns'}, $default // ());
}

=item startGauge( $text [, $percent = 0 ] )

 See iMSCP::Dialog::DialogAbstract::startGauge()

=cut

sub startGauge
{
    my ( $self, $text, $percent ) = @_;

    defined $_[0] or die( '$text parameter is undefined' );

    return 0 if iMSCP::Getopt->noprompt || $self->hasGauge();

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions(), '--gauge', $self->_stripFormats( $text ),
        $self->{'lines'}, $self->{'columns'}, $percent // 0 or die( "Couldn't start gauge" );
    $self->{'_gauge'}->autoflush( TRUE );
}

=item setGauge( $percent, $text )

 See iMSCP::Dialog::DialogAbstract::setGauge()

=cut

sub setGauge
{
    my ( $self, $percent, $text ) = @_;

    unless ( defined $self->{'_gauge'} ) {
        $self->startGauge( $text, $percent );
        return;
    }

    print { $self->{'_gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, $self->_stripFormats( $text ));
}

=item endGauge( )

 See iMSCP::Dialog::DialogAbstract::endGauge()

=cut

sub endGauge
{
    my ( $self ) = @_;

    return unless $self->{'_gauge'};
    
    $self->{'_gauge'}->close();
    undef $self->{'_gauge'};
}

=item hasGauge( )

 See iMSCP::Dialog::DialogAbstract::hasGauge()

=cut

sub hasGauge
{
    my ( $self ) = @_;

    !!$self->{'_gauge'}
}

=item resetLabels( )

 See iMSCP::Dialog::DialogAbstract::resetLabels()

=cut

sub resetLabels
{
    @{ $_[0]->{'_opts'} }{qw/ yes-button no-button ok-button cancel-button /} = ( 'Yes', 'No', 'Ok', 'Cancel' );
}

=item executeDialogs( \@dialogs )

 See iMSCP::Dialog::DialogAbstract::executeDialogs()

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

 See iMSCP::Dialog::DialogAbstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    $self->{'_bin'} = $self->_findBin();
    # Only relevant options are listed there.
    @{ $self->{'_opts'} }{qw/ clear scrolltext defaultno nocancel notags yes-button no-button ok-button cancel-button title backtitle /} = (
        undef, '', undef, undef, undef, 'Yes', 'No', 'Ok', 'Cancel', undef, 'i-MSCP™ - internet Multi Server Control Panel'
    );
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

 Get dialog command common options

 Return List Command common options

=cut

sub _getCommonOptions
{
    my ( $self ) = @_;

    ( map {
        defined $self->{'_opts'}->{$_} ? ( '--' . $_, ( $self->{'_opts'}->{$_} eq '' ? () : $self->{'_opts'}->{$_} ) ) : ()
    } keys %{ $self->{'_opts'} }
    ), '--fb'
}

=item _execute( $boxType, @boxOptions )

 Execute dialog command

 Param string $boxType Box type
 Param list @boxOptions Box options 
 Return string|array Dialog output or array containing both dialog exit code and dilaog output

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

    $boxOptions[0] = $self->_stripFormats( $boxOptions[0] );

    my $ret = execute( [ $self->{'_bin'}, $self->_getCommonOptions(), "--$boxType", '--', @boxOptions ], undef, \my $output );
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
    $SIG{'WINCH'} = 'DEFAULT';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
