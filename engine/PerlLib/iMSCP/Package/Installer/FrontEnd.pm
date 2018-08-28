=head1 NAME

 iMSCP::Package::Installer::FrontEnd - i-MSCP FrontEnd package

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

package iMSCP::Package::Installer::FrontEnd;

use strict;
use warnings;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Crypt qw/ apr1MD5 randomStr ALNUM /;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/
    isStringNotInList isOneOfStringsInList isValidUsername isValidPassword isValidEmail isValidDomain isNumber isNumberInRange isStringInList
/;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Net;
use iMSCP::OpenSSL;
use iMSCP::ProgramFinder;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Service;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use Net::LibIDN qw/ idn_to_ascii idn_to_unicode /;
use Servers::httpd;
use Servers::mta;
use Servers::named;
use version;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP FrontEnd package.
 
 =head1 CLASS METHODS

=over 4

=item getPriority( \%data )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    my ( $class ) = @_;

    150;
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs },
        sub { $self->_askForMasterAdminCredentials( @_ ) },
        sub { $self->_askForMasterAdminEmail( @_ ) },
        sub { $self->_askForControlPanelDomain( @_ ) },
        sub { $self->_askForControlPanelSSL( @_ ) },
        sub { $self->_askForControlPanelHttpPorts( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndPreInstall' );
    $rs ||= $self->stop();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndPreInstall' );
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndInstall' );
    $rs ||= $self->_setupMasterAdmin();
    $rs ||= $self->_setupSsl();
    $rs ||= $self->_setHttpdVersion();
    $rs ||= $self->_addMasterWebUser();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_copyPhpBinary();
    $rs ||= $self->_buildPhpConfig();
    $rs ||= $self->_buildHttpdConfig();
    $rs ||= $self->_addDnsRecord();
    $rs ||= $self->_cleanup();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndInstall' );
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndPostInstall' );
    return $rs if $rs;

    my $serviceMngr = iMSCP::Service->getInstance();
    $serviceMngr->enable( $self->{'config'}->{'HTTPD_SNAME'} );
    $serviceMngr->enable( 'imscp_panel' );

    $rs = $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'i-MSCP FrontEnd services' ];
            0;
        },
        2
    );
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndPostInstall' );
}

=item dpkgPostInvokeTasks( )

 See iMSCP::AbstractInstallerActions::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndDpkgPostInvokeTasks' );
    return $rs if $rs;

    my $systemPhpBin = iMSCP::ProgramFinder::find( "php$self->{'config'}->{'PHP_VERSION'}" );
    my $frontendPhpBin = iMSCP::ProgramFinder::find( 'imscp_panel' );

    if ( defined $frontendPhpBin && !defined $systemPhpBin ) {
        # Cover case where administrator removed the package
        $rs = $self->stop();
        $rs ||= iMSCP::File->new( filename => $frontendPhpBin )->delFile();
        return $rs;
    }

    if ( defined $frontendPhpBin ) {
        my $v1 = $self->getFullPhpVersionFor( $systemPhpBin );
        my $v2 = $self->getFullPhpVersionFor( $frontendPhpBin );

        if ( $v1 eq $v2 ) {
            debug( "Both system PHP version and i-MSCP frontEnd PHP version are even. Nothing to do..." );
            return 0;
        } else {
            $rs = $self->stopPhpFpm();
            return $rs if $rs;
            debug( sprintf( "Updating i-MSCP frontEnd PHP version '%s' to version '%s'", $v2, $v1 ));
        }
    } else {
        debug( 'i-MSCP frontEnd PHP binary is missing. Creating it...' );
    }

    $rs = $self->_copyPhpBinary();
    $rs ||= $self->startPhpFpm();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndDpkgPostInvokeTasks' );
}

=item uninstall( )

 See iMSCP::AbstractUninstallerActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndUninstall' );
    $rs ||= $self->_deconfigurePHP();
    $rs ||= $self->_deconfigureHTTPD();
    $rs ||= $self->_deleteMasterWebUser();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndUninstall' );
}

=item setEnginePermissions( )

 See iMSCP::AbstractInstallerActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndSetEnginePermissions' );

    $rs ||= setRights( $self->{'config'}->{'HTTPD_CONF_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0644',
        recursive => TRUE
    } );
    $rs ||= setRights( $self->{'config'}->{'HTTPD_LOG_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0640',
        recursive => TRUE
    } );
    return $rs if $rs;

    # Temporary directories as provided by nginx package (from Debian Team)
    if ( -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}" ) {
        $rs = setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}, {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'}
        } );

        for my $tmp ( 'body', 'fastcgi', 'proxy', 'scgi', 'uwsgi' ) {
            next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp";
            $rs = setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user      => $self->{'config'}->{'HTTPD_USER'},
                group     => $self->{'config'}->{'HTTPD_GROUP'},
                dirnmode  => '0700',
                filemode  => '0640',
                recursive => TRUE
            } );
            $rs ||= setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user  => $self->{'config'}->{'HTTPD_USER'},
                group => $::imscpConfig{'ROOT_GROUP'},
                mode  => '0700'
            } );
            return $rs if $rs;
        }
    }

    # Temporary directories as provided by nginx package (from nginx Team)
    return 0 unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}";

    $rs = setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'}
    } );
    return $rs if $rs;

    for my $tmp ( 'client_temp', 'fastcgi_temp', 'proxy_temp', 'scgi_temp', 'uwsgi_temp' ) {
        next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp";
        $rs = setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user      => $self->{'config'}->{'HTTPD_USER'},
            group     => $self->{'config'}->{'HTTPD_GROUP'},
            dirnmode  => '0700',
            filemode  => '0640',
            recursive => TRUE
        } );
        $rs ||= setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user  => $self->{'config'}->{'HTTPD_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0700'
        } );
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterFrontEndSetEnginePermissions' );
}

