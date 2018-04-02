#!/usr/bin/make -f

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

CC := gcc
CFLAGS := -DDEBUG=0 -s -ansi -Wall -Wextra -std=c11 -Wstrict-prototypes -pedantic-errors -O2

headers = sys/syscall.h linux/fs.h

# Debian/Ubuntu specific (Multiarch)
-include /usr/share/dpkg/architecture.mk
ifdef DEB_HOST_MULTIARCH
    headers += $(DEB_HOST_MULTIARCH)/sys/mount.h
    CFLAGS += -DMULTIARCH='"$(DEB_HOST_MULTIARCH)"'
else
    headers += sys/mount.h
endif

default: H2ph.pm
all: default

bin/%: %.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -o $@

%.pm: bin/% h2ph
	$< > iMSCP/$@
	$(RM) -r bin/

h2ph:
	@mkdir -p $@
	-cd /usr/include; h2ph -Q -a -d $(shell pwd)/$@ $(headers)

clean:
	$(RM) -r h2ph/ iMSCP/H2ph.pm
