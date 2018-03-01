#!/usr/bin/perl

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

use strict;
use warnings;
use File::Spec;
use iMSCP::Bootstrapper;
use iMSCP::Composer;
use iMSCP::Database;
use iMSCP::DbTasksProcessor;
use iMSCP::Debug qw/ error /;
use iMSCP::Dialog;
use iMSCP::Dialog::InputValidation qw/ isStringInList /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute qw/ executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Packages;
use iMSCP::Plugins;
use iMSCP::Servers;
use iMSCP::Service;
use iMSCP::Stepper qw/ endDetail startDetail step /;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use iMSCP::Umask;

sub setupBoot
{
    iMSCP::Bootstrapper->getInstance()->boot( {
        config_readonly => 1, # We do not allow writing in conffile at this time
        nodatabase      => 1  # We do not establish connection to the database at this time
    } );

    # FIXME: Should be done through the bootstrapper

    untie( %::imscpOldConfig ) if %::imscpOldConfig;

    # If we are not in installer context, we need first create the
    # imscpOld.conf file if it doesn't already exist
    unless ( iMSCP::Getopt->context() eq 'installer' && -f "$::imscpConfig{'CONF_DIR'}/imscpOld.conf" ) {
        iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscp.conf" )->copy(
            "$::imscpConfig{'CONF_DIR'}/imscpOld.conf", { umask => 0027 }
        );
    }

    # We open the imscpOld.conf file in write mode. This is needed because some
    # servers will update it after processing tasks  that must be done once,
    # such as uninstallation tasks (older server alternatives)
    tie %::imscpOldConfig, 'iMSCP::Config', filename => "$::imscpConfig{'CONF_DIR'}/imscpOld.conf";

    if ( iMSCP::Getopt->context() eq 'installer' && iMSCP::Service->getInstance()->isSystemd() ) {
        # Unit files could have been updated. We need make systemd aware of changes
        iMSCP::Service->getInstance()->getProvider()->daemonReload();
    }
}

sub setupRegisterListeners
{

    $_->factory()->registerSetupListeners() for iMSCP::Servers->getInstance()->getListWithFullNames();

    my $eventManager = iMSCP::EventManager->getInstance();

    for my $package ( iMSCP::Packages->getInstance()->getListWithFullNames() ) {
        ( my $subref = $package->can( 'registerSetupListeners' ) ) or next;
        $subref->( $package->getInstance( eventManager => $eventManager ));
    }
}

sub setupDialog
{
    my $dialogStack = [];

    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupDialog', $dialogStack );

    # Implements a simple state machine (backup capability)
    # Any dialog subroutine *should* allow user to step back by returning 30
    # when the 'back' button is pushed In case of a 'yesno' dialog box, there
    # is no 'back' button. Instead, user can back up using the ESC keystroke.
    # In other contexts, the ESC keystroke make user able to abort.
    my ( $state, $nbDialog, $dialog ) = ( 0, scalar @{ $dialogStack }, iMSCP::Dialog->getInstance() );
    while ( $state < $nbDialog ) {
        $dialog->set( 'no-cancel', $state == 0 ? '' : undef );

        my $rs = $dialogStack->[$state]->( $dialog );
        exit $rs if $rs == 50;
        return $rs if $rs && $rs < 30;

        if ( $rs == 30 ) {
            iMSCP::Getopt->reconfigure( 'forced' ) if isStringInList( 'none', @{ iMSCP::Getopt->reconfigure } );
            $state--;
            next;
        }

        iMSCP::Getopt->reconfigure( 'none' ) if isStringInList( 'forced', @{ iMSCP::Getopt->reconfigure } );
        $state++;
    }

    $dialog->set( 'no-cancel', undef );
    
    iMSCP::EventManager->getInstance()->trigger( 'afterSetupDialog' );
}

