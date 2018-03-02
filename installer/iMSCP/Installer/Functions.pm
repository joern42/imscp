=head1 NAME

 iMSCP::Installer::Functions - Functions for the i-MSCP installer

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

package iMSCP::Installer::Functions;

use strict;
use warnings;
use File::Basename;
use File::Find qw/ find /;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Config;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug error output /;
use iMSCP::Dialog;
use iMSCP::Dialog::InputValidation qw/ isStringInList /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use iMSCP::Stepper qw/ step /;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Service;
use iMSCP::Umask;
use Net::LibIDN qw/ idn_to_unicode /;
use JSON qw/ decode_json /;
use XML::Simple;
use version;
use parent 'Exporter';

our @EXPORT_OK = qw/ loadConfig build install expandVars /;

# Installer instance
my $DISTRO_INSTALLER;

=head1 DESCRIPTION

 Common functions for the i-MSCP installer

=head1 PUBLIC FUNCTIONS

=over 4

=item loadConfig( )

 Load main i-MSCP configuration

 Return void, die on failure

=cut

sub loadConfig
{
    # Gather system information
    my $sysInfo = eval {
        my $facter = iMSCP::ProgramFinder::find( 'facter' ) or die( "Couldn't find facter executable in \$PATH" );
        decode_json( `$facter _2.5.1_ --json architecture os virtual 2> /dev/null` );
    };
    !$@ or die( sprintf( "Couldn't gather system information: %s", $@ ));

    # Fix for the osfamily FACT that is badly detected by FACTER(8) for Devuan (Linux instead of Debian)
    $sysInfo->{'os'}->{'osfamily'} = 'Debian' if $sysInfo->{'os'}->{'lsb'}->{'distid'} eq 'Devuan';

    # Load the master i-MSCP configuration file
    tie %::imscpConfig, 'iMSCP::Config', filename => "$FindBin::Bin/configs/imscp.conf", readonly => TRUE, temporary => TRUE;

    # Override the master i-MSCP configuration file with parameters from the
    # OS family master configuration file if any
    if ( -f "$FindBin::Bin/configs/$sysInfo->{'os'}->{'family'}/imscp.conf" ) {
        tie my %distroConfig, 'iMSCP::Config',
            filename  => "$FindBin::Bin/configs/$sysInfo->{'os'}->{'family'}/imscp.conf",
            readonly  => TRUE,
            temporary => TRUE;
        @::imscpConfig{keys %distroConfig} = values %distroConfig;
        untie( %distroConfig );
    }

    # Override the master i-MSCP configuration file with parameters from the
    # distribution ID master configuration file if any
    if ( $sysInfo->{'os'}->{'lsb'}->{'distid'} ne $sysInfo->{'os'}->{'family'}
        && -f "$FindBin::Bin/configs/$sysInfo->{'os'}->{'lsb'}->{'distid'}/imscp.conf"
    ) {
        tie my %distroConfig, 'iMSCP::Config',
            filename  => "$FindBin::Bin/configs/$sysInfo->{'os'}->{'lsb'}->{'distid'}/imscp.conf",
            readonly  => TRUE,
            temporary => TRUE;
        @::imscpConfig{keys %distroConfig} = values %distroConfig;
        untie( %distroConfig );
    }

    # Load old master i-MSCP configuration file
    if ( -f "$::imscpConfig{'CONF_DIR'}/imscpOld.conf" ) {
        # Recovering case (after update or installation failure)
        tie %::imscpOldConfig, 'iMSCP::Config', filename => "$::imscpConfig{'CONF_DIR'}/imscpOld.conf", readonly => TRUE, temporary => TRUE;
    } elsif ( -f "$::imscpConfig{'CONF_DIR'}/imscp.conf" ) {
        # Update case
        tie %::imscpOldConfig, 'iMSCP::Config', filename => "$::imscpConfig{'CONF_DIR'}/imscp.conf", readonly => TRUE, temporary => TRUE;
    } else {
        # Fresh installation case
        %::imscpOldConfig = %::imscpConfig;
    }

    if ( tied( %::imscpOldConfig ) ) {
        debug( 'Merging old configuration with new configuration...' );

        # Entries that we want keep in %::imscpConfig
        my @toKeepFromNew = @::imscpConfig{ qw/ BuildDate Version CodeName PluginApi THEME_ASSETS_VERSION / };

        # Fill %::imscpConfig with values from %::imscpOldConfig
        while ( my ( $key, $value ) = each( %::imscpOldConfig ) ) {
            $::imscpConfig{$key} = $value if exists $::imscpConfig{$key};
        }

        # Restore entries that we wanted to keep in %::imscpConfig
        @::imscpConfig{ qw/ BuildDate Version CodeName PluginApi THEME_ASSETS_VERSION / } = @toKeepFromNew;
        undef( @toKeepFromNew );

        # Make sure that %::imscpOldConfig contains all expected parameters (e.g. case of new parameters)
        while ( my ( $param, $value ) = each( %::imscpConfig ) ) {
            $::imscpOldConfig{$param} = $value unless exists $::imscpOldConfig{$param};
        }
    }

    # Set/Update the distribution lsb/system info
    @::imscpConfig{qw/ DISTRO_FAMILY DISTRO_ID DISTRO_CODENAME DISTRO_RELEASE DISTRO_ARCH SYSTEM_INIT SYSTEM_VIRTUALIZER /} = (
        $sysInfo->{'os'}->{'family'},
        $sysInfo->{'os'}->{'lsb'}->{'distid'},
        $sysInfo->{'os'}->{'lsb'}->{'distcodename'},
        $sysInfo->{'os'}->{'lsb'}->{'distrelease'},
        $sysInfo->{'architecture'},
        iMSCP::Service->getInstance()->getInitSystem(),
        $sysInfo->{'virtual'}
    );

    # Init variable that holds questions if not already done (eg. by preseed file)
    %::questions = () unless %::questions;

    # Load i-MSCP listener files
    iMSCP::EventManager->getInstance();
}

