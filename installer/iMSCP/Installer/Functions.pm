=head1 NAME

 iMSCP::Installer::Functions - Functions for the i-MSCP installer

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 by internet Multi Server Control Panel
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

package iMSCP::Installer::Functions;

use strict;
use warnings;
use Carp qw/ croak /;
use File::Basename;
use File::Find qw/ find /;
use iMSCP::Bootstrapper;
use iMSCP::Config;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug error /;
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
use JSON qw/ decode_json /;
use XML::Simple;
use version;
use parent 'Exporter';

our @EXPORT_OK = qw/ loadConfig build install /;

# Installer instance
my $DISTRO_INSTALLER;

=head1 DESCRIPTION

 Common functions for the i-MSCP installer

=head1 PUBLIC FUNCTIONS

=over 4

=item loadConfig( )

 Load main i-MSCP configuration

 Return void

=cut

sub loadConfig
{
    # Gather system information
    my $sysInfo = eval {
        my $facter = iMSCP::ProgramFinder::find( 'facter' ) or croak( "Couldn't find FACTER(8) program" );
        decode_json( `$facter _2.5.1_ --json os virtual 2> /dev/null` );
    };
    if ( $@ ) {
        error( sprintf( "Couldn't gather system information: %s", $@ ));
        return 1;
    }

    # Fix for the osfamily FACT that is badly detected by FACTER(8) for Devuan
    $sysInfo->{'os'}->{'osfamily'} = 'Debian' if $sysInfo->{'os'}->{'lsb'}->{'distid'} eq 'Devuan';

    # Load the i-MSCP master configuration file
    tie %main::imscpConfig, 'iMSCP::Config', fileName => "$FindBin::Bin/configs/imscp.conf", readonly => 1, temporary => 1;

    # Override the i-MSCP master configuration file with parameters from the
    # OS family configuration file if any
    if ( -f "$FindBin::Bin/configs/$sysInfo->{'os'}->{'family'}/imscp.conf" ) {
        tie my %distroConfig, 'iMSCP::Config',
            fileName  => "$FindBin::Bin/configs/$sysInfo->{'os'}->{'family'}/imscp.conf",
            readonly  => 1,
            temporary => 1;
        @main::imscpConfig{keys %distroConfig} = values %distroConfig;
        untie( %distroConfig );
    }

    # Override the i-MSCP master configuration file with parameters from the
    # distribution ID configuration file if any
    if ( $sysInfo->{'os'}->{'lsb'}->{'distid'} ne $sysInfo->{'os'}->{'family'}
        && -f "$FindBin::Bin/configs/$sysInfo->{'os'}->{'lsb'}->{'distid'}/imscp.conf"
    ) {
        tie my %distroConfig, 'iMSCP::Config',
            fileName  => "$FindBin::Bin/configs/$sysInfo->{'os'}->{'lsb'}->{'distid'}/imscp.conf",
            readonly  => 1,
            temporary => 1;
        @main::imscpConfig{keys %distroConfig} = values %distroConfig;
        untie( %distroConfig );
    }

    # Load old master configuration file
    if ( -f "$main::imscpConfig{'CONF_DIR'}/imscpOld.conf" ) {
        # Recovering case (after update or installation failure)
        tie %main::imscpOldConfig, 'iMSCP::Config', fileName => "$main::imscpConfig{'CONF_DIR'}/imscpOld.conf", readonly => 1, temporary => 1;
    } elsif ( -f "$main::imscpConfig{'CONF_DIR'}/imscp.conf" ) {
        # Update case
        tie %main::imscpOldConfig, 'iMSCP::Config', fileName => "$main::imscpConfig{'CONF_DIR'}/imscp.conf", readonly => 1, temporary => 1;
    } else {
        # Fresh installation case
        %main::imscpOldConfig = %main::imscpConfig;
    }

    if ( tied( %main::imscpOldConfig ) ) {
        debug( 'Merging old configuration with new configuration...' );

        # Entries that we want keep in %main::imscpConfig
        my @toKeepFromNew = @main::imscpConfig{ qw/ BuildDate Version CodeName PluginApi THEME_ASSETS_VERSION / };

        # Fill %main::imscpConfig with values from %main::imscpOldConfig
        while ( my ($key, $value) = each( %main::imscpOldConfig ) ) {
            $main::imscpConfig{$key} = $value if exists $main::imscpConfig{$key};
        }

        # Restore entries that we wanted to keep in %main::imscpConfig
        @main::imscpConfig{ qw/ BuildDate Version CodeName PluginApi THEME_ASSETS_VERSION / } = @toKeepFromNew;
        undef( @toKeepFromNew );

        # Make sure that %main::imscpOldConfig contains all expected parameters
        while ( my ($param, $value) = each( %main::imscpConfig ) ) {
            $main::imscpOldConfig{$param} = $value unless exists $main::imscpOldConfig{$param};
        }
    }

    # Set/Update the distribution lsb/system info
    @main::imscpConfig{qw/ DISTRO_FAMILY DISTRO_ID DISTRO_CODENAME DISTRO_RELEASE SYSTEM_INIT SYSTEM_VIRTUALIZER /} = (
        $sysInfo->{'os'}->{'family'},
        $sysInfo->{'os'}->{'lsb'}->{'distid'},
        $sysInfo->{'os'}->{'lsb'}->{'distcodename'},
        $sysInfo->{'os'}->{'lsb'}->{'distrelease'},
        iMSCP::Service->getInstance()->getInitSystem(),
        $sysInfo->{'virtual'}
    );

    # Load listener files
    iMSCP::EventManager->getInstance();
}

