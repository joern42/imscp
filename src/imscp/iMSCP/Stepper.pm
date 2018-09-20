=head1 NAME

 iMSCP::Stepper - i-MSCP stepper

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by internet Multi Server Control Panel
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

package iMSCP::Stepper;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Dialog;
use iMSCP::Getopt;
use parent 'Exporter';

BEGIN {
    local $@;
    no warnings 'redefine';
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

our @EXPORT = qw/ startDetail endDetail step /;

my @all = ();
my $last = '';

=head1 DESCRIPTION

 i-MSCP stepper

=head1 PUBLIC FUNCTIONS

=over 4

=item startDetail( )

 Start new steps group details

 Return int 0

=cut

sub startDetail
{
    return 0 if iMSCP::Getopt->noprompt;
    iMSCP::Dialog->getInstance()->endGauge();
    push @all, $last;
    0;
}

=item endDetail( )

 End step group details

 Return int 0

=cut

sub endDetail
{
    return 0 if iMSCP::Getopt->noprompt;
    $last = pop @all;
    0;
}

=item step( $callback, $text, $nSteps, $nStep )

 Process a step

 Param callback|undef $callback Callback
 Param string $text Step description
 Param int $nSteps Total number of steps (for a group of steps)
 Param int $nStep Current step number
 Return 0 on success, other on failure

=cut

sub step
{
    my ( $callback, $text, $nSteps, $nStep ) = @_;

    return _callback( $callback, $text ) if iMSCP::Getopt->noprompt;

    use integer;
    $last = sprintf( "\n\\ZbStep %s of %s\\Zn\n\n%s", $nStep, $nSteps, $text );
    my $msg = @all ? join( "\n", @all ) . "\n" . $last : $last;
    my $percent = $nStep * 100 / $nSteps;
    iMSCP::Dialog->getInstance()->setGauge( $percent, $msg );

    my $rs = _callback( $callback, $text );
    return $rs unless $rs && $rs != 50;

    # Make error message free of any ANSI color and end of line codes
    ( my $error = iMSCP::Debug::getMessageByType( 'error', { remove => TRUE } ) || 'Unknown error' ) =~ s/\x1b\[[0-9;]*[mGKH]//g;
    $error =~ s/^[\s\n]+|[\s\n+]+$//g;
    iMSCP::Dialog->getInstance()->msgbox( <<"EOF" );
\\Z1[ERROR]\\Zn

Error while performing step:

$text

Error was:

\\Z1$error\\Zn

For any problem please have a look at https://i-mscp.net
EOF

    exit 1;
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _callback( $callback [, $debugMsg ] )

 Execute the given callback

 Param callback $callback Callback to execute
 Param string debugMsg Optional DEBUG message
 Return int 0 on success, other on failure

=cut

sub _callback
{
    my ( $callback, $debugMsg ) = @_;

    iMSCP::Debug::debug( $debugMsg ) if length $debugMsg;

    return 0 unless defined $callback;

    my $rs = eval { $callback->() };
    if ( $@ ) {
        iMSCP::Debug::error( $@ );
        $rs = 1;
    }

    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