=item build( )

 Process build tasks

 Return void, die on failure

=cut

sub build
{
    # If one of those parameter is not set, we need force processing of package files
    unless ( length $::imscpConfig{'iMSCP::Servers::Cron'} && length $::imscpConfig{'iMSCP::Servers::Ftpd'}
        && length $::imscpConfig{'iMSCP::Servers::Httpd'} && length $::imscpConfig{'iMSCP::Servers::Mta'}
        && length $::imscpConfig{'iMSCP::Servers::Named'} && length $::imscpConfig{'iMSCP::Servers::Php'}
        && length $::imscpConfig{'iMSCP::Servers::Po'} && length $::imscpConfig{'iMSCP::Servers::Server'}
        && length $::imscpConfig{'iMSCP::Servers::Sqld'}
    ) {
        iMSCP::Getopt->noprompt( 0 ) unless iMSCP::Getopt->preseed;
        iMSCP::Getopt->verbose( 0 ) unless iMSCP::Getopt->noprompt;
        iMSCP::Getopt->skippackages( 0 );
    }

    print STDOUT output( 'Build steps in progress... Please wait.', 'info' ) if iMSCP::Getopt->noprompt;

    my $dialog = iMSCP::Dialog->getInstance();

    if ( !iMSCP::Getopt->noprompt && isStringInList( 'none', @{ iMSCP::Getopt->reconfigure } ) ) {
        _showWelcomeMsg( $dialog ) unless iMSCP::Getopt->buildonly;
        _showUpdateWarning( $dialog ) if $::imscpOldConfig{'Version'} ne $::imscpConfig{'Version'};
        _confirmDistro( $dialog ) unless iMSCP::Getopt->buildonly;
        _askInstallerMode( $dialog ) unless iMSCP::Getopt->buildonly;
    }

    my @steps = (
        [ \&_packDistributionFiles, 'Packing required distribution files' ],
        [ \&_removeObsoleteFiles, 'Removing obsolete files' ],
        [ \&_savePersistentData, 'Saving persistent data' ]
    );

    iMSCP::EventManager->getInstance()->trigger( 'preBuild', \@steps );

    _getInstaller()->preBuild( \@steps );

    my ( $nStep, $nbSteps ) = ( 1, scalar @steps );
    for my $step ( @steps ) {
        step( @{ $step }, $nbSteps, $nStep++ );
    }

    iMSCP::Dialog->getInstance()->endGauge();
    _getInstaller()->postBuild();

    # Make $::DESTDIR free of any .gitkeep file
    {
        local $SIG{'__WARN__'} = sub { die @_ };
        find(
            {
                wanted   => sub { unlink or die( sprintf( "Failed to remove the %s file: %s", $_, $! )) if /\.gitkeep$/; },
                no_chdir => TRUE
            },
            $::{'DESTDIR'}
        );
    }

    iMSCP::EventManager->getInstance()->trigger( 'afterPostBuild' );

    my %confmap = (
        imscp    => \%::imscpConfig,
        imscpOld => \%::imscpOldConfig
    );

    # Write configuration in $::{'DESTDIR'}
    while ( my ( $name, $config ) = each %confmap ) {
        iMSCP::File->new( filename => "$::{'IMSCP_CONF_DIR'}/$name.conf" )->save( 0027 ) if $name eq 'imscpOld';

        tie my %config, 'iMSCP::Config', filename => "$::{'IMSCP_CONF_DIR'}/$name.conf";
        @config{ keys %{ $config } } = values %{ $config };
        untie %config;
    }
    undef( %confmap );

    iMSCP::EventManager->getInstance()->trigger( 'postBuild' );

    return unless iMSCP::Getopt->buildonly;

    my $output = <<"EOF";
@{[ iMSCP::Getopt->noprompt ? 'i-MSCP has been successfully built.' : '\\Z4\\ZuBuild Steps Successful\\Zn' ]}

To continue, you must execute the following commands:

 rm -fR $::imscpConfig{'ROOT_DIR'}/{engine,gui}
 cp -PRT --preserve=ownership,mode $::{'DESTDIR'} /
 rm -fR $::{'DESTDIR'}
 perl $::imscpConfig{'ROOT_DIR'}/engine/setup/imscp-reconfigure -d
EOF
    iMSCP::Getopt->noprompt ? print STDOUT output( $output, 'ok' ) : iMSCP::Dialog->getInstance()->infobox( $output );
}

