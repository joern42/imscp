=head1 NAME

 iMSCP::Faker - Fake Perl modules to fulfill Perl dependencies

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

package iMSCP::Faker;

use strict;
use warnings;

=head1 DESCRIPTION

 Fake Perl modules to fulfill the installer Perl dependencies at an early stage
 of i-MSCP installation.
 
 This module is required in libraries requiring modules that can be unavailable
 on a fresh i-MSCP installation, that is, when the installer prerequisites
 (Distribution package, Perl packages...) were not installed yet. It has to be
 required in a BEGIN block, for instance:

 BEGIN {
    local $@;
    eval { require iMSCP::Debug } or require iMSCP::Faker;
 }
 
 You must keep in mind that only some parts of Perl modules are faked on, that
 is, only those known to be used at an early stage of i-MSCP installation. Once
 that the installer prerequisites were installed, the installer will relaunch
 itself to load the real modules.

 The following Perl modules are faked:
  - iMSCP::Debug
  - File::Copy

=cut

eval { require iMSCP::Debug } or do {
    package iMSCP::Debug;

    use iMSCP::Boolean;
    use iMSCP::Getopt;
    use POSIX ();

    # Whether \*STDERR fd refers to a termlinal
    use constant ISATTY => POSIX::isatty \*STDERR;

    $SIG{'__DIE__'} = sub {
        die @_ if $^S or not defined $^S;
        error( $_[0] =~ s/\n$//r );
        exit 1;
    };
    $SIG{'__WARN__'} = sub {
        die @_ if exists $ENV{'IMSCP_DEVELOP'};
        warning( $_[0] =~ s/\n$//r );
    };

    my @stack = ();

    sub newDebug( $ )
    {
    }

    sub endDebug( )
    {
    }

    sub debug( $;$ )
    {
        my ( $message, $caller ) = @_;
        $caller //= TRUE;
        $caller = $caller ? _getCaller() : '';

        # In fake context, we do not store debug message as those are not logged to a file
        #push @stack, { when => scalar localtime, message => $caller . $message, tag => 'debug' };
        print STDOUT output( $caller . $message, 'debug' ) if iMSCP::Getopt->verbose;
    }

    sub warning( $;$ )
    {
        my ( $message, $caller ) = @_;
        $caller //= TRUE;
        push @stack, { when => scalar localtime, message => ( $caller ? _getCaller() : '' ) . $message, tag => 'warn' };
    }

    sub error( $;$ )
    {
        my ( $message, $caller ) = @_;
        $caller //= TRUE;
        push @stack, { when => scalar localtime, message => ( $caller ? _getCaller() : '' ) . $message, tag => 'error' };
    }

    sub getLastError( )
    {
        scalar getMessageByType( 'error' );
    }

    sub getMessageByType( $;$ )
    {
        my ( $type, $options ) = @_;
        $options = {
            tag     => ref $type eq 'Regexp' ? $type : qr/$type/i,
            amount  => $options->{'amount'} // scalar @stack,
            chrono  => $options->{'chrono'},
            message => $options->{'message'},
            remove  => $options->{'remove'} // FALSE
        };

        # Prevent removal of items which are not effectively returned to
        # caller ( amount > 1 but scalar context)
        $options->{'amount'} = 1 unless wantarray;
        
        my @messages = ();
        for my $log ( $options->{'chrono'} ? @stack : reverse @stack ) {
            next unless $log->{'tag'} =~ /$options->{'tag'}/ && ( !defined $options->{'message'} || $log->{'message'} =~ /$options->{'message'}/ );
            push @messages, $log;
            undef $log if $options->{'remove'};
            $options->{'amount'}--;
            last unless $options->{'amount'} > 0;
        }

        @stack = grep defined, @stack if $options->{'remove'} && @messages;
        wantarray ? map { $_->{'message'} } @messages : join "\n", map { $_->{'message'} } @messages;
    }

    sub output( $;$ )
    {
        my ( $text, $level ) = @_;

        if ( defined $level ) {
            unless ( iMSCP::Getopt->noansi ) {
                return "[\x1b[0;34mDEBUG\x1b[0m] $text\n" if $level eq 'debug';
                return "[\x1b[0;34mINFO\x1b[0m]  $text\n" if $level eq 'info';
                return "[\x1b[0;33mWARN\x1b[0m]  $text\n" if $level eq 'warn';
                return "[\x1b[0;31mERROR\x1b[0m] $text\n" if $level eq 'error';
                return "[\x1b[0;31mFATAL\x1b[0m] $text\n" if $level eq 'fatal';
                return "[\x1b[0;32mDONE\x1b[0m]  $text\n" if $level eq 'ok';
            }

            return "[DEBUG] $text\n" if $level eq 'debug';
            return "[INFO]  $text\n" if $level eq 'info';
            return "[WARN]  $text\n" if $level eq 'warn';
            return "[ERROR] $text\n" if $level eq 'error';
            return "[FATAL] $text\n" if $level eq 'fatal';
            return "[DONE]  $text\n" if $level eq 'ok';
        }

        "$text\n";
    }

    sub _getCaller
    {
        my $caller;
        my $stackIDX = 2;
        do {
            $caller = ( ( caller $stackIDX++ )[3] || 'main' );
        } while $caller eq '(eval)' || index( $caller, '__ANON__' ) != -1;
        $caller . ': ';
    }

    END {
        eval {
            return unless ISATTY;
            print STDERR output( $_, 'warn' ) for getMessageByType( 'warn', { remove => TRUE } );
            print STDERR output( $_, 'error' ) for getMessageByType( 'error', { remove => TRUE } );
        };
    }
};

eval { require File::Copy } or do {
    package File::Copy;

    use strict;
    use warnings;
    use iMSCP::Boolean;
    use iMSCP::Execute;

    sub copy
    {
        my ( $stderr, $stdout );
        return TRUE if iMSCP::Execute::execute( "cp $_[0] $_[1]", \$stdout, \$stderr ) == 0;
        $! = $stderr || 'Unknown error';
        FALSE;
    }

    sub cp
    {
        my ( $stderr, $stdout );
        return TRUE if iMSCP::Execute::execute( "cp -p $_[0] $_[1]", \$stdout, \$stderr ) == 0;
        $! = $stderr || 'Unknown error';
        FALSE;
    }

    sub move
    {
        my ( $stderr, $stdout );
        return TRUE if iMSCP::Execute::execute( "mv $_[0] $_[1]", \$stdout, \$stderr ) == 0;
        $! = $stderr || 'Unknown error';
        FALSE;
    }
};

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
