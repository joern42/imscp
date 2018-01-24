#!/usr/bin/perl

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

# i-MSCP installer bootstrap file for Debian like distributions
#
# Tested with:
#  - Debian 8 - 10
#  - Ubuntu 14.04, 16.04
#  - Devuan 1.0

system( 'clear 2>/dev/null' );

print "Satisfying pre-requisites for the i-MSCP installer\n";

unless ( -f '/etc/imscp/listener.d/10_apt_sources_list.pl' ) {
    print " [\x1b[0;34mINFO\x1b[0m] Updating distribution package index files...\n";
    system( 'apt-get', '--quiet=1', 'update' ) == 0 or die( "[\x1b[0;31mERROR\x1b[0m] Couldn't update APT index.\n" );

    print " [\x1b[0;34mINFO\x1b[0m] Installing the lsb-reelase distribution package...\n";
    system( 'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'install', 'lsb-release' ) == 0 or die(
        "[\x1b[0;31mERROR\x1b[0m] Couldn't install the lsb-release package.\n"
    );

    my $distId = `/usr/bin/lsb_release --short --id 2>/dev/null` or die( "[\x1b[0;31mERROR\x1b[0m] Couldn't guess distribution ID\n" );
    chomp( $distId );
    my $distCodename = `/usr/bin/lsb_release --short --codename 2>/dev/null` or die(
        "[\x1b[0;31mERROR\x1b[0m] Couldn't guess distribution codename\n"
    );
    chomp( $distCodename );
    my $file = "$ROOTDIR/configs/$distId/apt/sources.list";

    if ( -f $file ) {
        print " [\x1b[0;34mINFO\x1b[0m] Updating APT sources.list file...\n";
        system( '/bin/cp', '-f', $file,
            '/etc/apt/sources.list' ) == 0 or die( "[\x1b[0;31mERROR\x1b[0m] Couldn't copy APT sources.list file \n" );
        system( "perl -pi -e 's/{codename}/$distCodename/g;' /etc/apt/sources.list" );
    }
}

print " [\x1b[0;34mINFO\x1b[0m] Updating distribution package index files...\n";
system( 'apt-get', '--quiet=1', 'update' ) == 0 or die( "[\x1b[0;31mERROR\x1b[0m] Couldn't update APT index.\n" );

print " [\x1b[0;34mINFO\x1b[0m] Upgrading distribution packages (upgrade)...\n";
system( 'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'upgrade' ) == 0 or die(
    "[\x1b[0;31mERROR\x1b[0m] Couldn't upgrade distribution packages.\n"
);

print " [\x1b[0;34mINFO\x1b[0m] Installing pre-required distribution package...\n";
system(
    'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'install', 'apt-transport-https', 'apt-utils', 'build-essential',
    'ca-certificates', 'debconf-utils', 'dialog', 'dirmngr', 'libbit-vector-perl', 'libcapture-tiny-perl', 'libcarp-always-perl',
    'libclass-autouse-perl', 'libdata-compare-perl', 'libdata-validate-domain-perl', 'libfile-homedir-perl', 'libjson-perl', 'libjson-xs-perl',
    'liblchown-perl', 'liblist-compare-perl', 'liblist-moreutils-perl', 'libnet-ip-perl', 'libnet-domain-tld-perl', 'libscalar-defer-perl',
    'libsort-versions-perl', 'libxml-simple-perl', 'policyrcd-script-zg2', 'wget', 'whiptail', 'virt-what', 'libdatetime-perl', 'libemail-valid-perl',
    'libdata-validate-ip-perl', 'lsb-release', 'ruby'
) == 0 or die(
    "[\x1b[0;31mERROR\x1b[0m] Couldn't install pre-required distribution packages.\n"
);

# Install FACTER(8) from rubygem.org as the version provided by some distributions is too old
print " [\x1b[0;34mINFO\x1b[0m] Installing pre-required facter program (RubyGem)...\n";
system( '/usr/bin/gem', 'install', 'facter', '--quiet', '--minimal-deps' ) == 0 or die(
    "[\x1b[0;31mERROR\x1b[0m] Couldn't install pre-required distribution packages.\n"
);

if ( eval "require Module::Load::Conditional; 1;" ) {
    Module::Load::Conditional->import( 'check_install' );
    my %perlModules = ( 'Array::Utils', 0.5, 'Data::Clone', 0.004 );

    while ( my ($module, $version) = each %perlModules ) {
        my $rv = check_install( module => $module, version => $version );
        delete $perlModules{$module} if $rv && $rv->{'uptodate'};
    }

    if ( %perlModules ) {
        print " [\x1b[0;34mINFO\x1b[0m] Installing pre-required Perl module(s) from CPAN...\n";
        system( "echo 'yes' | cpan -T @{ [ keys %perlModules ] }" ) == 0 or die(
            "[\x1b[0;31mERROR\x1b[0m] Couldn't install pre-reuired Perl module(s) from CPAN.\n"
        );
    }
} else {
    die "[\x1b[0;31mERROR\x1b[0m] Module::Load::Conditional Perl module not available\n";
}

1;
__END__
