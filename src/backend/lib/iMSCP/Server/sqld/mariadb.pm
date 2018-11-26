=head1 NAME

 iMSCP::Server::sqld::mariadb - i-MSCP MariaDB server implementation

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

package iMSCP::Server::sqld::mariadb;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::Server::sqld::mariadb::installer iMSCP::Server::sqld::mariadb::uninstaller /;
use iMSCP::Boolean;
use iMSCP::Service;
use parent 'iMSCP::Server::sqld::mysql';

=head1 DESCRIPTION

 i-MSCP MariaDB server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeSqldPreinstall', 'mariadb' );
    $rs ||= iMSCP::Server::sqld::mariadb::installer->getInstance()->preinstall();
    $rs ||= $self->{'eventManager'}->trigger( 'afterSqldPreinstall', 'mariadb' )
}

=item postinstall( )

 See iMSCP::Installer::AbstractActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeSqldPostInstall', 'mariadb' );

    iMSCP::Service->getInstance()->enable( 'mysql' );

    $rs = $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'MariaDB' ];
            0;
        },
        7
    );

    $rs ||= $self->{'eventManager'}->trigger( 'afterSqldPostInstall', 'mariadb' );
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeSqldUninstall', 'mariadb' );
    $rs ||= iMSCP::Server::sqld::mariadb::uninstaller->getInstance()->uninstall();
    $rs ||= $self->{'eventManager'}->trigger( 'afterSqldUninstall', 'mariadb' );
}

=item createUser( $user, $host, $password )

 Create the given SQL user

 Param $string $user SQL username
 Param string $host SQL user host
 Param $string $password SQL user password
 Return int 0 on success, die on failure

=cut

sub createUser
{
    my ( $self, $user, $host, $password ) = @_;

    defined $user or die( '$user parameter is not defined' );
    defined $host or die( '$host parameter is not defined' );
    defined $user or die( '$password parameter is not defined' );

    eval {
        my $rdbh = $self->{'dbh'}->getRawDb();
        local $rdbh->{'RaiseError'} = TRUE;

        $rdbh->do( 'CREATE USER ?@? IDENTIFIED BY ?', undef, $user, $host, $password );
    };
    !$@ or die( sprintf( "Couldn't create the %s\@%s SQL user: %s", $user, $host, $@ ));
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
