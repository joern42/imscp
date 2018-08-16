=head1 NAME

 iMSCP::Getopt - Provides command line options parser for i-MSCP scripts

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

package iMSCP::Getopt;

use strict;
use warnings;
use File::Basename qw/ basename /;
use Cwd qw/ realpath /;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debugRegisterCallBack /;
use Text::Wrap;
use fields qw/ cleanPackageCache debug fixPermissions listener noprompt preseed reconfigure skipPackageUpdate verbose /;

$Text::Wrap::columns = 80;
$Text::Wrap::break = qr/[\s\n\|]/;

my $options = fields::new( 'iMSCP::Getopt' );
my $optionHelp = '';
my $showUsage;

=head1 DESCRIPTION

 This class provide command line options parser for i-MSCP.

=head1 CLASS METHODS

=over 4

=item parse( $usage, @options )

 Parses command line options in @ARGV with GetOptions from Getopt::Long

 The first parameter should be basic usage text for the program. Usage text for the globally supported options will be
 prepended to this if usage help must be printed.

 If any additonal parameters are passed to this function, they are also passed to GetOptions. This can be used to handle
 additional options.

 Param string $usage Usage text
 Param list @options OPTIONAL Additional options
 Return undef

=cut

sub parse
{
    my ( $class, $usage, @options ) = @_;

    $showUsage = sub {
        my $exitCode = shift || 0;
        print STDERR wrap( '', '', <<"EOF" );

$usage
 -a,    --skip-package-update    Skip i-MSCP packages update.
 -c,    --clean-package-cache    Cleanup i-MSCP package cache.
 -d,    --debug                  Force debug mode.
 -h,-?  --help                   Show this help.
 -l,    --listener <file>        Path to listener file.
 -n,    --noprompt               Switch to non-interactive mode.
 -p,    --preseed <file>         Path to preseed file.
 -r,    --reconfigure [item,...] Type `help` for list of available items.
 -v,    --verbose                Enable verbose mode.
 -x,    --fix-permissions        Fix permissions recursively.

$optionHelp
EOF
        debugRegisterCallBack( sub { exit $exitCode; } );
        exit $exitCode;
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
        'clean-package-cache|c', sub { $options->{'cleanPackageCache'} = 1 },
        'debug|d', sub { $options->{'debug'} = 1 },
        'help|?|h', sub { $class->showUsage() },
        'fix-permissions|x', sub { $options->{'fixPermissions'} = 1 },
        'listener|l=s', sub { $class->listener( $_[1] ) },
        'noprompt|n', sub { $options->{'noprompt'} = 1 },
        'preseed|p=s', sub { $class->preseed( $_[1] ) },
        'reconfigure|r:s', sub { $class->reconfigure( $_[1], TRUE ) },
        'skip-package-update|a', sub { $options->{'skipPackageUpdate'} = 1 },
        'verbose|v', sub { $options->{'verbose'} = 1 },
        @options,
    ) or $class->showUsage( 1 );

    undef;
}

=item parseNoDefault( $usage, @options )

 Parses command line options in @ARGV with GetOptions from Getopt::Long. Default options are excluded

 The first parameter should be basic usage text for the program. Any following parameters are passed to to GetOptions.

 Param string $usage Usage text
 Param list @options Options
 Return undef

=cut

