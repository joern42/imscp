=head1 NAME

 iMSCP::Servers::Sqld::Remote::Debian - i-MSCP (Debian) Remote SQL server implementation.

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

package iMSCP::Servers::Sqld::Remote::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Dir iMSCP::File /;
use iMSCP::Boolean;
use iMSCP::Database;
use version;
use parent 'iMSCP::Servers::Sqld::Mysql::Debian';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Remote SQL server implementation.

=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Sqld::Mysql::Debian::Postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;
}

=item getHumanServerName( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'Remote %s %s', $self->getVendor(), $self->getVersion());
}

=item restart( )

 See iMSCP::Servers::Sqld::Mysql::Debian::start()

=cut

sub start
{
    my ( $self ) = @_;
}

=item stop( )

 See iMSCP::Servers::Sqld::Mysql::Debian::stop()

=cut

sub stop
{
    my ( $self ) = @_;
}

=item restart( )

 See iMSCP::Servers::Sqld::Mysql::Debian::restart()

=cut

sub restart
{
    my ( $self ) = @_;
}

=item reload( )

 See iMSCP::Servers::Sqld::Mysql::Debian::reload()

=cut

sub reload
{
    my ( $self ) = @_;
}

=item createUser( $user, $host, $password )

 See iMSCP::Servers::Sqld::Mysql::Abstract::createUser()

=cut

sub createUser
{
    my ( $self, $user, $host, $password ) = @_;

    defined $user or croak( '$user parameter is not defined' );
    defined $host or croak( '$host parameter is not defined' );
    defined $password or croak( '$password parameter is not defined' );

    my $dbh = iMSCP::Database->getInstance();
    unless ( $dbh->selectrow_array( 'SELECT EXISTS(SELECT 1 FROM mysql.user WHERE User = ? AND Host = ?)', undef, $user, $host ) ) {
        # User doesn't already exist. We create it
        $dbh->do(
            'CREATE USER ?@? IDENTIFIED BY ?'
                . ( ( $self->getVendor() ne 'MariaDB' && version->parse( $self->getVersion()) >= version->parse( '5.7.6' ) )
                ? ' PASSWORD EXPIRE NEVER' : ''
            ),
            undef, $user, $host, $password
        );
        return;
    }

    # User does already exists. We update his password
    if ( $self->getVendor() eq 'MariaDB' || version->parse( $self->getVersion()) < version->parse( '5.7.6' ) ) {
        $dbh->do( 'SET PASSWORD FOR ?@? = PASSWORD(?)', undef, $user, $host, $password );
        return;
    }

    $dbh->do( 'ALTER USER ?@? IDENTIFIED BY ? PASSWORD EXPIRE NEVER', undef, $user, $host, $password )
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVendor( )

 Set SQL server vendor

 Return void, die on failure

=cut

sub _setVendor
{
    my ( $self ) = @_;

    my $row = iMSCP::Database->getInstance()->selectrow_hashref( 'SELECT @@version, @@version_comment' ) or die( "Could't find SQL server vendor" );
    my $vendor = 'MySQL';

    if ( index( lc $row->{'@@version'}, 'mariadb' ) != -1 ) {
        $vendor = 'MariaDB';
    } elsif ( index( lc $row->{'@@version_comment'}, 'percona' ) != -1 ) {
        $vendor = 'Percona';
    }

    debug( sprintf( 'SQL server vendor set to: %s', $vendor ));
    $self->{'config'}->{'SQLD_VENDOR'} = $vendor;
}

=item _buildConf( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::_buildConf()

=cut

sub _buildConf
{
    my ( $self ) = @_;

    # Make sure that the conf.d directory exists
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d" )->make( {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => 0755
    } );

    # Build the my.cnf file
    $self->{'eventManager'}->registerOne(
        'beforeMysqlBuildConfFile',
        sub {
            unless ( defined ${ $_[0] } ) {
                ${ $_[0] } = "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            } elsif ( ${ $_[0] } !~ m%^!includedir\s+$_[5]->{'SQLD_CONF_DIR'}/conf.d/\n%m ) {
                ${ $_[0] } .= "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            }
        }
    );
    $self->buildConfFile(
        iMSCP::File->new( filename => "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" ), undef, undef, undef, { srcname => 'my.cnf' }
    );

    # Build the imscp.cnf file
    $self->buildConfFile(
        iMSCP::File->new( filename => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf" )->set( <<'EOF' ),
# Configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
[mysql]
max_allowed_packet = {MAX_ALLOWED_PACKET}
EOF
        undef,
        undef,
        {
            MAX_ALLOWED_PACKET => '500M'
        },
        {
            mode    => 0644,
            srcname => 'imscp.cnf'
        }
    );
}

=item _updateServerConfig( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::_updateServerConfig()

=cut

sub _updateServerConfig
{
    my ( $self ) = @_;

    return if ( $self->getVendor() eq 'MariaDB' && version->parse( $self->getVersion()) < version->parse( '10.0' ) )
        || version->parse( $self->getVersion()) < version->parse( '5.6.6' );

    # Disable unwanted plugins (bc reasons)
    my $dbh = iMSCP::Database->getInstance();
    for my $plugin ( qw/ cracklib_password_check simple_password_check validate_password / ) {
        $dbh->do( "UNINSTALL PLUGIN $plugin" ) if $dbh->selectrow_hashref( "SELECT name FROM mysql.plugin WHERE name = '$plugin'" );
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
