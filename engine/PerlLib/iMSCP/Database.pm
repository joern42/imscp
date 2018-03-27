=head1 NAME

 iMSCP::Database - Database abstraction layer (DAL) for MySQL

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

package iMSCP::Database;

use strict;
use warnings;
use Carp qw/ croak /;
use DBI;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Execute qw/ execute escapeShell /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Provide a datababase abstraction layer (DAL) for MySQL

=cut

=head1 PUBLIC METHODS

=over 4

=item ( $prop, $value )

 Set properties

 Param string $prop Propertie name
 Param string $value Propertie value
 Return string|undef Value of propertie which has been set or undef in case the properties doesn't exist

=cut

sub set
{
    my ( $self, $prop, $value ) = @_;

    return unless exists $self->{'db'}->{$prop};

    $self->{'db'}->{$prop} = $value;
}

=item connect( )

 Connect to the MySQL server

 Return DBI::db, croak on failure

=cut

sub connect
{
    my ( $self ) = @_;

    my $dsn = "dbi:mysql:mysql_connect_timeout=30;database=$self->{'db'}->{'DATABASE_NAME'}"
        . ( $self->{'db'}->{'DATABASE_HOST'} ? ';host=' . $self->{'db'}->{'DATABASE_HOST'} : '' ) .
        ( $self->{'db'}->{'DATABASE_PORT'} ? ';port=' . $self->{'db'}->{'DATABASE_PORT'} : '' );

    return $self->{'connect'} if $self->{'connect'} && $self->{'_dsn'} eq $dsn && $self->{'_currentUser'} eq $self->{'db'}->{'DATABASE_USER'}
        && $self->{'_currentPassword'} eq $self->{'db'}->{'DATABASE_PASSWORD'};

    $self->{'_dsn'} = $dsn;
    $self->{'_currentUser'} = $self->{'db'}->{'DATABASE_USER'};
    $self->{'_currentPassword'} = $self->{'db'}->{'DATABASE_PASSWORD'};
    $self->disconnect() if $self->{'connect'};
    $self->{'connect'} = DBI->connect(
        $dsn, $self->{'db'}->{'DATABASE_USER'}, $self->{'db'}->{'DATABASE_PASSWORD'}, $self->{'db'}->{'DATABASE_SETTINGS'}
    );
}

=item useDatabase( $dbName )

 Change database for the current connection

 Param string $dbName Database name
 Return string Old database on success, die on failure

=cut

sub useDatabase
{
    my ( $self, $dbName ) = @_;

    length $dbName or croak( '$dbName parameter is not defined or invalid' );

    my $oldDbName = $self->{'db'}->{'DATABASE_NAME'};
    return $oldDbName if $dbName eq $oldDbName;

    $self->connect()->do( 'USE ' . $self->connect()->quote_identifier( $dbName ));
    $self->{'db'}->{'DATABASE_NAME'} = $dbName;
    $oldDbName;
}

=item getDbTables( [ $dbName ] )

 Return sorted list of database tables

 Param string $dbName Database name
 Return arrayref, die on failure

=cut

sub getDbTables
{
    my ( $self, $dbName ) = @_;
    $dbName //= $self->{'db'}->{'DATABASE_NAME'};

    [
        sort keys %{ $self->connect()->selectall_hashref(
            'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ?', 'TABLE_NAME', undef, $dbName
        ) }
    ];
}

=item getTableColumns( [$tableName [, dbName ] ] )

 Return sorted list of columns for a database table

 Param string $tableName Table name
 Param string $dbName Database name
 Return arrayref, error string on failure

=cut

sub getTableColumns
{
    my ( $self, $tableName, $dbName ) = @_;
    $dbName //= $self->{'db'}->{'DATABASE_NAME'};

    [
        sort keys %{ $self->connect()->selectall_hashref(
            'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?', 'COLUMN_NAME', undef, $dbName, $tableName
        ) }
    ];
}

