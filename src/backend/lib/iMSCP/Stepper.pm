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

 Return void

=cut

sub startDetail
{
    return if iMSCP::Getopt->noninteractive;
    iMSCP::Dialog->getInstance()->endGauge();
    push @all, $last;
}

=item endDetail( )

 End step group details

 Return void

=cut

sub endDetail
{
    return if iMSCP::Getopt->noninteractive;
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
    my ( $callback, $text, $nSteps, $nStep ) = @_;

    eval {
        use integer;
        $last = sprintf( "\\ZbStep %s of %s\\ZB\n\n%s", $nStep, $nSteps, $text );
        my $percent = $nStep * 100 / $nSteps;
        iMSCP::Dialog->getInstance()->setGauge( $percent, @all ? join( "\n", @all ) . "\n" . $last : $last );

        $callback->() if defined $callback;
    };
    return unless defined $callback && $@;

    # Make error message free of any ANSI code, trailing and leading whitespaces
    ( my $error = $@ ) =~ s/(\x1b\[[0-9;]*[mGKH]|^[\s]+|[\s+]+$)//g;
    iMSCP::Debug::error( $error );
    iMSCP::Dialog->getInstance()->error( <<"EOF" );
\\Z1[ERROR]\\Zn

Error while performing step:

$text

Error was:

\\Z1$error\\Zn
EOF

    exit 1;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
