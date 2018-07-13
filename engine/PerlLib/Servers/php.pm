=head1 NAME

 Servers::noserver - i-MSCP PHP server implementation

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2017 by Laurent Declercq <l.declercq@nuxwin.com>
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

package Servers::php;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::Service;
use parent 'Servers::noserver';

=head1 DESCRIPTION

 i-MSCP PHP server implementation.

=head1 PUBLIC METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    60;
}

=item install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_disableUnusedPhpVersions();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init

 Initialize instance

 Return Servers::php

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'httpd'} = Servers::httpd->factory();
    $self;
}

=item

 Disable unused PHP versions (PHP-FPM)

 Return 0 on success, other on failure

=cut

sub _disableUnusedPhpVersions
{
    my ( $self ) = @_;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();

        for my $version ( $self->getAvailablePhpVersions() ) {
            next $srvProvider->hasService( "php$version-fpm" );
            $srvProvider->stop( "php$version-fpm" );

            # Disables the PHP-FPM service if one of the following conditions is met:
            # The HTTP server implementation for customers is not FPM
            # The PHP version is not used by customers
            if ( ref $self->{'httpd'} ne 'Servers::httpd::apache_php_fpm'
                || $self->{'httpd'}->{'phpConfig'}->{'PHP_VERSION'} ne $version
            ) {
                if ( $srvProvider->isSystemd() ) {
                    # If systemd is the current init we mask the service. Service will be disabled and masked.
                    $srvProvider->getProvider()->mask( "php$version-fpm" );
                } else {
                    $srvProvider->disable( "php$version-fpm" );
                }
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _getAvailablePhpVersions()

 Return list of available PHP versions

=cut

sub _getAvailablePhpVersions
{
    CORE::state @versions;

    # A Debian like distribution is assumed here
    @versions = sort { $a <=> $b } iMSCP::Dir->new( dirname => '/etc/php' )->getDirs( qr/^\d+.\d+$/ ) unless @versions;
    @versions;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