sub setupTasks
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupTasks' );

    my @steps = (
        [ \&setupSaveConfig, 'Saving configuration' ],
        [ \&setupCreateMasterUser, 'Creating system master user' ],
        [ \&setupCoreServices, 'Setup core services' ],
        [ \&setupComposer, 'Setup PHP dependency manager (composer)' ],
        [ \&setupRegisterPluginListeners, 'Registering plugin setup listeners' ],
        [ \&setupServersAndPackages, 'Processing servers/packages' ],
        [ \&setupSetPermissions, 'Setting up permissions' ],
        [ \&setupDbTasks, 'Processing DB tasks' ],
        [ \&setupRestartServices, 'Restarting services' ],
        [ \&setupRemoveOldConfig, 'Removing old configuration ' ]
    );

    my ( $nStep, $nbSteps ) = ( 1, scalar @steps );
    for my $step ( @steps ) {
        step( @{ $step }, $nbSteps, $nStep++ );
    }

    iMSCP::Dialog->getInstance()->endGauge();
    iMSCP::EventManager->getInstance()->trigger( 'afterSetupTasks' );
}

sub setupDeleteBuildDir
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupDeleteBuildDir', $::{'DESTDIR'} );
    iMSCP::Dir->new( dirname => $::{'DESTDIR'} )->remove();
    iMSCP::EventManager->getInstance()->trigger( 'afterSetupDeleteBuildDir', $::{'DESTDIR'} );
}

#
## Setup subroutines
#

sub setupSaveConfig
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupSaveConfig' );

    # Re-open main configuration file in read/write mode
    iMSCP::Bootstrapper->getInstance()->loadMainConfig( {
        nocreate        => 1,
        nodeferring     => 1,
        config_readonly => 0
    } );

    while ( my ( $key, $value ) = each( %::questions ) ) {
        next unless exists $::imscpConfig{$key};
        $::imscpConfig{$key} = $value;
    }

    iMSCP::EventManager->getInstance()->trigger( 'afterSetupSaveConfig' );
}

# FIXME: Should be done by the Local server
sub setupCreateMasterUser
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupCreateMasterUser' );
    iMSCP::SystemGroup->getInstance()->addSystemGroup( $::imscpConfig{'IMSCP_GROUP'} );
    iMSCP::SystemUser->new(
        username => $::imscpConfig{'IMSCP_USER'},
        group    => $::imscpConfig{'IMSCP_GROUP'},
        comment  => 'i-MSCP master user',
        home     => $::imscpConfig{'IMSCP_HOMEDIR'}
    )->addSystemUser();
    iMSCP::Dir->new( dirname => $::imscpConfig{'IMSCP_HOMEDIR'} )->make( {
        user           => $::imscpConfig{'IMSCP_USER'},
        group          => $::imscpConfig{'IMSCP_GROUP'},
        mode           => 0755,
        fixpermissions => 1 # We fix permissions in any case
    } );
    iMSCP::EventManager->getInstance()->trigger( 'afterSetupCreateMasterUser' );
}

sub setupCoreServices
{
    # FIXME: Should be done by a specific package, eg:
    # iMSCP::Packages::Daemon
    # iMSCP::Packages::Traffic
    # iMSCP::Packages::Mounts
    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->enable( $_ ) for 'imscp_traffic', 'imscp_mountall';
}

sub setupComposer
{
    # FIXME: Don't run composer as root user
    my $composer = iMSCP::Composer->new();
    $composer->setStdRoutines(
        sub {
            ( my $line = $_[0] ) =~ s/^\s+|\s+$//g;
            return unless length $line;

            step( undef, <<"EOT", 1, 1 );
Installing PHP dependency manager (composer)

$line

Depending on your connection speed, this may take few seconds...
EOT
        },
        sub {}
    );

    startDetail;
    # For safety reasons, we install the composer version that we know to work well for us.
    $composer->installComposer( '/usr/local/bin', 'composer', $::imscpConfig{'COMPOSER_VERSION'} );
    endDetail;

    #    # Create composer.phar compatibility symlink for backward compatibility
    #    if ( -l "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar" ) {
    #        unlink ( "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar" ) or die(
    #            sprintf( "Couldn't delete %s symlink: %s", "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar", $! )
    #        );
    #    }
    #
    #    symlink File::Spec->abs2rel( '/usr/local/bin/composer', $::imscpConfig{'IMSCP_HOMEDIR'} ),
    #        "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar" or die(
    #        sprintf( "Couldn't create backward compatibility symlink for composer.phar: %s", $! )
    #    );
    #
    #    iMSCP::File->new( filename => "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar" )->owner(
    #        $::imscpConfig{'IMSCP_USER'}, $::imscpConfig{'IMSCP_GROUP'}
    #    );
}

