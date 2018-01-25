=head1 NAME

 iMSCP::Servers::Php::Debian - i-MSCP (Debian) PHP server implementation

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

package iMSCP::Servers::Php::Debian;

use strict;
use warnings;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt iMSCP::Servers::Httpd /;
use File::Basename;
use File::Spec;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use iMSCP::Servers::Php;
use Scalar::Defer;
use version;
use parent 'iMSCP::Servers::Php';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) PHP server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Php::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    my $rs = $self->SUPER::preinstall();
    return $rs if $rs;

    eval {
        my $httpd = iMSCP::Servers::Httpd->factory();

        # Disable i-MSCP Apache fcgid modules. It will be re-enabled in postinstall if needed
        $httpd->disableModules( 'fcgid_imscp' ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

        # Disable default Apache conffile for CGI programs
        # FIXME: One administrator could rely on default configuration (outside of i-MSCP)
        $httpd->disableConfs( 'serve-cgi-bin.conf' ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

        my $srvProvider = iMSCP::Service->getInstance();

        # Disable PHP session cleaner services as we don't rely on them
        # FIXME: One administrator could rely on those services (outside of i-MSCP)
        for ( qw/ phpsessionclean phpsessionclean.timer / ) {
            next unless $srvProvider->hasService( $_ );
            $srvProvider->stop( $_ );

            if ( $srvProvider->isSystemd() ) {
                # If systemd is the current init we mask the service. Service will be disabled and masked.
                $srvProvider->getProvider()->mask( $_ );
            } else {
                $srvProvider->disable( $_ );
            }
        }

        for ( @{$self->{'_available_php_versions'}} ) {
            # Tasks for apache2handler SAPI

            if ( $self->{'config'}->{'PHP_SAPI'} ne 'apache2handler' || $self->{'config'}->{'PHP_VERSION'} ne $_ ) {
                # Disable Apache PHP module if PHP version is other than selected PHP alternative
                $httpd->disableModules( "php$_" ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
            }

            # Tasks for cgi SAPI

            # Disable default Apache conffile
            $httpd->disableConfs( "php$_-cgi.conf" ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

            # Tasks for fpm SAPI

            if ( $srvProvider->hasService( "php$_-fpm" ) ) {
                # Stop PHP-FPM instance
                $self->stop( $_ ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

                # Disable PHP-FPM service if selected SAPI for customer is not fpm or if PHP version
                # is other than selected PHP alternative
                if ( $self->{'config'}->{'PHP_SAPI'} ne 'fpm' || $self->{'config'}->{'PHP_VERSION'} ne $_ ) {
                    if ( $srvProvider->isSystemd() ) {
                        # If systemd is the current init we mask the service. Service will be disabled and masked.
                        $srvProvider->getProvider()->mask( "php$_-fpm" );
                    } else {
                        $srvProvider->disable( "php$_-fpm" );
                    }
                }
            }

            # Disable default Apache conffile
            $httpd->disableConfs( "php$_-fpm.conf " ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

            # Reset PHP-FPM pool confdir
            for ( grep !/www\.conf$/, glob "/etc/php/$_/fpm/pool.d/*.conf" ) {
                iMSCP::File->new( filename => $_ )->delFile() == 0 or croak(
                    getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
                );
            }
        }

        # Create/Reset/Remove FCGI starter rootdir, depending of selected PHP SAPI for customers
        my $dir = iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} );
        $dir->remove();
        if ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
            $dir->make( {
                user  => $main::imscpConfig{'ROOT_USER'},
                group => $main::imscpConfig{'ROOT_GROUP'},
                mode  => 0555
            } );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    eval {
        my $httpd = iMSCP::Servers::Httpd->factory();
        my $serverData = {
            HTTPD_USER                          => $httpd->getRunningUser(),
            HTTPD_GROUP                         => $httpd->getRunningGroup(),
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
            TIMEZONE                            => $main::imscpConfig{'TIMEZONE'} || 'UTC'
        };

        # Configure all PHP alternatives
        for ( @{$self->{'_available_php_versions'}} ) {
            $serverData->{'PHP_VERSION'} = $_;

            # Master php.ini file for apache2handler, cli, cgi and fpm SAPIs
            for my $sapiDir( qw/ apache2 cgi cli fpm / ) {
                my $rs = $self->buildConfFile( "$sapiDir/php.ini", "/etc/php/$_/$sapiDir/php.ini", undef, $serverData );
                last if $rs;
            }

            # Master conffile for fpm SAPI
            my $rs = $self->buildConfFile( 'fpm/php-fpm.conf', "/etc/php/$_/fpm/php-fpm.conf", undef, $serverData );
            # Default pool conffile for fpm SAPI
            $rs ||= $self->buildConfFile( 'fpm/pool.conf.default', "/etc/php/$_/fpm/pool.d/www.conf", undef, $serverData );
            $rs == 0 or croak ( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
        }

        # Build the Apache fcgid module conffile
        $httpd->buildConfFile( "$self->{'cfgDir'}/cgi/apache_fcgid_module.conf", "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.conf",
            undef,
            {
                PHP_FCGID_MAX_REQUESTS_PER_PROCESS => $self->{'config'}->{'PHP_FCGID_MAX_REQUESTS_PER_PROCESS'} || 900,
                PHP_FCGID_MAX_REQUEST_LEN          => $self->{'config'}->{'PHP_FCGID_MAX_REQUEST_LEN'} || 1073741824,
                PHP_FCGID_IO_TIMEOUT               => $self->{'config'}->{'PHP_FCGID_IO_TIMEOUT'} || 600,
                PHP_FCGID_MAX_PROCESS              => $self->{'config'}->{'PHP_FCGID_MAX_PROCESS'} || 1000
            }
        ) == 0 or croak ( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

        my $file = iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid.load" );
        my $cfgTpl = $file->getAsRef();
        defined $cfgTpl or croak( sprintf( "Couldn't read the %s file", $file->{'filename'} ));

        $file = iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.load" );
        $file->set( "<IfModule !mod_fcgid.c>\n" . ${$cfgTpl} . "</IfModule>\n" );
        my $rs = $file->save();
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );

        $rs ||= $self->_cleanup();
        $rs == 0 or croak ( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval {
        my $httpd = iMSCP::Servers::Httpd->factory();

        if ( $self->{'config'}->{'PHP_SAPI'} eq 'apache2handler' ) {
            # Enable Apache PHP module for selected PHP alternative
            $httpd->enableModules( "php$self->{'config'}->{'PHP_VERSION'}" ) == 0 or croak (
                getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
            );
        } elsif ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
            # Enable Apache fcgid module
            $httpd->enableModules( qw/ fcgid fcgid_imscp / ) == 0 or croak (
                getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
            );
        } elsif ( $self->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
            # Enable proxy_fcgi module
            $httpd->enableModules( qw/ proxy_fcgi setenvif / ) == 0 or croak (
                getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
            );

            # Enable PHP-FPM service for selected PHP alternative
            iMSCP::Service->getInstance()->enable( "php$self->{'config'}->{'PHP_VERSION'}-fpm" );
        } else {
            croak( 'Unknown PHP SAPI' );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    eval {
        my $httpd = iMSCP::Servers::Httpd->factory();

        $httpd->disableModules( 'fcgid_imscp' ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

        for ( 'fcgid_imscp.conf', 'fcgid_imscp.load' ) {
            next unless -f "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_";
            iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_" )->delFile() == 0 or croak(
                getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
            );
        }

        for ( split /\s+/, $self->{'config'}->{'PHP_AVAILABLE_VERSIONS'} ) {
            next unless -f "/etc/init/php$_-fpm.override";
            iMSCP::File->new( filename => "/etc/init/php$_-fpm.override" )->delFile() == 0 or croak(
                getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
            );
        }

        iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} )->remove();
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Php::addDomain()

=cut

sub addDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpAddDomain', $moduleData );
    return $rs if $rs;

    eval { $self->_buildPhpConfig( $moduleData ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Php::disableDomain()

=cut

sub disableDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpDisableDomain', $moduleData );
    return $rs if $rs;

    eval { $self->_deletePhpConfig( $moduleData, 0 ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Php::deleteDomain()

=cut

sub deleteDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpDeleteDomain', $moduleData );
    return $rs if $rs;

    eval { $self->_deletePhpConfig( $moduleData, 0 ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Php::addSubdomain()

=cut

sub addSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpAddSubdomain', $moduleData );
    return $rs if $rs;

    eval { $self->_buildPhpConfig( $moduleData ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Php::disableSubdomain()

=cut

sub disableSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpDisableSubdomain', $moduleData );
    return $rs if $rs;

    eval { $self->_deletePhpConfig( $moduleData, 0 ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Php::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpDeleteSubdomain', $moduleData );
    return $rs if $rs;

    eval { $self->_deletePhpConfig( $moduleData, 0 ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterPhpDeleteSubdomain', $moduleData );
}

=item enableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 See iMSCP::Servers::Php::enableModules()

=cut

sub enableModules
{
    my ($self, $modules, $phpVersion, $phpSapi) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};
    $phpSapi ||= $self->{'config'}->{'PHP_SAPI'};
    $phpSapi = 'apache2' if $phpSapi eq 'apache2handler';

    ref $modules eq 'ARRAY' or croak( 'Invalid $module parameter. Array expected' );

    my $rs = execute( [ '/usr/sbin/phpenmod', '-v', $phpVersion, '-s', $phpSapi, @{$modules} ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;

    $self->{'restart'}->{$phpVersion} ||= 1 unless $rs;
    $rs;
}

=item disableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 See iMSCP::Servers::Php:disableModules()

=cut

sub disableModules
{
    my ($self, $modules, $phpVersion, $phpSapi) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};
    $phpSapi ||= $self->{'config'}->{'PHP_SAPI'};
    $phpSapi = 'apache2' if $phpSapi eq 'apache2handler';

    ref $modules eq 'ARRAY' or croak( 'Invalid $module parameter. Array expected' );

    my $rs = execute( [ '/usr/sbin/phpdismod', '-v', $phpVersion, '-s', $phpSapi, @{$modules} ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;

    $self->{'restart'}->{$phpVersion} ||= 1 unless $rs;
    $rs;
}

=item start( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self, $phpVersion) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    eval { iMSCP::Service->getInstance()->start( "php$phpVersion-fpm" ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self, $phpVersion) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    eval { iMSCP::Service->getInstance()->stop( "php$phpVersion-fpm" ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item reload( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self, $phpVersion) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    eval { iMSCP::Service->getInstance()->reload( "php$phpVersion-fpm" ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( [ $phpVersion = $self->{'config'}->{'PHP_VERSION'} ] )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self, $phpVersion) = @_;
    $phpVersion ||= $self->{'config'}->{'PHP_VERSION'};

    eval { iMSCP::Service->getInstance()->restart( "php$phpVersion-fpm" ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Php::_init()

=cut

sub _init
{
    my ($self) = @_;

    # Define properties that are expected by parent package
    @{$self}{qw/ PHP_FPM_POOL_DIR PHP_FPM_RUN_DIR PHP_PEAR_DIR /} = (
        # We defer the evaluation because the PHP version can be overriden by 3rd-party components.
        ( defer { "/etc/php/$self->{'config'}->{'PHP_VERSION'}/fpm/pool.d" } ),
        '/run/php',
        '/usr/share/php'
    );
    $self->{'_available_php_versions'} = lazy { [ split /\s+/, $self->{'config'}->{'PHP_AVAILABLE_VERSIONS'} ]; };
    $self->SUPER::_init();
}

=item _buildPhpConfig( \$moduleData )

 Build PHP config for a domain or subdomain

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return void, croak on failure

=cut

sub _buildPhpConfig
{
    my ($self, $moduleData) = @_;

    if ( $self->{'config'}->{'PHP_SAPI'} eq 'apache2handler' ) {
        $self->_buildApacheHandlerConfig( $moduleData );
        return;
    }

    $self->_deletePhpConfig( $moduleData );

    if ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
        $self->_buildCgiConfig( $moduleData );
        return;
    }

    if ( $self->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
        $self->_buildFpmConfig( $moduleData );
    }
}

=item _deletePhpConfig( \%moduleData [, $checkContext = TRUE ] )

 Delete PHP config for a domain or subdomain

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Param bool $checkContext Whether or not context must be checked
 Return void, croak on failure

=cut

sub _deletePhpConfig
{
    my ($self, $moduleData, $checkContext) = @_;
    $checkContext //= 1;

    if ( $self->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
        $self->_deleteCgiConfig( $moduleData, 0 );
        return;
    }

    if ( $self->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
        $self->_deleteFpmConfig( $moduleData, 0 );
    }
}

=item _deleteCgiConfig( \%moduleData [, $checkContext = TRUE ] )

 Delete CGI/FastCGI configuration for a domain or subdomain

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Param bool $checkContext Whether or not context must be checked
 return void, croak on failure

=cut

sub _deleteCgiConfig
{
    my ($self, $moduleData, $checkContext) = @_;
    $checkContext //= 1;

    for ( @{$self->{'_available_php_versions'}} ) {
        if ( $checkContext
            && ( $self->{'config'}->{'PHP_VERSION'} eq $_
            && ( $moduleData->{'PHP_SUPPORT'} eq 'yes'
            && ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} eq 'dmn' )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && grep($moduleData->{'DOMAIN_TYPE'} eq $_, 'dmn', 'als') )
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

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Param bool $checkContext Whether or not context must be checked
 return void, croak on failure

=cut

sub _deleteFpmConfig
{
    my ($self, $moduleData, $checkContext) = @_;
    $checkContext //= 1;

    for ( @{$self->{'_available_php_versions'}} ) {
        if ( $checkContext
            && ( $self->{'config'}->{'PHP_VERSION'} eq $_
            && ( $moduleData->{'PHP_SUPPORT'} eq 'yes'
            && ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} eq 'dmn' )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && grep($moduleData->{'DOMAIN_TYPE'} eq $_, 'dmn', 'als') )
            || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'no' ) ) )
        ) {
            next;
        }

        next unless -f "/etc/php/$_/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf";

        debug( sprintf( 'Deleting the %s FPM pool configuration file', "/etc/php/$_/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf" ));

        iMSCP::File->new( filename => "/etc/php/$_/fpm/pool.d/$moduleData->{'DOMAIN_NAME'}.conf" )->delFile() == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unkown error'
        );

        if ( $self->{'config'}->{'PHP_VERSION'} ne $_
            && $self->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'tcp'
            && iMSCP::Getopt->context() ne 'installer'
        ) {
            # In TCP mode, we need reload the FPM instance immediately, else,
            # one FPM instance could fail to reload due to port already in use
            iMSCP::Service->getInstance()->reload( "php$_-fpm" );
            next;
        }

        $self->{'reload'}->{$_} ||= 1;
    }
}

=item _setFullVersion()

 See iMSCP::Servers::Php::Abstract::_setFullVersion()

=cut

sub _setFullVersion
{
    my ($self) = @_;

    ( $self->{'config'}->{'PHP_VERSION_FULL'} ) = `/usr/bin/php -nv 2> /dev/null` =~ /^PHP\s+([\d.]+)/ or croak(
        "Couldn't guess PHP version for the selected PHP alternative"
    );
}

=item _cleanup( )

 See iMSCP::Servers::Php::Abstract::_cleanup()

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/php.old.data" ) {
        iMSCP::File->new( filename => "$self->{'cfgDir'}/php.old.data" )->delFile() == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );
    }

    if ( -f "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/php5-fpm" ) {
        iMSCP::File->new( filename => "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/php5-fpm" )->delFile() == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );
    }

    iMSCP::Dir->new( dirname => '/etc/php5' )->remove();

    my $httpd = iMSCP::Servers::Httpd->factory();

    $httpd->disableModules( qw/ fastcgi_imscp php5 php5_cgi php5filter php_fpm_imscp proxy_handler / ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );

    for ( 'fastcgi_imscp.conf', 'fastcgi_imscp.load', 'php_fpm_imscp.conf', 'php_fpm_imscp.load' ) {
        next unless -f "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_";

        iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_" )->delFile() == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );
    }
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless $self->{'config'}->{'PHP_SAPI'} eq 'fpm';

    my $srvProvider = iMSCP::Service->getInstance();

    for my $action( qw/ reload restart / ) {
        for my $phpVersion( keys %{$self->{$action}} ) {
            # Check for actions precedence. The 'restart' action has higher precedence than the 'reload' action
            next if $action eq 'reload' && $self->{'restart'}->{$phpVersion};
            # Do not act if the PHP version is not enabled
            next unless $srvProvider->isEnabled( "php$phpVersion-fpm" );

            $srvProvider->registerDelayedAction( "php$phpVersion-fpm", [ $action, sub { $self->$action(); } ], $priority );
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
