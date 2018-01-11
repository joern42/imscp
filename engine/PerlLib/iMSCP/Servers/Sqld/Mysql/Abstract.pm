=head1 NAME

 iMSCP::Servers::Sqld::Mysql::Abstract::Abstract - i-MSCP MySQL SQL server abstract implementation

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

package iMSCP::Servers::Sqld::Mysql::Abstract;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use autouse 'Net::LibIDN' => qw/ idn_to_ascii /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::File /;
use iMSCP::Config;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error getMessageByType /;
use version;
use parent 'iMSCP::Servers::Sqld';

=head1 DESCRIPTION

 i-MSCP MySQL SQL server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    my $rs = $self->_setVendor();
    $rs ||= $self->_setVersion();
}

=item setEnginePermissions( )

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    my $rs = setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
    $rs ||= setRights( "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $self->{'config'}->{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
}

=item getEventServerName( )

 See iMSCP::Servers::Abstract::getEventServerName()

=cut

sub getEventServerName
{
    my ($self) = @_;

    'Mysql';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'MySQL %s', $self->getVersion());
}

=item createUser( $user, $host, $password )

 See iMSCP::Servers::Sqld::createUser();

=cut

sub createUser
{
    my ($self, $user, $host, $password) = @_;

    defined $user or croak( '$user parameter is not defined' );
    defined $host or croak( '$host parameter is not defined' );
    defined $password or croak( '$password parameter is not defined' );

    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'} = 1;
        $dbh->do(
            'CREATE USER ?@? IDENTIFIED BY ?' . ( version->parse( $self->getVersion()) >= version->parse( '5.7.6' ) ? ' PASSWORD EXPIRE NEVER' : '' ),
            undef, $user, $host, $password
        );
    };
    !$@ or croak( sprintf( "Couldn't create the %s\@%s SQL user: %s", $user, $host, $@ ));
    0;
}

=item dropUser( $user, $host )

 See iMSCP::Servers::Sqld::dropUser();

=cut

sub dropUser
{
    my (undef, $user, $host) = @_;

    defined $user or croak( '$user parameter not defined' );
    defined $host or croak( '$host parameter not defined' );

    # Prevent deletion of system SQL users
    return 0 if grep($_ eq lc $user, 'debian-sys-maint', 'mysql.sys', 'root');

    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'} = 1;
        return unless $dbh->selectrow_hashref( 'SELECT 1 FROM mysql.user WHERE user = ? AND host = ?', undef, $user, $host );
        $dbh->do( 'DROP USER ?@?', undef, $user, $host );
    };
    !$@ or croak( sprintf( "Couldn't drop the %s\@%s SQL user: %s", $user, $host, $@ ));
    0;
}



=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Servers::Sqld::Mysql::Abstract

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->{'cfgDir'} = "$main::imscpConfig{'CONF_DIR'}/mysql";
    $self->_mergeConfig() if defined $main::execmode && $main::execmode eq 'setup' && -f "$self->{'cfgDir'}/mysql.data.dist";
    tie %{$self->{'config'}},
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/mysql.data",
        readonly    => !( defined $main::execmode && $main::execmode eq 'setup' ),
        nodeferring => defined $main::execmode && $main::execmode eq 'setup';
    $self->SUPER::_init();
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Return void, croak on failure

=cut

sub _mergeConfig
{
    my ($self) = @_;

    if ( -f "$self->{'cfgDir'}/mysql.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/mysql.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/mysql.data", readonly => 1;

        debug( 'Merging old configuration with new configuration ...' );

        while ( my ($key, $value) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/mysql.data.dist" )->moveFile( "$self->{'cfgDir'}/mysql.data" ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );
}

=item _setVendor( )

 Set SQL server vendor

 Return 0 on success, other on failure

=cut

sub _setVendor
{
    my ($self) = @_;

    debug( sprintf( 'SQL server vendor set to: %s', 'MySQL' ));
    $self->{'config'}->{'SQLD_VENDOR'} = 'MySQL';
    0;
}

=item _setVersion( )

 Set SQL server version

 Return 0 on success, other on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();

        local $dbh->{'RaiseError'} = 1;
        my $row = $dbh->selectrow_hashref( 'SELECT @@version' ) or croak( "Could't find SQL server version" );
        my ($version) = $row->{'@@version'} =~ /^([0-9]+(?:\.[0-9]+){1,2})/;

        unless ( defined $version ) {
            error( "Couldn't guess SQL server version with the `SELECT \@\@version` SQL query" );
            return 1;
        }

        debug( sprintf( 'SQL server version set to: %s', $version ));
        $self->{'config'}->{'SQLD_VERSION'} = $version;
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _tryDbConnect

 Try database connection

 Return int 0 on success, other on failure
=cut

sub _tryDbConnect
{
    my (undef, $host, $port, $user, $pwd) = @_;

    defined $host or croak( '$host parameter is not defined' );
    defined $port or croak( '$port parameter is not defined' );
    defined $user or croak( '$user parameter is not defined' );
    defined $pwd or croak( '$pwd parameter is not defined' );

    my $db = iMSCP::Database->getInstance();
    $db->set( 'DATABASE_HOST', idn_to_ascii( $host, 'utf-8' ) // '' );
    $db->set( 'DATABASE_PORT', $port );
    $db->set( 'DATABASE_USER', $user );
    $db->set( 'DATABASE_PASSWORD', $pwd );
    $db->connect();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