sub setupSetPermissions
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupSetPermissions' );

    for my $script ( 'set-engine-permissions.pl', 'set-gui-permissions.pl' ) {
        startDetail();

        my @options = (
            '--installer',
            ( iMSCP::Getopt->debug ? '--debug' : '' ),
            ( $script eq 'set-engine-permissions.pl' && iMSCP::Getopt->fixPermissions ? '--fix-permissions' : '' )
        );

        my $stderr;
        my $rs = executeNoWait(
            [ 'perl', "$::imscpConfig{'ENGINE_ROOT_DIR'}/setup/$script", @options ],
            ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose
                ? sub {}
                : sub {
                return unless ( shift ) =~ /^(.*)\t(.*)\t(.*)/;
                step( undef, $1, $2, $3 );
            }
            ),
            sub { $stderr .= shift; }
        );

        endDetail();
        !$rs or die( sprintf( 'Error while setting permissions: %s', $stderr || 'Unknown error' ));
    }

    iMSCP::EventManager->getInstance()->trigger( 'afterSetupSetPermissions' );
}

# Should be done through the iMSCP::DbTasksProcessor, even status changes
sub setupDbTasks
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupDbTasks' );

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

    my $db = iMSCP::Database->getInstance();
    my $oldDbName = $db->useDatabase( setupGetQuestion( 'DATABASE_NAME' ));

    while ( my ( $table, $field ) = each %{ $tables } ) {
        if ( ref $field eq 'ARRAY' ) {
            $aditionalCondition = $field->[1];
            $field = $field->[0];
        } else {
            $aditionalCondition = ''
        }

        ( $table, $field ) = ( $db->quote_identifier( $table ), $db->quote_identifier( $field ) );
        $db->do(
            "
                UPDATE $table
                SET $field = 'tochange'
                WHERE $field NOT IN('toadd', 'torestore', 'toenable', 'todisable', 'disabled', 'ordered', 'todelete')
                $aditionalCondition
            "
        );
        $db->do( "UPDATE $table SET $field = 'todisable' WHERE $field = 'disabled' $aditionalCondition" );
    }

    $db->do(
        "
            UPDATE plugin
            SET plugin_status = 'tochange', plugin_error = NULL
            WHERE plugin_status IN ('tochange', 'enabled')
            AND plugin_backend = 'yes'
        "
    );

    $db->useDatabase( $oldDbName ) if $oldDbName;

    startDetail();
    iMSCP::DbTasksProcessor->getInstance()->processDbTasks();
    endDetail();

    iMSCP::EventManager->getInstance()->trigger( 'afterSetupDbTasks' );
}

sub setupRegisterPluginListeners
{
    iMSCP::EventManager->getInstance()->trigger( 'beforeSetupRegisterPluginListeners' );

    my ( $db, $pluginNames ) = ( iMSCP::Database->getInstance(), undef );
    my $oldDbName = eval { $db->useDatabase( setupGetQuestion( 'DATABASE_NAME' )); };
    return if $@; # Fresh install case

    $pluginNames = $db->selectcol_arrayref( "SELECT plugin_name FROM plugin WHERE plugin_status = 'enabled'" );
    $db->useDatabase( $oldDbName ) if $oldDbName;

    if ( @{ $pluginNames } ) {
        my $eventManager = iMSCP::EventManager->getInstance();
        my $plugins = iMSCP::Plugins->getInstance();

        for my $pluginName ( $plugins->getList() ) {
            next unless grep ( $_ eq $pluginName, @{ $pluginNames } );
            my $pluginClass = $plugins->getClass( $pluginName );
            ( my $subref = $pluginClass->can( 'registerSetupListeners' ) ) or next;
            $subref->( $pluginClass, $eventManager );
        }
    }

    iMSCP::EventManager->getInstance()->trigger( 'afterSetupRegisterPluginListeners' );
}

