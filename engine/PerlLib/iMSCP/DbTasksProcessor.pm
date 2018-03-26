=head1 NAME

 iMSCP::DbTasksProcessor - i-MSCP database tasks processor

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

package iMSCP::DbTasksProcessor;

use strict;
use warnings;
use Encode qw/ encode_utf8 /;
use iMSCP::Database;
use iMSCP::Debug qw/ debug newDebug endDebug /;
use iMSCP::Execute qw/ execute escapeShell /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Stepper qw/ step /;
use iMSCP::Modules;
use JSON;
use MIME::Base64 qw/ encode_base64 /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP database tasks processor.

=head1 PUBLIC METHODS

=over 4

=item processDbTasks

 Process all db tasks

 Return void die on failure

=cut

sub processDbTasks
{
    my ( $self ) = @_;

    iMSCP::EventManager->getInstance( 'beforeDbTasksProcessing' );

    # Process plugins tasks
    # Must always be processed first to allow the plugins registering their listeners on the event manager
    $self->_processDbTasks(
        'iMSCP::Modules::Plugin',
        "
            SELECT plugin_id AS id, plugin_name AS name
            FROM plugin
            WHERE plugin_status IN ('enabled', 'toinstall', 'toenable', 'toupdate', 'tochange', 'todisable', 'touninstall')
            AND plugin_error IS NULL AND plugin_backend = 'yes'
            ORDER BY plugin_priority DESC
        ",
        'per_entity_log_file'
    );
    # Process IP addresses
    $self->_processDbTasks(
        'iMSCP::Modules::IpAddr', "SELECT ip_id AS id, ip_number AS name FROM server_ips WHERE ip_status IN( 'toadd', 'tochange', 'todelete' )"
    );
    # Process SSL certificate toadd|tochange SSL certificates tasks
    $self->_processDbTasks(
        'iMSCP::Modules::SSLcertificate',
        "SELECT cert_id AS id, domain_type AS name FROM ssl_certs WHERE status IN ('toadd', 'tochange', 'todelete') ORDER BY cert_id ASC"
    );
    # Process toadd|tochange users tasks
    $self->_processDbTasks(
        'iMSCP::Modules::User',
        "
            SELECT admin_id AS id, admin_name AS name
            FROM admin
            WHERE admin_type = 'user'
            AND admin_status IN ('toadd', 'tochange', 'tochangepwd')
            ORDER BY admin_id ASC
        "
    );
    # Process toadd|tochange|torestore|toenable|todisable domain tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Domain',
        "
            SELECT domain_id AS id, domain_name AS name
            FROM domain
            JOIN admin ON(admin_id = domain_admin_id)
            WHERE domain_status IN ('toadd', 'tochange', 'torestore', 'toenable', 'todisable')
            AND admin_status IN('ok', 'disabled')
            ORDER BY domain_id ASC
        "
    );
    # Process toadd|tochange|torestore|toenable|todisable subdomains tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Subdomain',
        "
            SELECT subdomain_id AS id, CONCAT(subdomain_name, '.', domain_name) AS name
            FROM subdomain
            JOIN domain USING(domain_id)
            WHERE subdomain_status IN ('toadd', 'tochange', 'torestore', 'toenable', 'todisable')
            AND domain_status IN('ok', 'disabled')
            ORDER BY subdomain_id ASC
        "
    );
    # Process toadd|tochange|torestore|toenable|todisable domain aliases tasks
    # (for each entity, process only if the parent entity is in a consistent state)
    $self->_processDbTasks(
        'iMSCP::Modules::Alias',
        "
           SELECT alias_id AS id, alias_name AS name
           FROM domain_aliasses
           JOIN domain USING(domain_id)
           WHERE alias_status IN ('toadd', 'tochange', 'torestore', 'toenable', 'todisable')
           AND domain_status IN('ok', 'disabled')
           ORDER BY alias_id ASC
        "
    );
    # Process toadd|tochange|torestore|toenable|todisable subdomains of domain aliases tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::SubAlias',
        "
            SELECT subdomain_alias_id AS id, CONCAT(subdomain_alias_name, '.', alias_name) AS name
            FROM subdomain_alias
            JOIN domain_aliasses USING(alias_id)
            WHERE subdomain_alias_status IN ('toadd', 'tochange', 'torestore', 'toenable', 'todisable')
            AND alias_status IN('ok', 'disabled')
            ORDER BY subdomain_alias_id ASC
        "
    );
    # Process toadd|tochange|toenable||todisable|todelete custom DNS records group which belong to domains
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::CustomDNS',
        "
            SELECT CONCAT(t1.domain_id, ';', 0) AS id, t2.domain_name AS name
            FROM domain_dns AS t1
            JOIN domain AS t2 ON(t2.domain_id = t1.domain_id)
            WHERE t1.domain_dns_status IN ('toadd', 'tochange', 'toenable', 'todisable', 'todelete')
            AND t1.alias_id = 0
            AND t2.domain_status IN('ok', 'disabled')
            GROUP BY t1.domain_id, t2.domain_name
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete custom DNS records group which belong to domain aliases
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::CustomDNS',
        "
            SELECT CONCAT(t1.domain_id, ';', t1.alias_id) AS id, t2.alias_name AS name
            FROM domain_dns AS t1
            JOIN domain_aliasses AS t2 ON(t2.alias_id = t1.alias_id)
            WHERE t1.domain_dns_status IN ('toadd', 'tochange', 'toenable', 'todisable', 'todelete')
            AND t1.alias_id <> 0
            AND t2.alias_status IN('ok', 'disabled')
            GROUP BY t1.alias_id, t1.domain_id, t2.alias_name
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete ftp users tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::FtpUser',
        "
            SELECT userid AS id, userid AS name
            FROM ftp_users
            JOIN domain ON(domain_admin_id = admin_id)
            WHERE status IN ('toadd', 'tochange', 'toenable', 'todelete', 'todisable')
            AND domain_status IN('ok', 'todelete', 'disabled')
            ORDER BY userid ASC
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete mail tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Mail',
        "
            SELECT mail_id AS id, mail_addr AS name
            FROM mail_users
            JOIN domain USING(domain_id)
            WHERE status IN ('toadd', 'tochange', 'toenable', 'todelete', 'todisable')
            AND domain_status IN('ok', 'todelete', 'disabled')
            ORDER BY mail_id ASC
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete Htusers tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Htpasswd',
        "
            SELECT id, uname AS name
            FROM htaccess_users
            JOIN domain ON(domain_id = dmn_id)
            WHERE status IN ('toadd', 'tochange', 'toenable', 'todelete', 'todisable')
            AND domain_status IN('ok', 'todelete', 'disabled')
            ORDER BY id ASC
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete Htgroups tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Htgroup',
        "
            SELECT id, ugroup AS name
            FROM htaccess_groups
            JOIN domain ON(domain_id = dmn_id)
            WHERE status IN ('toadd', 'tochange', 'toenable', 'todelete', 'todisable')
            AND domain_status IN('ok', 'todelete', 'disabled')
            ORDER BY id ASC
        "
    );
    # Process toadd|tochange|toenable|todisable|todelete Htaccess tasks
    # For each entity, process only if the parent entity is in a consistent state
    $self->_processDbTasks(
        'iMSCP::Modules::Htaccess',
        "
            SELECT id, auth_name AS name
            FROM htaccess
            JOIN domain ON(domain_id = dmn_id)
            WHERE status IN ('toadd', 'tochange', 'toenable', 'todelete', 'todisable')
            AND domain_status IN('ok', 'todelete', 'disabled')
            ORDER BY id ASC
        "
    );
    # Process todelete subdomain aliases tasks
    $self->_processDbTasks(
        'iMSCP::Modules::SubAlias',
        "
            SELECT subdomain_alias_id AS id, concat(subdomain_alias_name, '.', alias_name) AS name
            FROM subdomain_alias
            JOIN domain_aliasses USING(alias_id)
            WHERE subdomain_alias_status = 'todelete'
            ORDER BY subdomain_alias_id ASC
        "
    );
    # Process todelete domain aliases tasks
    # For each entity, process only if the entity do not have any direct children
    $self->_processDbTasks(
        'iMSCP::Modules::Alias',
        "
            SELECT alias_id AS id, alias_name AS name
            FROM domain_aliasses
            LEFT JOIN (SELECT DISTINCT alias_id FROM subdomain_alias) AS subdomain_alias  USING(alias_id)
            WHERE alias_status = 'todelete'
            AND subdomain_alias.alias_id IS NULL
            ORDER BY alias_id ASC
        "
    );
    # Process todelete subdomains tasks
    $self->_processDbTasks(
        'iMSCP::Modules::Subdomain',
        "
            SELECT subdomain_id AS id, CONCAT(subdomain_name, '.', domain_name) AS name
            FROM subdomain
            JOIN domain USING(domain_id)
            WHERE subdomain_status = 'todelete'
            ORDER BY subdomain_id ASC
        "
    );
    # Process todelete domains tasks
    # For each entity, process only if the entity do not have any direct children
    $self->_processDbTasks(
        'iMSCP::Modules::Domain',
        "
            SELECT domain_id AS id, domain_name AS name
            FROM domain
            LEFT JOIN (SELECT DISTINCT domain_id FROM subdomain) as subdomain USING (domain_id)
            WHERE domain_status = 'todelete'
            AND subdomain.domain_id IS NULL
            ORDER BY domain_id ASC
        "
    );
    # Process todelete users tasks
    # For each entity, process only if the entity do not have any direct children
    $self->_processDbTasks(
        'iMSCP::Modules::User',
        "
            SELECT admin_id AS id, admin_name AS name
            FROM admin
            LEFT JOIN domain ON(domain_admin_id = admin_id)
            WHERE admin_type = 'user'
            AND admin_status = 'todelete'
            AND domain_id IS NULL
            ORDER BY admin_id ASC
        "
    );

    # Process software package tasks

    my $rows = $self->{'_dbh'}->selectall_hashref(
        "
            SELECT domain_id, alias_id, subdomain_id, subdomain_alias_id, software_id, path, software_prefix,
                db, database_user, database_tmp_pwd, install_username, install_password, install_email,
                software_status, software_depot, software_master_id
            FROM web_software_inst
            WHERE software_status IN ('toadd', 'todelete')
            ORDER BY domain_id ASC
        ",
        'software_id'
    );

    if ( %{ $rows } ) {
        newDebug( 'imscp_sw_mngr_engine' );

        for my $row ( values %{ $rows } ) {
            my $pushString = encode_base64(
                encode_json( [
                    $row->{'domain_id'}, $row->{'software_id'}, $row->{'path'}, $row->{'software_prefix'}, $row->{'db'},
                    $row->{'database_user'}, $row->{'database_tmp_pwd'}, $row->{'install_username'},
                    $row->{'install_password'}, $row->{'install_email'}, $row->{'software_status'},
                    $row->{'software_depot'}, $row->{'software_master_id'}, $row->{'alias_id'},
                    $row->{'subdomain_id'}, $row->{'subdomain_alias_id'}
                ] ),
                ''
            );

            my ( $stdout, $stderr );
            execute( "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/imscp-sw-mngr " . escapeShell( $pushString ), \$stdout, \$stderr ) == 0 or die(
                $stderr || 'Unknown error'
            );
            debug( $stdout ) if length $stdout;
            execute( "rm -fR /tmp/sw-$row->{'domain_id'}-$row->{'software_id'}", \$stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
            debug( $stdout ) if length $stdout;
        }

        endDebug();
    }

    # Process software tasks
    $rows = $self->{'_dbh'}->selectall_hashref(
        "
            SELECT software_id, reseller_id, software_archive, software_status, software_depot
            FROM web_software
            WHERE software_status = 'toadd'
            ORDER BY reseller_id ASC
        ",
        'software_id'
    );

    if ( %{ $rows } ) {
        newDebug( 'imscp_pkt_mngr_engine.log' );

        for my $row ( values %{ $rows } ) {
            my $pushstring = encode_base64(
                encode_json( [
                    $row->{'software_id'}, $row->{'reseller_id'}, $row->{'software_archive'}, $row->{'software_status'}, $row->{'software_depot'}
                ] ),
                ''
            );

            my ( $stdout, $stderr );
            execute( "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/imscp-pkt-mngr " . escapeShell( $pushstring ), \$stdout, \$stderr ) == 0 or die(
                $stderr || 'Unknown error'
            );
            debug( $stdout ) if length $stdout;
            execute( "rm -fR /tmp/sw-$row->{'software_archive'}-$row->{'software_id'}", \$stdout,
                \$stderr ) == 0 or die( $stderr || 'Unknown error' );
            debug( $stdout ) if length $stdout;
        }

        endDebug();
    }

    iMSCP::EventManager->getInstance( 'afterDbTasksProcessing' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::DbTasksProcessor or die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    # Load all modules
    iMSCP::Modules->getInstance();

    $self->{'_dbh'} = iMSCP::Database->getInstance();
    $self->{'_needStepper'} = !iMSCP::Getopt->noprompt && iMSCP::Getopt->context() =~ /^(?:un)?installer$/;
    $self;
}

=item _processDbTasks( $module, $sql [, $perItemLogFile = FALSE ] )

 Process the db tasks for the given module

 Param string $module Module responsible to handle the db task
 Param string $sql SQL statement for retrieval of list of entities to process by the given module
 Param bool $perItemLogFile Enable per entity log file (default is per module log file)
 Return void, die on failure

=cut

sub _processDbTasks
{
    my ( $self, $module, $sql, $perItemLogFile ) = @_;

    debug( sprintf( 'Processing %s DB tasks...', $module ));

    my $sth = $self->{'_dbh'}->prepare( $sql );
    $sth->execute();

    my $countRows = $sth->rows();
    unless ( $countRows ) {
        debug( sprintf( 'No DB task to process for %s', $module ));
        return;
    }

    my ( $moduleInstance, $nStep ) = ( $module->getInstance(), 1 );
    while ( my $row = $sth->fetchrow_hashref() ) {
        my $name = encode_utf8( $row->{'name'} );
        debug( sprintf( 'Processing %s DB tasks for: %s (ID %s)', $module, $name, $row->{'id'} ));
        newDebug( $module . ( ( $perItemLogFile ) ? "_${name}" : '' ) . '.log' );

        if ( $self->{'_needStepper'} ) {
            step(
                sub { $moduleInstance->handleEntity( $row->{'id'} ) },
                sprintf( 'Processing %s DB tasks for: %s (ID %s)', $module, $name, $row->{'id'} ),
                $countRows,
                $nStep++
            );
        } else {
            $moduleInstance->handleEntity( $row->{'id'} );
        }

        endDebug();
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
