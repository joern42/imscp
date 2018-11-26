=head1 NAME

 iMSCP::Debug - Debug library

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

package iMSCP::Debug;

use strict;
use warnings;
use Fcntl;
use File::Spec;
use iMSCP::Log;
use iMSCP::Boolean;
use iMSCP::Getopt;
use POSIX ();
use parent 'Exporter';

# Whether \*STDERR fd refers to a terminal
use constant ISATTY => POSIX::isatty \*STDERR;

our @EXPORT = qw/ debug warning error newDebug endDebug getMessage getLastError getMessageByType output /;

BEGIN {
    $SIG{'__DIE__'} = sub {
        die @_ if $^S or not defined $^S;
        error( $_[0] =~ s/\n$//r );
        exit 1;
    };
    $SIG{'__WARN__'} = sub {
        die @_ if exists $ENV{'IMSCP_DEVELOP'};
        warning( $_[0] =~ s/\n$//r );
    };
}

# Log object stack
my @LOGS = ( iMSCP::Log->new( id => 'default' ) );
# Current log object
my $LOG = $LOGS[0];

=head1 DESCRIPTION

 Debug library.

=head1 FUNCTIONS

=over 4

=item newDebug( $logFileId )

 Create a new log object for the given log file identifier.
 New log object will become the current log object

 Param string logFileId Log file unique identifier (log file name)
 Return void

=cut

sub newDebug( $ )
{
    my ( $logFileId ) = @_;

    defined $logFileId or die( 'A log file unique identifier is expected' );
    !grep ( $_->getId() eq $logFileId, @LOGS ) or die( 'A log file with same identifier already exists' );
    push @LOGS, $LOG = iMSCP::Log->new( id => $logFileId );
}

=item endDebug( )

 Write all log messages from the current log object and remove it from log object
 stack (unless it is the default log object)

 Return void

=cut

sub endDebug( )
{
    return if @LOGS == 1;

    # Pop log object and update current log object
    ( my $log, $LOG ) = ( pop @LOGS, $LOGS[$#LOGS] );

    # warn and error messages must be always stored in default log object for
    # later processing (only if running through tty)
    if ( ISATTY ) {
        $LOGS[0]->store( %{ $_ } ) for $log->retrieve( tag => qr/(?:warn|error)/ )
    }

    eval {
        my $logDir = exists $::imscpConfig{'LOG_DIR'} ? $::imscpConfig{'LOG_DIR'} : '/var/log/imscp';
        require iMSCP::Dir;
        iMSCP::Dir->new( dirname => $logDir )->make( {
            user           => $::imscpConfig{'ROOT_USER'},
            group          => $::imscpConfig{'ROOT_GROUP'},
            mode           => 0750,
            fixpermissions => iMSCP::Getopt->fixpermissions
        } );
        _writeLogfile( $log, File::Spec->catfile( $logDir, $log->getId()));
    };
}

=item debug( $message [, $caller = TRUE ] )

 Add a debug message in the current log object if debug mode and/or print it if in verbose mode

 Param string $message Debug message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub debug( $;$ )
{
    my ( $message, $caller ) = @_;
    $caller //= TRUE;

    $caller = $caller ? _getCaller() : '';
    $LOG->store( message => $caller . $message, tag => 'debug' ) if iMSCP::Getopt->debug;
    print STDOUT output( $caller . $message, 'debug' ) if iMSCP::Getopt->verbose;
}

=item warning( $message [, $caller = TRUE ] )

 Add a warning message in the current log object

 Param string $message Warning message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub warning( $;$ )
{
    my ( $message, $caller ) = @_;
    $caller //= TRUE;

    $LOG->store( message => ( $caller ? _getCaller() : '' ) . $message, tag => 'warn' );
}

=item error( $message [, $caller = TRUE ] )

 Add an error message in the current log object

 Param string $message Error message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub error( $;$ )
{
    my ( $message, $caller ) = @_;
    $caller //= TRUE;

    $LOG->store( message => ( $caller ? _getCaller() : '' ) . $message, tag => 'error' );
}

=item getLastError()

 Get last error messages from the current log object as a string

 Return string Last error messages

=cut

sub getLastError( )
{
    scalar getMessageByType( 'error' );
}

=item getMessageByType( [ $type [, \%options = { amount => ALL, chrono => FALSE, message => qw/.*/ remove => FALSE } ] )

 Get message by type from current log object, according given options

 Param string $type Type (debug, warning, error) or a Regexp such as qr/error|warning/ ...
 Param hashref \%options OPTIONAL Option for message retrieval
  - amount: Number of message to retrieve (default all)
  - chrono: If TRUE, retrieve messages in chronological order (default TRUE)
  - message: A Regexp for retrieving messages with specific string
  - remove: If TRUE, delete messages upon retrieval
 Return array|string List of of messages in list context, string of joined messages in scalar context

=cut

sub getMessageByType( $;$ )
{
    my ( $type, $options ) = @_;
    $options ||= {};

    my @messages = map { $_->{'message'} } $LOG->retrieve(
        tag     => ref $type eq 'Regexp' ? $type : qr/$type/i,
        amount  => $options->{'amount'},
        chrono  => $options->{'chrono'},
        message => $options->{'message'},
        remove  => $options->{'remove'} // FALSE
    );

    wantarray ? @messages : join "\n", @messages;
}

=item output( $text [, $level ] )

 Prepare the given text to be show on the console according the given level

 Param string $text Text to format
 Param string $level OPTIONAL Format level
 Return string Formatted message

=cut

my %ANSI_LEVELS = (
    debug => "[\x1b[0;34mDEBUG\x1b[0m] %s",
    info  => "[\x1b[0;34mINFO\x1b[0m]  %s",
    warn  => "[\x1b[0;33mWARN\x1b[0m]  %s",
    error => "[\x1b[0;31mERROR\x1b[0m] %s",
    ok    => "[\x1b[0;32mDONE\x1b[0m]  %s"
);

sub output( $;$ )
{
    my ( $text, $level ) = @_;

    if ( defined $level ) {
        return sprintf( $ANSI_LEVELS{$level}, $text . "\n") unless iMSCP::Getopt->noansi;
        return "[@{ [ uc $level ] }] $text\n";
    }

    "$text\n";
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _writeLogfile( $log, $logfilePath )

 Write all log messages from the given log object into the given file in chronological order

 Param iMSCP::Log $log Log object
 Param string $logfilePath Logfile path in which log messages must be writen
 Return void

=cut

sub _writeLogfile
{
    my ( $log, $logfilePath ) = @_;

    local $SIG{'__WARN__'} = sub { die @_; };

    my $bf = '';
    $bf .= "[$_->{'when'}] [$_->{'tag'}] $_->{'message'}\n" for $log->flush();
    sysopen( my $fh, $logfilePath, O_WRONLY | O_CREAT | O_TRUNC | O_BINARY, 0600 ) or die(
        sprintf( "Failed to open '%s' logfile for writing: %s", $logfilePath, $! )
    );
    # Remove any ANSI and or DIALOG(1) \Z sequences
    print $fh $bf =~ s/(\x1b\[[0-9;]*[mGKH]|\\Z[brun])//gr;
    close $fh;
}

=item _getCaller()

 Return caller (excluding eval and __ANON__)

 Return string

=cut

sub _getCaller
{
    my $caller;
    my $stackIDX = 2;
    do {
        $caller = ( ( caller $stackIDX++ )[3] || 'main' );
    } while $caller eq '(eval)' || index( $caller, '__ANON__' ) != -1;
    $caller . ': ';
}

=item _getMessages( $log )

 Flush and return all log messages from the given log object as a string, joined in chronological order

 Param Param iMSCP::Log $log Log object
 Return string Concatenation of all messages found in the given log object

=cut

sub _getMessages
{
    my ( $log ) = @_;

    my $bf = '';
    $bf .= "[$_->{'when'}] [$_->{'tag'}] $_->{'message'}\n" for $log->flush();
    $bf;
}

=item END

 Process ending tasks and print warn, error and fatal log messages to STDERR if any

=cut

END {
    eval {
        endDebug for @LOGS;

        if ( ISATTY ) {
            print STDERR output( $_->{'message'}, $_->{'tag'} ) for $LOG->retrieve( tag => qr/(?:warn|error)/ );
            return;
        }

        require iMSCP::Mail;
        iMSCP::Mail
            ->new()
            ->errorMsg( scalar getMessageByType( 'error' ))
            ->warnMsg( scalar getMessageByType( 'warn' ));
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
