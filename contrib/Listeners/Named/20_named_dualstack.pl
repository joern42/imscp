# i-MSCP Listener::Bind9::DualStack listener file
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

# Provides dual stack support for bind9.

package Listener::Bind9::DualStack;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::EventManager;
use iMSCP::Net;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use List::MoreUtils 'uniq';

# Configuration variables

# Parameter that allows to add one or many IPs to specific DNS zone file
# Please replace the entries below by your own entries
# Be aware that invalid or unallowed IP addresses are ignored silently
my %perDomainAdditionalIPs = (
    'domain1.tld' => [ 'IP1', 'IP2' ],
    'domain2.tld' => [ 'IP1', 'IP2' ]
);

# Parameter that allows to add one or many IPs to all bind9 db files
# Please replace the entries below by your own entries
# Be aware that invalid or unallowed IP addresses are ignored silently
my @additionalIPs = ( 'IP1', 'IP2' );

# Please don't edit anything below this line

iMSCP::EventManager->getInstance()->register( 'afterNamedAddDmnDb', sub
{
    my ( $tplDbFileContent, $data ) = @_;

    my $net = iMSCP::Net->getInstance();
    my @ipList = uniq(
        map $net->normalizeAddr( $_ ), grep { $net->getAddrType( $_ ) =~ /^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/ } (
            @additionalIPs, ( $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}} && ref $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}} eq 'ARRAY'
            ? @{ $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}} } : () )
        )
    );

    return unless @ipList;

    my @formattedEntries = ();
    for my $ip ( @ipList ) {
        push @formattedEntries, $net->getAddrVersion( $ip ) eq 'ipv6' ? "\@\tIN\tAAAA\t$ip\n" : "\@\tIN\tA\t$ip\n";
    }

    replaceBlocByRef(
        "; dns rr begin.\n",
        "; dns rr ending.\n",
        "; dualstack rr begin.\n" . join( '', @formattedEntries ) . "; dualstack rr ending.\n",
        $tplDbFileContent,
        TRUE
    );
} );

iMSCP::EventManager->getInstance()->register( 'afterNamedAddSub', sub
{
    my ( $fileC, $data ) = @_;

    my $net = iMSCP::Net->getInstance();
    my @ipList = uniq(
        map $net->normalizeAddr( $_ ), grep { $net->getAddrType( $_ ) =~ /^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/ } (
            @additionalIPs, ( $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}}
            && ref $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}} eq 'ARRAY' ? @{ $perDomainAdditionalIPs{$data->{'DOMAIN_NAME'}} } : () )
        )
    );

    return unless @ipList;

    my @formattedEntries = ();
    for my $ip ( @ipList ) {
        push @formattedEntries, $net->getAddrVersion( $ip ) eq 'ipv6' ? "\@\tIN\tAAAA\t$ip\n" : "\@\tIN\tA\t$ip\n";
    }

    replaceBlocByRef(
        "; sub [$data->{'DOMAIN_NAME'}] begin.\n",
        "; sub [$data->{'DOMAIN_NAME'}] ending.\n",
        "; sub [$data->{'DOMAIN_NAME'}] begin.\n"
            . getBlocByRef( "; sub [$data->{'DOMAIN_NAME'}] begin.\n", "; sub [$data->{'DOMAIN_NAME'}] ending.\n", $fileC )
            . "; dualstack rr begin.\n"
            . join( '', @formattedEntries )
            . "; dualstack rr ending.\n"
            . "; sub [$data->{'DOMAIN_NAME'}] ending.\n",
        $fileC
    );
} );

1;
__END__