=item setGuiPermissions( )

 See iMSCP::AbstractInstallerActions::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontendSetGuiPermissions' );
    return $rs if $rs;

    my $panelUName = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my $panelGName = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    $rs = setRights( $::imscpConfig{'GUI_ROOT_DIR'}, {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_ROOT_DIR'}/themes", {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_ROOT_DIR'}/data", {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_ROOT_DIR'}/data/persistent", {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_ROOT_DIR'}/i18n", {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= setRights( $::imscpConfig{'PLUGINS_DIR'}, {
        user      => $panelUName,
        group     => $panelGName,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontendSetGuiPermissions' );
}

=item addUser( \%data )

 See iMSCP::Modules::AbstractActions::addUser()

=cut

sub addUser
{
    my ( $self, $data ) = @_;

    return 0 if $data->{'STATUS'} eq 'tochangepwd';

    iMSCP::SystemUser->new( username => $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} )->addToGroup(
        $data->{'GROUP'}
    );
}

=item enableSites( @sites )

 Enable the given site(s)

 Param array @sites List of sites to enable
 Return int 0 on sucess, other on failure

=cut

sub enableSites
{
    my ( $self, @sites ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeEnableFrontEndSites', \@sites );
    return $rs if $rs;

    for my $site ( @sites ) {
        my $target = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site";
        my $link = $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' );

        unless ( -f $target ) {
            error( sprintf( "Site '%s' doesn't exist", $site ));
            return 1;
        }

        next if -l $link;

        unless ( symlink( File::Spec->abs2rel( $target, $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} ), $link ) ) {
            error( sprintf( "Couldn't enable `%s` site: %s", $site, $! ));
            return 1;
        }

        $self->{'reload'} = TRUE;
    }

    $self->{'eventManager'}->trigger( 'afterEnableFrontEndSites', @sites );
}

=item disableSites( @sites )

 Disable the given site(s)

 Param array @sites List of sites to disable
 Return int 0 on success, other on failure

=cut

sub disableSites
{
    my ( $self, @sites ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeDisableFrontEndSites', \@sites );
    return $rs if $rs;

    for my $site ( @sites ) {
        my $link = $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' );
        next unless -l $link;

        $rs = iMSCP::File->new( filename => $link )->delFile();
        return $rs if $rs;

        $self->{'reload'} = TRUE;
    }

    $self->{'eventManager'}->trigger( 'afterDisableFrontEndSites', @sites );
}

=item start( )

 Start frontEnd

 Return int 0 on success, other on failure

=cut

sub start
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStart' );
    $rs ||= $self->startPhpFpm();
    $rs ||= $self->startNginx();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndStart' );
}

=item stop( )

 Stop frontEnd

 Return int 0 on success, other on failure

=cut

sub stop
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStop' );
    $rs ||= $self->stopPhpFpm();
    $rs ||= $self->stopNginx();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndStop' );
}

=item reload( )

 Reload frontEnd

 Return int 0 on success, other on failure

=cut

sub reload
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndReload' );
    $rs ||= $self->reloadPhpFpm();
    $rs ||= $self->reloadNginx();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndReload' );
}

=item restart( )

 Restart frontEnd

 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndRestart' );
    $rs ||= $self->restartPhpFpm();
    $rs ||= $self->restartNginx();
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndRestart' );
}

=item startNginx( )

 Start frontEnd (Nginx only)

 Return int 0 on success, other or die on failure

=cut

sub startNginx
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStartNginx' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->start( $self->{'config'}->{'HTTPD_SNAME'} );

    $self->{'eventManager'}->trigger( 'afterFrontEndStartNginx' );
}

=item stopNginx( )

 Stop frontEnd (Nginx only)

 Return int 0 on success, other or die on failure

=cut

sub stopNginx
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStopNginx' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->stop( "$self->{'config'}->{'HTTPD_SNAME'}" );

    $self->{'eventManager'}->trigger( 'afterFrontEndStop' );
}

=item reloadNginx( )

 Reload frontEnd (Nginx only)

 Return int 0 on success, other or die on failure

=cut

sub reloadNginx
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndReloadNginx' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->reload( $self->{'config'}->{'HTTPD_SNAME'} );

    $self->{'eventManager'}->trigger( 'afterFrontEndReloadNginx' );
}

=item restartNginx( )

 Restart frontEnd (Nginx only)

 Return int 0 on success, other or die on failure

=cut

sub restartNginx
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndRestartNginx' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->restart( $self->{'config'}->{'HTTPD_SNAME'} );

    $self->{'eventManager'}->trigger( 'afterFrontEndRestartNginx' );
}

=item startPhpFpm( )

 Start frontEnd (PHP-FPM instance only)

 Return int 0 on success, other or die on failure

=cut

sub startPhpFpm
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStartPhpFpm' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->start( 'imscp_panel' );

    $self->{'eventManager'}->trigger( 'afterFrontEndStartPhpFpm' );
}

=item stopPhpFpm( )

 Stop frontEnd (PHP-FPM instance only)

 Return int 0 on success, other or die on failure

=cut

sub stopPhpFpm
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndStopPhpFpm' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->stop( 'imscp_panel' );

    $self->{'eventManager'}->trigger( 'afterFrontEndStopPhpFpm' );
}

=item reloadPhpFpm( )

 Reload frontEnd (PHP-FPM instance only)

 Return int 0 on success, other or die on failure

=cut

sub reloadPhpFpm
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndReloadPhpFpm' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->reload( 'imscp_panel' );

    $self->{'eventManager'}->trigger( 'afterFrontEndReloadPhpFpm' );
}

=item restartPhpFpm( )

 Restart frontEnd (PHP-FPM instance only)

 Return int 0 on success, other or die on failure

=cut

sub restartPhpFpm
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndRestartPhpFpm' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->restart( 'imscp_panel' );

    $self->{'eventManager'}->trigger( 'afterFrontEndRestartPhpFpm' );
}

=item buildConfFile( $file [, \%tplVars = { } [, \%options = { } ] ] )

 Build the given configuration file

 Param string $file Absolute config file path or config filename relative to the nginx configuration directory
 Param hash \%tplVars OPTIONAL Template variables
 Param hash \%options OPTIONAL Options such as destination, mode, user and group for final file
 Return int 0 on success, other on failure

