=head1 NAME

 iMSCP::Getopt - Provides command line options parser for i-MSCP scripts

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

package iMSCP::Getopt;

use strict;
use warnings;
use File::Basename;
use Text::Wrap qw/ wrap /;

$Text::Wrap::columns = 80;
$Text::Wrap::break = qr/[\s\n\|]/;

my $options = {};
my $OPTION_HELP = '';
my $SHOW_USAGE;

=head1 DESCRIPTION

 This class provide command line options parser for i-MSCP.

=head1 CLASS METHODS

=over 4

=item parse( $usage, @options )

 Parses command line options in @ARGV with GetOptions from Getopt::Long

 The first parameter should be basic usage text for the program. Usage text for
 the globally supported options will be prepended to this if usage help must be
 printed.

 If any additonal parameters are passed to this function, they are also passed
 to GetOptions. This can be used to handle additional options.

 Param string $usage Usage text
 Param list @options OPTIONAL Additional options
 Return void

=cut

sub parse
{
    my ($class, $usage, @options) = @_;

    $SHOW_USAGE = sub {
        if ( length $OPTION_HELP ) {
            print STDERR wrap( '', '', <<"EOF" );
$OPTION_HELP
EOF

        } else {
            print STDERR wrap( '', '', <<"EOF" );

$usage
 -a,    --skip-package-update     Skip i-MSCP composer packages update.
 -c,    --clean-package-cache     Clear i-MSCP composer package cache.
 -d,    --debug                   Enable debug mode.
 -h,-?  --help                    Show this help.
 -n,    --noprompt                Run in non-interactive mode.
 -p,    --preseed <file>          Path to preseed file.
 -r,    --reconfigure [item,...]  Type `help` for list of allowed items.
 -v,    --verbose                 Enable verbose mode.
 -x,    --fix-permissions         Ask installer to fix permissions recursively.
 -z     --no-ansi                 Disable ANSI output
EOF
        }
    };

    # Do not load Getopt::Long if not needed
    return unless grep { $_ =~ /^-/ } @ARGV;

    local $SIG{'__WARN__'} = sub {
        my $error = shift;
        $error =~ s/(.*?) at.*/$1/;
        print STDERR wrap( '', '', $error ) if $error ne "Died\n";
    };

    require Getopt::Long;
    Getopt::Long::Configure( 'bundling' );
    Getopt::Long::GetOptions(
        'clean-package-cache|c', \&iMSCP::Getopt::clearPackageCache,
        'debug|d', \&iMSCP::Getopt::debug,
        'help|?|h', \&iMSCP::Getopt::showUsage,
        'fix-permissions|x', \&iMSCP::Getopt::fixPermissions,
        'noprompt|n', \&iMSCP::Getopt::noprompt,
        'preseed|p=s', \&iMSCP::Getopt::preseed,
        'reconfigure|r:s', \&iMSCP::Getopt::reconfigure,
        'skip-package-update|a', \&iMSCP::Getopt::skipPackageUpdate,
        'verbose|v', \&iMSCP::Getopt::verbose,
        'no-ansi|z', \&iMSCP::Getopt::noansi,
        @options,
    ) or $class->showUsage();
}

=item parseNoDefault( $usage, @options )

 Parses command line options in @ARGV with GetOptions from Getopt::Long.
 Default options are excluded

 The first parameter should be basic usage text for the program. Any following
 parameters are passed to to GetOptions.

 Param string $usage Usage text
 Param list @options Options
 Return void

=cut

sub parseNoDefault
{
    my ($class, $usage, @options) = @_;

    $SHOW_USAGE = sub {
        print STDERR wrap( '', '', <<"EOF" );

$usage
 -?,-h  --help          Show this help.

EOF
    };

    # Do not load Getopt::Long if not needed
    return unless grep { $_ =~ /^-/ } @ARGV;

    local $SIG{'__WARN__'} = sub {
        my $error = shift;
        $error =~ s/(.*?) at.*/$1/;
        print STDERR wrap( '', '', $error ) if $error ne "Died\n";
    };

    require Getopt::Long;
    Getopt::Long::Configure( 'bundling' );
    Getopt::Long::GetOptions( 'help|?|h', sub { $class->showUsage() }, @options ) or $class->showUsage();
}

=item showUsage( $exitCode )

 Show usage

 Param int $exitCode OPTIONAL Exit code
 Return void, die on failure

=cut

sub showUsage
{
    ref $SHOW_USAGE eq 'CODE' or die( 'showUsage( ) is not defined.' );
    $SHOW_USAGE->();
    exit 1;
}

