=head1 NAME

 iMSCP::Servers::Php::Debian - i-MSCP (Debian) PHP server implementation

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

package iMSCP::Servers::Php::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt /;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use Scalar::Defer qw/ defer lazy /;
use version;
use parent 'iMSCP::Servers::Php';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) PHP server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Php::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->SUPER::preinstall();

    my $httpdSname = $self->{'httpd'}->getServerName();

    if ( $httpdSname eq 'Apache' ) {
        # Disable the Apache fcgid_imscp modules. It will be re-enabled in postinstall if needed
        $self->{'httpd'}->disableModules( 'fcgid_imscp' );

        # Disable default Apache conffile for CGI programs
        # FIXME: One administrator could rely on that config (outside of i-MSCP)
        #$self->{'httpd'}->disableConfs( 'serve-cgi-bin.conf' );
    }

    my $srvProvider = iMSCP::Service->getInstance();

    # Disable PHP session cleaner services as we don't rely on them
    # FIXME: One administrator could rely on those services (outside of i-MSCP)
    # FIXME: If re-enabled, we should also disable the /etc/cron.d/php cron task
    # FIXME Are thse services provided for other init system than systemd?
    #for my $service ( qw/ phpsessionclean phpsessionclean.timer / ) {
    #    next unless $srvProvider->hasService( $service );
    #    $srvProvider->stop( $service );
    #
    #    if ( $srvProvider->isSystemd() ) {
    #        # If systemd is the current init we mask the service. Service will be disabled and masked.
    #        $srvProvider->getProvider()->mask( $service );
    #    } else {
    #        $srvProvider->disable( $service );
    #    }
    #}

    for my $version ( @{ $self->{'_available_php_versions'} } ) {
        # Tasks for apache2handler SAPI
        if ( $httpdSname eq 'Apache' && $self->{'config'}->{'PHP_SAPI'} ne 'apache2handler' || $self->{'config'}->{'PHP_VERSION'} ne $version ) {
            # Disable Apache PHP module if PHP version is other than selected PHP alternative
            $self->{'httpd'}->disableModules( "php$version" );
        }

        # Tasks for cgi SAPI
        # Disable default Apache conffile
        $self->{'httpd'}->disableConfs( "php$version-cgi.conf" ) if $httpdSname eq 'Apache';

        # Tasks for fpm SAPI
        if ( $srvProvider->hasService( "php$version-fpm" ) ) {
            # Stop PHP-FPM instance
            $self->stop( $version );

            # Disable PHP-FPM service if selected SAPI for customer is not fpm or if PHP version
            # is other than selected PHP alternative
            if ( $self->{'config'}->{'PHP_SAPI'} ne 'fpm' || $self->{'config'}->{'PHP_VERSION'} ne $version ) {
                if ( $srvProvider->isSystemd() ) {
                    # If systemd is the current init we mask the service. Service will be disabled and masked.
                    $srvProvider->getProvider()->mask( "php$version-fpm" );
                } else {
                    $srvProvider->disable( "php$version-fpm" );
                }
            }
        }

        # Disable default Apache conffile for PHP-FPM
        $self->{'httpd'}->disableConfs( "php$version-fpm.conf" ) if $httpdSname eq 'Apache';

        # Reset PHP-FPM pool confdir
        iMSCP::File->new( filename => $version )->remove() for grep !/www\.conf$/, glob "/etc/php/$version/fpm/pool.d/*.conf";
    }

    # Create/Reset/Remove FCGI starter rootdir, depending of selected PHP SAPI for customers
    my $dir = iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} );
    $dir->remove();
    if ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
        $dir->make( {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => 0555
        } );
    }
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $serverData = {
        HTTPD_USER                          => $self->{'httpd'}->getRunningUser(),
        HTTPD_GROUP                         => $self->{'httpd'}->getRunningGroup(),
        PHP_APCU_CACHE_ENABLED              => $self->{'config'}->{'PHP_APCU_CACHE_ENABLED'} // 1,
        PHP_APCU_CACHE_MAX_MEMORY           => $self->{'config'}->{'PHP_APCU_CACHE_MAX_MEMORY'} || 32,
        PHP_FPM_EMERGENCY_RESTART_THRESHOLD => $self->{'config'}->{'PHP_FPM_EMERGENCY_RESTART_THRESHOLD'} || 10,
        PHP_FPM_EMERGENCY_RESTART_INTERVAL  => $self->{'config'}->{'PHP_FPM_EMERGENCY_RESTART_INTERVAL'} || '1m',
        PHP_FPM_LOG_LEVEL                   => $self->{'config'}->{'PHP_FPM_LOG_LEVEL'} || 'error',
        PHP_FPM_PROCESS_CONTROL_TIMEOUT     => $self->{'config'}->{'PHP_FPM_PROCESS_CONTROL_TIMEOUT'} || '60s',
        PHP_FPM_PROCESS_MAX                 => $self->{'config'}->{'PHP_FPM_PROCESS_MAX'} || 0,
        PHP_FPM_RLIMIT_FILES                => $self->{'config'}->{'PHP_FPM_RLIMIT_FILES'} || 4096,
        PHP_OPCODE_CACHE_ENABLED            => $self->{'config'}->{'PHP_OPCODE_CACHE_ENABLED'} // 1,
        PHP_OPCODE_CACHE_MAX_MEMORY         => $self->{'config'}->{'PHP_OPCODE_CACHE_MAX_MEMORY'} || 32,
        TIMEZONE                            => $::imscpConfig{'TIMEZONE'} || 'UTC'
    };

    # Configure all PHP versions (even those which are disabled)
    for my $version ( @{ $self->{'_available_php_versions'} } ) {
        $serverData->{'PHP_VERSION'} = $version;

        # Master php.ini file for apache2handler, cli, cgi and fpm SAPIs
        for my $sapiDir ( qw/ apache2 cgi cli fpm / ) {
            $self->buildConfFile( "$sapiDir/php.ini", "/etc/php/$version/$sapiDir/php.ini", undef, $serverData );
        }

        # Master conffile for fpm SAPI
        $self->buildConfFile( 'fpm/php-fpm.conf', "/etc/php/$version/fpm/php-fpm.conf", undef, $serverData );
        # Default pool conffile for fpm SAPI
        $self->buildConfFile( 'fpm/pool.conf.default', "/etc/php/$version/fpm/pool.d/www.conf", undef, $serverData );
    }

    if ( $self->{'httpd'}->getServerName() eq 'Apache' ) {
        # Create the Apache fcgid_imscp module, which itself depends on the Apache fcgi module
        $self->{'httpd'}->buildConfFile( "$self->{'cfgDir'}/cgi/apache_fcgid_module.conf",
            "$self->{'httpd'}->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.conf",
            undef,
            {
                PHP_FCGID_MAX_REQUESTS_PER_PROCESS => $self->{'config'}->{'PHP_FCGID_MAX_REQUESTS_PER_PROCESS'} || 900,
                PHP_FCGID_MAX_REQUEST_LEN          => $self->{'config'}->{'PHP_FCGID_MAX_REQUEST_LEN'} || 1073741824,
                PHP_FCGID_IO_TIMEOUT               => $self->{'config'}->{'PHP_FCGID_IO_TIMEOUT'} || 600,
                PHP_FCGID_MAX_PROCESS              => $self->{'config'}->{'PHP_FCGID_MAX_PROCESS'} || 1000
            }
        );

        iMSCP::File
            ->new( filename => "$self->{'httpd'}->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.load" )
            ->set( "# Depends: fcgid\n" )
            ->save()
            ->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} )
            ->mode( 0644 );
    }

    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    if ( $self->{'httpd'}->getServerName() eq 'Apache' ) {
        if ( $self->{'config'}->{'PHP_SAPI'} eq 'apache2handler' ) {
            # Enable Apache PHP module for selected PHP alternative
            $self->{'httpd'}->enableModules( "php$self->{'config'}->{'PHP_VERSION'}" );
        } elsif ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
            # Enable Apache fcgid_imscp module, which itself depends on the Apache fcgid module
            $self->{'httpd'}->enableModules( 'fcgid_imscp' );
        } elsif ( $self->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
            # Enable proxy_fcgi module
            $self->{'httpd'}->enableModules( qw/ proxy_fcgi setenvif / );
            # Enable PHP-FPM service for selected PHP alternative
            iMSCP::Service->getInstance()->enable( "php$self->{'config'}->{'PHP_VERSION'}-fpm" );
        } else {
            die( 'Unknown PHP SAPI' );
        }
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->{'httpd'}->removeModules( 'fcgid_imscp' ) if $self->{'httpd'}->getServerName() eq 'Apache';
    iMSCP::File->new( filename => "/etc/init/php$_-fpm.override" )->remove() for split /\s+/, $self->{'config'}->{'PHP_AVAILABLE_VERSIONS'};
    iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} )->remove();
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Php::addDomain()

