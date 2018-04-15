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
use File::Spec;
use iMSCP::Log;
use iMSCP::Boolean;
use iMSCP::Getopt;
use Fcntl;
use POSIX qw/ isatty /;
use parent 'Exporter';

our @EXPORT_OK = qw/ debug warning error newDebug endDebug getMessage getLastError getMessageByType debugRegisterCallBack output /;

BEGIN {
    $SIG{'__DIE__'} = sub {
        return unless defined $^S && $^S == 0;
        error( shift =~ s/\n$//r );
        exit 1;
    };
    $SIG{'__WARN__'} = sub {
        warning( shift =~ s/\n$//r );
        exit 1 if exists $ENV{'iMSCP_DEVELOP'};
    };
}

my $self;
$self = {
    loggers => [ iMSCP::Log->new( id => 'default' ) ],
    logger  => sub { $self->{'loggers'}->[$#{ $self->{'loggers'} }] }
};

=head1 DESCRIPTION

 Debug library.

=head1 FUNCTIONS

=over 4

=item newDebug( $logFileId )

 Create a new logger for the given log file identifier.
 New logger will become the current logger

 Param string logFileId Log file unique identifier (log file name)
 Return void

=cut

sub newDebug( $ )
{
    my ( $logFileId ) = @_;

    defined $logFileId or die( 'A log file unique identifier is expected' );
    !grep ( $_->getId() eq $logFileId, @{ $self->{'loggers'} } ) or die( 'A logger with same identifier already exists' );
    push @{ $self->{'loggers'} }, iMSCP::Log->new( id => $logFileId );
}

=item endDebug( )

 Write all log messages from the current logger and remove it from loggers
 stack (unless it is the default logger)

 Return void

=cut

sub endDebug
{
    my $logger = $self->{'logger'}();

    return if $logger->getId() eq 'default';

    pop @{ $self->{'loggers'} }; # Remove logger from loggers stack

    # warn, error and fatal log messages must be always stored in default
    # logger for later processing
    for my $log ( $logger->retrieve( tag => qr/(?:warn|error|fatal)/ ) ) {
        $self->{'loggers'}->[0]->store( %{ $log } );
    }

    # FIXME Should not be done there
    my $logDir = $::imscpConfig{'LOG_DIR'} || '/tmp';
    if ( $logDir ne '/tmp' && !-d $logDir ) {
        require iMSCP::Dir;
        local $@;
        eval {
            iMSCP::Dir->new( dirname => $logDir )->make( {
                user  => $::imscpConfig{'ROOT_USER'},
                group => $::imscpConfig{'ROOT_GROUP'},
                mode  => 0750
            } );
        };
        $logDir = '/tmp' if $@;
    }

    _writeLogfile( $logger, File::Spec->catfile( $logDir, $logger->getId()));
}

=item debug( $message [, $caller = TRUE ] )

 Log a debug message in the current logger

 Param string $message Debug message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub debug( $;$ )
{
    my ( $message, $caller ) = @_;

    $caller = !defined $caller || $caller ? getCaller() : '';
    $self->{'logger'}()->store( message => $caller . $message, tag => 'debug' ) if iMSCP::Getopt->debug;
    print STDOUT output( $caller . $message, 'debug' ) if iMSCP::Getopt->verbose;
}

=item warning( $message [, $caller = TRUE ] )

 Log a warning message in the current logger

 Param string $message Warning message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub warning( $;$ )
{
    my ( $message, $caller ) = @_;

    $caller = !defined $caller || $caller ? getCaller() : '';
    $self->{'logger'}()->store( message => $caller . $message, tag => 'warn' );
}

=item error( $message [, $caller = TRUE ] )

 Log an error message in the current logger

 Param string $message Error message
 Param bool $caller OPTIONAL Flag indicating whether or not $message must be prefixed with caller
 Return void

=cut

sub error( $;$ )
{
    my ( $message, $caller ) = @_;

    $caller = !defined $caller || $caller ? getCaller() : '';
    $self->{'logger'}()->store( message => $caller . $message, tag => 'error' );
}

=item getLastError()

 Get last error messages from the current logger as a string

 Return string Last error messages

=cut

sub getLastError
{
    scalar getMessageByType( 'error' );
}

=item getMessageByType( [ $type [, \%options = { amount => ALL, chrono => FALSE, message => qw/.*/ remove => FALSE } ] )

 Get message by type from current logger, according given options

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

    my @messages = map { $_->{'message'} } $self->{'logger'}()->retrieve(
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

sub output( $;$ )
{
    my ( $text, $level ) = @_;

    if ( !iMSCP::Getopt->noansi && defined $level ) {
        return "[\x1b[0;34mDEBUG\x1b[0m] $text\n" if $level eq 'debug';
        return "[\x1b[0;34mINFO\x1b[0m]  $text\n" if $level eq 'info';
        return "[\x1b[0;33mWARN\x1b[0m]  $text\n" if $level eq 'warn';
        return "[\x1b[0;31mERROR\x1b[0m] $text\n" if $level eq 'error';
        return "[\x1b[0;31mFATAL\x1b[0m] $text\n" if $level eq 'fatal';
        return "[\x1b[0;32mDONE\x1b[0m]  $text\n" if $level eq 'ok';
    } elsif ( defined $level ) {
        return "[DEBUG] $text\n" if $level eq 'debug';
        return "[INFO]  $text\n" if $level eq 'info';
        return "[WARN]  $text\n" if $level eq 'warn';
        return "[ERROR] $text\n" if $level eq 'error';
        return "[FATAL] $text\n" if $level eq 'fatal';
        return "[DONE]  $text\n" if $level eq 'ok';
    }

    "$text\n";
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _writeLogfile($logger, $logfilePath)

 Write all log messages from the given logger into the given file in chronological order

 Param iMSCP::Log $logger Logger
 Param string $logfilePath Logfile path in which log messages must be writen
 Return void

=cut

sub _writeLogfile
{
    my ( $logger, $logfilePath ) = @_;

    local $SIG{'__WARN__'} = sub { die @_; };

    my $bf = '';
    $bf .= "[$_->{'when'}] [$_->{'tag'}] $_->{'message'}\n" for $logger->flush();
    sysopen( my $fh, $logfilePath, O_WRONLY | O_CREAT | O_TRUNC | O_BINARY ) or die(
        sprintf( "Failed to open '%s' logfile for writing: %s", $logfilePath, $! )
    );
    print $fh $bf =~ s/\x1b\[[0-9;]*[mGKH]//gr;
    close $fh;
}

=item getCaller()

 Return first subroutine caller or main, excluding eval and __ANON__

 Return string

=cut

sub getCaller
{
    my $caller;
    my $stackIDX = 2;
    do {
        $caller = ( ( caller $stackIDX++ )[3] || 'main' );
    } while $caller eq '(eval)' || index( $caller, '__ANON__' ) != -1;
    $caller . ': ';
}

=item _getMessages( $logger )

 Flush and return all log messages from the given logger as a string, joined in chronological order

 Param Param iMSCP::Log $logger Logger
 Return string Concatenation of all messages found in the given log object

=cut

sub _getMessages
{
    my ( $logger ) = @_;

    my $bf = '';
    $bf .= "[$_->{'when'}] [$_->{'tag'}] $_->{'message'}\n" for $logger->flush();
    $bf;
}

=item END

 Process ending tasks and print warn, error and fatal log messages to STDERR if any

=cut

END {
    eval {
        endDebug for @{ $self->{'loggers'} };

        if ( isatty( \*STDERR ) ) {
            print STDERR output( $_->{'message'}, $_->{'tag'} ) for $self->{'logger'}()->retrieve( tag => qr/(?:warn|error)/ );
            return;
        }

        require iMSCP::Mail;
        iMSCP::Mail->new()
            ->warnMsg( scalar getMessageByType( 'warn' ))
            ->errmsg( scalar getMessageByType( 'error' ));
    };

    print STDERR output( $@, 'fatal' ) if $@;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