=item install( )

 Process install tasks

 Return int 0 on success, other otherwise

=cut

sub install
{
    print STDOUT output( 'Installation in progress... Please wait.', 'info' ) if iMSCP::Getopt->noprompt;

    {
        package main;
        require "$FindBin::Bin/engine/setup/imscp-setup-methods.pl";
    }

    my $bootstrapper = iMSCP::Bootstrapper->getInstance();
    my @runningJobs = ();

    for my $job (
        qw/ imscp-backup-all imscp-backup-imscp imscp-dsk-quota imscp-srv-traff imscp-vrl-traff awstats_updateall.pl imscp-disable-accounts imscp /
    ) {
        next if $bootstrapper->lock( "$::imscpConfig{'LOCK_DIR'}/$job.lock", 'nowait' );
        push @runningJobs, $job,
    }

    if ( @runningJobs ) {
        iMSCP::Dialog->getInstance()->msgbox( <<"EOF" );

There are i-MSCP jobs currently running on your system. You must wait until the end of these jobs.

Running jobs are: @runningJobs
EOF
        exit 1;
    }

    undef @runningJobs;

    my @steps = (
        ( iMSCP::Getopt->skippackages ? () : [ \&_installDistributionPackages, 'Installing distribution packages' ] ),
        [ \&_checkRequirements, 'Checking for requirements' ],
        [ \&installDistributionFiles, 'Installing distribution files' ],
        [ \&::setupBoot, 'Booting installer' ],
        [ \&::setupRegisterListeners, 'Registering servers/packages event listeners' ],
        [ \&::setupDialog, 'Processing installation dialogs' ],
        [ \&::setupTasks, 'Processing installation tasks' ],
        [ \&::setupDeleteBuildDir, 'Deleting temporary files' ]
    );

    iMSCP::EventManager->getInstance()->trigger( 'preInstall', \@steps );
    _getInstaller()->preInstall( \@steps );

    my ( $nStep, $nbSteps ) = ( 1, scalar @steps );
    for my $step ( @steps ) {
        step( @{ $step }, $nbSteps, $nStep++ );
    }

    iMSCP::Dialog->getInstance()->endGauge();
    _getInstaller()->postInstall();
    iMSCP::EventManager->getInstance()->trigger( 'postInstall' );

    # Destroy the distribution installer as we don't need it anymore
    undef $DISTRO_INSTALLER;

    my $port = $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'} eq 'http://'
        ? $::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'};
    my $vhost = idn_to_unicode( $::imscpConfig{'BASE_SERVER_VHOST'}, 'utf-8' ) // '';
    my $output = <<"EOF";
@{[ iMSCP::Getopt->noprompt ? 'i-MSCP has been successfully installed/updated.' : '\\Zbi-MSCP has been successfully installed/updated.\\Zb' ]}

Please connect to $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'}$vhost:$port and login with your administrator account.

Thank you for choosing i-MSCP.
EOF
    iMSCP::Getopt->noprompt ? print STDOUT output( $output, 'ok' ) : iMSCP::Dialog->getInstance()->infobox( $output );
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _installPreRequiredPackages( )

 Trigger pre-required package installation tasks

 Return void, die on failure

=cut

sub _installPreRequiredPackages
{
    _getInstaller()->installPreRequiredPackages();
}

=item _showWelcomeMsg( \%dialog )

 Show welcome message

 Param iMSCP::Dialog \%dialog
 Return void, die on failure

=cut

sub _showWelcomeMsg
{
    my ( $dialog ) = @_;

    exit if $dialog->msgbox( <<"EOF" );

\\Zb\\Z4i-MSCP - internet Multi Server Control Panel
============================================\\Zn

Welcome to the i-MSCP setup dialog.

i-MSCP (internet Multi Server Control Panel) is a software easing shared hosting environments management on Linux servers.
It support various services such as Apache2, ProFTPD, VsFTPD, Dovecot, Courier, Bind9... and can be easily extended through plugins and/or event listener files.

i-MSCP was designed for professional Hosting Service Providers (HSPs), Internet Service Providers (ISPs) and IT professionals.

\\Zb\\Z4License\\Zn

Unless otherwise stated all code is licensed under LGPL 2.1 and has the following copyright:

\\ZbCopyright © 2010-2018, Laurent Declercq (i-MSCP)
All rights reserved\\ZB
EOF
}

=item _showUpdateWarning( \%dialog )

 Show update warning

 Return void, exit when user is aborting

=cut

sub _showUpdateWarning
{
    my ( $dialog ) = @_;

    my $warning = '';
    if ( $::imscpConfig{'Version'} =~ /git/i ) {
        $warning = <<"EOF";

The installer detected that you intend to install an i-MSCP development version.

We would remind you that development versions can be highly unstable and that they are not supported by the i-MSCP team.

Before you continue, be sure to have read the errata file:

    \\Zbhttps://github.com/i-MSCP/imscp/blob/1.6.x/docs/1.6.x_errata.md\\ZB
EOF
    } elsif ( $::imscpOldConfig{'Version'} ne $::imscpConfig{'Version'} ) {
        $warning = <<"EOF";

Before you continue, be sure to have read the errata file which is located at

    \\Zbhttps://github.com/i-MSCP/imscp/blob/1.6.x/docs/1.6.x_errata.md\\ZB
EOF
    }

    return unless length $warning;

    local $dialog->{'opts'}->{'yes-label'} = 'Continue';
    local $dialog->{'opts'}->{'no-label'} = 'Abort';

    exit 50 if $dialog->yesno( <<"EOF", TRUE );

\\Zb\\Z1WARNING \\Z0PLEASE READ CAREFULLY \\Z1WARNING\\Zn
$warning
You can now either continue or abort.
EOF
}

=item _confirmDistro( \%dialog )

 Distribution confirmation dialog

 Param iMSCP::Dialog \%dialog
 Return void, exit on failure or when user abort or doesn't confirm the distribution

=cut

sub _confirmDistro
{
    my ( $dialog ) = @_;

    if ( length $::imscpConfig{'DISTRO_ID'} && length $::imscpConfig{'DISTRO_RELEASE'} && length $::imscpConfig{'DISTRO_CODENAME'} ) {
        my $packagesFile = "$::imscpConfig{'DISTRO_ID'}-$::imscpConfig{'DISTRO_CODENAME'}.xml";

        unless ( -f "$FindBin::Bin/installer/Packages/$packagesFile" ) {
            $dialog->msgbox( <<"EOF" );

\\Z1$::imscpConfig{'DISTRO_ID'} $::imscpConfig{'DISTRO_RELEASE'}/@{ [ ucfirst $::imscpConfig{'DISTRO_CODENAME'} ] } not supported yet\\Zn

We are sorry but no packages file has been found for your $::imscpConfig{'DISTRO_ID'} version.

Thanks for choosing i-MSCP.
EOF
            exit 1
        }

        exit if ( my $rs = $dialog->yesno( <<"EOF" ) ) == 50;

$::imscpConfig{'DISTRO_ID'} $::imscpConfig{'DISTRO_RELEASE'}/@{ [ ucfirst $::imscpConfig{'DISTRO_CODENAME'} ] } has been detected. Is this ok?
EOF
        return unless $rs;

        $dialog->msgbox( <<"EOF" );

\\Z1Distribution not supported\\Zn

We are sorry but the installer has failed to detect your distribution.

Please report the problem to i-MSCP team.

Thanks for choosing i-MSCP.
EOF
    } else {
        $dialog->msgbox( <<"EOF" );

\\Z1Distribution not supported\\Zn

We are sorry but your distribution is not supported yet.

Thanks for choosing i-MSCP.
EOF
    }

    exit 1;
}

=item _askInstallerMode( \%dialog )

 Asks for installer mode

 Param iMSCP::Dialog \%dialog
 Return void, exit when user is aborting

=cut

sub _askInstallerMode
{
    my ( $dialog ) = @_;

    local $dialog->{'opts'}->{'cancel-label'} = 'Abort';

    my %choices = ( 'auto', 'Automatic installation', 'manual', 'Manual installation' );
    my ( $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, 'auto' );
Please choose the installer mode:

See https://wiki.i-mscp.net/doku.php?id=start:installer#installer_modes for a full description of the installer modes.
\\Z \\Zn
EOF

    exit 50 if $rs;

    iMSCP::Getopt->buildonly( $value eq 'manual' );
}

=item _installDistributionPackages( )

 Install distribution packages

 Return void, die on failure

=cut

sub _installDistributionPackages
{
    _getInstaller()->installPackages();
}

=item _packDistributionFiles( )

 Pack distribution files

 Return void, die on failure

=cut

sub _packDistributionFiles
{
    _packConfigFiles();
    _packEngineFiles();
    _packFrontendFiles();
}

=item _checkRequirements( )

 Check for requirements

 Return undef if all requirements are met, throw a fatal error otherwise

=cut

sub _checkRequirements
{
    iMSCP::Requirements->new()->all();
}

=item _packConfigFiles( )

 Pack configuration files

 Return void, die on failure

=cut

sub _packConfigFiles
{
    # Process master install.xml file
    #
    # In order of preference:
    # Distribution master install.xml file (for Instance: Ubuntu)
    # Distribution family master install.xml file (For instance: Debian)
    _processXmlInstallFile( -f "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/install.xml"
        ? "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/install.xml"
        : "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_FAMILY'}/install.xml"
    );

    my $distroFamilyConfDir = "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_FAMILY'}";
    my $distroConfDir = $::imscpConfig{'DISTRO_ID'} ne $::imscpConfig{'DISTRO_FAMILY'} && -d "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}"
        ? "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}" : $distroFamilyConfDir;

    for my $dir ( iMSCP::Dir->new( dirname => $distroFamilyConfDir )->getDirs() ) {
        my $installFile = $distroConfDir ne $distroFamilyConfDir && -f "$distroConfDir/$dir/install.xml"
            ? "$distroConfDir/$dir/install.xml" : "$distroFamilyConfDir/$dir/install.xml";

        next unless -f $installFile;

        _processXmlInstallFile( $installFile );
    }

    iMSCP::File->new( filename => "$FindBin::Bin/configs/imscp.conf" )->copy(
        "$::{'IMSCP_CONF_DIR'}/imscp.conf", { umask => 0027, preserve => FALSE }
    );

    # Copy database schema
    iMSCP::Dir->new( dirname => "$FindBin::Bin/configs/database" )->copy( "$::{'IMSCP_CONF_DIR'}/database", { umask => 0027, preserve => FALSE } );
}

=item _packEngineFiles( )

 Pack engine files

 Return void, die on failure

=cut

sub _packEngineFiles
{
    _processXmlInstallFile( "$FindBin::Bin/engine/install.xml" );

    for my $dir ( iMSCP::Dir->new( dirname => "$FindBin::Bin/engine" )->getDirs() ) {
        next unless -f "$FindBin::Bin/engine/$dir/install.xml";
        _processXmlInstallFile( "$FindBin::Bin/engine/$dir/install.xml" );
    }
}

=item _packFrontendFiles( )

 Pack frontEnd files

 Return void, die on failure

=cut

sub _packFrontendFiles
{
    iMSCP::Dir->new( dirname => "$FindBin::Bin/gui" )->copy( "$::{'IMSCP_ROOT_DIR'}/gui", { umask => 0027, preserve => FALSE } );
}

=item _savePersistentData( )

 Save persistent data

 Return void, die on failure

=cut

sub _savePersistentData
{
    # Change the umask once instead of passing umask option to each copy() call.
    # The change will be effective for the full enclosing block.
    local $UMASK = 0027;

    # Move old skel directory to new location
    iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/apache/skel" )->copy(
        "$::imscpConfig{'CONF_DIR'}/skel"
    ) if -d "$::imscpConfig{'CONF_DIR'}/apache/skel"; # To be moved in cleanup routine from apache server

    # FIXME: Should we really do that?
    iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/skel" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'CONF_DIR'}/skel"
    ) if -d "$::imscpConfig{'CONF_DIR'}/skel";

    # Move old listener files to new location
    iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/hooks.d" )->copy(
        "$::imscpConfig{'CONF_DIR'}/listeners.d"
    ) if -d "$::imscpConfig{'CONF_DIR'}/hooks.d";

    # Save ISP logos (older location)
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/themes/user_logos" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/data/persistent/ispLogos"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/themes/user_logos";

    # Save ISP logos (new location)
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/data/ispLogos" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/data/persistent/ispLogos"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/data/ispLogos";

    # Save GUI logs
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/data/logs" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/data/logs"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/data/logs";

    # Save GUI persistent data
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/data/persistent" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/data/persistent"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/data/persistent";

    # Save software (older path ./gui/data/softwares) to new path (./gui/data/persistent/softwares)
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/data/softwares" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/data/persistent/softwares"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/data/softwares";

    # Save plugins
    iMSCP::Dir->new( dirname => "$::imscpConfig{'PLUGINS_DIR'}" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'PLUGINS_DIR'}"
    ) if -d $::imscpConfig{'PLUGINS_DIR'};

    # Quick fix for #IP-1340 (Removes old filemanager directory which is no longer used)
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/public/tools/filemanager" )->remove();

    # Save tools
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/gui/public/tools" )->copy(
        "$::{'DESTDIR'}$::imscpConfig{'ROOT_DIR'}/gui/public/tools"
    ) if -d "$::imscpConfig{'ROOT_DIR'}/gui/public/tools";
}