=cut

sub buildConfFile
{
    my ( $self, $file, $tplVars, $options ) = @_;

    $tplVars ||= {};
    $options ||= {};

    my ( $filename, $path ) = fileparse( $file );
    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'frontend', $filename, \my $cfgTpl, $tplVars );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $file = "$self->{'cfgDir'}/$file" unless -d $path && $path ne './';
        $cfgTpl = iMSCP::File->new( filename => $file )->get();
        return 1 unless defined $cfgTpl;
    }

    $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConfFile', \$cfgTpl, $filename, $tplVars, $options );
    return $rs if $rs;

    $cfgTpl = $self->_buildConf( $cfgTpl, $filename, $tplVars );
    $cfgTpl =~ s/\n{2,}/\n\n/g; # Remove any duplicate blank lines

    $rs = $self->{'eventManager'}->trigger( 'afterFrontEndBuildConfFile', \$cfgTpl, $filename, $tplVars, $options );
    return $rs if $rs;

    $options->{'destination'} ||= "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$filename";

    my $fileHandler = iMSCP::File->new( filename => $options->{'destination'} );
    $rs = $fileHandler->set( $cfgTpl );
    $rs ||= $fileHandler->save();
    $rs ||= $fileHandler->owner(
        ( $options->{'user'} ? $options->{'user'} : $::imscpConfig{'ROOT_USER'} ),
        ( $options->{'group'} ? $options->{'group'} : $::imscpConfig{'ROOT_GROUP'} )
    );
    $rs ||= $fileHandler->mode( $options->{'mode'} ? $options->{'mode'} : 0644 );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Package::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();

    @{ $self }{qw/ start reload restart /} = ( FALSE, FALSE, FALSE );
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/frontend";

    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/frontend.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/frontend.data",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer';

    $self->guessPhpVariables() if iMSCP::Getopt->context() eq 'installer';
    $self;
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/frontend.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/frontend.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/frontend.data", readonly => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/frontend.data.dist" )->moveFile( "$self->{'cfgDir'}/frontend.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item guessPhpVariables

 Guess PHP Variables

 Return int 0 on success, die on failure

=cut

sub guessPhpVariables
{
    my ( $self ) = @_;

    ( $self->{'config'}->{'PHP_VERSION'} ) = `$::imscpConfig{'PANEL_PHP_VERSION'} -nv 2> /dev/null` =~ /^PHP\s+(\d+.\d+)/ or die(
        "Couldn't guess PHP version"
    );

    my ( $phpConfDir ) = `$::imscpConfig{'PANEL_PHP_VERSION'} -ni 2> /dev/null | grep '(php.ini) Path'` =~ /([^\s]+)$/ or die(
        "Couldn't guess PHP configuration directory path"
    );

    my $phpConfBaseDir = dirname( $phpConfDir );
    $self->{'config'}->{'PHP_CONF_DIR_PATH'} = $phpConfBaseDir;
    $self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'} = "$phpConfBaseDir/fpm/pool.d";

    unless ( -d $self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'} ) {
        $self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'} = '';
        die( sprintf( "Couldn't guess '%s' PHP configuration parameter value: directory doesn't exists.", $_ ));
    }

    $self->{'config'}->{'PHP_CLI_BIN_PATH'} = iMSCP::ProgramFinder::find( "php$self->{'config'}->{'PHP_VERSION'}" );
    $self->{'config'}->{'PHP_FCGI_BIN_PATH'} = iMSCP::ProgramFinder::find( "php-cgi$self->{'config'}->{'PHP_VERSION'}" );
    $self->{'config'}->{'PHP_FPM_BIN_PATH'} = iMSCP::ProgramFinder::find( "php-fpm$self->{'config'}->{'PHP_VERSION'}" );

    for ( qw/ PHP_CLI_BIN_PATH PHP_FCGI_BIN_PATH PHP_FPM_BIN_PATH / ) {
        next if $self->{'config'}->{$_};
        die( sprintf( "Couldn't guess '%s' PHP configuration parameter value.", $_ ));
    }

    0;
}

=item _askForMasterAdminCredentials( $dialog )

 Ask for master administrator credentials

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForMasterAdminCredentials
{
    my ( $self, $dialog ) = @_;

    my ( $username, $password, $freshInstall ) = ( '', '', TRUE );

    if ( iMSCP::Getopt->preseed ) {
        $username = ::setupGetQuestion( 'ADMIN_LOGIN_NAME' );
        $password = ::setupGetQuestion( 'ADMIN_PASSWORD' );
    } elsif ( eval {
        $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));
        TRUE;
    } ) {
        $freshInstall = FALSE;
        my $row = $self->{'dbh'}->selectrow_hashref( "SELECT admin_name, admin_pass FROM admin WHERE created_by = 0 AND admin_type = 'admin'" );
        if ( $row ) {
            $username = $row->{'admin_name'} // '';
            $password = $row->{'admin_pass'} // '';
        }
    }

    ::setupSetQuestion( 'ADMIN_OLD_LOGIN_NAME', $username );
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_admin', 'cp_admin_credentials', 'all' ] )
        || !isValidUsername( $username ) || $password eq ''
    ) {
        Q1:
        do {
            unless ( length $username ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $username = 'admin';
            }

            ( my $rs, $username ) = $dialog->inputbox( <<"EOF", $username );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the master administrator:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;

            if ( isValidUsername( $username ) ) {
                unless ( $freshInstall ) {
                    my $row = $self->{'dbh'}->selectrow_hashref( 'SELECT 1 FROM admin WHERE admin_name = ? AND created_by <> 0', undef, $username );
                    if ( $row ) {
                        $iMSCP::Dialog::InputValidation::lastValidationError = <<"EOF";
\\Z1This username is not available.\\Zn
EOF
                    }
                }
            }
        } while length $iMSCP::Dialog::InputValidation::lastValidationError;

        $password = '';

        do {
            unless ( length $password ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $password = randomStr( 16, ALNUM );
            }

            ( my $rs, $password ) = $dialog->inputbox( <<"EOF", $password );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the control panel master administrator:
\\Z \\Zn
EOF
            goto Q1 if $rs == 30;
            return $rs if $rs == 50;
        } while !isValidPassword( $password );
    } else {
        $password = '' unless iMSCP::Getopt->preseed
    }

    ::setupSetQuestion( 'ADMIN_LOGIN_NAME', $username );
    ::setupSetQuestion( 'ADMIN_PASSWORD', $password );
    0;
}

