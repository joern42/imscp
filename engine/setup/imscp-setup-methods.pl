#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declecq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Database;
use iMSCP::DbTasksProcessor;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dialog;
use iMSCP::Dir;
use iMSCP::DistPackageManager;
use iMSCP::EventManager;
use iMSCP::Execute qw/ executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Packages;
use iMSCP::Plugins;
use iMSCP::Servers;
use iMSCP::Service;
use iMSCP::Stepper;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use iMSCP::Umask;

sub setupBoot
{
    iMSCP::Bootstrapper->getInstance()->boot( {
        mode            => 'setup', # Backend mode
        config_readonly => TRUE,    # We do not allow writing in conffile at this time
        nodatabase      => TRUE     # We do not establish connection to the database at this time
    } );

    untie( %::imscpOldConfig ) if %::imscpOldConfig;

    unless ( -f "$::imscpConfig{'CONF_DIR'}/imscpOld.conf" ) {
        local $UMASK = 027;
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscp.conf" )->copyFile(
            "$::imscpConfig{'CONF_DIR'}/imscpOld.conf", { preserve => 'no' }
        );
        return $rs if $rs;
    }

    tie %::imscpOldConfig, 'iMSCP::Config', fileName => "$::imscpConfig{'CONF_DIR'}/imscpOld.conf";
    0;
}

sub setupTasks
{
    my $rs ||= step( \&setupRegisterEventListeners, 'Registering setup listeners', 11, 1 );
    $rs ||= step( \&setupDialogs, 'Processing setup dialogs', 11, 2 );
    $rs ||= step( \&setupSaveConfig, 'Saving configuration', 11, 3 );
    $rs ||= step( \&setupCreateMasterUser, 'Creating system master user', 11, 4 );
    $rs ||= step( \&setupCoreServices, 'Setup core services', 11, 5 );
    $rs ||= step( \&setupRegisterPluginListeners, 'Registering plugin setup listeners', 11, 6 );
    $rs ||= step( \&setupServersAndPackages, 'Processing servers/packages', 11, 7 );
    $rs ||= step( \&setupSetPermissions, 'Setting up permissions', 11, 8 );
    $rs ||= step( \&setupDbTasks, 'Processing DB tasks', 11, 9 );
    $rs ||= step( \&setupRestartServices, 'Restarting services', 11, 10 );
    $rs ||= step( \&setupRemoveOldConfig, 'Removing old configuration ', 11, 11 );
    $rs ||= iMSCP::EventManager->getInstance()->trigger( 'afterSetupTasks' );
}

sub setupRegisterEventListeners
{
    my ( $eventManager, $rs ) = ( iMSCP::EventManager->getInstance(), 0 );

    for my $server ( iMSCP::Servers->getInstance()->getList() ) {
        $rs = $server->factory()->setupRegisterEventListeners( $eventManager );
        return $rs if $rs;
    }

    for my $package ( iMSCP::Packages->getInstance()->getList() ) {
        $rs = $package->getInstance()->setupRegisterEventListeners( $eventManager );
        return $rs if $rs;
    }

    $rs;
}

sub setupDialogs
{
    my ( $rs, $dialogs ) = ( 0, [] );

    for my $server ( iMSCP::Servers->getInstance()->getList() ) {
        $rs = $server->factory()->registerInstallerDialogs( $dialogs );
        return $rs if $rs;
    }

    for my $package ( iMSCP::Packages->getInstance()->getList() ) {
        $rs = $package->getInstance()->registerInstallerDialogs( $dialogs );
        return $rs if $rs;
    }

    $rs ||= iMSCP::Dialog->getInstance()->executeDialogs( $dialogs );
}

#
## Setup subroutines
#

sub setupSaveConfig
{
    # Re-open main configuration file in read/write mode
    iMSCP::Bootstrapper->getInstance()->loadMainConfig( {
        nocreate        => TRUE,
        nodeferring     => TRUE,
        config_readonly => FALSE
    } );

    while ( my ( $key, $value ) = each( %::questions ) ) {
        next unless exists $::imscpConfig{$key};
        $::imscpConfig{$key} = $value;
    }

    0;
}