=item _removeObsoleteFiles( )

 Removes obsolete files

 Return void, die on failure

=cut

sub _removeObsoleteFiles
{
    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    for my $dir ( "$::imscpConfig{'CACHE_DATA_DIR'}/addons",
        "$::imscpConfig{'CONF_DIR'}/apache/backup",                   # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/skel/alias/phptmp",        # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/skel/subdomain/phptmp",    # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/working",                  # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/courier/backup",                  # To be moved in cleanup routine from Courier server
        "$::imscpConfig{'CONF_DIR'}/courier/working",                 # To be moved in cleanup routine from Courier server
        "$::imscpConfig{'CONF_DIR'}/cron.d",                          # To be moved in cleanup routine from Cron server
        "$::imscpConfig{'CONF_DIR'}/fcgi",                            # To be moved in cleanup routine from PHP server
        "$::imscpConfig{'CONF_DIR'}/hooks.d",                         # To be moved in cleanup routine from local server
        "$::imscpConfig{'CONF_DIR'}/init.d",                          # To be moved in cleanup routine from local server
        "$::imscpConfig{'CONF_DIR'}/nginx",                           # To be moved in cleanup routine from nginx server
        "$::imscpConfig{'CONF_DIR'}/php/apache",                      # To be moved in cleanup routine from php server
        "$::imscpConfig{'CONF_DIR'}/php/fcgi",                        # To be moved in cleanup routine from php server
        "$::imscpConfig{'CONF_DIR'}/php-fpm",                         # To be moved in cleanup routine from php server
        "$::imscpConfig{'CONF_DIR'}/postfix/backup",                  # To be moved in cleanup routine from postfix server
        "$::imscpConfig{'CONF_DIR'}/postfix/imscp",                   # To be moved in cleanup routine from postfix server
        "$::imscpConfig{'CONF_DIR'}/postfix/parts",                   # To be moved in cleanup routine from postfix server
        "$::imscpConfig{'CONF_DIR'}/postfix/working",                 # To be moved in cleanup routine from php server
        "$::imscpConfig{'CONF_DIR'}/skel/domain/domain_disable_page", # To be moved in cleanup routine from httpd server
        "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/.composer",         # To be moved in cleanup routine from local server
        "$::imscpConfig{'LOG_DIR'}/imscp-arpl-msgr"                   # To be moved in cleanup routine from postfix server
    ) {
        iMSCP::Dir->new( dirname => $dir )->remove();
    }

    for my $file ( "$::imscpConfig{'CONF_DIR'}/apache/parts/domain_disabled_ssl.tpl", # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/parts/domain_redirect.tpl",                # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/parts/domain_redirect_ssl.tpl",            # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/parts/domain_ssl.tpl",                     # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/vsftpd/imscp_allow_writeable_root.patch",         # To be moved in cleanup routine from vsftpd server
        "$::imscpConfig{'CONF_DIR'}/vsftpd/imscp_pthread_cancel.patch",               # To be moved in cleanup routine from vsftpd server
        "$::imscpConfig{'CONF_DIR'}/apache/parts/php5.itk.ini",                       # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/apache/vlogger.sql",                              # To be moved in cleanup routine from Apache2 server
        "$::imscpConfig{'CONF_DIR'}/dovecot/dovecot.conf.2.0",                        # To be moved in cleanup routine from dovecot server
        "$::imscpConfig{'CONF_DIR'}/dovecot/dovecot.conf.2.1",                        # To be moved in cleanup routine from dovecot server
        "$::imscpConfig{'CONF_DIR'}/frontend/00_master.conf",                         # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/frontend/00_master_ssl.conf",                     # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/frontend/imscp_fastcgi.conf",                     # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/frontend/imscp_php.conf",                         # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/frontend/nginx.conf",                             # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/frontend/php-fcgi-starter",                       # To be moved in cleanup routine from frontend package
        "$::imscpConfig{'CONF_DIR'}/listeners.d/README",                              # To be moved in cleanup routine from local server
        "$::imscpConfig{'CONF_DIR'}/php/fpm/logrotate.tpl",                           # To be moved in cleanup routine from php server
        "$::imscpConfig{'CONF_DIR'}/skel/domain/.htgroup",                            # To be moved in cleanup routine from apache server
        "$::imscpConfig{'CONF_DIR'}/skel/domain/.htpasswd",                           # To be moved in cleanup routine from apache server
        "$::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar",
        "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/composer.phar",
        "$::imscpConfig{'CONF_DIR'}/imscp.old.conf",                                  # To be moved in cleanup routine from local server
        "$::imscpConfig{'CONF_DIR'}/imscp-db-keys",                                   # To be moved in cleanup routine from local server
        '/etc/default/imscp_panel',                                                   # To be moved in cleanup routine from php server
        '/etc/init/php5-fpm.override',                                                # To be moved in cleanup routine from php server
        '/etc/logrotate.d/imscp',                                                     # To be moved in cleanup routine from local server
        '/etc/nginx/imscp_net2ftp.conf',                                              # To be moved in cleanup routine from local server
        '/etc/systemd/system/php5-fpm.override',                                      # To be moved in cleanup routine from php server
        '/usr/local/lib/imscp_panel/imscp_panel_checkconf',                           # To be moved in cleanup routine from frontend package
        '/usr/sbin/maillogconvert.pl'                                                 # To be moved in cleanup routine from postfix server
    ) {
        iMSCP::File->new( filename => $file )->remove();
    }
}

