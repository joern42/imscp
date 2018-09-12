=head1 NAME

 iMSCP::Getopt - Provide command line options parser for i-MSCP scripts

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
use File::Basename 'basename';
use iMSCP::Boolean;
use Text::Wrap 'wrap';

$Text::Wrap::columns = 80;
$Text::Wrap::break = qr/[\s\n\|]/;

my $OPTIONS = {};
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
    my ( $class, $usage, @options ) = @_;

    chomp($usage);
    $SHOW_USAGE = sub {
        my $exitCode = shift || 0;
        if ( length $OPTION_HELP ) {
            print STDERR wrap( '', '', <<"EOF" );
$OPTION_HELP
EOF
        } else {
            print STDERR wrap( '', '', <<"EOF" );

$usage
 -d,    --debug                  Enable debug mode.
 -h,-?  --help                   Show this help.
EOF
        }
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
        'debug|d'  => sub { $OPTIONS->{'debug'} = TRUE },
        'help|?|h' => sub { $class->showUsage() },
        @options,
    ) or $class->showUsage( TRUE );

    return;
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
    ref $SHOW_USAGE eq 'CODE' or die( 'ShowUsage( ) is not defined.' );
    $SHOW_USAGE->( $exitCode );
}

my %reconfigurationItems = (
    all                     => 'All items',
    alternatives            => 'All alternatives',
    antirootkits            => 'Antirootkits packages',
    antispam                => 'Spam filtering system',
    antivirus               => 'Antivirus solution',
    backup                  => 'Backup feature',

    client_backup           => 'Client data backup',

    filemanager             => 'File manager',
    ftpd                    => 'FTP server',
    hostnames               => 'System and control panel hostnames',
    httpd                   => 'Httpd server',
    mta                     => 'SMTP server',

    named                   => 'DNS servers',
    named_ips_policy        => 'Policy for DNS IP addresse',
    named_ipv6              => 'IPv6 support for name server',
    named_master            => 'Master name',
    named_resolver          => 'Local DNS resolver',
    named_slave             => 'Slave name server(s)',
    named_type              => 'DNS server type',

    cp                      => 'Control panel',
    cp_backup               => 'Control panel database and configuration backup',
    cp_admin                => 'Master administrator',
    cp_admin_credentials    => 'Master administrator credential',
    cp_admin_email          => 'Master administrator email',
    cp_hostname             => 'Hostname for the control panel',
    cp_php                  => 'PHP version for the control panel',
    cp_ports                => 'Http(s) ports for the control panel',
    cp_ssl                  => 'SSL for the control panel',

    php                     => 'PHP version for customers',
    po                      => 'IMAP/POP servers',
    postfix_srs             => 'Postfix SRS',

    system                  => 'System',
    system_ipv6             => 'System IPv6 support',
    system_hostname         => 'System hostname',
    system_primary_ip       => 'System primary IP address',
    system_timezone         => 'System timezone',

    services_ssl            => 'SSL for the IMAP/POP, SMTP and FTP services',
    sqld                    => 'SQL server',
    sqlmanager              => 'SQL manager packages',
    ssl                     => 'SSL for the servers and control panel',
    webmails                => 'Webmails packages',
    website_alt_urls        => 'Website alternative URLs',
    webstats                => 'Webstats packages'
);

=item reconfigure( [ $items = 'none', [ $viaCmdLine = FALSE, [ $append = FALSE ] ] ] )

 Reconfiguration item

 Param string $items OPTIONAL List of comma separated items to reconfigure
 Param boolean $viaCmdLineOpt Flag indicating whether or not $items were been
                              passed through command line option rather than
                              programmatically
 Param boolean $append Flag indicating whether $items must be appended
 Return array_ref List of item to reconfigure

=cut

sub reconfigure
{
    my ( undef, $items, $viaCmdLineOpt, $append ) = @_;

    return $OPTIONS->{'reconfigure'} ||= [ 'none' ] unless defined $items;

    my @items = split /,/, $items;

    if ( grep ( 'help' eq $_, @items ) ) {
        $OPTION_HELP = <<"EOF";

Reconfiguration option usage:

Without any argument, this option make it possible to reconfigure all items. You can reconfigure specific items by providing a list of comma separated items as follows:

 perl @{[ basename( $0 ) ]} --reconfigure httpd,php,po

The following items are available:

EOF
        $OPTION_HELP .= " - $_" . ( ' ' x ( 20-length( $_ ) ) ) . " : $reconfigurationItems{$_}\n" for sort keys %reconfigurationItems;
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

    push @items, @{ $OPTIONS->{'reconfigure'} } if $OPTIONS->{'reconfigure'} && $append;
    $OPTIONS->{'reconfigure'} = [ do {
        my %seen;
        grep { !$seen{$_}++ } @items
    } ];
}

=item context( [ $context = 'backend' ])

 Accessor/Mutator for the execution context

 Param string $context Execution context (installer, uninstaller, backend)
 Return string Execution context

=cut

# Backward compatibility with 3rd-party
$::execmode = 'backend' unless defined $::execmode;

sub context
{
    my ( undef, $context ) = @_;

    return $OPTIONS->{'context'} // 'backend' unless defined $context;

    grep ( $context eq $_, 'installer', 'uninstaller', 'backend' ) or die( 'Unknown execution context' );

    if ( grep ( $context eq $_, 'installer', 'uninstaller' ) ) {
        # Needed to make sub processes aware of i-MSCP setup context
        $ENV{'IMSCP_INSTALLER'} = TRUE;
    }

    # Backward compatibility with 3rd-party
    $::execmode = $context;
    $OPTIONS->{'context'} = $context;
}

=back

=head1 AUTOLOAD

 Handles all option fields, by creating accessor methods for them the
 first time they are accessed.

=cut

sub AUTOLOAD
{
    ( my $field = $iMSCP::Getopt::AUTOLOAD ) =~ s/.*://;

    no strict 'refs';
    *{ $iMSCP::Getopt::AUTOLOAD } = sub {
        shift;
        return $OPTIONS->{$field} unless @_;
        $OPTIONS->{$field} = shift;
    };
    goto &{ $iMSCP::Getopt::AUTOLOAD };
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
