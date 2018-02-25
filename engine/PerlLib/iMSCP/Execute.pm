=head1 NAME

 iMSCP::Execute - Allows to execute external commands

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

package iMSCP::Execute;

use strict;
use warnings;
use Carp qw/ croak /;
use Capture::Tiny qw/ capture capture_stdout capture_stderr /;
use Errno qw/ EINTR /;
use iMSCP::Debug qw/ debug error /;
use IO::Select;
use IPC::Open3;
use Symbol 'gensym';
use parent 'Exporter';

our @EXPORT = qw/ execute executeNoWait escapeShell getExitCode /;

=head1 DESCRIPTION

 This package provides a set of functions allowing to execute external commands.

=head1 FUNCTIONS

=over 4

=item execute( $command [, \$stdout = undef [, \$stderr = undef ] ] )

 Execute the given command

 Param string|array $command Command to execute
 Param string \$stdout OPTIONAL Variable for capture of STDOUT
 Param string \$stderr OPTIONAL Variable for capture of STDERR
 Return int Command exit code, die on failure

=cut

sub execute( $;$$ )
{
    my ($command, $stdout, $stderr) = @_;

    defined( $command ) or croak( 'Missing $command parameter' );

    if ( defined $stdout ) {
        ref $stdout eq 'SCALAR' or croak( "Expects a scalar reference as second parameter for capture of STDOUT" );
        ${$stdout} = '';
    }

    if ( defined $stderr ) {
        ref $stderr eq 'SCALAR' or croak( "Expects a scalar reference as third parameter for capture of STDERR" );
        ${$stderr} = '';
    }

    my $list = ref $command eq 'ARRAY';
    debug( $list ? "@{$command}" : $command );

    if ( defined $stdout && defined $stderr ) {
        ( ${$stdout}, ${$stderr} ) = capture sub { system( $list ? @{$command} : $command ); };
        chomp( ${$stdout}, ${$stderr} );
    } elsif ( defined $stdout ) {
        ${$stdout} = capture_stdout sub { system( $list ? @{$command} : $command ); };
        chomp( ${$stdout} );
    } elsif ( defined $stderr ) {
        ${$stderr} = capture_stderr sub { system( $list ? @{$command} : $command ); };
        chomp( $stderr );
    } else {
        system( $list ? @{$command} : $command ) != -1 or die( sprintf( "Couldn't execute command: %s", $! ));
    }

    getExitCode();
}

=item executeNoWait( $command [, $subStdout = sub { print STDOUT @_ } [, $subStderr = sub { print STDERR @_ } ] ] )

 Execute the given command without wait, processing command STDOUT|STDERR line by line

 Param string|array $command Command to execute
 Param CODE $subStdout OPTIONAL routine for processing of command STDOUT line by line
 Param CODE $subStderr OPTIONAL routine for processing of command STDERR line by line
 Return int Command exit code, die on failure

=cut

sub executeNoWait( $;$$ )
{
    my ($command, $subStdout, $subStderr) = @_;

    $subStdout ||= sub { print STDOUT @_ };
    ref $subStdout eq 'CODE' or croak( 'Expects CODE as second parameter for STDOUT processing' );

    $subStderr ||= sub { print STDERR @_ };
    ref $subStderr eq 'CODE' or croak( 'Expects CODE as third parameter for STDERR processing' );

    my $list = ref $command eq 'ARRAY';
    debug( $list ? "@{$command}" : $command );

    my $pid = open3( my $stdin, my $stdout, my $stderr = gensym, $list ? @{$command} : $command );
    $stdin->close();

    my %buffers = ( $stdout => '', $stderr => '' );
    my $sel = IO::Select->new( $stdout, $stderr );

    while ( my @ready = $sel->can_read ) {
        for my $fh ( @ready ) {
            # Read 1 byte at a time to avoid ending with multiple lines
            my $ret = sysread( $fh, my $nextbyte, 1 );
            next if $!{'EINTR'}; # Ignore signal interrupt
            defined $ret or croak( $! ); # Something is going wrong; Best is to abort early

            if ( $ret == 0 ) {
                # EOL
                $sel->remove( $fh );
                close( $fh );
                next;
            }

            $buffers{$fh} .= $nextbyte;
            next unless $buffers{$fh} =~ /\n\z/;
            $fh == $stdout ? $subStdout->( $buffers{$fh} ) : $subStderr->( $buffers{$fh} );
            $buffers{$fh} = ''; # Reset buffer for next line
        }
    }

    $stdout->close();
    $stderr->close();

    waitpid( $pid, 0 );
    getExitCode();
}

=item escapeShell( $string )

 Escape the given string

 Param string $string String to escape
 Return string Escaped string

=cut

sub escapeShell( $ )
{
    my $string = shift;

    return $string if !length $string || $string =~ /^[a-zA-Z0-9_\-]+\z/;
    $string =~ s/'/'\\''/g;
    "'$string'";
}

=item getExitCode( [ $ret = $? ] )

 Return human exit code

 Param int $ret Raw exit code
 Return int exit code

=cut

sub getExitCode( ;$ )
{
    my ($ret) = @_;
    $ret //= $?;

    if ( $ret == -1 ) {
        debug( "Couldn't execute command" );
        return 1;
    }

    if ( $ret & 127 ) {
        debug( sprintf( 'Command died with signal %d, %s coredump', ( $ret & 127 ), ( $? & 128 ) ? 'with' : 'without' ));
        return $ret;
    }

    $ret >> 8;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