=item installDistributionFiles( )

 Install distribution files

 Return void, die on failure

=cut

sub installDistributionFiles
{
    # FIXME: Should be done by a specific package, eg: iMSCP::Packages::FrontEnd
    # FIXME: Should be done by a specific package, eg: iMSCP::Packages::Setup::Backend
    iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/$_" )->remove() for qw/ engine gui /;
    iMSCP::Dir->new( dirname => $::{'DESTDIR'} )->copy( '/', { preserve => TRUE } );
}

=item expandVars( $string )

 Expand variables in the given string

 Param string $string string containing variables to expands
 Return string

=cut

sub expandVars
{
    my ( $string ) = @_;
    $string //= '';

    while ( my ( $var ) = $string =~ /\$\{([^{}]+)\}/g ) {
        if ( defined $::{$var} ) {
            $string =~ s/\$\{$var\}/$::{$var}/;
        } elsif ( defined $::imscpConfig{$var} ) {
            $string =~ s/\$\{$var\}/$::imscpConfig{$var}/;
        } else {
            die( "Couldn't expand the \${$var} variable. Variable is not found." );
        }
    }

    $string;
}

=item _processXmlInstallFile( $installFilePath )

 Process an install.xml file

 Param string $installFilePath XML installation file path
 Return void, die on failure

