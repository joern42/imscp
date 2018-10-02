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
    ABSTRACT         => 'i-MSCP H2ph library',
    AUTHOR           => 'Laurent Declercq <l.declercq@nuxwin.com>',
    NAME             => 'iMSCP::H2ph',
    VERSION_FROM     => '../lib/iMSCP/Version.pm',
    LICENSE          => 'lgpl_2_1',
    MIN_PERL_VERSION => '5.0018_002',
    SKIP             => [ 'static' ],
    CCFLAGS          => '-s -ansi -Wall -Wextra -std=c99 -Wstrict-prototypes -pedantic-errors',
    NO_META          => 1,
    NO_MYMETA        => 1
);

# Override default top_targets to add the H2ph.pm target
sub MY::top_targets
{
    <<'MAKE_FRAG';
all :: pure_all manifypods
	$(NOECHO) $(NOOP)

pure_all :: config pm_to_blib subdirs H2ph.pm
	$(NOECHO) $(NOOP)

subdirs :: $(MYEXTLIB)
	$(NOECHO) $(NOOP)

config :: $(FIRST_MAKEFILE) blibdirs
	$(NOECHO) $(NOOP)

help :
	perldoc ExtUtils::MakeMaker
MAKE_FRAG
}

# Add required targets to convert .h C header files to .ph Perl header files and
# build the iMSCP::H2ph package
sub MY::postamble
{
    <<'MAKE_FRAG';
%.pm: bin/%
	$< > $(INST_LIB)/iMSCP/$@
	$(RM) -r bin/

bin/%: %.c h2ph
	mkdir -p $(@D)
	$(CC) $(DEFINE) $(CCFLAGS) $(OPTIMIZE) $< -o $@

h2ph:
	-cd /usr/include; $@ -a -d $(shell pwd)/$(INST_ARCHLIB) linux/fs.h syscall.h sys/mount.h
MAKE_FRAG
}

1;
__END__
