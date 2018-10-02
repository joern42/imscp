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

use ExtUtils::MakeMaker;
$Verbose = 1;

WriteMakefile(
    ABSTRACT         => 'i-MSCP Backend',
    AUTHOR           => 'Laurent Declercq <l.declercq@nuxwin.com>',
    NAME             => 'iMSCP',
    DISTNAME         => 'iMSCP',
    LICENSE          => 'lgpl_2_1',
    MIN_PERL_VERSION => '5.0018_002',
    VERSION_FROM     => 'lib/iMSCP/Version.pm',
    EXE_FILES        => [ glob( 'bin/*' ) ],
    # Discard man pages
    MAN1PODS         => {},
    MAN3PODS         => {},
    NO_META          => 1,
    NO_MYMETA        => 1
);

1;
__END__