sub setupCreateMasterUser
{
    my $rs = iMSCP::SystemGroup->getInstance()->addSystemGroup( $::imscpConfig{'IMSCP_GROUP'} );
    $rs ||= iMSCP::SystemUser->new(
        username => $::imscpConfig{'IMSCP_USER'},
        group    => $::imscpConfig{'IMSCP_GROUP'},
        comment  => 'i-MSCP master user',
        home     => $::imscpConfig{'IMSCP_HOMEDIR'}
    )->addSystemUser();
    # Ensure that correct permissions are set on i-MSCP master user homedir (handle upgrade case)
    $rs ||= iMSCP::Dir->new( dirname => $::imscpConfig{'IMSCP_HOMEDIR'} )->make( {
        user           => $::imscpConfig{'IMSCP_USER'},
        group          => $::imscpConfig{'IMSCP_GROUP'},
        mode           => 0755,
        fixpermissions => TRUE # We fix permissions in any case
    } );

    0;
}

sub setupCoreServices
{
    my $serviceMngr = iMSCP::Service->getInstance();
    $serviceMngr->enable( $_ ) for 'imscp_daemon', 'imscp_traffic', 'imscp_mountall';
    0;
}

sub setupImportSqlSchema
{
    my ( $db, $file ) = @_;

    my $rs = iMSCP::EventManager->getInstance()->trigger( 'beforeSetupImportSqlSchema', \$file );
    return $rs if $rs;

    my $content = iMSCP::File->new( filename => $file )->get();
    return 1 unless defined $content;

    my $rdbh = $db->getRawDb();
    local $rdbh->{'RaiseError'} = TRUE;
    $rdbh->do( $_ ) for split /;\n/, $content =~ s/^(--[^\n]{0,})?\n//gmr;

    iMSCP::EventManager->getInstance()->trigger( 'afterSetupImportSqlSchema' );
}

sub setupSetPermissions
{
    for my $script ( 'set-engine-permissions.pl', 'set-gui-permissions.pl' ) {
        startDetail();

        my @options = (
            '--setup', ( iMSCP::Getopt->debug ? '--debug' : '' ),
            ( $script eq 'set-engine-permissions.pl' && iMSCP::Getopt->fixPermissions ? '--fix-permissions' : '' )
        );

        my $stderr;
        my $rs = executeNoWait(
            [ 'perl', "$::imscpConfig{'ENGINE_ROOT_DIR'}/setup/$script", @options ],
            ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                return unless ( shift ) =~ /^(.*)\t(.*)\t(.*)/;
                step( undef, $1, $2, $3 );
            } ),
            sub { $stderr .= shift; }
        );

        endDetail();

        if ( $rs ) {
            error( sprintf( 'Error while setting permissions: %s', $stderr || 'Unknown error' ));
            last;
        }
    }

    0;
}

sub setupDbTasks
{
    {
        my $tables = {
            ssl_certs       => 'status',
            admin           => [ 'admin_status', "AND admin_type = 'user'" ],
            domain          => 'domain_status',
            subdomain       => 'subdomain_status',
            domain_aliasses => 'alias_status',
            subdomain_alias => 'subdomain_alias_status',
            domain_dns      => 'domain_dns_status',
            ftp_users       => 'status',
            mail_users      => 'status',
            htaccess        => 'status',
            htaccess_groups => 'status',
            htaccess_users  => 'status',
            server_ips      => 'ip_status'
        };
        my $aditionalCondition;

        my $db = iMSCP::Database->factory();
        my $oldDbName = $db->useDatabase( setupGetQuestion( 'DATABASE_NAME' ));

        my $rdbh = $db->getRawDb();
        local $rdbh->{'RaiseError'} = TRUE;

        while ( my ( $table, $field ) = each %{ $tables } ) {
            if ( ref $field eq 'ARRAY' ) {
                $aditionalCondition = $field->[1];
                $field = $field->[0];
            } else {
                $aditionalCondition = ''
            }

            ( $table, $field ) = ( $rdbh->quote_identifier( $table ), $rdbh->quote_identifier( $field ) );
            $rdbh->do(
                "
                    UPDATE $table
                    SET $field = 'tochange'
                    WHERE $field NOT IN('toadd', 'torestore', 'toenable', 'todisable', 'disabled', 'ordered', 'todelete')
                    $aditionalCondition
                "
            );
            $rdbh->do( "UPDATE $table SET $field = 'todisable' WHERE $field = 'disabled' $aditionalCondition" );
        }

        $rdbh->do(
            "
                UPDATE plugin
                SET plugin_status = 'tochange', plugin_error = NULL
                WHERE plugin_status IN ('tochange', 'enabled')
                AND plugin_backend = 'yes'
            "
        );
        $db->useDatabase( $oldDbName ) if $oldDbName;
    }

    startDetail();
    iMSCP::DbTasksProcessor->getInstance( mode => 'setup' )->processDbTasks();
    endDetail();
    0;
}