=item dumpdb( $dbName, $dbDumpTargetDir )

 Dump the given database
 
 # TODO: Sign the SQL dump using SSL and verify the signature

 Param string $dbName Database name
 Param string $dbDumpTargetDir Database dump target directory
 Return void, die on failure

=cut

sub dumpdb
{
    my ( $self, $dbName, $dbDumpTargetDir ) = @_;

    # Encode slashes as SOLIDUS unicode character
    # Encode dots as Full stop unicode character
    ( my $encodedDbName = $dbName ) =~ s%([./])%{ '/', '@002f', '.', '@002e' }->{$1}%ge;

    debug( sprintf( 'Dump %s database into %s', $dbName, $dbDumpTargetDir . '/' . $encodedDbName . '.sql' ));

    my $innoDbOnly = !$self->connect()->selectrow_array(
        "SELECT COUNT(ENGINE) FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND ENGINE <> 'InnoDB'", undef, $dbName
    );

    unless ( $self->{'_sql_default_extra_file'} ) {
        $self->{'_sql_default_extra_file'} = File::Temp->new();
        print { $self->{'_sql_default_extra_file'} } <<"EOF";
[mysqldump]
databases = true
host = $self->{'db'}->{'DATABASE_HOST'}
port = $self->{'db'}->{'DATABASE_PORT'}
user = "@{ [ $self->{'db'}->{'DATABASE_USER'} =~ s/"/\\"/gr ] }"
password = "@{ [ $self->{'db'}->{'DATABASE_PASSWORD'} =~ s/"/\\"/gr ] }"
max_allowed_packet = 500M
add-drop-table = false
add-locks = true
create-options = true
disable-keys = true
extended-insert = true
lock-tables = true
quick = true
set-charset = true
add-drop-database = true
allow-keywords = true
quote-names = true
complete-insert = true
@{ [ $innoDbOnly ? 'single-transaction = true' : 'lock-tables = true' ] }
@{ [ $innoDbOnly ? 'skip-lock-tables = true' : '' ] }
@{ [ index( $::imscpConfig{'iMSCP::Servers::Sqld'}, '::Remote::' ) == -1 ? 'compress = true' : '' ] }
EOF
        $self->{'_sql_default_extra_file'}->close();
    }

    my $stderr;
    execute(
        "nice -n 19 ionice -c2 -n7 /usr/bin/mysqldump --defaults-extra-file=$self->{'_sql_default_extra_file'} @{ [ escapeShell( $dbName ) ] } >"
            . escapeShell( "$dbDumpTargetDir/$encodedDbName.sql" ),
        undef,
        \$stderr
    ) == 0 or die( $stderr || 'Unknown error' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Database

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'db'} = {
        DATABASE_NAME     => '',
        DATABASE_HOST     => '',
        DATABASE_PORT     => '',
        DATABASE_USER     => '',
        DATABASE_PASSWORD => '',
        DATABASE_SETTINGS => {
            AutoCommit           => TRUE,
            AutoInactiveDestroy  => TRUE,
            Callbacks            => {
                connected => sub {
                    $_[0]->do( "SET SESSION sql_mode = 'NO_AUTO_CREATE_USER', SESSION group_concat_max_len = 65535" );
                    return;
                }
            },
            mysql_auto_reconnect => TRUE,
            mysql_enable_utf8    => TRUE,
            PrintError           => FALSE,
            RaiseError           => TRUE
        }
    };

    # For internal use only
    $self->{'_dsn'} = '';
    $self->{'_currentUser'} = '';
    $self->{'_currentPassword'} = '';
    $self->{'_sql_default_extra_file'} = undef;
    $self;
}

=item AUTOLOAD( )

 Proxy to DBI::db

=cut

sub AUTOLOAD
{
    ( my $method = our $AUTOLOAD ) =~ s/.*:://;

    no strict 'refs';
    *{ $AUTOLOAD } = sub {
        shift;
        __PACKAGE__->getInstance()->connect()->$method( @_ );
    };

    goto &{ $AUTOLOAD };
}

=item DESTROY( )

 Destroy tasks

=cut

sub DESTROY
{
    # Needed due to AUTOLOAD
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
