=head1 NAME

 iMSCP::Servers::Mta::Postfix::Driver::Database::MySQL - i-MSCP MySQL database driver for Postfix

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

package iMSCP::Servers::Mta::Postfix::Driver::Database::MySQL;

use strict;
use warnings;
use autouse 'iMSCP::Crypt' => qw/ ALNUM randomStr /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Database iMSCP::Dir iMSCP::File iMSCP::Servers::Sqld /;
use iMSCP::Boolean;
use iMSCP::Umask;
use parent 'iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract';

=head1 DESCRIPTION

 i-MSCP MySQL database driver for Postfix.
 
 See http://www.postfix.org/MYSQL_README.html
 See http://www.postfix.org/mysql_table.5.html
 See http://www.postfix.org/proxymap.8.html

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setupDatabases();
}

=item uninstall( )

 See iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $dbh = iMSCP::Database->getInstance();
    my $oldDbName = $dbh->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));
    $dbh->do(
        "
            DROP VIEW IF EXISTS postfix_virtual_alias_maps, postfix_virtual_mailbox_domains, postfix_virtual_mailbox_maps, postfix_relay_domains,
            postfix_transport_maps
        "
    );
    $dbh->useDatabase( $oldDbName ) if length $oldDbName;
    iMSCP::Dir->new( dirname => $self->{'mta'}->{'config'}->{'MTA_DB_DIR'} )->remove();
    iMSCP::Servers::Sqld->factory()->dropUser( 'imscp_postfix_user', $::imscpOldConfig{'DATABASE_USER_HOST'} );
}