=item build( )

 Process build tasks

 Return int 0 on success, other on failure

=cut

sub build
{
    if ( $main::imscpConfig{'iMSCP::Packages::FrontEnd'} eq '' || $main::imscpConfig{'iMSCP::Servers::Ftpd'} eq ''
        || $main::imscpConfig{'iMSCP::Servers::Httpd'} eq '' || $main::imscpConfig{'iMSCP::Servers::Named'} eq ''
        || $main::imscpConfig{'iMSCP::Servers::Mta'} eq '' || $main::imscpConfig{'iMSCP::Servers::Php'} eq ''
        || $main::imscpConfig{'iMSCP::Servers::Po'} eq '' || $main::imscpConfig{'iMSCP::Servers::Sqld'} eq ''
    ) {
        iMSCP::Getopt->noprompt( 0 ) unless iMSCP::Getopt->preseed;
        iMSCP::Getopt->skippackages( 0 );
    }

    my $dialog = iMSCP::Dialog->getInstance();

    unless ( iMSCP::Getopt->noprompt || !isStringInList( 'none', @{iMSCP::Getopt->reconfigure} ) ) {
        my $rs = _showWelcomeMsg( $dialog );
        return $rs if $rs;

        if ( %main::imscpOldConfig ) {
            $rs = _showUpdateWarning( $dialog );
            return $rs if $rs;
        }

        $rs = _confirmDistro( $dialog );
        return $rs if $rs;
    }

    my $rs = 0;
    $rs = _askInstallerMode( $dialog ) unless iMSCP::Getopt->noprompt || iMSCP::Getopt->buildonly
        || !isStringInList( 'none', @{iMSCP::Getopt->reconfigure} );
    return $rs if $rs;

    my @steps = (
        [ \&_buildDistributionFiles, 'Building distribution files' ],
        ( iMSCP::Getopt->skippackages ? () : [ \&_installDistributionPackages, 'Installing distribution packages' ] ),
        [ \&_checkRequirements, 'Checking for requirements' ],
        [ \&_removeObsoleteFiles, 'Removing obsolete files' ],
        [ \&_savePersistentData, 'Saving persistent data' ]
    );

    $rs = iMSCP::EventManager->getInstance()->trigger( 'preBuild', \@steps );
    $rs ||= _getInstaller()->preBuild( \@steps );
    return $rs if $rs;

    my ($step, $nbSteps) = ( 1, scalar @steps );
    for ( @steps ) {
        $rs = step( @{$_}, $nbSteps, $step );
        error( 'An error occurred while performing build steps' ) if $rs && $rs != 50;
        return $rs if $rs;
        $step++;
    }

    iMSCP::Dialog->getInstance()->endGauge();

    $rs = iMSCP::EventManager->getInstance()->trigger( 'postBuild' );
    $rs ||= _getInstaller()->postBuild();
    return $rs if $rs;

    # Clean build directory (remove any .gitkeep file)
    find(
        sub {
            return unless $_ eq '.gitkeep';
            unlink or croak( sprintf( "Couldn't remove %s file: %s", $File::Find::name, $! ));
        },
        $main::{'DESTDIR'}
    );

    $rs = iMSCP::EventManager->getInstance()->trigger( 'afterPostBuild' );
    return $rs if $rs;

    my %confmap = (
        imscp    => \ %main::imscpConfig,
        imscpOld => \ %main::imscpOldConfig
    );

    # Write configuration
    while ( my ($name, $config) = each %confmap ) {
        if ( $name eq 'imscpOld' ) {
            local $UMASK = 027;
            iMSCP::File->new( filename => "$main::{'IMSCP_CONF_DIR'}/$name.conf" )->save();
        }

        tie my %config, 'iMSCP::Config', fileName => "$main::{'IMSCP_CONF_DIR'}/$name.conf";
        @config{ keys %{$config} } = values %{$config};
        untie %config;
    }
    undef( %confmap );

    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other otherwise

=cut

sub install
{
    {
        package main;
        require "$FindBin::Bin/engine/setup/imscp-setup-methods.pl";
    }

    my $bootstrapper = iMSCP::Bootstrapper->getInstance();
    my @runningJobs = ();

    for ( 'imscp-backup-all', 'imscp-backup-imscp', 'imscp-dsk-quota', 'imscp-srv-traff', 'imscp-vrl-traff',
        'awstats_updateall.pl', 'imscp-disable-accounts', 'imscp'
    ) {
        next if $bootstrapper->lock( "$main::imscpConfig{'LOCK_DIR'}/$_.lock", 'nowait' );
        push @runningJobs, $_,
    }

    if ( @runningJobs ) {
        iMSCP::Dialog->getInstance()->msgbox( <<"EOF" );

There are jobs currently running on your system that can not be locked by the installer.

You must wait until the end of these jobs.

Running jobs are: @runningJobs
EOF
        return 1;
    }

    undef @runningJobs;

    my @steps = (
        [ \&installDistributionFiles, 'Installing distribution files' ],
        [ \&main::setupBoot, 'Bootstrapping installer' ],
        [ \&main::setupRegisterListeners, 'Registering servers/packages event listeners' ],
        [ \&main::setupDialog, 'Processing setup dialog' ],
        [ \&main::setupTasks, 'Processing setup tasks' ],
        [ \&main::setupDeleteBuildDir, 'Deleting build directory' ]
    );

    my $rs = iMSCP::EventManager->getInstance()->trigger( 'preInstall', \@steps );
    $rs ||= _getInstaller()->preInstall( \@steps );
    return $rs if $rs;

    my $step = 1;
    my $nbSteps = @steps;
    for ( @steps ) {
        $rs = step( @{$_}, $nbSteps, $step );
        error( 'An error occurred while performing installation steps' ) if $rs;
        return $rs if $rs;
        $step++;
    }

    iMSCP::Dialog->getInstance()->endGauge();

    $rs = iMSCP::EventManager->getInstance()->trigger( 'postInstall' );
    $rs ||= _getInstaller()->postInstall();
    return $rs if $rs;

    # Destroy the distribution installer as we don't need it anymore
    undef $DISTRO_INSTALLER;

    require Net::LibIDN;
    Net::LibIDN->import( 'idn_to_unicode' );

    my $port = $main::imscpConfig{'BASE_SERVER_VHOST_PREFIX'} eq 'http://'
        ? $main::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $main::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'};
    my $vhost = idn_to_unicode( $main::imscpConfig{'BASE_SERVER_VHOST'}, 'utf-8' ) // '';

    iMSCP::Dialog->getInstance()->infobox( <<"EOF" );

\\Z1Congratulations\\Zn

i-MSCP has been successfully installed/updated.

Please connect to $main::imscpConfig{'BASE_SERVER_VHOST_PREFIX'}$vhost:$port and login with your administrator account.

Thank you for choosing i-MSCP.
EOF

    0;
}

=back

=head1 PRIVATE FUNCTIONS

=over 4

=item _installPreRequiredPackages( )

 Trigger pre-required package installation tasks

 Return int 0 on success, other otherwise

=cut

sub _installPreRequiredPackages
{
    _getInstaller()->installPreRequiredPackages();
}

=item _showWelcomeMsg( \%dialog )

 Show welcome message

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other otherwise

=cut

sub _showWelcomeMsg
{
    my ($dialog) = @_;

    $dialog->msgbox( <<"EOF" );

\\Zb\\Z4i-MSCP - internet Multi Server Control Panel
============================================\\Zn

Welcome to the i-MSCP setup dialog.

i-MSCP (internet Multi Server Control Panel) is a software easing shared hosting environments management on Linux servers.
It support various services such as Apache2, ProFTPd, Dovecot, Courier, Bind9, and can be easily extended through plugins.

i-MSCP was designed for professional Hosting Service Providers (HSPs), Internet Service Providers (ISPs) and IT professionals.

\\Zb\\Z4License\\Zn

Unless otherwise stated all code is licensed under GPL 2.0 and has the following copyright:

\\ZbCopyright 2010-2018, Laurent Declercq (i-MSCP)
All rights reserved\\ZB
EOF
}

=item _showUpdateWarning( \%dialog )

 Show update warning

 Return 0 on success, other on failure or when user is aborting

=cut

sub _showUpdateWarning
{
    my ($dialog) = @_;

    my $warning = '';
    if ( $main::imscpConfig{'Version'} !~ /git/i ) {
        $warning = <<"EOF";

Before you continue, be sure to have read the errata file which is located at

    \\Zbhttps://github.com/i-MSCP/imscp/blob/1.6.x/docs/1.6.x_errata.md\\ZB
EOF

    } else {
        $warning = <<"EOF";

The installer detected that you intend to install an i-MSCP development version.

We would remind you that development versions can be highly unstable and that they are not supported by the i-MSCP team.

Before you continue, be sure to have read the errata file:

    \\Zbhttps://github.com/i-MSCP/imscp/blob/1.6.x/docs/1.6.x_errata.md\\ZB
EOF
    }

    return 0 if $warning eq '';

    $dialog->set( 'yes-label', 'Continue' );
    $dialog->set( 'no-label', 'Abort' );
    return 50 if $dialog->yesno( <<"EOF", 'abort_by_default' );

\\Zb\\Z1WARNING \\Z0PLEASE READ CAREFULLY \\Z1WARNING\\Zn
$warning
You can now either continue or abort.
EOF

    $dialog->resetLabels();
    0;
}

=item _confirmDistro( \%dialog )

 Distribution confirmation dialog

 Param iMSCP::Dialog \%dialog
 Return 0 on success, other on failure on when user is aborting

=cut

sub _confirmDistro
{
    my ($dialog) = @_;

    $dialog->infobox( "\nDetecting target distribution..." );

    if ( $main::imscpConfig{'DISTRO_ID'} ne '' && $main::imscpConfig{'DISTRO_RELEASE'} ne '' && $main::imscpConfig{'DISTRO_CODENAME'} ne '' ) {
        my $packagesFile = "$main::imscpConfig{'DISTRO_ID'}-$main::imscpConfig{'DISTRO_CODENAME'}.xml";

        unless ( -f "$FindBin::Bin/installer/Packages/$packagesFile" ) {
            $dialog->msgbox( <<"EOF" );

\\Z1$main::imscpConfig{'DISTRO_ID'} $main::imscpConfig{'DISTRO_RELEASE'}/@{ [ ucfirst $main::imscpConfig{'DISTRO_CODENAME'} ] } not supported yet\\Zn

We are sorry but no packages file has been found for your $main::imscpConfig{'DISTRO_ID'} version.

Thanks for choosing i-MSCP.
EOF

            return 50;
        }

        my $rs = $dialog->yesno( <<"EOF" );

$main::imscpConfig{'DISTRO_ID'} $main::imscpConfig{'DISTRO_RELEASE'}/@{ [ ucfirst $main::imscpConfig{'DISTRO_CODENAME'} ] } has been detected. Is this ok?
EOF

        $dialog->msgbox( <<"EOF" ) if $rs;

\\Z1Distribution not supported\\Zn

We are sorry but the installer has failed to detect your distribution.

Please report the problem to i-MSCP team.

Thanks for choosing i-MSCP.
EOF

        return 50 if $rs;
    } else {
        $dialog->msgbox( <<"EOF" );

\\Z1Distribution not supported\\Zn

We are sorry but your distribution is not supported yet.

Thanks for choosing i-MSCP.
EOF

        return 50;
    }

    0;
}

=item _askInstallerMode( \%dialog )

 Asks for installer mode

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, 50 otherwise

=cut

sub _askInstallerMode
{
    my ($dialog) = @_;

    $dialog->set( 'cancel-label', 'Abort' );

    my %choices = ( 'auto', 'Automatic installation', 'manual', 'Manual installation' );
    my ($rs, $value) = $dialog->radiolist( <<"EOF", \%choices, 'auto' );
Please choose the installer mode:

See https://wiki.i-mscp.net/doku.php?id=start:installer#installer_modes for a full description of the installer modes.
\\Z \\Zn
EOF

    return 50 if $rs;

    iMSCP::Getopt->buildonly( $value eq 'manual' );
    $dialog->set( 'cancel-label', 'Back' );
    0;
}

=item _installDistributionPackages( )

 Install distribution packages

 Return int 0 on success, other on failure

=cut

sub _installDistributionPackages
{
    _getInstaller()->installPackages();
}

=item _checkRequirements( )

 Check for requirements

 Return undef if all requirements are met, throw a fatal error otherwise

=cut

sub _checkRequirements
{
    iMSCP::Requirements->new()->all();
}

=item _buildDistributionFiles( )

 Build distribution files

 Return int 0 on success, other on failure

=cut

sub _buildDistributionFiles
{
    my $rs = _buildConfigFiles();
    $rs ||= _buildEngineFiles();
    $rs ||= _buildFrontendFiles();
    0;
}

=item _buildConfigFiles( )

 Build configuration files

 Return int 0 on success, other on failure

=cut

sub _buildConfigFiles
{
    # Master install.xml file

    my $rs = _processXmlInstallFile(
            -f "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_ID'}/install.xml"
        ? "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_ID'}/install.xml"
        : ( -f "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_FAMILY'}/install.xml"
            ? "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_FAMILY'}/install.xml"
            : "$FindBin::Bin/configs/install.xml"
        )
    );
    return $rs if $rs;

    # servers/services install.xml files

    my $distroFamilyConfDir = "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_FAMILY'}";
    my $distroConfDir = $main::imscpConfig{'DISTRO_ID'} ne $main::imscpConfig{'DISTRO_FAMILY'}
            && -d "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_ID'}"
        ? "$FindBin::Bin/configs/$main::imscpConfig{'DISTRO_ID'}" : $distroFamilyConfDir;

    for ( iMSCP::Dir->new( dirname => $distroFamilyConfDir )->getDirs() ) {
        my $installFile = $distroConfDir ne $distroFamilyConfDir && -f "$distroConfDir/$_/install.xml"
            ? "$distroConfDir/$_/install.xml" : "$distroFamilyConfDir/$_/install.xml";

        next unless -f $installFile;

        $rs = _processXmlInstallFile( $installFile );
        return $rs if $rs;
    }
}

=item _buildEngineFiles( )

 Build engine files

 Return int 0 on success, other on failure

=cut

sub _buildEngineFiles
{
    my $rs = _processXmlInstallFile( "$FindBin::Bin/engine/install.xml" );
    return $rs if $rs;

    for ( iMSCP::Dir->new( dirname => "$FindBin::Bin/engine" )->getDirs() ) {
        next unless -f "$FindBin::Bin/engine/$_/install.xml";
        $rs = _processXmlInstallFile( "$FindBin::Bin/engine/$_/install.xml" );
        return $rs if $rs;
    }

    0;
}

=item _buildFrontendFiles( )

 Build frontEnd files

 Return int 0 on success, other on failure

=cut

sub _buildFrontendFiles
{
    local $UMASK = 0027;

    debug( "Copying $FindBin::Bin/gui to $main::{'IMSCP_ROOT_DIR'}/gui" );

    iMSCP::Dir->new( dirname => "$FindBin::Bin/gui" )->rcopy( "$main::{'IMSCP_ROOT_DIR'}/gui", { preserve => 'no' } );
}

=item _savePersistentData( )

 Save persistent data

 Return int 0 on success, other on failure

=cut

sub _savePersistentData
{
    local $UMASK = 0027;

    # Move old skel directory to new location
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'CONF_DIR'}/apache/skel" )->rcopy(
        "$main::imscpConfig{'CONF_DIR'}/skel", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'CONF_DIR'}/apache/skel";

    iMSCP::Dir->new( dirname => "$main::imscpConfig{'CONF_DIR'}/skel" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'CONF_DIR'}/skel", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'CONF_DIR'}/skel";

    # Move old listener files to new location
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'CONF_DIR'}/hooks.d" )->rcopy(
        "$main::imscpConfig{'CONF_DIR'}/listeners.d", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'CONF_DIR'}/hooks.d";

    # Save ISP logos (older location)
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/themes/user_logos" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent/ispLogos", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/themes/user_logos";

    # Save ISP logos (new location)
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/data/ispLogos" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent/ispLogos", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/data/ispLogos";

    # Save GUI logs
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/data/logs" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/data/logs", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/data/logs";

    # Save GUI persistent data
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent";

    # Save software (older path ./gui/data/softwares) to new path (./gui/data/persistent/softwares)
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/data/softwares" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/data/persistent/softwares", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/data/softwares";

    # Save plugins
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'PLUGINS_DIR'}" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'PLUGINS_DIR'}", { preserve => 'no' }
    ) if -d $main::imscpConfig{'PLUGINS_DIR'};

    # Quick fix for #IP-1340 (Removes old filemanager directory which is no longer used)
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/public/tools/filemanager" )->remove();

    # Save tools
    iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/gui/public/tools" )->rcopy(
        "$main::{'DESTDIR'}$main::imscpConfig{'ROOT_DIR'}/gui/public/tools", { preserve => 'no' }
    ) if -d "$main::imscpConfig{'ROOT_DIR'}/gui/public/tools";

    0;
}

