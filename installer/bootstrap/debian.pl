#!/usr/bin/perl

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

# i-MSCP installer bootstrap file for Debian like distributions
#
# Only base (Perl core) modules *MUST* be used here, that is, those which are
# made available after a base distribution installation.
#
# Tested with:
#  - Debian [8..10]
#  - Ubuntu 14.04, 16.04, 18.04
#  - Devuan 1.0

unless ( -f '/etc/imscp/listener.d/10_apt_sources_list.pl' || -f '/etc/imscp/imscp.conf' ) {
    prntInfo 'Updating distribution package index files...';
    system( 'apt-get', '--quiet=1', 'update' ) == 0 or die( "couldn't update APT index" );

    prntInfo 'Installing the lsb-release distribution package...';
    system( 'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'install', 'lsb-release' ) == 0 or die(
        "couldn't install the lsb-release package"
    );

    my $distId = `lsb_release --short --id 2>/dev/null` or die( "coudln't guess distribution ID" );
    chomp( $distId );
    my $distCodename = `lsb_release --short --codename 2>/dev/null` or die( "couldn't guess distribution codename" );
    chomp( $distCodename );
    my $file = "$ROOTDIR/configs/$distId/apt/sources.list";

    if ( -f $file ) {
        prntInfo 'Updating APT sources.list file...';
        system( '/bin/cp', '-f', $file, '/etc/apt/sources.list' ) == 0 or die( "Couldn't copy APT sources.list file" );
        system( "perl -pi -e 's/{codename}/$distCodename/g;' /etc/apt/sources.list" );
    }
}

prntInfo 'Updating distribution package index files...';
system( 'apt-get', '--quiet=1', 'update' ) == 0 or die( "couldn't update APT index" );

prntInfo "Upgrading distribution packages (upgrade)...";
system( 'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'upgrade' ) == 0 or die( "couldn't upgrade distribution packages" );

prntInfo 'Installing pre-required distribution packages...';
system(
    'apt-get', '--assume-yes', '--no-install-recommends', '--quiet=1', 'install', 'apt-transport-https', 'apt-utils', 'build-essential',
    'ca-certificates', 'cpanminus', 'debconf-utils', 'dialog', 'dirmngr', 'libcapture-tiny-perl', 'libclass-autouse-perl', 'libdata-clone-perl',
    'libdata-compare-perl', 'libdata-validate-domain-perl', 'libfile-homedir-perl', 'libjson-perl', 'libjson-xs-perl', 'liblist-compare-perl',
    'libnet-ip-perl', 'libnet-libidn-perl', 'libscalar-defer-perl', 'libxml-simple-perl', 'policyrcd-script-zg2', 'wget', 'whiptail', 'virt-what',
    'libdatetime-perl', 'libemail-valid-perl', 'libdata-validate-ip-perl', 'lsb-release', 'ruby',
    # Required for H2ph build on amd64 OS...
    ( `/usr/bin/arch 2>/dev/null` eq "x86_64\n" ? ( 'libc6-dev-i386', 'libc6-dev-x32' ) : () )
) == 0 or die( "couldn't install pre-required distribution packages" );

# Install FACTER(8) from rubygem.org as the version provided by some distributions is too old
# TODO: Add the --minimal-deps option when support for Ubuntu Trusty Thar will be dropped 
prntInfo "Installing pre-required facter program (RubyGem)...";
system( '/usr/bin/gem', 'install', 'facter', '--quiet', '--conservative', '--version', '2.5.1' ) == 0 or die(
    "couldn't install pre-required distribution packages"
);

if ( eval "require Module::Load::Conditional; 1;" ) {
    Module::Load::Conditional->import( 'check_install' );
    require iMSCP::Requirements;
    my $perlModules = iMSCP::Requirements->new()->getPerlModuleRequirements( 'prerequiredOnly' );

    while ( my ( $module, $version ) = each %{ $perlModules } ) {
        my $rv = check_install( module => $module, version => $version );

        if ( $rv && $rv->{'uptodate'} ) {
            delete $perlModules->{$module} if $rv && $rv->{'uptodate'};
            next;
        }

        $perlModules->{$module} .= "~$version'";
    }

    if ( %{ $perlModules } ) {
        prntInfo "Installing pre-required Perl module(s) from CPAN...";
        system( '/usr/bin/cpanm', '--notest', '--quiet', keys %{ $perlModules } ) == 0 or die(
            "couldn't install all pre-required Perl module(s) from CPAN"
        );
    }
} else {
    die( 'the Module::Load::Conditional Perl module is not available' );
}

1;
__END__
