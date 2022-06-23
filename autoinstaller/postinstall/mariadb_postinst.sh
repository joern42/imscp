#!/bin/sh
# i-MSCP - internet Multi Server Control Panel
# Copyright 2022 by Christian Hernmarck <joximu@web.de>
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

set -e

# Only for Devuan ASCII (and Beowulf) - MariaDB has service name mysql

/bin/sed -i "s/.*eval { iMSCP::Service->getInstance()->enable( 'mariadb' ); };/    eval { iMSCP::Service->getInstance()->enable( 'mysql' ); };/g" ../../engine/PerlLib/Servers/sqld/mariadb.pm