=item _removeObsoleteFiles( )

 Removes obsolete files

 Return int 0 on success, other on failure

=cut

sub _removeObsoleteFiles
{
    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    for ( "$main::imscpConfig{'CACHE_DATA_DIR'}/addons",
        "$main::imscpConfig{'CONF_DIR'}/apache/backup",
        "$main::imscpConfig{'CONF_DIR'}/apache/skel/alias/phptmp",
        "$main::imscpConfig{'CONF_DIR'}/apache/skel/subdomain/phptmp",
        "$main::imscpConfig{'CONF_DIR'}/apache/working",
        "$main::imscpConfig{'CONF_DIR'}/courier/backup",
        "$main::imscpConfig{'CONF_DIR'}/courier/working",
        "$main::imscpConfig{'CONF_DIR'}/cron.d",
        "$main::imscpConfig{'CONF_DIR'}/fcgi",
        "$main::imscpConfig{'CONF_DIR'}/hooks.d",
        "$main::imscpConfig{'CONF_DIR'}/init.d",
        "$main::imscpConfig{'CONF_DIR'}/nginx",
        "$main::imscpConfig{'CONF_DIR'}/php/apache",
        "$main::imscpConfig{'CONF_DIR'}/php/fcgi",
        "$main::imscpConfig{'CONF_DIR'}/php-fpm",
        "$main::imscpConfig{'CONF_DIR'}/postfix/backup",
        "$main::imscpConfig{'CONF_DIR'}/postfix/imscp",
        "$main::imscpConfig{'CONF_DIR'}/postfix/parts",
        "$main::imscpConfig{'CONF_DIR'}/postfix/working",
        "$main::imscpConfig{'CONF_DIR'}/skel/domain/domain_disable_page",
        "$main::imscpConfig{'IMSCP_HOMEDIR'}/packages/.composer",
        "$main::imscpConfig{'LOG_DIR'}/imscp-arpl-msgr"
    ) {
        iMSCP::Dir->new( dirname => $_ )->remove();
    }

    for ( "$main::imscpConfig{'CONF_DIR'}/apache/parts/domain_disabled_ssl.tpl",
        "$main::imscpConfig{'CONF_DIR'}/apache/parts/domain_redirect.tpl",
        "$main::imscpConfig{'CONF_DIR'}/apache/parts/domain_redirect_ssl.tpl",
        "$main::imscpConfig{'CONF_DIR'}/apache/parts/domain_ssl.tpl",
        "$main::imscpConfig{'CONF_DIR'}/vsftpd/imscp_allow_writeable_root.patch",
        "$main::imscpConfig{'CONF_DIR'}/vsftpd/imscp_pthread_cancel.patch",
        "$main::imscpConfig{'CONF_DIR'}/apache/parts/php5.itk.ini",
        "$main::imscpConfig{'CONF_DIR'}/apache/vlogger.sql",
        "$main::imscpConfig{'CONF_DIR'}/dovecot/dovecot.conf.2.0",
        "$main::imscpConfig{'CONF_DIR'}/dovecot/dovecot.conf.2.1",
        "$main::imscpConfig{'CONF_DIR'}/frontend/00_master.conf",
        "$main::imscpConfig{'CONF_DIR'}/frontend/00_master_ssl.conf",
        "$main::imscpConfig{'CONF_DIR'}/frontend/imscp_fastcgi.conf",
        "$main::imscpConfig{'CONF_DIR'}/frontend/imscp_php.conf",
        "$main::imscpConfig{'CONF_DIR'}/frontend/nginx.conf",
        "$main::imscpConfig{'CONF_DIR'}/frontend/php-fcgi-starter",
        "$main::imscpConfig{'CONF_DIR'}/listeners.d/README",
        "$main::imscpConfig{'CONF_DIR'}/php/fpm/logrotate.tpl",
        "$main::imscpConfig{'CONF_DIR'}/skel/domain/.htgroup",
        "$main::imscpConfig{'CONF_DIR'}/skel/domain/.htpasswd",
        "$main::imscpConfig{'IMSCP_HOMEDIR'}/composer.phar",
        "$main::imscpConfig{'IMSCP_HOMEDIR'}/packages/composer.phar",
        "$main::imscpConfig{'CONF_DIR'}/imscp.old.conf",
        "$main::imscpConfig{'CONF_DIR'}/imscp-db-keys",
        '/etc/default/imscp_panel',
        '/etc/init/php5-fpm.override',
        '/etc/logrotate.d/imscp',
        '/etc/nginx/imscp_net2ftp.conf',
        '/etc/systemd/system/php5-fpm.override',
        '/usr/local/lib/imscp_panel/imscp_panel_checkconf',
        '/usr/sbin/maillogconvert.pl'
    ) {
        next unless -l || -f _;
        my $rs = iMSCP::File->new( filename => $_ )->delFile();
        return $rs if $rs;
    }

    0;
}

