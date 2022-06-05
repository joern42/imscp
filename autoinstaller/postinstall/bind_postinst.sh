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

# Starting with bind v9.13.6 the service name is "named" and not "bind9" anymore
# [around Debian 11 (bullseye), Devuan 4 (chimaera) and Ubuntu 20.04 (focal)] 
if [ -f /etc/init.d/named ]; then
  sed -i "s/^NAMED_SERVICE = bind9/NAMED_SERVICE = named/g" ../../configs/debian/bind/bind.data.dist
fi