sub parseNoDefault
{
    my ( $class, $usage, @options ) = @_;

    $showUsage = sub {
        my $exitCode = shift || 0;
        print STDERR wrap( '', '', <<"EOF" );

$usage
 -?,-h  --help          Show this help.

EOF
        debugRegisterCallBack( sub { exit $exitCode; } );
        exit $exitCode;
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
    Getopt::Long::GetOptions( 'help|?|h', sub { $class->showUsage() }, @options ) or $class->showUsage( 1 );
    undef;
}

=item showUsage( $exitCode )

 Show usage

 Param int $exitCode OPTIONAL Exit code
 Return undef

=cut

sub showUsage
{
    my ( undef, $exitCode ) = @_;

    $exitCode //= 1;
    ref $showUsage eq 'CODE' or die( 'ShowUsage( ) is not defined.' );
    $showUsage->( $exitCode );
}

my %reconfigurationItems = (
    all                  => 'All items',
    alternatives         => 'All alternatives',
    antirootkits         => 'Antirootkits packages',
    antispam             => 'Spam filtering system',
    antivirus            => 'Antivirus solution',
    backup               => 'Backup feature',

    client_alt_url       => 'Client alternative URL feature',
    client_backup        => 'Client data backup',

    filemanager          => 'File manager',
    ftpd                 => 'FTP server',
    hostnames            => 'System and control panel hostnames',
    httpd                => 'Httpd server',
    mta                  => 'SMTP server',

    named                => 'DNS servers',
    named_ips_policy     => 'Policy for DNS IP addresse',
    named_ipv6           => 'IPv6 support for name server',
    named_master         => 'Master name',
    named_resolver       => 'Local DNS resolver',
    named_slave          => 'Slave name server(s)',
    named_type           => 'DNS server type',

    cp                   => 'Control panel',
    cp_backup            => 'Backup for the control panel database and configuration files',
    cp_admin             => 'Master administrator',
    cp_admin_credentials => 'Credential for the master administrator',
    cp_admin_email       => 'Master administrator email',
    cp_hostname          => 'Hostname for the control panel',
    cp_php               => 'PHP version for the control panel',
    cp_ports             => 'Http(s) ports for the control panel',
    cp_ssl               => 'SSL for the control panel',

    php                  => 'PHP version for customers',
    po                   => 'IMAP/POP servers',
    postfix_srs          => 'Postfix SRS',

    system               => 'System',
    system_ipv6          => 'System IPv6 support',
    system_hostname      => 'System hostname',
    system_primary_ip    => 'System primary IP address',
    system_timezone      => 'System timezone',

    services_ssl         => 'SSL for the IMAP/POP, SMTP and FTP services',
    sqld                 => 'SQL server',
    sqlmanager           => 'SQL manager packages',
    ssl                  => 'SSL for the servers and control panel',
    webmails             => 'Webmails packages',
    webstats             => 'Webstats packages'
);

=item reconfigure( [ $items = 'none', [ $viaCmdLine = FALSE, [ $append = FALSE ] ] ] )

 Reconfiguration item

 Param string $items OPTIONAL List of comma separated items to reconfigure
 Param boolean $viaCmdLineOpt Flag indicating whether or not $items were been passed through command line option rather than programmatically
 Param boolean $append Flag indicating whether $items must be appended
 Return array_ref List of item to reconfigure

=cut

sub reconfigure
{
    my ( undef, $items, $viaCmdLineOpt, $append ) = @_;

    return $options->{'reconfigure'} ||= [ 'none' ] unless defined $items;

    my @items = split /,/, $items;

    if ( grep ( 'help' eq $_, @items ) ) {
        $optionHelp = <<"EOF";
Reconfiguration option usage:

Without any argument, this option make it possible to reconfigure all items. You can reconfigure many items at once by providing a list of comma separated items as follows:

 perl @{[ basename( $0 ) ]} --reconfigure httpd,php,po

Bear in mind that even when only one item is reconfigured, all i-MSCP configuration files are regenerated, even those that don't belong to the item being reconfigured.

Each item belong to one i-MSCP package/server.

The following items are available:

EOF
        $optionHelp .= " - $_" . ( ' ' x ( 17-length( $_ ) ) ) . " : $reconfigurationItems{$_}\n" for sort keys %reconfigurationItems;
        die();
    } elsif ( !@items ) {
        push @items, 'all';
    } else {
        for my $item ( @items ) {
            !$viaCmdLineOpt || grep ( $_ eq $item, keys %reconfigurationItems, 'none' ) or die(
                sprintf( "Error: '%s' is not a valid item for the the --reconfigure option.", $item )
            );
        }

        # Both the 'node' and 'forced' items MUST not be set through command
        # line options as those are used internally only.
        die() if $viaCmdLineOpt && grep (/^(?:force|none)$/, @items);
    }

    push @items, @{ $options->{'reconfigure'} } if $options->{'reconfigure'} && $append;
    $options->{'reconfigure'} = [ do {
        my %seen;
        grep { !$seen{$_}++ } @items
    } ];
}

=item preseed( [ $file = undef ] )

 Accessor/Mutator for the preseed command line option

 Param string $file OPTIONAL Preseed file path
 Return string Path to preseed file or empty string

=cut

sub preseed
{
    my ( undef, $file ) = @_;

    return $options->{'preseed'} unless defined $file;

    -f $file or die( sprintf( 'Preseed file not found: %s', $file ));
    $options->{'preseed'} = realpath( $file );
}

=item listener( [ $file = undef ] )

 Accessor/Mutator for the listener command line option

 Param string $file OPTIONAL Listener file path
 Return string Path to listener file or undef

=cut

sub listener
{
    my ( undef, $file ) = @_;

    return $options->{'listener'} unless defined $file;

    -f $file or die( sprintf( 'Listener file not found: %s', $file ));
    $options->{'listener'} = $file;
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
    *{ $AUTOLOAD } = sub {
        shift;
        return $options->{$field} unless @_;
        $options->{$field} = shift;
    };
    goto &{ $AUTOLOAD };
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