=item _buildDistributionFiles( )

 Install distribution files

 Return int 0 on success, other on failure

=cut

sub installDistributionFiles
{
    # FIXME: Should be done by a specific package, eg: iMSCP::Packages::FrontEnd
    # FIXME: Should be done by a specific package, eg: iMSCP::Packages::Setup::Backend
    eval {
        iMSCP::Dir->new( dirname => "$main::imscpConfig{'ROOT_DIR'}/$_" )->remove() for qw/ engine gui /;
        iMSCP::Dir->new( dirname => $main::{'DESTDIR'} )->rcopy( '/' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }
}

=item _processXmlInstallFile( $installFilePath )

 Process an install.xml file

 Param string $installFilePath XML installation file path
 Return int 0 on success, other on failure

=cut

sub _processXmlInstallFile
{
    my ($installFilePath) = @_;

    my $xml = XML::Simple->new( ForceArray => 1, ForceContent => 1, KeyAttr => [] );
    my $node = eval { $xml->XMLin( $installFilePath, VarAttr => 'export', NormaliseSpace => 2 ) };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    local $CWD = dirname( $installFilePath );
    local $UMASK = defined $node->{'umask'} ? oct( $node->{'umask'} ) : 0027;

    # Process 'folder' nodes
    if ( $node->{'folder'} ) {
        for ( @{$node->{'folder'}} ) {
            $_->{'content'} = _expandVars( $_->{'content'} );
            $main::{$_->{'export'}} = $_->{'content'} if defined $_->{'export'};
            my $rs = _processFolderNode( $_ );
            return $rs if $rs;
        }
    }

    # Process 'copy_config' nodes
    if ( $node->{'copy_config'} ) {
        for ( @{$node->{'copy_config'}} ) {
            $_->{'content'} = _expandVars( $_->{'content'} );
            my $rs = _processCopyConfigNode( $_ );
            return $rs if $rs;
        }
    }

    # Process 'copy' nodes
    if ( $node->{'copy'} ) {
        for ( @{$node->{'copy'}} ) {
            $_->{'content'} = _expandVars( $_->{'content'} );
            my $rs = _processCopyNode( $_ );
            return $rs if $rs;
        }
    }

    0;
}

=item _expandVars( $string )

 Expand variables in the given string

 Param string $string string containing variables to expands
 Return string

=cut

sub _expandVars
{
    my ($string) = @_;
    $string //= '';

    while ( my ($var) = $string =~ /\$\{([^{}]+)\}/g ) {
        if ( defined $main::{$var} ) {
            $string =~ s/\$\{$var\}/$main::{$var}/;
        } elsif ( defined $main::imscpConfig{$var} ) {
            $string =~ s/\$\{$var\}/$main::imscpConfig{$var}/;
        } else {
            fatal( "Couldn't expand the \${$var} variable. Variable is not found." );
        }
    }

    $string;
}

=item _processFolderNode( \%node )

 Create a folder according the given node

 OPTIONAL node attributes:
  create_if     : Create the folder only if the condition is met
  pre_remove    : Whether the directory must be re-created from scratch
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal)
  user          : Target directory owner
  group         : Target directory group
  mode          : Target directory mode
 Param hashref \%node Node
 Return int 0 on success, other or croak on failure