my %RECONFIGURATION_ITEMS = (
    admin             => 'Master administrator',
    admin_credentials => 'Credential for the master administrator',
    admin_email       => 'Master administrator email',
    alt_urls          => 'Alternative URL feature',
    antirootkits      => 'Anti-rootkits',
    backup            => 'Backup feature',
    cron              => 'Cron server',
    daemon            => 'Daemon type for processing of backend requests',
    filemanagers      => 'File managers',
    ftpd              => 'FTP server',
    hostnames         => 'Server and control panel hostnames',
    httpd             => 'Httpd server',
    ipv6              => 'IPv6 support',
    mta               => 'SMTP server',
    named             => 'DNS server',
    panel             => 'Control panel',
    panel_hostname    => 'Hostname for the control panel',
    panel_ports       => 'Http(s) ports for the control panel',
    panel_ssl         => 'SSL for the control panel',
    php               => 'PHP server',
    po                => 'IMAP/POP servers',
    primary_ip        => 'Server primary IP address',
    servers           => 'All servers',
    servers_ssl       => 'SSL for the IMAP/POP, SMTP and FTP servers',
    sqld              => 'SQL server',
    sqlmanager        => 'SQL manager',
    ssl               => 'SSL for the servers and control panel',
    system_hostname   => 'System hostname',
    system_server     => 'System server',
    timezone          => 'System timezone',
    webmails          => 'Webmails packages',
    webstats          => 'Webstats packages'
);

=item reconfigure( [ $items = 'none' ] )

 Reconfiguration items

 Param string $items OPTIONAL List of comma separated items to reconfigure
 Return string Name of item to reconfigure or none

=cut

sub reconfigure
{
    my (undef, $items) = @_;

    return $options->{'reconfigure'} ||= [ 'none' ] unless defined $items;

    my @items = split /,/, $items;

    if ( grep( 'help' eq $_, @items ) ) {
        $OPTION_HELP = <<"EOF";
Reconfiguration option usage:

Without any argument, this option make it possible to reconfigure all items. You can reconfigure many items at once by providing a list of comma separated items as follows

 perl @{[ basename( $0 ) ]} --reconfigure httpd,php,po

Bear in mind that even when only one item is reconfigured, all i-MSCP configuration files are regenerated, even those that don't belong to the item being reconfigured.

Each item belong to one i-MSCP package/server.

The following items are available:

EOF
        $OPTION_HELP .= " - $_" . ( ' ' x ( 17-length( $_ ) ) ) . " : $RECONFIGURATION_ITEMS{$_}\n" for sort keys %RECONFIGURATION_ITEMS;
        die();
    } elsif ( !@items ) {
        push @items, 'all';
    } else {
        for my $item( @items ) {
            grep($_ eq $item, keys %RECONFIGURATION_ITEMS, 'none', 'forced') or die(
                sprintf( "Error: '%s' is not a valid item for the the --reconfigure option.", $item )
            );
        }
    }

    $options->{'reconfigure'} = [ @items ];
}

=item preseed( [ $file = undef ] )

 Accessor/Mutator for the preseed command line option

 Note that the preseed option can be set only once. For subsequent calls, the
 routine will always act as accessor, returning TRUE value.

 Param string $file OPTIONAL Preseed file path
 Return bool TRUE if in preseed mode, FALSE otherwise

=cut

sub preseed
{
    my (undef, $file) = @_;

    return $options->{'preseed'} if $options->{'preseed'};
    return 0 unless defined $file;

    eval {
        require $file;
        1;
    } or die( sprintf( "Couldn't load preseed file: %s\n", $@ ));

    END {
        return unless $? == 5;
        print STDERR output( 'Missing or bad entry found in your preseed file.', 'fatal' );
    }

    $options->{'preseed'} = 1;
}

=item context( [ $context = 'backend' ])

 Accessor/Mutator for the execution context

 Param string $context Execution context (installer, uninstaller, backend)
 Return string Execution context

=cut

sub context
{
    my (undef, $context) = @_;

    return $options->{'context'} // 'backend' unless defined $context;

    grep($context eq $_, ( 'installer', 'uninstaller', 'backend' )) or die( 'Unknown execution context' );

    if ( grep($context eq $_, 'installer', 'uninstaller') ) {
        # Needed to make sub processes aware of i-MSCP setup context
        $ENV{'IMSCP_INSTALLER'} = 1;
    }

    $options->{'context'} = $context;
}

=back

=head1 AUTOLOAD

 Handles all option fields, by creating accessor methods for them the
 first time they are accessed.

=cut

sub AUTOLOAD
{
    ( my $field = our $AUTOLOAD ) =~ s/.*://;

    no strict 'refs';
    *{$AUTOLOAD} = sub {
        shift;
        return $options->{$field} // 0 unless @_;
        $options->{$field} = shift;
    };
    goto &{$AUTOLOAD};
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
