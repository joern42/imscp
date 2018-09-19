=head1 NAME

 iMSCP::Execute - Set of functions to execute external commands.

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

package iMSCP::Execute;

use strict;
use warnings;
use Carp 'croak';
use Errno 'EINTR';
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Getopt;
use IO::Handle ();
use IO::Select;
use IPC::Open3;
use Symbol 'gensym';
use parent 'Exporter';

BEGIN {
    local $@;
    # Get iMSCP::Debug::debug or fake it
    eval {
        require iMSCP::Debug;
        1;
    } or *iMSCP::Debug::debug = sub( $;$ )
    {
        my $caller;
        my $stackIDX = 1;
        do {
            $caller = ( ( caller $stackIDX++ )[3] || 'main' );
        } while $caller eq '(eval)' || index( $caller, '__ANON__' ) != -1;
        print STDOUT "[\x1b[0;34mDEBUG\x1b[0m] $caller: $_[0]\n" if iMSCP::Getopt->verbose;
    };
}

our @EXPORT = qw/ capture captureStdout captureStderr execute executeNoWait escapeShell getExitCode /;
our %EXPORT_TAGS = ( capture => [ qw/ capture captureStdout captureStderr / ], exec => [ qw/ execute executeNoWait escapeShell getExitCode / ] );

# module vars and their defaults
our $Debug = TRUE;

=head1 DESCRIPTION

 Set of functions to execute external commands.
 
 This library also provide functions for capture of STDOUT and/or STDERR from
 Perl, XS or external programs.
 
 Because this library is used at an early stage in i-MSCP installation process,
 only Perl builtin and modules which are made available in Perl base must be
 used.

=head1 PUBLIC FUNCTIONS

=over 4

=item capture( &code )

 Capture STDOUT and STDERR from Perl, XS or external programs

 Param CODE &code
 return list Captured STDOUT and STDERR

=cut

sub capture( & )
{
    _capture( TRUE, TRUE, @_ );
}

=item captureStdout( &code )

 Capture STDOUT from Perl, XS or external programs

 Param CODE &code
 return string Captured STDOUT

=cut

sub captureStdout( & )
{
    _capture( TRUE, FALSE, @_ );
}

=item captureStdout( &code )

 Capture STDERR from Perl, XS or external programs

 Param CODE &code
 return string Captured STDERR

=cut

sub captureStderr( & )
{
    _capture( FALSE, TRUE, @_ );
}

=item execute( $command [, \$stdout = STDOUT [, \$stderr = STDERR ] ] )

 Execute the given command

 Param string|arrayref $command Command to execute
 Param string \$stdout OPTIONAL Variable for capture of $command STDOUT
 Param string \$stderr OPTIONAL Variable for capture of $command STDERR
 Return int Command exit code or die on failure

=cut

sub execute( $;$$ )
{
    my ( $command, $stdout, $stderr ) = @_;

    defined $command or croak 'Missing $command parameter';

    if ( $stdout ) {
        ref $stdout eq 'SCALAR' or croak 'Invalid $stdout parameter. SCALAR reference expected.';
        ${ $stdout } = '';
    }

    if ( $stderr ) {
        ref $stderr eq 'SCALAR' or croak 'Invalid $stderr parameter. SCALAR reference expected.';
        ${ $stderr } = '';
    }

    $command = [ $command ] unless ref $command eq 'ARRAY';
    iMSCP::Debug::debug "@{ $command }" if $Debug;

    if ( defined $stdout && defined $stderr ) {
        chomp( ( ${ $stdout }, ${ $stderr } ) = capture { system( @{ $command } ) } );
    } elsif ( defined $stdout ) {
        chomp( ${ $stdout } = captureStdout { system( @{ $command } ); } );
    } elsif ( defined $stderr ) {
        chomp( ${ $stderr } = captureStderr { system( @{ $command } ); } );
    } else {
        system( @{ $command } ) != -1 or croak( sprintf( "Couldn't execute command: %s", $! ));
    }

    getExitCode();
}

=item executeNoWait( $command [, &stdoutSub = { print STDOUT @_ } [, &stderrSub = { print STDERR @_ } ] ] )

 Execute the given command without wait, processing command STDOUT|STDERR line by line 

 Param string|arrayref $command Command to execute
 Param CODE &stdoutSub Subroutine for processing of STDOUT line by line
 Param CODE &stderrSub Subroutine for processing of STDERR line by line
 Return int Command exit code or die on failure

=cut

