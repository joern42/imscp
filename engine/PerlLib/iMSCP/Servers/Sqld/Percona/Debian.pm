=head1 NAME

 iMSCP::Servers::Sqld::Percona::Debian - i-MSCP (Debian) Percona SQL server implementation.

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

package iMSCP::Servers::Sqld::Percona::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::Dir /;
use File::Temp;
use iMSCP::Debug qw/ debug error /;
use version;
use parent 'iMSCP::Servers::Sqld::Mysql::Debian';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Percona SQL server implementation.

=head1 PUBLIC METHODS

=over 4

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Percona %s', $self->getVersion());
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVendor( )

 See iMSCP::Servers::Sqld::Mysql::Abstract::_setVendor()

=cut

sub _setVendor
{
    my ($self) = @_;

    debug( sprintf( 'SQL server vendor set to: %s', 'Percona' ));
    $self->{'config'}->{'SQLD_VENDOR'} = 'Percona';
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

    # Build the /etc/mysql/my.cnf file

    my $conffile = "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf";
    unless ( -f $conffile ) {
        $conffile = File::Temp->new();
        $conffile->close();
    }

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
    $rs ||= $self->buildConfFile( $conffile, "$self->{'config'}->{'SQLD_CONF_DIR'}/my.cnf" );

    # Build the /etc/mysql/conf.d/imscp.cnf file

    $rs ||= $self->{'eventManager'}->registerOne(
        'beforeMysqlBuildConfFile',
        sub {
            ${$_[0]} .= <<"EOF";
[mysql]
max_allowed_packet = {MAX_ALLOWED_PACKET}
[mysqld]
default_password_lifetime = {DEFAULT_PASSWORD_LIFETIME}
event_scheduler = {EVENT_SCHEDULER}
innodb_use_native_aio = {INNODB_USE_NATIVE_AIO}
max_connections = {MAX_CONNECTIONS}
max_allowed_packet = MAX_ALLOWED_PACKET}
performance_schema = {PERFORMANCE_SCHEMA}
sql_mode = {SQL_MODE}
EOF
            @{$_[4]}{ qw/ EVENT_SCHEDULER INNODB_USE_NATIVE_AIO MAX_CONNECTIONS MAX_ALLOWED_PACKET PERFORMANCE_SCHEMA SQL_MODE SQLD_SOCK_DIR / } = (
                ( version->parse( $self->getVersion()) >= version->parse( '5.7.4' ) ),
                'DISABLED', ( $main::imscpConfig{'SYSTEM_VIRTUALIZER'} ne 'physical' ? 0 : 1 ), 500, '500M', 0, 0, $_[5]->{'SQLD_SOCK_DIR'}
            );

            my $version = version->parse( $self->getVersion());

            # For backward compatibility - We will review this in later version
            if ( $version >= version->parse( '5.7.4' ) ) {
                ${$_[0]} .= "default_password_lifetime = {DEFAULT_PASSWORD_LIFETIME}\n";
                $_->[4]->{'DEFAULT_PASSWORD_LIFETIME'} = 0;
            }

            # Fix For: The 'INFORMATION_SCHEMA.SESSION_VARIABLES' feature is disabled; see the documentation for
            # 'show_compatibility_56' (3167) - Occurs when executing mysqldump with Percona server 5.7.x
            ${$_[0]} .= "show_compatibility_56 = 1\n" if $version >= version->parse( '5.7.6' );

            0;
        }
    );
    $rs ||= $self->buildConfFile( 'imscp.cnf', "$self->{'config'}->{'SQLD_CONF_DIR'}/conf.d/imscp.cnf" );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