=cut

sub addDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpAddDomain', $moduleData );
    $self->_buildPhpConfig( $moduleData );
    $self->{'eventManager'}->trigger( 'afterPhpAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Php::disableDomain()

=cut

sub disableDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpDisableDomain', $moduleData );
    $self->_deletePhpConfig( $moduleData, FALSE );
    $self->{'eventManager'}->trigger( 'afterPhpDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Php::deleteDomain()

=cut

sub deleteDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpDeleteDomain', $moduleData );
    $self->_deletePhpConfig( $moduleData, FALSE );
    $self->{'eventManager'}->trigger( 'afterPhpDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Php::addSubdomain()

=cut

sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpAddSubdomain', $moduleData );
    $self->_buildPhpConfig( $moduleData );
    $self->{'eventManager'}->trigger( 'afterPhpAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Php::disableSubdomain()

=cut

sub disableSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpDisableSubdomain', $moduleData );
    $self->_deletePhpConfig( $moduleData, FALSE );
    $self->{'eventManager'}->trigger( 'afterPhpDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Php::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePhpDeleteSubdomain', $moduleData );
    $self->_deletePhpConfig( $moduleData, FALSE );
    $self->{'eventManager'}->trigger( 'afterPhpDeleteSubdomain', $moduleData );
}

=item enableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 See iMSCP::Servers::Php::enableModules()

=cut

sub enableModules
{
    my ( $self, $modules, $phpVersion, $phpSapi ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};
    $phpSapi ||= $self->{'config'}->{'PHP_SAPI'};
    $phpSapi = 'apache2' if $phpSapi eq 'apache2handler';

    ref $modules eq 'ARRAY' or croak( 'Invalid $module parameter. Array expected' );

    my $rs = execute( [ 'phpenmod', '-v', $phpVersion, '-s', $phpSapi, @{ $modules } ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );

    $self->{'restart'}->{$phpVersion} ||= TRUE;
}

=item disableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 See iMSCP::Servers::Php:disableModules()

=cut

sub disableModules
{
    my ( $self, $modules, $phpVersion, $phpSapi ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};
    $phpSapi ||= $self->{'config'}->{'PHP_SAPI'};
    $phpSapi = 'apache2' if $phpSapi eq 'apache2handler';

    ref $modules eq 'ARRAY' or croak( 'Invalid $module parameter. Array expected' );

    my $rs = execute( [ 'phpdismod', '-v', $phpVersion, '-s', $phpSapi, @{ $modules } ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );

    $self->{'restart'}->{$phpVersion} ||= TRUE;
}

=item start( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self, $phpVersion ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    iMSCP::Service->getInstance()->start( "php$phpVersion-fpm" );
}

=item stop( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self, $phpVersion ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    iMSCP::Service->getInstance()->stop( "php$phpVersion-fpm" );
}

=item reload( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self, $phpVersion ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    iMSCP::Service->getInstance()->reload( "php$phpVersion-fpm" );
}

=item restart( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self, $phpVersion ) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    iMSCP::Service->getInstance()->restart( "php$phpVersion-fpm" );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Php::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    # Define properties that are expected by parent package
    @{ $self }{qw/ PHP_FPM_POOL_DIR PHP_FPM_RUN_DIR PHP_PEAR_DIR /} = (
        # We defer the evaluation because the PHP version can be overriden by 3rd-party components.
        defer { "/etc/php/$self->{'config'}->{'PHP_VERSION'}/fpm/pool.d" }, '/run/php', '/usr/share/php'
    );
    $self->{'_available_php_versions'} = lazy { [ split /\s+/, $self->{'config'}->{'PHP_AVAILABLE_VERSIONS'} ]; };
    $self->SUPER::_init();
}

=item _buildPhpConfig( \$moduleData )

 Build PHP config for a domain or subdomain

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub _buildPhpConfig
{
    my ( $self, $moduleData ) = @_;

    return $self->_buildApacheHandlerConfig( $moduleData ) if $self->{'config'}->{'PHP_SAPI'} eq 'apache2handler';

    $self->_deletePhpConfig( $moduleData );

    return $self->_buildCgiConfig( $moduleData ) if $self->{'config'}->{'PHP_SAPI'} eq 'cgi';

    $self->_buildFpmConfig( $moduleData ) if $self->{'config'}->{'PHP_SAPI'} eq 'fpm';
}

=item _deletePhpConfig( \%moduleData [, $checkContext = TRUE ] )

 Delete PHP config for a domain or subdomain

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Param bool $checkContext Whether or not context must be checked
 Return void, croak on failure

=cut

sub _deletePhpConfig
{
    my ( $self, $moduleData, $checkContext ) = @_;
    $checkContext //= TRUE;

    return $self->_deleteCgiConfig( $moduleData, FALSE ) if $self->{'config'}->{'PHP_SAPI'} eq 'cgi';

    $self->_deleteFpmConfig( $moduleData, FALSE ) if $self->{'config'}->{'PHP_SAPI'} eq 'fpm';
}

=item _deleteCgiConfig( \%moduleData [, $checkContext = TRUE ] )

 Delete CGI/FastCGI configuration for a domain or subdomain

 Param hashref \%moduleData Data as provided by the Alias|Domain|SubAlias|Subdomain modules
 Param bool $checkContext Whether or not context must be checked
 return void, die on failure

=cut

sub _deleteCgiConfig
{
    my ( $self, $moduleData, $checkContext ) = @_;
    $checkContext //= 1;

    for my $version ( @{ $self->{'_available_php_versions'} } ) {
        if ( $checkContext
            && ( $self->{'config'}->{'PHP_VERSION'} eq $version
            && ( $moduleData->{'PHP_SUPPORT'} eq 'yes'
            && ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} eq 'dmn' )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && grep ( $moduleData->{'DOMAIN_TYPE'} eq $_, 'dmn', 'als' ) )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'no' ) ) )
        ) {
            next;
        }

        debug( sprintf(
            'Deleting the %s CGI/FastCGI configuration directory', "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'DOMAIN_NAME'}"
        ));

        iMSCP::Dir->new( dirname => "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove();
    }
}

=item _deleteFpmConfig( \%moduleData [, $checkContext = TRUE ] )

 Delete PHP-FPM configuration for a domain or subdomain

 Param hashref \%moduleData Data as provided by the Alias|Domain|SubAlias|Subdomain modules
 Param bool $checkContext Whether or not context must be checked
 Return void, die on failure

=cut

sub _deleteFpmConfig
{
    my ( $self, $moduleData, $checkContext ) = @_;
    $checkContext //= 1;

    for my $version ( @{ $self->{'_available_php_versions'} } ) {
        if ( $checkContext
            && ( $self->{'config'}->{'PHP_VERSION'} eq $version
            && ( $moduleData->{'PHP_SUPPORT'} eq 'yes'
            && ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} eq 'dmn' )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && grep ( $moduleData->{'DOMAIN_TYPE'} eq $_, 'dmn', 'als' ) )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'no' ) ) )
        ) {
            next;
        }

        next unless -f "/etc/php/$version/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf";

        debug( sprintf( 'Deleting the %s FPM pool configuration file', "/etc/php/$version/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf" ));

        iMSCP::File->new( filename => "/etc/php/$version/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf" )->remove();

        if ( $self->{'config'}->{'PHP_VERSION'} ne $version
            && $self->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'tcp'
            && iMSCP::Getopt->context() ne 'installer'
        ) {
            # In TCP mode, we need reload the FPM instance immediately, else,
            # one FPM instance could fail to reload due to port already in use
            iMSCP::Service->getInstance()->reload( "php$version-fpm" );
            next;
        }

        $self->{'reload'}->{$version} ||= TRUE;
    }
}

