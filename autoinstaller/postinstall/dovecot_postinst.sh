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

# Starting with dovecot 2.3 (debian 11/devuan 4) there is an option ssl_min_protocol 
# which is simpler than the old ssl_protocols so we try to use this to prevent warnings

sed -i "s/^ssl_protocols = @.*/ssl_min_protocol = TLSv1.2/g" ../../engine/PerlLib/Servers/po/dovecot/installer.pm