=cut

sub _processXmlInstallFile
{
    my ( $installFilePath ) = @_;

    my $xml = XML::Simple->new( ForceArray => TRUE, ForceContent => TRUE, KeyAttr => [] );
    my $nodes = $xml->XMLin( $installFilePath, VarAttr => 'export', NormaliseSpace => 2 );

    local $CWD = dirname( $installFilePath );
    local $UMASK = oct( $nodes->{'umask'} ) if defined $nodes->{'umask'};

    # Process 'folder' nodes
    if ( $nodes->{'folder'} ) {
        for my $node ( @{ $nodes->{'folder'} } ) {
            $node->{'content'} = expandVars( $node->{'content'} );
            $::{$node->{'export'}} = $node->{'content'} if defined $node->{'export'};
            _processFolderNode( $node );
        }
    }

    # Process 'copy_config' nodes
    if ( $nodes->{'copy_config'} ) {
        for my $node ( @{ $nodes->{'copy_config'} } ) {
            $node->{'content'} = expandVars( $node->{'content'} );
            _processCopyConfigNode( $node );
        }
    }

    # Process 'copy' nodes
    if ( $nodes->{'copy'} ) {
        for my $node ( @{ $nodes->{'copy'} } ) {
            $node->{'content'} = expandVars( $node->{'content'} );
            _processCopyNode( $node );
        }
    }
}

