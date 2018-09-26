=head1 NAME

 iMSCP::Dialog::Dialog - Wrapper to DIALOG(1)

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

BEGIN {
    local $@;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

=head1 DESCRIPTION

 Wrapper to DIALOG(1)

=head1 PUBLIC METHODS

=over 4

=item yesno( $text [, $defaultno =  FALSE [, $backbutton = FALSE ] ] )

 See iMSCP::Dialog::DialogAbstract::yesno()

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

=item passwordbox( $text [, $default = '' ] )

 See iMSCP::Dialog::DialogAbstract::passwordbox()

=cut

sub passwordbox
{
    my ( $self, $text, $default ) = @_;

    local $self->{'_opts'}->{'insecure'} = '';
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

    open $self->{'_gauge'}, '|-', $self->{'_bin'}, $self->_getCommonOptions(), '--gauge', $text, $self->{'lines'}, $self->{'columns'},
        $percent // 0 or die( "Couldn't start gauge" );
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

    print { $self->{'_gauge'} } sprintf( "XXX\n%d\n%s\nXXX\n", $percent, $text );
}

=item resetLabels( )

 See iMSCP::Dialog::DialogAbstract::resetLabels()

=cut

sub resetLabels
{
    my ( $self ) = @_;

    $self->SUPER::resetLables();
    $self->{'_opts'}->{'extra-label'} = undef;
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

    $self->SUPER::_init();

    # Return specific exit status when ESC is pressed
    $ENV{'DIALOG_ESC'} = 50;
    # We want get 30 as exit code when CANCEL button is pressed
    $ENV{'DIALOG_CANCEL'} = 30;

    # Only relevant options are listed.
    @{ $self->{'_opts'} }{qw/ extra-button extra-label /} = ( undef, undef, );
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

    my $ret = execute( [ $self->{'_bin'}, $self->_getCommonOptions(), "--$boxType", @boxOptions ], undef, \my $output );
    # For the input and password boxes, we do not want lose previous value when
    # backing up
    # TODO radiolist, checklist and yesno dialog boxes
    $output = pop @boxOptions if $ret == 30 && grep ( $boxType eq $_, 'inputbox', 'passwordbox' );
    wantarray ? ( $ret, $output ) : $output;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