=cut

sub _processFolderNode
{
    my ($node) = @_;

    return 0 if $node->{'content'} eq '' || ( defined $node->{'create_if'} && !eval _expandVars( $node->{'create_if'} ) );

    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    debug( sprintf( "Creating %s directory", $node->{'content'} ));

    my $dir = iMSCP::Dir->new( dirname => $node->{'content'} );
    $dir->remove() if $node->{'pre_remove'};
    $dir->make( {
        user  => defined $node->{'user'} ? _expandVars( $node->{'owner'} ) : undef,
        group => defined $node->{'group'} ? _expandVars( $node->{'group'} ) : undef,
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
  copy_cwd      : Copy the $CWD directory (excluding the install.xml), instead of a directory in $CWD (current config directory)
  copy_as       : Target file or directory name
  subdir        : Sub-directory in which file must be searched, relative to $CWD (current config directory)
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal)
  mode          : Target file or directory mode
  dirmode       : Target directory mode (can be set only if the mode attribute is not set)
  filemode      : Target directory mode (can be set only if the mode attribute is not set)
  user          : Target file or directory owner
  group         : Target file or directory group
  recursive     : Whether or not ownership and permissions must be fixed recursively
  srv_provider  : Whether or not the give node must be processed by the service provider on removal (case of SysVinit, Upstart and Systemd conffiles)
                  That attribute must be set with the service name for which the system provider must act. This attribute is evaluated only when
                  the node provide the copy_if attribute and only if the expression (value) of that attribute evaluate to FALSE.
 Param hashref \%node Node
 Return int 0 on success, other or croak on failure

=cut

sub _processCopyConfigNode
{
    my ($node) = @_;

    if ( defined $node->{'copy_if'} && !eval _expandVars( $node->{'copy_if'} ) ) {
        return 0 if defined $node->{'keep_if_exist'} && eval _expandVars( $node->{'keep_if_exist'} );

        my $syspath;
        if ( defined $node->{'copy_as'} ) {
            my (undef, $dirs) = fileparse( $node->{'content'} );
            ( $syspath = "$dirs/$node->{'copy_as'}" ) =~ s/^$main::{'DESTDIR'}//;
        } else {
            ( $syspath = $node->{'content'} ) =~ s/^$main::{'DESTDIR'}//;
        }

        return 0 unless $syspath ne '/' && -e $syspath;

        if ( $node->{'srv_provider'} ) {
            debug( sprintf( "Removing %s through the service provider", $syspath ));
            iMSCP::Service->getInstance()->remove( $node->{'srv_provider'} );
            return;
        }

        return iMSCP::Dir->new( dirname => $syspath )->remove() if -d _;
        return iMSCP::File->new( filename => $syspath )->delFile();
    }

    local $CWD = dirname( $CWD ) if $node->{'copy_cwd'};
    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my ($name, $dirs) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $target = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    if ( !-e $source && $main::imscpConfig{'DISTRO_FAMILY'} ne $main::imscpConfig{'DISTRO_ID'} ) {
        # If name isn't in $CWD(/$node->{'subdir'})?, search for it in the <DISTRO_FAMILY>(/$node->{'subdir'})? directory,
        $source =~ s%^($FindBin::Bin/configs/)$main::imscpConfig{'DISTRO_ID'}%${1}$main::imscpConfig{'DISTRO_FAMILY'}%;
        # stat again as _ refers to the previous stat structure
        unless ( stat $source ) {
            error( sprintf( "Couldn't stat %s: %s", $source, $! ));
            return 1;
        }
    }

    debug( sprintf( "Copying %s to %s", $source, $target ));

    if ( -d _ ) {
        iMSCP::Dir->new( dirname => $source )->rcopy( $target, { preserve => 'no' } );
        if ( $node->{'copy_cwd'} ) {
            my $rs = iMSCP::File->new( filename => $target . '/install.xml' )->delFile();
            return $rs if $rs;
        }
    } else {
        my $rs = iMSCP::File->new( filename => $source )->copyFile( $target, { preserve => 'no' } );
        return $rs if $rs;
    }

    setRights( $target,
        {
            mode      => $node->{'mode'},
            dirmode   => $node->{'dirmode'},
            filemode  => $node->{'filemode'},
            user      => defined $node->{'user'} ? _expandVars( $node->{'user'} ) : undef,
            group     => defined $node->{'group'} ? _expandVars( $node->{'group'} ) : undef,
            recursive => $node->{'recursive'}
        }
    );
}

=item _processCopyNode( \%node )

 Copy a directory or file according the given node

 OPTIONAL node attributes:
  copy_if       : Copy the file or directory only if the condition is met, delete it otherwise, unless the keep_if_exists attribute is TRUE
  keep_if_exist : keep_if_exist : Don't delete the file or directory if it exists and if the keep_if_exist evaluate to TRUE
  copy_as       : Target file or directory name
  subdir        : Sub-directory in which file must be searched, relative to $CWD (current confiration directory)
  umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal)
  mode          : Target file or directory mode
  dirmode       : Target directory mode (can be set only if the mode attribute is not set)
  filemode      : Target directory mode (can be set only if the mode attribute is not set)
  user          : Target file or directory owner
  group         : Target file or directory group
  recursive     : Whether or not ownership and permissions must be fixed recursively
 Param hashref \%node Node
 Return int 0 on success, other or croak on failure

=cut

sub _processCopyNode
{
    my ($node) = @_;

    if ( defined $node->{'copy_if'} && !eval _expandVars( $node->{'copy_if'} ) ) {
        return 0 if defined $node->{'keep_if_exist'} && eval _expandVars( $node->{'keep_if_exist'} );

        ( my $syspath = $node->{'content'} ) =~ s/^$main::{'INST_PREF'}//;
        return 0 unless $syspath ne '/' && -e $syspath;
        return iMSCP::Dir->new( dirname => $syspath )->remove() if -d _;
        return iMSCP::File->new( filename => $syspath )->delFile();
    }

    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my ($name, $dirs) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $target = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    debug( sprintf( "Copying %s to %s", $source, $target ));

    if ( -d $source ) {
        iMSCP::Dir->new( dirname => $source )->rcopy( $target, { preserve => 'no' } );
    } else {
        my $rs = iMSCP::File->new( filename => $source )->copyFile( $target, { preserve => 'no' } );
        return $rs if $rs;
    }

    setRights( $target,
        {
            mode      => $node->{'mode'},
            dirmode   => $node->{'dirmode'},
            filemode  => $node->{'filemode'},
            user      => defined $node->{'user'} ? _expandVars( $node->{'user'} ) : undef,
            group     => defined $node->{'group'} ? _expandVars( $node->{'group'} ) : undef,
            recursive => $node->{'recursive'}
        }
    );
}

=item _getInstaller( )

 Returns i-MSCP installer instance for the current distribution

 Return iMSCP::Installer::Abstract, croak on failure

=cut

sub _getInstaller
{
    return $DISTRO_INSTALLER if $DISTRO_INSTALLER;

    $DISTRO_INSTALLER = "iMSCP::Installer::${main::imscpConfig{'DISTRO_FAMILY'}}";
    eval "require $DISTRO_INSTALLER; 1" or croak( $@ );
    $DISTRO_INSTALLER = $DISTRO_INSTALLER->new();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
