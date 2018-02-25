#!/usr/bin/perl

=head1 NAME

 imscp-check-requirements.pl Check i-MSCP requirements

=head1 SYNOPSIS

 imscp-check-requirements.pl

=cut

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

use lib '/usr/local/src/imscp/engine/PerlLib';
use iMSCP::Requirements;
use iMSCP::Debug qw/ output /;

iMSCP::Requirements->new()->all();

print output(' All i-MSCP requirements are met.', 'ok');

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