=item _askForMasterAdminEmail( $dialog )

 Ask for master administrator email address

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForMasterAdminEmail
{
    my ( $self, $dialog ) = @_;

    my $email = ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' );
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_admin', 'cp_admin_email', 'all' ] ) || !isValidEmail( $email ) ) {
        do {
            ( my $rs, $email ) = $dialog->inputbox( <<"EOF", $email );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter an email address for the control panel master administrator:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidEmail( $email );
    }

    ::setupSetQuestion( 'DEFAULT_ADMIN_ADDRESS', $email );
    0;
}

=item _askForControlPanelDomain( $dialog )

 Show for frontEnd domain name

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForControlPanelDomain
{
    my ( $self, $dialog ) = @_;

    my $domain = ::setupGetQuestion( 'BASE_SERVER_VHOST' );
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_hostname', 'hostname', 'all' ] ) || !isValidDomain( $domain ) ) {
        $domain = ( split /\./, ::setupGetQuestion( 'SERVER_HOSTNAME' ), 2 )[1] unless length $domain;
        $domain = idn_to_unicode( $domain, 'utf-8' );

        do {
            ( my $rs, $domain ) = $dialog->inputbox( <<"EOF", $domain, 'utf-8' );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a domain name for the control panel:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidDomain( $domain );
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST', idn_to_ascii( $domain, 'utf-8' ));
    0;
}

=item _askForControlPanelSSL( $dialog )

 Ask for frontEnd SSL

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForControlPanelSSL
{
    my ( $self, $dialog ) = @_;

    my $domainName = ::setupGetQuestion( 'BASE_SERVER_VHOST' );
    my $domainNameUnicode = idn_to_unicode( $domainName, 'utf-8' );
    my $sslEnabled = ::setupGetQuestion( 'PANEL_SSL_ENABLED' );
    my $selfSignedCertificate = ::setupGetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE', 'no' );
    my $privateKeyPath = ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH', '/root' );
    my $passphrase = ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE' );
    my $certificatePath = ::setupGetQuestion( 'PANEL_SSL_CERTIFICATE_PATH', '/root' );
    my $caBundlePath = ::setupGetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH', '/root' );
    my $openSSL = iMSCP::OpenSSL->new();

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_ssl', 'ssl', 'all' ] )
        || isStringNotInList( $sslEnabled, 'yes', 'no' )
        || ( $sslEnabled eq 'yes' && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel_hostname', 'hostnames' ] ) )
    ) {
        Q1:
        my $rs = $dialog->yesno( <<'EOF', $sslEnabled eq 'no', TRUE );

Do you want to enable SSL for the control panel?
EOF
        return $rs unless $rs < 30;

        if ( $rs ) {
            ::setupSetQuestion( 'PANEL_SSL_ENABLED', 'no' );
            return 0;
        }

        $sslEnabled = 'yes';
        my $msg = '';

        Q2:
        $rs = $dialog->yesno( <<"EOF", $selfSignedCertificate eq 'no', TRUE );

Do you have an SSL certificate for the $domainNameUnicode domain?
EOF
        goto Q1 if $rs == 30;
        return $rs if $rs == 50;

        unless ( $rs ) {
            Q3:
            do {
                ( $rs, $privateKeyPath ) = $dialog->inputbox( <<"EOF", $privateKeyPath );
$msg
Please enter the path to your private key:
EOF
                goto Q2 if $rs == 30;
                return $rs if $rs == 50;

                $msg = length $privateKeyPath && -f $privateKeyPath ? '' : <<'EOF'

\Z1Invalid private key path.\Zn
EOF
            } while length $msg;

            Q4:
            ( $rs, $passphrase ) = $dialog->passwordbox( <<'EOF', $passphrase );

Please enter the passphrase for your private key if any:
EOF
            goto Q3 if $rs == 30;
            return $rs if $rs == 50;

            $openSSL->{'private_key_container_path'} = $privateKeyPath;
            $openSSL->{'private_key_passphrase'} = $passphrase;

            if ( $openSSL->validatePrivateKey() ) {
                debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                $msg = <<'EOF';

\Z1Invalid private key or passphrase.\Zn
EOF
                goto Q3;
            }

            Q5:
            $rs = $dialog->yesno( <<'EOF', FALSE, TRUE );

Do you have a CA bundle (root and intermediate certificates)?
EOF
            goto Q4 if $rs == 30;
            return $rs if $rs == 50;

            if ( $rs ) {
                $openSSL->{'ca_bundle_container_path'} = '';
                goto Q7
            }

            Q6:
            do {
                ( $rs, $caBundlePath ) = $dialog->inputbox( <<"EOF", $caBundlePath );
$msg
Please enter the path to your CA bundle:
EOF
                goto Q5 if $rs == 30;
                return $rs if $rs == 50;

                $msg = length $caBundlePath || -f $caBundlePath ? '' : <<'EOF';

\Z1Invalid CA bundle path.\Zn
EOF
            } while length $msg;

            $openSSL->{'ca_bundle_container_path'} = $caBundlePath;

            Q7:
            do {
                ( $rs, $certificatePath ) = $dialog->inputbox( <<"EOF", $certificatePath );
$msg
Please enter the path to your SSL certificate:
EOF
                goto Q6 if $rs == 30;
                return $rs if $rs == 50;

                $msg = length $certificatePath && -f $certificatePath ? '' : <<'EOF';

\Z1Invalid SSL certificate path.\Zn
EOF
            } while length $msg;

            $openSSL->{'certificate_container_path'} = $certificatePath;

            if ( $openSSL->validateCertificate() ) {
                debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                $msg = <<'EOF';
\Z1Invalid SSL certificate.
EOF
                goto Q3;
            }
        } else {
            $selfSignedCertificate = 'yes';
        }
    } elsif ( $sslEnabled eq 'yes' && !iMSCP::Getopt->preseed ) {
        $openSSL->{'private_key_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";
        $openSSL->{'ca_bundle_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";
        $openSSL->{'certificate_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";

        if ( $openSSL->validateCertificateChain() ) {
            debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
            my $rs = $dialog->msgbox( <<'EOF' );

Your SSL certificate for the control panel is missing or invalid.
EOF
            iMSCP::Getopt->reconfigure( 'panel_ssl', FALSE, TRUE );
            return $rs if $rs == 50;
            goto &{ askSsl };
        }

        ::setupSetQuestion( 'PANEL_SSL_SETUP', 'no' );
    }

    ::setupSetQuestion( 'PANEL_SSL_ENABLED', $sslEnabled );
    ::setupSetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE', $selfSignedCertificate );
    ::setupSetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH', $privateKeyPath );
    ::setupSetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE', $passphrase );
    ::setupSetQuestion( 'PANEL_SSL_CERTIFICATE_PATH', $certificatePath );
    ::setupSetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH', $caBundlePath );
    0;
}

=item _askForControlPanelDefaultAccessMode( $dialog )

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK) or 50 (ESC)

=cut

sub _askForControlPanelDefaultAccessMode
{
    my ( $self, $dialog ) = @_;

    unless ( ::setupGetQuestion( 'PANEL_SSL_ENABLED' ) eq 'yes' ) {
        ::setupSetQuestion( 'BASE_SERVER_VHOST_PREFIX', 'http://' );
        return 20;
    }

    my $scheme = ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX', 'http://' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_ssl', 'ssl', 'all' ] )
        || !isStringInList( $scheme, 'http://', 'https://' )
    ) {
        my %choices = ( 'http://', 'No secure access (No SSL)', 'https://', 'Secure access (SSL)' );
        ( my $rs, $scheme ) = $dialog->radiolist(
            <<"EOF", \%choices, ( grep ( $scheme eq $_, keys %choices ) )[0] || 'https://' );

Please choose the default access mode for the control panel:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST_PREFIX', $scheme );
    0;
}

=item _askForControlPanelHttpPorts( $dialog )

 Ask for frontEnd http ports

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForControlPanelHttpPorts
{
    my ( $self, $dialog ) = @_;

    my $httpPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT' );
    my $httpsPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT' );
    my $ssl = ::setupGetQuestion( 'PANEL_SSL_ENABLED' );
    ( my $rs, $iMSCP::Dialog::InputValidation::lastValidationError ) = ( 0, '' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp', 'cp_ports', 'all' ] )
        || !isNumber( $httpPort ) || !isNumberInRange( $httpPort, 1025, 65535 ) || !isStringNotInList( $httpPort, $httpsPort )
        || !isNumber( $httpsPort ) || !isNumberInRange( $httpsPort, 1025, 65535 ) || !isStringNotInList( $httpsPort, $httpPort )
    ) {
        Q1:
        do {
            ( $rs, $httpPort ) = $dialog->inputbox( <<"EOF", $httpPort ? $httpPort : 8880 );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the HTTP port for the control panel:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isNumber( $httpPort ) || !isNumberInRange( $httpPort, 1025, 65535 ) || !isStringNotInList( $httpPort, $httpsPort );

        $iMSCP::Dialog::InputValidation::lastValidationError = '';

        if ( $ssl eq 'yes' ) {
            do {
                ( $rs, $httpsPort ) = $dialog->inputbox( <<"EOF", $httpsPort ? $httpsPort : 8443 );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the HTTPS port for the control panel:
\\Z \\Zn
EOF
                goto Q1 if $rs == 30;
                return $rs if $rs == 50;
            } while !isNumber( $httpsPort ) || !isNumberInRange( $httpsPort, 1025, 65535 ) || !isStringNotInList( $httpsPort, $httpPort );
        } else {
            $httpsPort ||= 8443;
        }
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT', $httpPort );
    ::setupSetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT', $httpsPort );
    0;
}

=item _setupMasterAdmin( )

 Setup master administrator

 Return int 0 on success, other on failure

=cut

sub _setupMasterAdmin
{
    my ( $self ) = @_;

    my $login = ::setupGetQuestion( 'ADMIN_LOGIN_NAME' );
    my $loginOld = ::setupGetQuestion( 'ADMIN_OLD_LOGIN_NAME' );
    my $password = ::setupGetQuestion( 'ADMIN_PASSWORD' );
    my $email = ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' );

    return 0 if $password eq '';

    $password = apr1MD5( $password );

    my $rdbh = $self->{'dbh'}->getRawDb();

    eval {
        my $oldDbName = $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));

        {
            local $rdbh->{'RaiseError'} = TRUE;
            $rdbh->begin_work();

            my $row = $rdbh->selectrow_hashref( "SELECT admin_id FROM admin WHERE admin_name = ?", undef, $loginOld );

            if ( $row ) {
                $rdbh->do(
                    'UPDATE admin SET admin_name = ?, admin_pass = ?, email = ? WHERE admin_id = ?',
                    undef, $login, $password, $email, $row->{'admin_id'}
                );
            } else {
                $rdbh->do(
                    'INSERT INTO admin (admin_name, admin_pass, admin_type, email) VALUES (?, ?, ?, ?)',
                    undef, $login, $password, 'admin', $email
                );
                $rdbh->do( 'INSERT INTO user_gui_props SET user_id = LAST_INSERT_ID()' );
            }

            $rdbh->commit();
        }

        $self->{'dbh'}->useDatabase( $oldDbName ) if $oldDbName;
    };
    if ( $@ ) {
        $rdbh->rollback();
        error( $@ );
        return 1;
    }

    0
}

=item _setupSsl( )

 Setup SSL

 Return int 0 on success, other on failure

=cut

sub _setupSsl
{
    my $sslEnabled = ::setupGetQuestion( 'PANEL_SSL_ENABLED' );
    my $oldCertificate = $::imscpOldConfig{'BASE_SERVER_VHOST'};
    my $domainName = ::setupGetQuestion( 'BASE_SERVER_VHOST' );

    # Remove old certificate if any (handle case where panel hostname has been changed)
    if ( $oldCertificate ne '' && $oldCertificate ne "$domainName.pem" && -f "$::imscpConfig{'CONF_DIR'}/$oldCertificate" ) {
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/$oldCertificate" )->delFile();
        return $rs if $rs;
    }

    if ( $sslEnabled eq 'no' || ::setupGetQuestion( 'PANEL_SSL_SETUP', 'yes' ) eq 'no' ) {
        if ( $sslEnabled eq 'no' && -f "$::imscpConfig{'CONF_DIR'}/$domainName.pem" ) {
            my $rs = iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/$domainName.pem" )->delFile();
            return $rs if $rs;
        }

        return 0;
    }

    if ( ::setupGetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE' ) eq 'yes' ) {
        return iMSCP::OpenSSL->new(
            certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
            certificate_chain_name         => $domainName
        )->createSelfSignedCertificate( {
            common_name => $domainName,
            email       => ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' )
        } );
    }

    iMSCP::OpenSSL->new(
        certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
        certificate_chain_name         => $domainName,
        private_key_container_path     => ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH' ),
        private_key_passphrase         => ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE' ),
        certificate_container_path     => ::setupGetQuestion( 'PANEL_SSL_CERTIFICATE_PATH' ),
        ca_bundle_container_path       => ::setupGetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH' )
    )->createCertificateChain();
}

=item _setHttpdVersion( )

 Set httpd version

 Return int 0 on success, other on failure

=cut

sub _setHttpdVersion( )
{
    my ( $self ) = @_;

    my $rs = execute( 'nginx -v', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stderr !~ m%nginx/([\d.]+)% ) {
        error( "Couldn't guess Nginx version" );
        return 1;
    }

    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Nginx version set to: %s', $1 ));
    0;
}

=item _addMasterWebUser( )

 Add master Web user

 Return int 0 on success, other on failure

=cut

sub _addMasterWebUser
{
    my ( $self ) = @_;

    my $rs = eval {
        my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndAddUser' );
        return $rs if $rs;

        my $user = my $group = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

        my $rdbh = $self->{'dbh'}->getRawDb();
        local $rdbh->{'RaiseError'} = TRUE;

        $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));

        my $row = $rdbh->selectrow_hashref(
            "SELECT admin_sys_name, admin_sys_uid, admin_sys_gname FROM admin WHERE admin_type = 'admin' AND created_by = 0 LIMIT 1"
        );
        $row or die( "Couldn't find master administrator user in database" );

        my ( $oldUser, $uid, $gid ) = ( $row->{'admin_sys_uid'} && $row->{'admin_sys_uid'} ne '0' )
            ? ( getpwuid( $row->{'admin_sys_uid'} ) )[0, 2, 3] : ();

        $rs = iMSCP::SystemUser->new(
            username       => $oldUser,
            comment        => 'i-MSCP Control Panel Web User',
            home           => $::imscpConfig{'GUI_ROOT_DIR'},
            skipCreateHome => TRUE
        )->addSystemUser( $user, $group );
        return $rs if $rs;

        ( $uid, $gid ) = ( getpwnam( $user ) )[2, 3];

        $rdbh->do(
            "UPDATE admin SET admin_sys_name = ?, admin_sys_uid = ?, admin_sys_gname = ?, admin_sys_gid = ? WHERE admin_type = 'admin'",
            undef, $user, $uid, $group, $gid
        );

        $rs = iMSCP::SystemUser->new( username => $user )->addToGroup( $::imscpConfig{'IMSCP_GROUP'} );
        $rs = iMSCP::SystemUser->new( username => $user )->addToGroup( Servers::mta->factory()->{'config'}->{'MTA_MAILBOX_GID_NAME'} );
        $rs ||= iMSCP::SystemUser->new( username => $self->{'config'}->{'HTTPD_USER'} )->addToGroup( $group );
        $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndAddUser' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $rs;
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndMakeDirs' );
    return $rs if $rs;

    my $rootUName = $::imscpConfig{'ROOT_USER'};
    my $rootGName = $::imscpConfig{'ROOT_GROUP'};

    my $nginxTmpDir = $self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'};
    $nginxTmpDir = $self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'} unless -d $nginxTmpDir;

    # Force re-creation of cache directory tree (needed to prevent any permissions problem from an old installation)
    # See #IP-1530
    iMSCP::Dir->new( dirname => $nginxTmpDir )->remove();

    for ( [ $nginxTmpDir, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_CONF_DIR'}, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_LOG_DIR'}, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}, $rootUName, $rootGName, 0755 ]
    ) {
        iMSCP::Dir->new( dirname => $_->[0] )->make( {
            user  => $_->[1],
            group => $_->[2],
            mode  => $_->[3]
        } );
    }

    if ( iMSCP::Service->getInstance->isSystemd() ) {
        iMSCP::Dir->new( dirname => '/run/imscp' )->make( {
            user  => $self->{'config'}->{'HTTPD_USER'},
            group => $self->{'config'}->{'HTTPD_GROUP'},
            mode  => 0755
        } );
    }

    $self->{'eventManager'}->trigger( 'afterFrontEndMakeDirs' );
}

