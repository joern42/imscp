=head1 NAME

 Servers::noserver - i-MSCP PHP server implementation

=cut

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

package Servers::php;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Debug 'error';
use iMSCP::Cwd '$CWD';
use iMSCP::Service;
use parent qw/ Common::SingletonClass iMSCP::Installer::AbstractActions /;

# php server instance
my $instance;

=head1 DESCRIPTION

 i-MSCP PHP server implementation.

=head1 PUBLIC METHODS

=over 4

=item factory( )

 Create and return noserver server instance

 Return Servers::noserver

=cut

sub factory
{
    return $instance if $instance;

    $instance = __PACKAGE__->getInstance();
    @{ $instance }{qw/ start restart reload /} = ( FALSE, FALSE, FALSE );
    $instance;
}

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    60;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_disableUnusedPhpVersions();
}

=item getAvailablePhpVersions( )

 Get list of available PHP versions

 Return list of available PHP versions

=cut

sub getAvailablePhpVersions
{
    CORE::state @versions;

    # A Debian like distribution is assumed here
    local $CWD = '/etc/php';
    @versions = sort { $a <=> $b } <[0-9].[0-9]> unless @versions;
    @versions;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _disableUnusedPhpVersions( )

 Disable unused PHP versions (PHP-FPM)

 Return int 0 on success, die on failure

=cut

sub _disableUnusedPhpVersions
{
    my ( $self ) = @_;

    my $httpd = Servers::httpd->factory();
    my $service = iMSCP::Service->getInstance();

    for my $version ( $self->getAvailablePhpVersions() ) {
        next unless $service->hasService( "php$version-fpm" );

        # Disables the PHP-FPM service if one of the following conditions is met:
        # The HTTP server implementation for customers is not FPM
        # The PHP version is not used by customers
        if ( ref $httpd ne 'Servers::httpd::apache_php_fpm' || $httpd->{'phpConfig'}->{'PHP_VERSION'} ne $version ) {
            $service->stop( "php$version-fpm" );
            $service->disable( "php$version-fpm" );
        }
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
