=head1 NAME

 iMSCP::Servers::Sqld::Remote::Debian - i-MSCP (Debian) Remote SQL server implementation.

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

package iMSCP::Servers::Sqld::Remote::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Dir /;
use iMSCP::Database;
use iMSCP::Debug qw/ error /;
use version;
use parent 'iMSCP::Servers::Sqld::Mysql::Debian';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Remote SQL server implementation.

=head1 PUBLIC METHODS

=over 4

=item postinstall( )

 See iMSCP::Servers::Sqld::Mysql::Debian::Postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    0;
}

=item getHumanServerName( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Remote %s %s', $self->getVendor(), $self->getVersion());
}

=item restart( )

 See iMSCP::Servers::Sqld::Mysql::Debian::start()

=cut

sub start
{
    my ($self) = @_;

    0;
}

=item stop( )

 See iMSCP::Servers::Sqld::Mysql::Debian::stop()

=cut

sub stop
{
    my ($self) = @_;

    0;
}

=item restart( )

 See iMSCP::Servers::Sqld::Mysql::Debian::restart()

=cut

sub restart
{
    my ($self) = @_;

    0;
}

=item reload( )

 See iMSCP::Servers::Sqld::Mysql::Debian::reload()

=cut

sub reload
{
    my ($self) = @_;

    0;
}

=item createUser( $user, $host, $password )

 See iMSCP::Servers::Sqld::Mysql::Abstract::createUser()

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
            'CREATE USER ?@? IDENTIFIED BY ?'
                . ( ( $self->getVendor() ne 'MariaDB' && version->parse( $self->getVersion()) >= version->parse( '5.7.6' ) )
                ? ' PASSWORD EXPIRE NEVER' : ''
            ),
            undef, $user, $host, $password
        );
    };
    !$@ or croak( sprintf( "Couldn't create the %s\@%s SQL user: %s", $user, $host, $@ ));
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVendor( )

 Set SQL server vendor

 Return 0 on success, other on failure

=cut

sub _setVendor
{
    my ($self) = @_;

    local $@;
    eval {
        my $dbh = iMSCP::Database->factory()->getRawDb();

        local $dbh->{'RaiseError'} = 1;
        my $row = $dbh->selectrow_hashref( 'SELECT @@version, @@version_comment' ) or die( "Could't find SQL server vendor" );
        my $vendor = 'MySQL';

        if ( index( lc $row->{'@@version'}, 'mariadb' ) != -1 ) {
            $vendor = 'MariaDB';
        } elsif ( index( lc $row->{'@@version_comment'}, 'percona' ) != -1 ) {
            $vendor = 'Percona';
        }

        debug( sprintf( 'SQL server vendor set to: %s', $vendor ));
        $self->{'config'}->{'SQLD_VENDOR'} = $vendor;
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _buildConf( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::_buildConf()

=cut

sub _buildConf
{
    my ($self) = @_;

    eval {
        # Make sure that the conf.d directory exists
        iMSCP::Dir->new( dirname => "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d" )->make( {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => 0755
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    # Build the my.cnf file
    my $rs = $self->{'eventManager'}->registerOne(
        'beforeMysqlBuildConfFile',
        sub {
            unless ( defined ${$_[0]} ) {
                ${$_[0]} = "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            } elsif ( ${$_[0]} !~ m%^!includedir\s+$_[5]->{'SQLD_CONF_DIR'}/conf.d/\n%m ) {
                ${$_[0]} .= "!includedir $_[5]->{'SQLD_CONF_DIR'}/conf.d/\n";
            }

            0;
        }
    );
    $rs ||= $self->buildConfFile(
        ( -f "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" ? "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" : File::Temp->new() ),
        "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf",
        undef,
        undef,
        {
            srcname => 'my.cnf'
        }
    );
    return $rs if $rs;

    # Build the imscp.cnf file
    my $conffile = File::Temp->new();
    print $conffile <<'EOF';
# Configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
[mysql]
max_allowed_packet = {MAX_ALLOWED_PACKET}
EOF
    $conffile->close();
    $rs ||= $self->buildConfFile( $conffile, "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf", undef,
        {
            MAX_ALLOWED_PACKET => '500M',
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
    my ($self) = @_;

    return 0 if ( $self->getVendor() eq 'MariaDB' && version->parse( $self->getVersion()) < version->parse( '10.0' ) )
        || version->parse( $self->getVersion()) < version->parse( '5.6.6' );

    eval {
        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'};

        # Disable unwanted plugins (bc reasons)
        for ( qw/ cracklib_password_check simple_password_check validate_password / ) {
            $dbh->do( "UNINSTALL PLUGIN $_" ) if $dbh->selectrow_hashref( "SELECT name FROM mysql.plugin WHERE name = '$_'" );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