sub executeNoWait( $;&& )
{
    my ( $command, $stdoutSub, $stderrSub ) = @_;
    $stdoutSub //= sub { print STDOUT @_ };
    $stderrSub //= sub { print STDERR @_ };

    $command = [ $command ] unless ref $command eq 'ARRAY';
    iMSCP::Debug::debug "@{ $command }" if $Debug;

    my $pid = open3 my $stdin, my $stdout, my $stderr = gensym, @{ $command };
    close $stdin;

    my %buffers = ( $stdout => '', $stderr => '' );
    my $sel = IO::Select->new( $stdout, $stderr );

    while ( my @ready = $sel->can_read ) {
        for my $fh ( @ready ) {
            my $readBytes = sysread $fh, $buffers{$fh}, 4096, length $buffers{$fh};
            next if $!{'EINTR'};          # Ignore signal interrupt
            defined $readBytes or die $!; # Something is going wrong; Best is to abort early
            next unless $readBytes == 0;  # EOF
            delete $buffers{$fh};
            $sel->remove( $fh );
            close $fh;
        }

        # If we have any lines in buffers, we process them
        for my $buffer ( keys %buffers ) {
            while ( $buffers{$buffer} =~ s/(.*\n)// ) {
                $buffer eq $stdout ? $stdoutSub->( $1 ) : $stderrSub->( $1 );
            }
        }
    }

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

    return $string if $string eq '' || $string =~ /^[a-zA-Z0-9_\-]+\z/;
    $string =~ s/'/'\\''/g;
    "'$string'";
}

=item getExitCode( [ $ret = $? ] )

 Return human exit code

 Param int $ret Raw exit code
 Return int exit code or die on failure

=cut

sub getExitCode( ;$ )
{
    my ( $ret ) = @_;
    $ret //= $?;

    if ( $ret == -1 ) {
        iMSCP::Debug::debug "Couldn't execute command";
        return 1;
    }

    if ( $ret & 127 ) {
        iMSCP::Debug::debug sprintf( 'Command died with signal %d, %s coredump', ( $ret & 127 ), ( $? & 128 ) ? 'with' : 'without' );
        return $ret;
    }

    $ret >> 8;
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _capture( $stdout, $stderr, &code )

 Capture STDOUT and/or STDERR from Perl, XS or external programs

 This routine assume default (not tied) std(out|err) file handles.

 Param bool $stdout Flag indicating whether or not STDOUT must be captured
 Param bool $captureSTDERR Flag indicating whether or not STDERR must be captured
 Param CODE &code Code to execute and for which STDOUT and/or STDERR must be captured
 Return list, string Depending on context return a list containing both STDOUT and STDERR output or only STDOUT or STDERR output

=cut

sub _capture
{
    my ( $stdout, $stderr, $code ) = @_;

    my %toCapture = ( $stdout ? ( stdout => TRUE ) : (), $stderr ? ( stderr => TRUE ) : () );
    my $stash = {};

    # Save original file handles
    $stash->{'old'} = _saveStdFilehandles();
    # Set default file handles to original file handles
    $stash->{'new'} = { %{ $stash->{'old'} } };
    # Setup required file handles for capture
    $stash->{'new'}->{$_} = $stash->{'capture'}->{$_} = File::Temp->new for keys %toCapture;

    # Setup redirection
    _openStdFilehandles( $stash->{'new'} );

    # Execute code
    $code->();

    # Flush file handles
    STDOUT->flush if $stdout;
    STDERR->flush if $stderr;

    # Restore original filehandles
    _openStdFilehandles( $stash->{'old'} );
    close $_ or die $! for values %{ $stash->{'old'} };

    # Get captured output
    my %output;
    $output{$_} = _slurpFilehandle( $stash->{'capture'}->{$_} ) for keys %toCapture;

    wantarray
        ? ( $output{'stdout'}, $output{'stderr'} )
        : ( $stdout ? $output{'stdout'} : ( $stderr ? $output{'stderr'} : undef ) );
}

=item _saveStdFilehandles( )

 Save current standard (STDOUT, STDERR) file handles

 Return hashref Copied standard filehandles

=cut

sub _saveStdFilehandles
{
    my %fh;
    open $fh{'stdout'} = IO::Handle->new, '>&STDOUT' or die $!;
    open $fh{'stderr'} = IO::Handle->new, '>&STDERR' or die $!;
    \%fh;
}

=item _openStdFilehandles( )

 Open standard (STDOUT, STDERR) file handles

 Return void

=cut

sub _openStdFilehandles
{
    my ( $fh ) = @_;

    open \*STDOUT, '>&' . fileno $fh->{'stdout'} or die $! if defined $fh->{'stdout'};
    open \*STDERR, '>&' . fileno $fh->{'stderr'} or die $! if defined $fh->{'stderr'};
}

=item _slurpFilehandle( $fh )

 Slurp a filehandle

 Param File::TempFile::Temp $fh File handle
 Return string

=cut

sub _slurpFilehandle
{
    my ( $fh ) = @_;

    seek $fh, 0, 0 or die $!;
    local $/;
    readline $fh // '';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