=item setBackendPermissions( )

 See iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( $self->{'mta'}->{'config'}->{'MTA_DB_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $self->{'mta'}->{'config'}->{'MTA_GROUP'},
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item getDbType( )

 See iMSCP::Server::Mta::Posfix::Driver::Database::Abstract::getDbType()

=cut

sub getDbType
{
    my ( $self ) = @_;

    'mysql';
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setupDatabases( )

 Setup default databases

 Return void, die on failure

=cut

sub _setupDatabases
{
    my ( $self ) = @_;

    # Create SQL views

    $self->_createSqlViews();

    # Create SQL user

    my $sdata = {
        DATABASE_USER     => 'imscp_postfix_user',
        DATABASE_PASSWORD => randomStr( 16, ALNUM ),
        DATABASE_HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
        DATABASE_NAME     => ::setupGetQuestion( 'DATABASE_NAME' )
    };

    my $sqlUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $sqlServer = iMSCP::Servers::Sqld->factory();

    for my $host ( $sqlUserHost, $::imscpOldConfig{'DATABASE_USER_HOST'} ) {
        next unless length $host;
        $sqlServer->dropUser( $sdata->{'DATABASE_USER'}, $host );
    }

    $sqlServer->createUser( $sdata->{'DATABASE_USER'}, $sqlUserHost, $sdata->{'DATABASE_PASSWORD'} );

    # Grant privileges to SQL user

    my $dbh = iMSCP::Database->getInstance();
    my $qDbName = $dbh->quote_identifier( ::setupGetQuestion( 'DATABASE_NAME' ));

    for ( qw/ virtual_alias_maps virtual_mailbox_domains virtual_mailbox_maps relay_domains transport_maps / ) {
        $dbh->do( "GRANT SELECT ON $qDbName.postfix_$_ TO ?\@?", undef, $sdata->{'DATABASE_USER'}, $sqlUserHost );
    }

    # Create MySQL source files

    my $dbDir = $self->{'mta'}->{'config'}->{'MTA_DB_DIR'};

    # Changes the umask once. The change will be effective for the full
    # enclosing block, that is, to the scope of this routine.
    local $UMASK = 0027;

    # Make sure to start with a clean directory by re-creating it from scratch
    iMSCP::Dir->new( dirname => $self->{'mta'}->{'config'}->{'MTA_DB_DIR'} )->remove()->make( {
        group => $self->{'mta'}->{'config'}->{'MTA_GROUP'}
    } );

    # virtual_alias_maps.cf
    $self->{'mta'}->buildConfFile( iMSCP::File->new( filename => "$dbDir/virtual_alias_maps.cf" )->set( <<'EOF' ),
# Postfix virtual_alias_maps MySQL source file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
user     = {DATABASE_USER}
password = {DATABASE_PASSWORD}
hosts    = {DATABASE_HOST}
dbname   = {DATABASE_NAME}
query    = SELECT goto FROM postfix_virtual_alias_maps WHERE address = '%s'
EOF
        undef, undef, $sdata, { create => TRUE, group => $self->{'mta'}->{'config'}->{'MTA_GROUP'} }
    );

    # virtual_mailbox_domains.cf
    $self->{'mta'}->buildConfFile( iMSCP::File->new( filename => "$dbDir/virtual_mailbox_domains.cf" )->set( <<'EOF' ),
# Postfix virtual_mailbox_domains MySQL source file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
user     = {DATABASE_USER}
password = {DATABASE_PASSWORD}
hosts    = {DATABASE_HOST}
dbname   = {DATABASE_NAME}
query    = SELECT domain_name FROM postfix_virtual_mailbox_domains WHERE domain_name = '%s'
EOF
        undef, undef, $sdata, { create => TRUE, group => $self->{'mta'}->{'config'}->{'MTA_GROUP'} }
    );

    # virtual_mailbox_maps.cf
    $self->{'mta'}->buildConfFile( iMSCP::File->new( filename => "$dbDir/virtual_mailbox_maps.cf" )->set( <<'EOF' ),
# Postfix virtual_mailbox_maps MySQL source file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
user     = {DATABASE_USER}
password = {DATABASE_PASSWORD}
hosts    = {DATABASE_HOST}
dbname   = {DATABASE_NAME}
query    = SELECT maildir FROM postfix_virtual_mailbox_maps WHERE username = '%s'
EOF
        undef, undef, $sdata, { create => TRUE, group => $self->{'mta'}->{'config'}->{'MTA_GROUP'} }
    );

    # relay_domains.cf
    $self->{'mta'}->buildConfFile( iMSCP::File->new( filename => "$dbDir/relay_domains.cf" )->set( <<'EOF' ),
# Postfix relay_domains MySQL source file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
user     = {DATABASE_USER}
password = {DATABASE_PASSWORD}
hosts    = {DATABASE_HOST}
dbname   = {DATABASE_NAME}
query    = SELECT domain_name FROM postfix_relay_domains WHERE domain_name = '%s'
EOF
        undef, undef, $sdata, { create => TRUE, group => $self->{'mta'}->{'config'}->{'MTA_GROUP'}, mode => 0640 }
    );

    # transport_maps.cf
    $self->{'mta'}->buildConfFile( iMSCP::File->new( filename => "$dbDir/transport_maps.cf" )->set( <<'EOF' ),
# Postfix transport_maps MySQL source file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
user     = {DATABASE_USER}
password = {DATABASE_PASSWORD}
hosts    = {DATABASE_HOST}
dbname   = {DATABASE_NAME}
query    = SELECT transport FROM postfix_transport_maps WHERE address = '%s'
EOF
        undef, undef, $sdata, { create => TRUE, group => $self->{'mta'}->{'config'}->{'MTA_GROUP'}, mode => 0640 }
    );

    # Add configuration in the main.cf file
    my $dbType = $self->getDbType();
    $self->{'mta'}->postconf(
        virtual_alias_domains   => { values => [ '' ], empty => TRUE },
        virtual_alias_maps      => { values => [ "proxy:$dbType:$dbDir/virtual_alias_maps.cf" ] },
        virtual_mailbox_domains => { values => [ "proxy:$dbType:$dbDir/virtual_mailbox_domains.cf" ] },
        virtual_mailbox_maps    => { values => [ "proxy:$dbType:$dbDir/virtual_mailbox_maps.cf" ] },
        relay_domains           => { values => [ "proxy:$dbType:$dbDir/relay_domains.cf" ] },
        transport_maps          => { values => [ "proxy:$dbType:$dbDir/transport_maps.cf" ] }
    );
}

=item _createSqlViews( )

 Create SQL views for postfix databases

 Return void, die on failure

=cut

sub _createSqlViews
{
    my ( $self ) = @_;

    my $dbh = iMSCP::Database->getInstance();
    my $oldDbName = $dbh->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));

    # Create the SQL view for the virtual_alias_maps map
    $dbh->do( <<'EOF' );
CREATE OR REPLACE VIEW postfix_virtual_alias_maps AS
SELECT mail_forward AS goto, mail_addr AS address FROM mail_users WHERE mail_type LIKE '%forward%' AND status = 'ok'
UNION ALL SELECT mail_acc AS goto, mail_addr AS address FROM mail_users WHERE mail_type LIKE '%catchall%' AND status = 'ok'
EOF
    # Create the SQL view for the virtual_mailbox_domains map
    $dbh->do( <<'EOF' );
CREATE OR REPLACE VIEW postfix_virtual_mailbox_domains AS
SELECT domain_name FROM domain WHERE domain_status <> 'disabled' AND external_mail = 'off'
UNION ALL
SELECT CONCAT(t1.subdomain_name, '.', t2.domain_name) FROM subdomain AS t1 JOIN domain AS t2 USING(domain_id)
WHERE t1.subdomain_status <> 'disabled' AND t2.external_mail = 'off'
UNION ALL
SELECT alias_name FROM domain_aliasses WHERE alias_status <> 'disabled' AND external_mail = 'off'
UNION ALL
SELECT CONCAT(t1.subdomain_alias_name, '.', t2.alias_name) FROM subdomain_alias AS t1 JOIN domain_aliasses AS t2 USING(alias_id)
WHERE t1.subdomain_alias_status <> 'disabled' AND t2.external_mail = 'off'
EOF
    # Create the SQL view for the virtual_mailbox_maps map
    $dbh->do( <<"EOF" );
CREATE OR REPLACE VIEW postfix_virtual_mailbox_maps AS
SELECT CONCAT('$self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/', SUBSTRING(mail_addr, LOCATE('\@', mail_addr) + 1), '/', mail_acc, '/') AS maildir,
mail_addr AS username FROM mail_users WHERE mail_type LIKE '%mail%' AND status = 'ok'
EOF
    # Create SQL view for the relay_domains map
    $dbh->do( <<"EOF" );
CREATE OR REPLACE VIEW postfix_relay_domains AS
SELECT domain_name FROM domain WHERE domain_status <> 'disabled' AND external_mail = 'on'
UNION ALL
SELECT alias_name FROM domain_aliasses WHERE alias_status <> 'disabled' AND external_mail = 'on'
EOF
    # Create the SQL view for the transport_maps map (for vacation entries only)
    $dbh->do( <<'EOF' );
CREATE OR REPLACE VIEW postfix_transport_maps AS
SELECT mail_addr AS address, 'imscp-arpl:' AS transport FROM mail_users WHERE mail_auto_respond = 1 AND mail_auto_respond_text IS NOT NULL
AND status = 'ok'
EOF
    $dbh->useDatabase( $oldDbName ) if length $oldDbName;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
