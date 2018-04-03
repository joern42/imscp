=head1 NAME

 iMSCP::Servers::Sqld::Mariadb::Debian - i-MSCP (Debian) MariaDB SQL server implementation

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

package iMSCP::Servers::Sqld::Mariadb::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Crypt' => qw/ decryptRijndaelCBC /;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::TemplateParser' => qw/ processByRef /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Dir iMSCP::File /;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Sqld::Mysql::Debian';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) MariaDB SQL server implementation.

=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Sqld::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'mariadb' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices', sub { push @{ $_[0] }, [ sub { $self->restart(); }, $self->getServerHumanName() ]; }, $self->getServerPriority()
    );
}

=item uninstall( )

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_removeConfig();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'mariadb' ) if $srvProvider->hasService( 'mariadb' ) && $srvProvider->isRunning( 'mariadb' );
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'mariadb' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'mariadb' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'mariadb' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'mariadb' );
}

=item getServerHumanName( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::getServerHumanName()

=cut

sub getServerHumanName
{
    my ( $self ) = @_;

    sprintf( 'MariaDB %s', $self->getServerVersion());
}

=item createUser( $user, $host, $password )

 See iMSCP::Servers::Sqld::Mysql::Abstract::createUser()

=cut

sub createUser
{
    my ( undef, $user, $host, $password ) = @_;

    defined $user or croak( '$user parameter is not defined' );
    defined $host or croak( '$host parameter is not defined' );
    defined $password or croak( '$password parameter is not defined' );

    unless ( $self->{'dbh'}->selectrow_array( 'SELECT EXISTS(SELECT 1 FROM mysql.user WHERE User = ? AND Host = ?)', undef, $user, $host ) ) {
        # User doesn't already exist. We create it
        $self->{'dbh'}->do( 'CREATE USER ?@? IDENTIFIED BY ?', undef, $user, $host, $password );
        return;
    }

    $self->{'dbh'}->do( 'SET PASSWORD FOR ?@? = PASSWORD(?)', undef, $user, $host, $password );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVendor( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::_setVendor()

=cut

sub _setVendor
{
    my ( $self ) = @_;

    debug( sprintf( 'SQL server vendor set to: %s', 'MariaDB' ));
    $self->{'config'}->{'SQLD_VENDOR'} = 'MariaDB';
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
[mysqld]
event_scheduler = {EVENT_SCHEDULER}
innodb_use_native_aio = {INNODB_USE_NATIVE_AIO}
max_connections = {MAX_CONNECTIONS}
max_allowed_packet = {MAX_ALLOWED_PACKET}
performance_schema = {PERFORMANCE_SCHEMA}
sql_mode = {SQL_MODE}
EOF
        undef,
        undef,
        {
            EVENT_SCHEDULER       => 'DISABLED',
            INNODB_USE_NATIVE_AIO => $::imscpConfig{'SYSTEM_VIRTUALIZER'} eq 'physical' ? 'ON' : 'OFF',
            MAX_CONNECTIONS       => '500',
            MAX_ALLOWED_PACKET    => '500M',
            PERFORMANCE_SCHEMA    => 'OFF',
            SQL_MODE              => ''
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

    # Upgrade MySQL tables if necessary
    {
        my $defaultsExtraFile = File::Temp->new();
        print $defaultsExtraFile <<'EOF';
[mysql_upgrade]
host = {HOST}
port = {PORT}
user = "{USER}"
password = "{PASSWORD}"
EOF
        $defaultsExtraFile->close();
        $self->buildConfFile( $defaultsExtraFile, undef, undef,
            {
                HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
                PORT     => ::setupGetQuestion( 'DATABASE_PORT' ),
                USER     => ::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
                PASSWORD => decryptRijndaelCBC( $::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
            },
            {
                srcname => 'defaults-extra-file'
            }
        );
        # Simply mimic Debian behavior (/usr/share/mysql/debian-start.inc.sh)
        my $rs = execute(
            "/mysql_upgrade --defaults-extra-file=$defaultsExtraFile 2>&1 | egrep -v '^(1|\@had|ERROR (1054|1060|1061))'", \my $stdout, \my $stderr
        );
        debug( $stdout ) if length $stdout;
        !$rs or die( sprintf( "Couldn't upgrade SQL server system tables: %s", $stderr || 'Unknown error' ));
    }

    return if version->parse( $self->getServerVersion()) < version->parse( '10.0' );

    # Disable unwanted plugins (bc reasons)
    for my $plugin ( qw/ cracklib_password_check simple_password_check unix_socket validate_password / ) {
        $self->{'dbh'}->do( "UNINSTALL PLUGIN $plugin" ) if $self->{'dbh'}->selectrow_hashref( "SELECT name FROM mysql.plugin WHERE name = '$plugin'" );
    }

}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