=item _copyPhpBinary( )

 Copy system PHP-FPM binary for imscp_panel service

 Return int 0 on success, other on failure

=cut

sub _copyPhpBinary
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndCopyPhpBinary' );
    return $rs if $rs;

    if ( $self->{'config'}->{'PHP_FPM_BIN_PATH'} eq '' ) {
        error( "PHP 'PHP_FPM_BIN_PATH' configuration parameter is not set." );
        return 1;
    }

    $rs ||= iMSCP::File->new( filename => $self->{'config'}->{'PHP_FPM_BIN_PATH'} )->copyFile( '/usr/local/sbin/imscp_panel' );
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndCopyPhpBinary' );
}

=item _buildPhpConfig( )

 Build PHP configuration

 Return int 0 on success, other on failure

=cut

sub _buildPhpConfig
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndBuildPhpConfig' );
    return $rs if $rs;

    my $user = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my $group = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    $rs = $self->buildConfFile(
        "$self->{'cfgDir'}/php-fpm.conf",
        {
            CHKROOTKIT_LOG            => $::imscpConfig{'CHKROOTKIT_LOG'},
            CONF_DIR                  => $::imscpConfig{'CONF_DIR'},
            DOMAIN                    => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
            DISTRO_OPENSSL_CNF        => $::imscpConfig{'DISTRO_OPENSSL_CNF'},
            DISTRO_CA_BUNDLE          => $::imscpConfig{'DISTRO_CA_BUNDLE'},
            FRONTEND_FCGI_CHILDREN    => $self->{'config'}->{'FRONTEND_FCGI_CHILDREN'},
            FRONTEND_FCGI_MAX_REQUEST => $self->{'config'}->{'FRONTEND_FCGI_MAX_REQUEST'},
            FRONTEND_GROUP            => $group,
            FRONTEND_USER             => $user,
            HOME_DIR                  => $::imscpConfig{'GUI_ROOT_DIR'},
            MTA_VIRTUAL_MAIL_DIR      => Servers::mta->factory()->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
            PEAR_DIR                  => $self->{'config'}->{'PHP_PEAR_DIR'},
            OTHER_ROOTKIT_LOG         => $::imscpConfig{'OTHER_ROOTKIT_LOG'} ne '' ? ":$::imscpConfig{'OTHER_ROOTKIT_LOG'}" : '',
            RKHUNTER_LOG              => $::imscpConfig{'RKHUNTER_LOG'},
            TIMEZONE                  => ::setupGetQuestion( 'TIMEZONE' ),
            WEB_DIR                   => $::imscpConfig{'GUI_ROOT_DIR'}
        },
        {
            destination => "/usr/local/etc/imscp_panel/php-fpm.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0640
        }
    );
    $rs ||= $self->buildConfFile(
        "$self->{'cfgDir'}/php.ini",
        {

            PEAR_DIR => $self->{'config'}->{'PHP_PEAR_DIR'},
            TIMEZONE => ::setupGetQuestion( 'TIMEZONE' )
        },
        {
            destination => "/usr/local/etc/imscp_panel/php.ini",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0640,
        }
    );
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndBuildPhpConfig' );
}