=item _setFullVersion()

 See iMSCP::Servers::Php::Abstract::_setFullVersion()

=cut

sub _setFullVersion
{
    my ( $self ) = @_;

    ( $self->{'config'}->{'PHP_VERSION_FULL'} ) = `php$self->{'config'}->{'PHP_VERSION'} -nv 2> /dev/null` =~ /^PHP\s+([\d.]+)/ or die(
        "Couldn't guess PHP version for the selected PHP alternative"
    );
}

=item _cleanup( )

 See iMSCP::Servers::Php::Abstract::_cleanup()

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/php.old.data" )->remove();

    # FIXME: Really needed?
    iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/php5-fpm" )->remove();
    iMSCP::Dir->new( dirname => '/etc/php5' )->remove();

    if ( $self->{'httpd'}->getServerName() ) {
        $self->{'httpd'}->disableModules( qw/ fastcgi_imscp php5 php5_cgi php5filter php_fpm_imscp proxy_handler / );

        for my $file ( 'fastcgi_imscp.conf', 'fastcgi_imscp.load', 'php_fpm_imscp.conf', 'php_fpm_imscp.load' ) {
            iMSCP::File->new( filename => "$self->{'httpd'}->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$file" )->remove();
        }
    }
}

=item _shutdown( )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ( $self ) = @_;

    return unless $self->{'config'}->{'PHP_SAPI'} eq 'fpm';

    my $srvProvider = iMSCP::Service->getInstance();

    for my $action ( qw/ reload restart / ) {
        for my $phpVersion ( keys %{ $self->{$action} } ) {
            # Check for actions precedence. The 'restart' action has higher precedence than the 'reload' action
            next if $action eq 'reload' && $self->{'restart'}->{$phpVersion};

            # Do not act if the PHP version is not enabled
            next unless $srvProvider->isEnabled( "php$phpVersion-fpm" );

            $self->$action();
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
