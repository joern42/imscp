=head1 NAME

 iMSCP::Stepper - i-MSCP stepper

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

package iMSCP::Stepper;

use strict;
use warnings;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dialog;
use iMSCP::Getopt;
use Scalar::Defer qw/ lazy /;
use parent 'Exporter';

our @EXPORT = qw/ startDetail endDetail step /;

my @all = ();
my $last = '';
my $dialog = lazy { iMSCP::Dialog->getInstance(); };
my $stepperRoutine = lazy { iMSCP::Getopt->noprompt ? \&_callback : \&_step; };

=head1 DESCRIPTION

 i-MSCP stepper.

=head1 PUBLIC FUNCTIONS

=over 4

=item startDetail( )

 Start new steps group details

 Return void

=cut

sub startDetail
{
    return if iMSCP::Getopt->noprompt;
    $dialog->endGauge();
    push @all, $last;
}

=item endDetail( )

 End step group details

 Return void

=cut

sub endDetail
{
    return if iMSCP::Getopt->noprompt;
    $last = pop @all;
}

=item step( $callback, $text, $nSteps, $nStep )

 Process a step

 Param callback|undef $callback Callback
 Param string $text Step description
 Param int $nSteps Total number of steps (for a group of steps)
 Param int $nStep Current step number
 Return void, die on failure

=cut

sub step
{
    $stepperRoutine->( @_ );
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _callback( $callback [, $debugMsg ] )

 Execute the given callback

 Param callback $callback Callback to execute
 Param string debugMsg Optional DEBUG message
 Return void, die on failure

=cut

sub _callback
{
    my ( $callback, $debugMsg ) = @_;

    debug( $debugMsg ) if length $debugMsg;

    return unless defined $callback;

    $callback->();
}

=item _dialogstep
 
 See step( )
 
=cut

sub _step
{
    my ( $callback, $text, $nSteps, $nStep ) = @_;

    eval {
        unless ( iMSCP::Getopt->noprompt ) {
            use integer;
            $last = sprintf( "\n\\ZbStep %s of %s\\Zn\n\n%s", $nStep, $nSteps, $text );
            my $msg = @all ? join( "\n", @all ) . "\n" . $last : $last;
            my $percent = $nStep * 100 / $nSteps;
            $dialog->hasGauge ? $dialog->setGauge( $percent, $msg ) : $dialog->startGauge( $msg, $percent );
        }

        _callback( $callback, iMSCP::Getopt->noprompt ? $text : undef );
    };
    return unless defined $callback && $@;

    # Make error message free of most ANSI sequences
    ( my $errorMessage = $@ ) =~ s/\x1b\[[0-9;]*[mGKH]//g;
    $errorMessage =~ s/^[\s\n]+|[\s\n+]+$//g;
    $dialog->endGauge();
    $dialog->msgbox( <<"EOF" );
\\Z1[ERROR]\\Zn

Error while performing step:

$text

Error was:

\\Z1$errorMessage\\Zn

Please have a look at https://i-mscp.net/ if you need help.
EOF
    exit 1;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
