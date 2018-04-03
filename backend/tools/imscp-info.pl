#!/usr/bin/perl

=head1 NAME

 imscp-info.pl - Display information about i-MSCP instance

=head1 SYNOPSIS

 perl imscp-info.pl [OPTION]...

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

use strict;
use warnings;
use autouse 'iMSCP::Debug' => qw/ output /;
use Class::Autouse qw/ :nostat iMSCP::Packages iMSCP::Servers JSON /;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Getopt;

iMSCP::Getopt->parseNoDefault( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq{

Display information about i-MSCP instance.

By default all information are shown. Use the display options below to restrict
list of information. You can cumul the display options.

OPTIONS:
 -v,    --release       Display release info.
 -s,    --servers       Display servers info.
 -p,    --packages      Display packages info.
 -d,    --daemon        Displat daemon info.
 -j,    --json          Display output in JSON format.
 -t,    --pretty        Enable JSON pretty print.
 -n,    --noansi        Disable ainsi output.
 -e,    --noheaders     Disable headers.},
    'release|r'   => \&iMSCP::Getopt::release,
    'servers|s'   => \&iMSCP::Getopt::servers,
    'packages|p'  => \&iMSCP::Getopt::packages,
    'daemon|d'    => \&iMSCP::Getopt::daemon,
    'json|j'      => \&iMSCP::Getopt::json,
    'pretty|t'    => \&iMSCP::Getopt::pretty,
    'noansi|n'    => \&iMSCP::Getopt::noansi,
    'noheaders|e' => \&iMSCP::Getopt::noheaders
);

my $nodisplayopts = !iMSCP::Getopt->release && !iMSCP::Getopt->servers && !iMSCP::Getopt->packages && !iMSCP::Getopt->daemon;

iMSCP::Bootstrapper->getInstance()->boot( {
    config_readonly => TRUE,
    nodatabase      => TRUE,
    nokeys          => TRUE,
    nolock          => TRUE
} );

iMSCP::Getopt->debug( FALSE );
iMSCP::Getopt->context( 'installer' );

my $json = {} if iMSCP::Getopt->json;

if ( $nodisplayopts || iMSCP::Getopt->release ) {
    if ( iMSCP::Getopt->json ) {
        $json->{'build_date'} = $::imscpConfig{'BuildDate'} || 'Unreleased';
        $json->{'version'} = $::imscpConfig{'Version'};
        $json->{'codename'} = $::imscpConfig{'CodeName'};
        $json->{'plugin_api'} = $::imscpConfig{'PluginApi'};
    } else {
        print <<'EOF' unless iMSCP::Getopt->noheaders;

###############################################################################
###                              Release Info                               ###
###############################################################################

EOF
        print output "Build date            : @{ [ $::imscpConfig{'BuildDate'} || 'Unreleased' ] }", 'info';
        print output "Version               : $::imscpConfig{'Version'}", 'info';
        print output "Codename              : $::imscpConfig{'CodeName'}", 'info';
        print output "Plugin API            : $::imscpConfig{'PluginApi'}", 'info';
    }
}

if ( $nodisplayopts || iMSCP::Getopt->daemon ) {
    unless ( iMSCP::Getopt->json || iMSCP::Getopt->noheaders ) {
        print <<'EOF';

###############################################################################
###                               Daemon Info                               ###
###############################################################################

EOF
        print output "Daemon type           : $::imscpConfig{'DAEMON_TYPE'}", 'info';
    } else {
        $json->{'daemon_type'} = $::imscpConfig{'DAEMON_TYPE'};
    }
}

if ( $nodisplayopts || iMSCP::Getopt->servers ) {
    unless ( iMSCP::Getopt->json || iMSCP::Getopt->noheaders ) {
        print <<'EOF';

###############################################################################
###                               Servers Info                              ###
###############################################################################

EOF
    }

    for ( iMSCP::Servers->getInstance()->getList() ) {
        my $srvInstance = $_->factory();

        if ( iMSCP::Getopt->json ) {
            $json->{'servers'}->{$_} = {
                implementation => ref $srvInstance,
                version        => $srvInstance->getServerImplVersion(),
                internal_name  => $srvInstance->getServerName(),
                human_name     => $srvInstance->getServerHumanName(),
                priority       => $srvInstance->getServerPriority()
            };
            next;
        }

        print output "Server                : $_", 'info';
        print output "Server implementation : @{ [ ref $srvInstance ] }", 'info';
        print output "Server version        : @{ [ $srvInstance->getServerImplVersion() ] }", 'info';
        print output "Server name           : @{ [ $srvInstance->getServerName() ] }", 'info';
        print output "Server human name     : @{ [ $srvInstance->getServerHumanName() ] }", 'info';
        print output "Server priority       : @{ [ $srvInstance->getServerPriority() ] }", 'info';
        print "\n" unless iMSCP::Getopt->noheaders;
    }
}

if ( $nodisplayopts || iMSCP::Getopt->packages ) {
    unless ( iMSCP::Getopt->json || iMSCP::Getopt->noheaders ) {
        print <<'EOF';
###############################################################################
###                              Packages Info                              ###
###############################################################################

EOF
    }

    for ( iMSCP::Packages->getInstance()->getList() ) {
        my $pkgInstance = $_->getInstance();

        if ( $pkgInstance->isa( 'iMSCP::Packages::AbstractCollection' ) ) {
            for ( $pkgInstance->getCollection() ) {
                if ( iMSCP::Getopt->json ) {
                    $json->{'packages'}->{ref $_} = {
                        version       => $_->getPackageImplVersion(),
                        internal_name => $_->getPackageName(),
                        human_name    => $_->getPackageHumanName(),
                        priority      => $_->getPackagePriority()
                    };
                    next;
                }

                print output "Package               : @{ [ ref $_ ] }", 'info';
                print output "Package version       : @{ [ $_->getPackageImplVersion() ] }", 'info';
                print output "Package name          : @{ [ $_->getPackageName() ] }", 'info';
                print output "Package human name    : @{ [ $_->getPackageHumanName() ] }", 'info';
                print output "Package priority      : @{ [ $_->getPackagePriority() ] }", 'info';
                print "\n";
            }

            next;
        }

        if ( iMSCP::Getopt->json ) {
            $json->{'packages'}->{$_} = {
                implementation => ref $pkgInstance,
                version        => $pkgInstance->getPackageImplVersion(),
                internal_name  => $pkgInstance->getPackageName(),
                human_name     => $pkgInstance->getPackageHumanName(),
                priority       => $pkgInstance->getPackagePriority()
            };
            next;
        }

        print output "Package               : $_", 'info';
        print output "Package version       : @{ [ $pkgInstance->getPackageImplVersion() ] }", 'info';
        print output "Package name          : @{ [ $pkgInstance->getPackageName() ] }", 'info';
        print output "Package human name    : @{ [ $pkgInstance->getPackageHumanName() ] }", 'info';
        print output "Package priority      : @{ [ $pkgInstance->getPackagePriority() ] }", 'info';
        print "\n";
    }
}

print JSON->new()->utf8()->pretty( iMSCP::Getopt->pretty )->encode( $json ) if iMSCP::Getopt->json;

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
