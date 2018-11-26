# i-MSCP Listener::FrontEnd::Templates::Override listener file
# Copyright (C) 2016-2017 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

# Allows to override default i-MSCP frontEnd template files by copying your
# own template files.

package Listener::FrontEnd::Templates::Override;

use strict;
use warnings;
use iMSCP::Dir;
use iMSCP::Boolean;
use iMSCP::EventManager;

# Install custom i-MSCP frontEnd theme
#
# Howto setup and activate
# 1. Upload that listener file into the /etc/imscp/listeners.d directory
# 2. Edit the uploaded file and set the $CUSTOM_THEMES_PATH configuration
#    variable to the path of your custom i-MSCP theme
# 3. Rerun the i-MSCP distribution installer : perl imscp-installer -danv

# Configuration parameters

# Path to your own i-MSCP theme directory
my $CUSTOM_THEMES_PATH = '';

# Please don't edit anything below this line

# Don't register event listeners if not needed
return 1 unless length $CUSTOM_THEMES_PATH;

iMSCP::EventManager->getInstance()->register( 'afterInstallDistributionFiles', sub
{
    iMSCP::Dir->new( dirname => $CUSTOM_THEMES_PATH )->copy( "$::imscpConfig{'GUI_ROOT_DIR'}/themes/default" );
} );

1;
__END__