=item _processFolderNode( \%node )

 Create a folder according the given node

 OPTIONAL node attributes:
  create_if     : Create the folder only if the condition is met
  pre_remove    : Whether the directory must be re-created from scratch
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
  user          : Folder owner
  group         : Folder group
  mode          : Folder mode
 Param hashref \%node Node
 Return void, die on failure

=cut

sub _processFolderNode
{
    my ( $node ) = @_;

    return unless length $node->{'content'} && ( !defined $node->{'create_if'} || eval expandVars( $node->{'create_if'} ) );

    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my $dir = iMSCP::Dir->new( dirname => $node->{'content'} );
    $dir->remove() if $node->{'pre_remove'};
    $dir->make( {
        user  => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
        group => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
        mode  => defined $node->{'mode'} ? oct( $node->{'mode'} ) : undef
    } );
}

=item _processCopyConfigNode( \%node )

 Copy a configuration directory or file according the given node

 Files that are being removed and which are located under one of /etc/init,
 /etc/init.d, /etc/systemd/system or /usr/local/lib/systemd/system directories
 are processed by the service provider. Specific treatment must be applied for
 these files. Removing them without further care could cause unexpected issues
 with the init system

 OPTIONAL node attributes:
  copy_if       : Copy the file or directory only if the condition is met, remove it otherwise, unless the keep_if_exists attribute is TRUE
  keep_if_exist : Don't delete the file or directory if it exists and if the keep_if_exist evaluate to TRUE
  copy_cwd      : Copy the $CWD directory (excluding the install.xml), instead of a directory in $CWD (current configuration directory)
  copy_as       : Destination file or directory name
  subdir        : Sub-directory in which file must be searched, relative to $CWD (current configuration directory)
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
  mode          : Destination file or directory mode
  dirmode       : Destination directory mode (can be set only if the mode attribute is not set)
  filemode      : Destination directory mode (can be set only if the mode attribute is not set)
  user          : Destination file or directory owner
  group         : Destination file or directory group
  recursive     : Whether or not ownership and permissions must be fixed recursively
  srv_provider  : Whether or not the give node must be processed by the service provider on removal (case of SysVinit, Upstart and Systemd conffiles)
                  That attribute must be set with the service name for which the system provider must act. This attribute is evaluated only when
                  the node provide the copy_if attribute and only if the expression (value) of that attribute evaluate to FALSE.
 Param hashref \%node Node
 Return void, die on failure

=cut

