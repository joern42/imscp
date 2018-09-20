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
# Only Perl builtin and modules which are available in Perl base installation
# must be used in that script.
#
# Tested with:
#  - Debian [8..9]
#  - Ubuntu 14.04, 16.04, 18.04
#  - Devuan 1.0, 2.0

use warnings;
use strict;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use iMSCP::Getopt;
use iMSCP::LsbRelease;

BEGIN {
    local $@;
    no warnings 'redefine';
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

return TRUE if iMSCP::Getopt->skipDistPackages;

iMSCP::Debug::debug( "Satisfying i-MSCP installer prerequisites for @{ [ iMSCP::LsbRelease->getInstance()->getId( TRUE ) ] } OS..." );
iMSCP::DistPackageManager
    ->getInstance()
    # Make sure that APT indexes are up-to-date
    ->updateRepositoryIndexes()
    # Install pre-required distribution packages
    ->installPackages( [
        'apt-transport-https', 'ca-certificates', 'cpanminus', 'dialog', 'dirmngr', 'dpkg-dev', 'gdebi-core', 'lsb-release', 'pbuilder', 'perl',
        'perl-modules', 'policyrcd-script-zg2', 'wget',
        # FIXME: Does the following packages really needed at this stage?
        'binutils', 'debconf-utils',
        'libbit-vector-perl', 'libclass-insideout-perl', 'libdata-clone-perl', 'libdata-compare-perl', 'liblist-compare-perl',
        'liblist-moreutils-perl', 'libscalar-defer-perl', 'libsort-versions-perl', 'libxml-simple-perl'
    ] )
    # Install pre-required Perl modules
    ->installPerlModules( [
    'Class::Autouse@2.01', 'Data::Validate::Domain@0.14', 'Net::Domain::TLD@1.75', 'Net::IP@1.26'
] );

TRUE;
__END__