=item _buildHttpdConfig( )

 Build httpd configuration

 Return int 0 on success, other on failure

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndBuildHttpdConfig' );
    return $rs if $rs;

    # Build main nginx configuration file
    $rs = $self->buildConfFile(
        "$self->{'cfgDir'}/nginx.nginx",
        {
            HTTPD_USER               => $self->{'config'}->{'HTTPD_USER'},
            HTTPD_WORKER_PROCESSES   => $self->{'config'}->{'HTTPD_WORKER_PROCESSES'},
            HTTPD_WORKER_CONNECTIONS => $self->{'config'}->{'HTTPD_WORKER_CONNECTIONS'},
            HTTPD_RLIMIT_NOFILE      => $self->{'config'}->{'HTTPD_RLIMIT_NOFILE'},
            HTTPD_LOG_DIR            => $self->{'config'}->{'HTTPD_LOG_DIR'},
            HTTPD_PID_FILE           => $self->{'config'}->{'HTTPD_PID_FILE'},
            HTTPD_CONF_DIR           => $self->{'config'}->{'HTTPD_CONF_DIR'},
            HTTPD_LOG_DIR            => $self->{'config'}->{'HTTPD_LOG_DIR'},
            HTTPD_SITES_ENABLED_DIR  => $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}
        },
        {
            destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/nginx.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0644
        }
    );

    # Build FastCGI configuration file
    $rs ||= $self->buildConfFile( "$self->{'cfgDir'}/imscp_fastcgi.nginx", {}, {
        destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );

    # Build PHP backend configuration file
    $rs ||= $self->buildConfFile( "$self->{'cfgDir'}/imscp_php.nginx", {}, {
        destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterFrontEndBuildHttpdConfig' );
    $rs ||= $self->{'eventManager'}->trigger( 'beforeFrontEndBuildHttpdVhosts' );
    return $rs if $rs;

    # Build frontEnd site files
    my $baseServerIpVersion = iMSCP::Net->getInstance()->getAddrVersion( ::setupGetQuestion( 'BASE_SERVER_IP' ));
    my $httpsPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT' );
    my $tplVars = {
        BASE_SERVER_VHOST            => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        BASE_SERVER_IP               => ( $baseServerIpVersion eq 'ipv4' )
            ? ::setupGetQuestion( 'BASE_SERVER_IP' ) =~ s/^\Q0.0.0.0\E$/*/r : '[' . ::setupGetQuestion( 'BASE_SERVER_IP' ) . ']',
        BASE_SERVER_VHOST_HTTP_PORT  => ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT' ),
        BASE_SERVER_VHOST_HTTPS_PORT => $httpsPort,
        WEB_DIR                      => $::imscpConfig{'GUI_ROOT_DIR'},
        CONF_DIR                     => $::imscpConfig{'CONF_DIR'},
        PLUGINS_DIR                  => $::imscpConfig{'PLUGINS_DIR'}
    };

    $rs = $self->disableSites( 'default', '00_master.conf', '00_master_ssl.conf' );
    $rs ||= $self->{'eventManager'}->register( 'beforeFrontEndBuildConf', sub {
        my ( $cfgTpl, $tplName ) = @_;

        return 0 unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

        if ( $baseServerIpVersion eq 'ipv6' || ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'no' ) {
            replaceBlocByRef( '# SECTION IPv6 BEGIN.', '# SECTION IPv6 END.', '', $cfgTpl );
        }

        return 0 unless $tplName eq '00_master.nginx' && ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) eq 'https://';

        replaceBlocByRef(
            "# SECTION custom BEGIN.\n",
            "# SECTION custom END.\n",
            "    # SECTION custom BEGIN.\n"
                . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $cfgTpl )
                . <<'EOF'
    return 302 https://{BASE_SERVER_VHOST}:{BASE_SERVER_VHOST_HTTPS_PORT}$request_uri;
EOF
                . "    # SECTION custom END.\n",
            $cfgTpl
        );

        0;
    } );
    $rs ||= $self->buildConfFile( '00_master.nginx', $tplVars, {
        destination => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );
    $rs ||= $self->enableSites( '00_master.conf' );
    return $rs if $rs;

    if ( ::setupGetQuestion( 'PANEL_SSL_ENABLED' ) eq 'yes' ) {
        $rs ||= $self->buildConfFile( '00_master_ssl.nginx', $tplVars, {
            destination => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master_ssl.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0644
        } );
        $rs ||= $self->enableSites( '00_master_ssl.conf' );
        return $rs if $rs;
    } elsif ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master_ssl.conf" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master_ssl.conf" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf" ) {
        # Nginx package as provided by Nginx Team
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf" )->moveFile(
            "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled"
        );
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterFrontEndBuildHttpdVhosts' );
}

=item _addDnsRecord( )

 Add a DNS A record in the master zone for the control panel

 Return int 0 on success, other on failure

=cut

sub _addDnsRecord
{
    my ( $self ) = @_;

    return 0 if ::setupGetQuestion( 'BASE_SERVER_VHOST' ) eq ::setupGetQuestion( 'SERVER_HOSTNAME' );

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedAddMasterZone' );
    $rs ||= Servers::named->factory()->addSub( {
        DOMAIN_NAME  => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        DOMAIN_IP    => ::setupGetQuestion( 'BASE_SERVER_IP' ),
        MAIL_ENABLED => TRUE
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedAddMasterZone' );
}

=item getFullPhpVersionFor( $binaryPath )

 Get full PHP version for the given PHP binary

 Param string $binaryPath Path to PHP binary
 Return int 0 on success, other on failure

=cut

sub getFullPhpVersionFor
{
    my ( $self, $binaryPath ) = @_;

    my $rs = execute( [ $binaryPath, '-nv' ], \my $stdout, \my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return undef unless $stdout;
    $stdout =~ /PHP\s+([^\s]+)/;
    $1;
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFrontEndCleanup' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/frontend.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/frontend.old.data" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterFrontEndCleanup' );
}

=item _buildConf( $cfgTpl, $filename [, \%tplVars ] )

 Build the given configuration template

 Param string $cfgTpl Temmplate content
 Param string $filename Template filename
 Param hash OPTIONAL \%tplVars Template variables
 Return string Template content

=cut

sub _buildConf
{
    my ( $self, $cfgTpl, $filename, $tplVars ) = @_;

    $tplVars ||= {};
    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConf', \$cfgTpl, $filename, $tplVars );
    processByRef( $tplVars, \$cfgTpl );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildConf', \$cfgTpl, $filename, $tplVars );
    $cfgTpl;
}

=item _deconfigurePHP( )

 Deconfigure PHP (imscp_panel service)

 Return int 0 on success, other on failure

=cut

sub _deconfigurePHP
{

    iMSCP::Service->getInstance()->remove( 'imscp_panel' );

    for my $file ( '/etc/default/imscp_panel', '/etc/tmpfiles.d/imscp_panel.conf',
        "$::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp_panel", '/usr/local/sbin/imscp_panel', '/var/log/imscp_panel.log'
    ) {
        next unless -f $file;
        my $rs = iMSCP::File->new( filename => $file )->delFile();
        return $rs if $rs;
    }

    iMSCP::Dir->new( dirname => '/usr/local/lib/imscp_panel' )->remove();
    iMSCP::Dir->new( dirname => '/usr/local/etc/imscp_panel' )->remove();
    iMSCP::Dir->new( dirname => '/var/run/imscp' )->remove();
}

=item _deconfigureHTTPD( )

 Deconfigure HTTPD (nginx)

 Return int 0 on success, other on failure

=cut

sub _deconfigureHTTPD
{
    my ( $self ) = @_;

    my $rs = $self->disableSites( '00_master.conf' );
    return $rs if $rs;

    if ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/default" ) {
        # Nginx as provided by Debian
        $rs = $self->enableSites( 'default' );
        return $rs if $rs;
    } elsif ( "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled" ) {
        # Nginx package as provided by Nginx
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled" )->moveFile(
            "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf"
        );
        return $rs if $rs;
    }

    0;
}

=item _deleteMasterWebUser( )

 Delete i-MSCP master Web user

 Return int 0 on success, other on failure

=cut

sub _deleteMasterWebUser
{
    my $rs = iMSCP::SystemUser->new( force => 'yes' )->delSystemUser( $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} );
    $rs ||= iMSCP::SystemGroup->getInstance()->delSystemGroup( $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} );
}

=item END

 Start, restart or reload frontEnd services: nginx or/and imscp_panel when required

 Return int Exit code

=cut

sub END
{
    return if $?;

    if ( iMSCP::Getopt->context() ne 'backend' ) {
        return if iMSCP::Getopt->context() eq 'installer';
        $? = iMSCP::Package::Installer::FrontEnd->getInstance()->restartNginx() if iMSCP::Getopt->context() eq 'uninstaller';
        return;
    }

    my $self = iMSCP::Package::Installer::FrontEnd->getInstance();
    if ( $self->{'start'} ) {
        $? = $self->start();
    } elsif ( $self->{'restart'} ) {
        $? = $self->restart();
    } elsif ( $self->{'reload'} ) {
        $? = $self->reload();
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