sub _processCopyConfigNode
{
    my ( $node ) = @_;

    if ( defined $node->{'copy_if'} && !eval expandVars( $node->{'copy_if'} ) ) {
        return if defined $node->{'keep_if_exist'} && eval expandVars( $node->{'keep_if_exist'} );

        my $syspath;
        if ( defined $node->{'copy_as'} ) {
            my ( undef, $dirs ) = fileparse( $node->{'content'} );
            ( $syspath = "$dirs/$node->{'copy_as'}" ) =~ s/^$::{'DESTDIR'}//;
        } else {
            ( $syspath = $node->{'content'} ) =~ s/^$::{'DESTDIR'}//;
        }

        return unless $syspath ne '/' && -e $syspath;

        if ( $node->{'srv_provider'} ) {
            iMSCP::Service->getInstance()->remove( $node->{'srv_provider'} );
            return;
        }

        if ( -d _ ) {
            iMSCP::Dir->new( dirname => $syspath )->remove();
        } else {
            iMSCP::File->new( filename => $syspath )->remove();
        }

        return;
    }

    local $CWD = dirname( $CWD ) if $node->{'copy_cwd'};
    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my ( $name, $dirs ) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $dest = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    if ( !-e $source && $::imscpConfig{'DISTRO_FAMILY'} ne $::imscpConfig{'DISTRO_ID'} ) {
        # If name isn't in $CWD(/$node->{'subdir'})?, search for it in the <DISTRO_FAMILY>(/$node->{'subdir'})? directory,
        $source =~ s%^($FindBin::Bin/configs/)$::imscpConfig{'DISTRO_ID'}%${1}$::imscpConfig{'DISTRO_FAMILY'}%;
        # stat again as _ refers to the previous stat structure
        stat $source or die( sprintf( "Couldn't stat %s: %s", $source, $! ));
    }

    if ( -d _ ) {
        iMSCP::Dir->new( dirname => $source )->copy( $dest );
        iMSCP::File->new( filename => $dest . '/install.xml' )->remove() if $node->{'copy_cwd'};
    } else {
        iMSCP::File->new( filename => $source )->copy( $dest );
    }

    setRights( $dest,
        {
            mode      => $node->{'mode'},
            dirmode   => $node->{'dirmode'},
            filemode  => $node->{'filemode'},
            user      => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
            group     => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
            recursive => $node->{'recursive'}
        }
    );
}

=item _processCopyNode( \%node )

 Copy a directory or file according the given node

 OPTIONAL node attributes:
  copy_if       : Copy the file or directory only if the condition is met, delete it otherwise, unless the keep_if_exists attribute is TRUE
  keep_if_exist : keep_if_exist : Don't delete the file or directory if it exists and if the keep_if_exist evaluate to TRUE
  copy_cwd      : Copy the $CWD directory (excluding the install.xml), instead of a directory in $CWD (current configuration directory)
  copy_as       : Destination file or directory name
  subdir        : Sub-directory in which file must be searched, relative to $CWD (current configuration directory)
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
  mode          : Destination file or directory mode
  dirmode       : Destination directory mode (can be set only if the mode attribute is not set)
  filemode      : Destination directory mode (can be set only if the mode attribute is not set)
  user          : Destination file or directory owner
  group         : Destination file or directory group
  recursive     : Whether or not ownership and permissions must be fixed recursively
 Param hashref \%node Node
 Return void, die on failure

=cut

sub _processCopyNode
{
    my ( $node ) = @_;

    if ( defined $node->{'copy_if'} && !eval expandVars( $node->{'copy_if'} ) ) {
        return if defined $node->{'keep_if_exist'} && eval expandVars( $node->{'keep_if_exist'} );

        ( my $syspath = $node->{'content'} ) =~ s/^$::{'INST_PREF'}//;
        return unless $syspath ne '/' && -e $syspath;

        if ( -d _ ) {
            iMSCP::Dir->new( dirname => $syspath )->remove();
        } else {
            iMSCP::File->new( filename => $syspath )->remove();
        }

        return;
    }

    local $CWD = dirname( $CWD ) if $node->{'copy_cwd'};
    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my ( $name, $dirs ) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $dest = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    if ( -d $source ) {
        iMSCP::Dir->new( dirname => $source )->copy( $dest );
    } else {
        iMSCP::File->new( filename => $source )->copy( $dest );
    }

    setRights( $dest,
        {
            mode      => $node->{'mode'},
            dirmode   => $node->{'dirmode'},
            filemode  => $node->{'filemode'},
            user      => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
            group     => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
            recursive => $node->{'recursive'}
        }
    );
}

=item _getInstaller( )

 Returns i-MSCP installer instance for the current distribution

 Return iMSCP::Installer::Abstract, die on failure

=cut

sub _getInstaller
{
    return $DISTRO_INSTALLER if $DISTRO_INSTALLER;

    $DISTRO_INSTALLER = "iMSCP::Installer::$::imscpConfig{'DISTRO_FAMILY'}";
    eval "require $DISTRO_INSTALLER; 1" or die( $@ );
    $DISTRO_INSTALLER = $DISTRO_INSTALLER->new();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