sub setupRegisterPluginListeners
{
    my ( $dbh, $pluginNames ) = ( iMSCP::Database->factory(), undef );

    eval { $dbh->useDatabase( setupGetQuestion( 'DATABASE_NAME' )); };
    return 0 if $@; # Fresh install case

    {
        my $rdbh = $dbh->getRawDb();
        $rdbh->{'RaiseError'} = TRUE;
        $pluginNames = $rdbh->selectcol_arrayref( "SELECT plugin_name FROM plugin WHERE plugin_status = 'enabled'" );
    }

    if ( @{ $pluginNames } ) {
        my $eventManager = iMSCP::EventManager->getInstance();
        my $plugins = iMSCP::Plugins->getInstance();

        for my $pluginName ( $plugins->getList() ) {
            next unless grep ( $_ eq $pluginName, @{ $pluginNames } );
            my $pluginClass = $plugins->getClass( $pluginName );
            ( my $subref = $pluginClass->can( 'registerSetupListeners' ) ) or next;
            my $rs = $subref->( $pluginClass, $eventManager );
            return $rs if $rs;
        }
    }

    0;
}

sub setupServersAndPackages
{
    my @servers = iMSCP::Servers->getInstance()->getList();
    my @packages = iMSCP::Packages->getInstance()->getList();
    my @actions = ( 'preinstall', 'install', 'postinstall' );
    my $nbSteps = ( @servers+@packages ) * @actions;
    my ( $rs, $step ) = ( 0, 1 );

    ACTION:
    for my $action ( @actions ) {
        startDetails();
        for my $server ( @servers ) {
            $rs = step( sub { $server->factory()->$action() }, sprintf( "Executing %s %s tasks...", $server, $action ), $nbSteps, $step );
            last ACTION if $rs;
            $step++;
        }
        for my $package ( packages ) {
            $rs = step( sub { $package->getInstance()->$action() }, sprintf( "Executing %s %s tasks...", $package, $action ), $nbSteps, $step );
            last ACTION if $rs;
            $step++;
        }
        endDetail();

        next unless $action eq 'preinstall';
        iMSCP::DistPackageManager->getInstance()->processDelayedTasks();
    }

    endDetail() if $rs;
    $rs;
}

sub setupRestartServices
{
    my @services = ();
    my $eventManager = iMSCP::EventManager->getInstance();

    # This is a bit annoying but we have not choice.
    # Not doing this would prevent propagation of upstream changes (eg: static mount entries)
    my $rs = $eventManager->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] },
                [
                    sub {
                        iMSCP::Service->getInstance()->restart( 'imscp_mountall' );
                        0;
                    },
                    'i-MSCP mounts'
                ];
            0;
        },
        999
    );
    $rs ||= $eventManager->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] },
                [
                    sub {
                        iMSCP::Service->getInstance()->restart( 'imscp_traffic' );
                        0;
                    },
                    'i-MSCP Traffic Logger'
                ];
            0;
        },
        99
    );
    $rs ||= $eventManager->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] },
                [
                    sub {
                        iMSCP::Service->getInstance()->start( 'imscp_daemon' );
                        0;
                    },
                    'i-MSCP Daemon'
                ];
            0;
        },
        99
    );
    $rs ||= $eventManager->trigger( 'beforeSetupRestartServices', \@services );
    return $rs if $rs;

    startDetail();

    my $nbSteps = @services;
    my $step = 1;

    for ( @services ) {
        $rs = step( $_->[0], sprintf( 'Restarting/Starting %s service...', $_->[1] ), $nbSteps, $step );
        last if $rs;
        $step++;
    }

    endDetail();

    $rs ||= $eventManager->trigger( 'afterSetupRestartServices' );
}

sub setupRemoveOldConfig
{
    untie %::imscpOldConfig;
    iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscpOld.conf" )->delFile();
}

sub setupGetQuestion
{
    my ( $qname, $default ) = @_;
    $default //= '';

    if ( iMSCP::Getopt->preseed ) {
        return length $::questions{$qname} ? $::questions{$qname} : $default // '';
    }

    return $::questions{$qname} if length $::questions{$qname};
    exists $::imscpConfig{$qname} && length $::imscpConfig{$qname} ? $::imscpConfig{$qname} : $default // '';
}

sub setupSetQuestion
{
    $::questions{$_[0]} = $_[1];
}

1;
__END__