sub setupServersAndPackages
{
    my $eventManager = iMSCP::EventManager->getInstance();
    my @servers = iMSCP::Servers->getInstance()->getListWithFullNames();
    my @packages = iMSCP::Packages->getInstance()->getListWithFullNames();
    my $nSteps = @servers;

    # First, we need to uninstall older servers  (switch to another alternative)
    for my $task ( qw/ PreUninstall Uninstall PostUninstall / ) {
        my $lcTask = lc( $task );
        $eventManager->trigger( 'beforeSetup' . $task . 'Servers' );
        startDetail();
        my $nStep = 1;
        # For uninstallation, we reverse server priorities
        for my $server ( reverse @servers ) {
            next if $::imscpOldConfig{$server} eq $::imscpConfig{$server} || !length $::imscpOldConfig{$server};

            step(
                sub { $server->factory( $::imscpOdlConfig{$server} )->$lcTask(); },
                sprintf( "Executing %s %s tasks...", $server, $lcTask ), $nSteps, $nStep++
            );

            $::imscpOdlConfig{$server} = $::imscpConfig{$server};
        }
        endDetail();
        $eventManager->trigger( 'afterSetup' . $task . 'Servers' );
    }

    $nSteps = @servers+@packages;

    for my $task ( qw/ PreInstall Install PostInstall / ) {
        if ( $task eq 'PostInstall' ) {
            iMSCP::Dialog->getInstance()->endGauge();
            use Data::Dumper;
            print Dumper( \@servers );
            print Dumper( \@packages );
            exit;
        }
        my $lcTask = lc( $task );
        startDetail();

        $eventManager->trigger( 'beforeSetup' . $task . 'Servers' );
        my $nStep = 1;
        for my $server ( @servers ) {
            step( sub { $server->factory()->$lcTask(); }, sprintf( "Executing %s %s tasks...", $server, $lcTask ), $nSteps, $nStep++ );
            $eventManager->trigger( 'afterSetup' . $task . 'Servers' );
        }

        $eventManager->trigger( 'beforeSetup' . $task . 'Packages' );
        for my $package ( @packages ) {
            ( my $subref = $package->can( $lcTask ) ) or $nStep++ && next;
            step(
                sub { $subref->( $package->getInstance( eventManager => $eventManager )) },
                sprintf( "Executing %s %s tasks...", $package, $lcTask ), $nSteps, $nStep++
            );
        }
        $eventManager->trigger( 'afterSetup' . $task . 'Packages' );

        endDetail();
    }
}

sub setupRestartServices
{
    my @services = ();
    my $eventManager = iMSCP::EventManager->getInstance();

    # This is a bit annoying but we have not choice.
    # Not doing this would prevent propagation of upstream changes (eg: static mount entries)
    $eventManager->registerOne(
        'beforeSetupRestartServices',
        sub { push @{ $_[0] }, [ sub { iMSCP::Service->getInstance()->restart( 'imscp_mountall' ); }, 'i-MSCP mounts' ]; },
        999
    );
    $eventManager->registerOne(
        'beforeSetupRestartServices',
        sub { push @{ $_[0] }, [ sub { iMSCP::Service->getInstance()->restart( 'imscp_traffic' ); }, 'i-MSCP Traffic Logger' ]; },
        99
    );
    $eventManager->trigger( 'beforeSetupRestartServices', \@services );

    startDetail();
    my ( $step, $nbSteps ) = ( 1, scalar @services );
    step( $_->[0], sprintf( 'Starting/Restarting %s service...', $_->[1] ), $nbSteps, $step++ ) for @services;
    endDetail();

    $eventManager->trigger( 'afterSetupRestartServices' );
}

sub setupRemoveOldConfig
{
    untie %::imscpOldConfig;
    iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscpOld.conf" )->remove();
}

sub setupGetQuestion
{
    my ( $qname, $default ) = @_;

    if ( iMSCP::Getopt->preseed ) {
        return exists $::questions{$qname} && length $::questions{$qname} ? $::questions{$qname} : $default // '';
    }

    return $::questions{$qname} if exists $::questions{$qname};

    exists $::imscpConfig{$qname} && length $::imscpConfig{$qname} ? $::imscpConfig{$qname} : $default // '';
}

sub setupSetQuestion
{
    $::questions{$_[0]} = $_[1];
}

1;
__END__
