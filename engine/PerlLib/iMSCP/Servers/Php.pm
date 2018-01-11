=head1 NAME

 iMSCP::Servers::Php - Factory and abstract implementation for the i-MSCP php servers

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

package iMSCP::Servers::Php;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use File::Basename;
use File::Spec;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef getBlocByRef replaceBlocByRef /;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP php servers.

 TODO (Enterprise Edition):
 - Depending of selected Httpd server, customer should be able to choose between several SAPI:
  - Apache2 with MPM Event, Worker or Prefork: cgi or fpm
  - Apache2 with MPM ITK                     : apache2handler or fpm
  - Nginx (Implementation not available yet) : fpm
  - ...
 - Customer should be able to select the PHP version to use (Merge of PhpSwitcher plugin in core)

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get server priority

 Return int Server priority

=cut

sub getPriority
{
    250;
}

=back

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    eval { $self->_setFullVersion(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    return 0 unless $self->{'config'}->{'PHP_SAPI'} eq 'cgi';

    setRights( $self->{'config'}->{'PHP_FCGI_STARTER_DIR'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0555'
        }
    );
}

=item getEventServerName( )

 See iMSCP::Servers::Abstract::getEventServerName()

=cut

sub getEventServerName
{
    my ($self) = @_;

    'Php';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'PHP %s', $self->{'config'}->{'PHP_VERSION'} );
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

    $self->{'config'}->{'PHP_VERSION'};
}

=item addDomain( \%moduleData )

 Process addDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpAddDomain( \%moduleData )
  - afterPhpAddDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub addDomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the addDomain() method', ref $self ));
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpdDisableDomain( \%moduleData )
  - afterPhpDisableDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the AliasiMSCP::Modules::|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub disableDomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the disableDomain() method', ref $self ));
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpDeleteDomain( \%moduleData )
  - afterPhpdDeleteDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain modules
 Return int 0 on success, other on failure

=cut

sub deleteDomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the deleteDomain() method', ref $self ));
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpAddSubdomain( \%moduleData )
  - afterPhpAddSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return int 0 on success, other on failure

=cut

sub addSubdomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the addSubdomain() method', ref $self ));
}

=item disableSubdomain( \%moduleData )

 Process disableSubdomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpDisableSubdomain( \%moduleData )
  - afterPhpdDisableSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return int 0 on success, other on failure

=cut

sub disableSubdomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the disableSubdomain() method', ref $self ));
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpDeleteSubdomain( \%moduleData )
  - afterPhpDeleteSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return int 0 on success, other on failure

=cut

sub deleteSubdomain
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the deleteSubdomain() method', ref $self ));
}

=item enableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 Enable the given PHP modules

 Param array \@modules Array containing list of modules to enable
 Param string $phpVersion OPTIONAL PHP version to operate on (default to selected PHP alternative)
 Param string phpSApi OPTIONAL PHP SAPI to operate on (default to selected PHP SAPI)
 Return int 0 on sucess, other on failure

=cut

sub enableModules
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the enableModules() method', ref $self ));
}

=item disableModules( \@modules [, $phpVersion = $self->{'config'}->{'PHP_VERSION'} [, $phpSapi = $self->{'config'}->{'PHP_SAPI'} ] ] )

 Disable the given PHP modules

 Param array \@modules Array containing list of modules to disable
 Param string $phpVersion OPTIONAL PHP version to operate on (default to selected PHP alternative)
 Param string phpSApi OPTIONAL PHP SAPI to operate on (default to selected PHP SAPI)
 Return int 0 on sucess, other on failure

=cut

sub disableModules
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the disableModules() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Servers::Php::Abstract, croak on failure

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    # Check for properties that must be defined in concret server implementations
    for ( qw/ PHP_FPM_POOL_DIR PHP_FPM_RUN_DIR PHP_PEAR_DIR / ) {
        defined $self->{$_ } or croak( sprintf( 'The %s package must define the %s property', ref $self, $_ ));
    }

    @{$self}{qw/ reload restart _templates cfgDir /} = ( {}, {}, {}, "$main::imscpConfig{'CONF_DIR'}/php" );
    $self->_mergeConfig() if defined $main::execmode && $main::execmode eq 'setup' && -f "$self->{'cfgDir'}/php.data.dist";
    tie %{$self->{'config'}},
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/php.data",
        readonly    => !( defined $main::execmode && $main::execmode eq 'setup' ),
        nodeferring => defined $main::execmode && $main::execmode eq 'setup';
    $self->{'eventManager'}->register( [ qw/ beforeApache2BuildConfFile afterApache2AddFiles / ], $self, 100 );
    $self->SUPER::_init();
}

=item _mergeConfig()

 Merge distribution configuration with production configuration

 Croak on failure

=cut

sub _mergeConfig
{
    my ($self) = @_;

    if ( -f "$self->{'cfgDir'}/php.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/php.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/php.data", readonly => 1;

        debug( 'Merging old configuration with new configuration ...' );

        while ( my ($key, $value) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/php.data.dist" )->moveFile( "$self->{'cfgDir'}/php.data" ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );
}

=item _setFullVersion()

 Set full version for selected PHP version

 Return void, croak on failure

=cut

sub _setFullVersion
{
    my ($self) = @_;

    croak( sprintf( 'The %s class must implement the _setFullVersion() method', ref $self ));
}

=item _buildApache2HandlerConfig( \%moduleData )

 Build PHP apache2handler configuration for the given domain
 
 There are nothing special to do here. We trigger events for consistency reasons.

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return void, croak on failure

=cut

sub _buildApache2HandlerConfig
{
    my ($self, $moduleData) = @_;

    if ( $moduleData->{'PHP_SUPPORT'} eq 'no'
        || $moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'} ne $moduleData->{'DOMAIN_NAME'}
        || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'yes' )
    ) {
        return;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpApache2HandlerSapiBuildConf', $moduleData );

    debug( sprintf( 'Building Apache2Handler configuration for the %s domain', $moduleData->{'DOMAIN_NAME'} ));

    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpApache2HandlerSapiBuildConf', $moduleData );
    $rs == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
}

=item _buildCgiConfig( \%moduleData )

 Build PHP CGI/FastCGI configuration for the given domain

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return void, croak on failure

=cut

sub _buildCgiConfig
{
    my ($self, $moduleData) = @_;

    if ( $moduleData->{'PHP_SUPPORT'} eq 'no'
        || $moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'} ne $moduleData->{'DOMAIN_NAME'}
        || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'yes' )
    ) {
        return;
    }

    $self->{'eventManager'}->trigger( 'beforePhpCgiSapiBuildConf', $moduleData ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );

    debug( sprintf( 'Building PHP CGI/FastCGI configuration for the %s domain', $moduleData->{'DOMAIN_NAME'} ));

    #iMSCP::Dir->new( dirname => "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}" )->remove();
    iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} )->make( {
        user  => $main::imscpConfig{'ROOT_USER'},
        group => $main::imscpConfig{'ROOT_GROUP'},
        mode  => 0555
    } );

    for ( "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}",
        "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}/php$self->{'config'}->{'PHP_VERSION'}"
    ) {
        iMSCP::Dir->new( dirname => $_ )->make( {
            user  => $moduleData->{'USER'},
            group => $moduleData->{'GROUP'},
            mode  => 0550
        } );
    }

    my $serverData = {
        EMAIL_DOMAIN          => $moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'},
        PHP_FCGI_CHILDREN     => $self->{'config'}->{'PHP_FCGI_CHILDREN'},
        PHP_FCGI_MAX_REQUESTS => $self->{'config'}->{'PHP_FCGI_MAX_REQUESTS'},
        PHP_VERSION           => $self->{'config'}->{'PHP_VERSION'},
        TMPDIR                => $moduleData->{'HOME_DIR'} . '/phptmp'
    };

    my $rs = $self->buildConfFile(
        'cgi/php-fcgi-starter',
        "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}/php-fcgi-starter",
        $moduleData,
        $serverData,
        {
            user   => $moduleData->{'USER'},
            group  => $moduleData->{'GROUP'},
            mode   => 0550,
            cached => 1
        }
    );
    $rs ||= $self->buildConfFile(
        'cgi/php.ini.user',
        "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}/php$self->{'config'}->{'PHP_VERSION'}/php.ini",
        $moduleData,
        $serverData,
        {
            user   => $moduleData->{'USER'},
            group  => $moduleData->{'GROUP'},
            mode   => 0440,
            cached => 1
        }
    );
    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpCgiSapiBuildConf', $moduleData );
    $rs == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
}

=item _buildFpmConfig( \%moduleData )

 Build PHP fpm configuration for the given domain

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::SubAlias|iMSCP::Modules::Subdomain modules
 Return void, croak on failure

=cut

sub _buildFpmConfig
{
    my ($self, $moduleData) = @_;

    if ( $moduleData->{'PHP_SUPPORT'} eq 'no'
        || $moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'} ne $moduleData->{'DOMAIN_NAME'}
        || ( $moduleData->{'PHP_CONFIG_LEVEL'} eq 'per_site' && $moduleData->{'FORWARD'} eq 'yes' )
    ) {
        return;
    }

    $self->{'eventManager'}->trigger( 'beforePhpFpmSapiBuildConf', $moduleData ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );

    debug( sprintf( 'Building PHP-FPM configuration for the %s domain', $moduleData->{'DOMAIN_NAME'} ));

    my $serverData = {
        EMAIL_DOMAIN                 => $moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'},
        PHP_FPM_LISTEN_ENDPOINT      => ( $self->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds' )
            ? "{PHP_FPM_RUN_DIR}/php{PHP_VERSION}-fpm-{PHP_CONFIG_LEVEL_DOMAIN}.sock"
            : '127.0.0.1:' . ( $self->{'config'}->{'PHP_FPM_LISTEN_PORT_START'}+$moduleData->{'PHP_FPM_LISTEN_PORT'} ),
        PHP_FPM_MAX_CHILDREN         => $self->{'config'}->{'PHP_FPM_MAX_CHILDREN'} // 6,
        PHP_FPM_MAX_REQUESTS         => $self->{'config'}->{'PHP_FPM_MAX_REQUESTS'} // 1000,
        PHP_FPM_MAX_SPARE_SERVERS    => $self->{'config'}->{'PHP_FPM_MAX_SPARE_SERVERS'} // 2,
        PHP_FPM_MIN_SPARE_SERVERS    => $self->{'config'}->{'PHP_FPM_MIN_SPARE_SERVERS'} // 1,
        PHP_FPM_PROCESS_IDLE_TIMEOUT => $self->{'config'}->{'PHP_FPM_PROCESS_IDLE_TIMEOUT'} || '60s',
        PHP_FPM_PROCESS_MANAGER_MODE => $self->{'config'}->{'PHP_FPM_PROCESS_MANAGER_MODE'} || 'ondemand',
        PHP_FPM_RUN_DIR              => $self->{'PHP_FPM_RUN_DIR'},
        PHP_FPM_START_SERVERS        => $self->{'config'}->{'PHP_FPM_START_SERVERS'} // 1,
        PHP_VERSION                  => $self->{'config'}->{'PHP_VERSION'},
        TMPDIR                       => "$moduleData->{'HOME_DIR'}/phptmp"
    };

    my $rs = $self->buildConfFile(
        'fpm/pool.conf', "$self->{'PHP_FPM_POOL_DIR'}/$moduleData->{'PHP_CONFIG_LEVEL_DOMAIN'}.conf", $moduleData, $serverData, { cached => 1 }
    );
    $self->{'reload'}->{$serverData->{'PHP_VERSION'}} ||= 1 unless $rs;
    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpFpmSapiBuildConf', $moduleData );
    $rs == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
}

=back

=head1 EVENT LISTENERS

=over 4

=item beforeApache2BuildConfFile( $phpServer, \$cfgTpl, $filename, \$trgFile, \%mdata, \%sdata, \%sconfig, $params )

 Event listener that inject PHP configuration in Apache2 vhosts

 Param iMSCP::Servers::Php $phpServer  instance
 Param scalar \$cfgTpl Reference to Apache2 template content
 Param string $filename Apache2 template name
 Param scalar \$trgFile Target file path
 Param hashref \%mdata Data as provided by the iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Param hashref \%sconfig Apache2 server data
 Param hashref \%sconfig Apache2 server data
 Param hashref \%params OPTIONAL parameters:
  - umask   : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal), default to UMASK(2)
  - user    : File owner (default: $> for a new file, no change for existent file)
  - group   : File group (default: $) for a new file, no change for existent file)
  - mode    : File mode (default: 0666 & (~UMASK(2)) for a new file, no change for existent file )
  - cached  : Whether or not loaded file must be cached in memory
  - srcname : Make it possible to override default source filename passed into event listeners. Most used when $srcFile is a TMPFILE(3) file
 Return int 0 on success, other on failure

=cut

sub beforeApache2BuildConfFile
{
    my ($phpServer, $cfgTpl, $filename, $trgFile, $mdata, $sdata, $sconfig, $params) = @_;

    return 0 unless $filename eq 'domain.tpl' && grep( $_ eq $sdata->{'VHOST_TYPE'}, ( 'domain', 'domain_ssl' ) );

    $phpServer->{'eventManager'}->trigger(
        'beforePhpApache2BuildConfFile', $phpServer, $cfgTpl, $filename, $trgFile, $mdata, $sdata, $sconfig, $params
    );

    debug( sprintf( 'Injecting PHP configuration in Apache2 vhost for the %s domain', $mdata->{'DOMAIN_NAME'} ));

    if ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'apache2handler' ) {
        if ( $mdata->{'FORWARD'} eq 'no' && $mdata->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$sdata}{qw/ EMAIL_DOMAIN PHP_PEAR_DIR TMPDIR /} = (
                $mdata->{'PHP_CONFIG_LEVEL_DOMAIN'},
                $phpServer->{'PHP_PEAR_DIR'},
                $mdata->{'HOME_DIR'} . '/phptmp'
            );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_apache2handler BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        php_admin_value open_basedir "{HOME_DIR}/:{PHP_PEAR_DIR}/:dev/random:/dev/urandom"
        php_admin_value upload_tmp_dir "{TMPDIR}"
        php_admin_value session.save_path "{TMPDIR}"
        php_admin_value soap.wsdl_cache_dir "{TMPDIR}"
        php_admin_value sendmail_path "/usr/sbin/sendmail -t -i -f webmaster\@{EMAIL_DOMAIN}"
        php_admin_value max_execution_time {MAX_EXECUTION_TIME}
        php_admin_value max_input_time {MAX_INPUT_TIME}
        php_admin_value memory_limit "{MEMORY_LIMIT}M"
        php_flag display_errors {DISPLAY_ERRORS}
        php_admin_value post_max_size "{POST_MAX_SIZE}M"
        php_admin_value upload_max_filesize "{UPLOAD_MAX_FILESIZE}M"
        php_admin_flag allow_url_fopen {ALLOW_URL_FOPEN}
        # SECTION php_apache2handler END.
        # SECTION document root addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
      # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
      AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
        Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    php_admin_flag engine off
    # SECTION addons END.
EOF
        }
    } elsif ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
        if ( $mdata->{'FORWARD'} eq 'no' && $mdata->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$sdata}{qw/ PHP_FCGI_STARTER_DIR PHP_FCGID_BUSY_TIMEOUT PHP_FCGID_MIN_PROCESSES_PER_CLASS PHP_FCGID_MAX_PROCESS_PER_CLASS /} = (
                $phpServer->{'config'}->{'PHP_FCGI_STARTER_DIR'},
                $mdata->{'MAX_EXECUTION_TIME'}+10,
                $phpServer->{'config'}->{'PHP_FCGID_MIN_PROCESSES_PER_CLASS'} || 0,
                $phpServer->{'config'}->{'PHP_FCGID_MAX_PROCESS_PER_CLASS'} || 6
            );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_cgi BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        Options +ExecCGI
        FCGIWrapper {PHP_FCGI_STARTER_DIR}/{PHP_CONFIG_LEVEL_DOMAIN}/php-fcgi-starter
        # SECTION php_cgi END.
        # SECTION document root addons END.
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    FcgidBusyTimeout {PHP_FCGID_BUSY_TIMEOUT}
    FcgidMinProcessesPerClass {PHP_FCGID_MIN_PROCESSES_PER_CLASS}
    FcgidMaxProcessesPerClass {PHP_FCGID_MAX_PROCESS_PER_CLASS}
    # SECTION addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    # SECTION addons END.
EOF
        }
    } elsif ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
        if ( $mdata->{'FORWARD'} eq 'no' && $mdata->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$sdata}{
                qw/ PHP_FPM_RUN_DIR PHP_VERSION PROXY_FCGI_PATH PROXY_FCGI_URL PROXY_FCGI_RETRY PROXY_FCGI_CONNECTION_TIMEOUT PROXY_FCGI_TIMEOUT /
            } = (
                $phpServer->{'PHP_FPM_RUN_DIR'},
                $phpServer->{'config'}->{'PHP_VERSION'},
                ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds'
                    ? "unix:{PHP_FPM_RUN_DIR}/php{PHP_VERSION}-fpm-{PHP_CONFIG_LEVEL_DOMAIN}.sock|" : ''
                ),
                ( 'fcgi://' . ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds'
                    ? '{PHP_CONFIG_LEVEL_DOMAIN}'
                    : '127.0.0.1:' . ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_PORT_START'}+$mdata->{'PHP_FPM_LISTEN_PORT'} )
                ) ),
                0,
                5,
                $mdata->{'MAX_EXECUTION_TIME'}+10
            );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_fpm BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        <If "%{REQUEST_FILENAME} =~ /\.ph(?:p[3457]?|t|tml)\$/ && -f %{REQUEST_FILENAME}">
            SetEnvIfNoCase ^Authorization\$ "(.+)" HTTP_AUTHORIZATION=\$1
            SetHandler proxy:{PROXY_FCGI_URL}
        </If>
        # SECTION php_fpm END.
        # SECTION document root addons END.
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    # SECTION php_fpm_proxy BEGIN.
    <Proxy "{PROXY_FCGI_PATH}{PROXY_FCGI_URL}" retry={PROXY_FCGI_RETRY}>
        ProxySet connectiontimeout={PROXY_FCGI_CONNECTION_TIMEOUT} timeout={PROXY_FCGI_TIMEOUT}
    </Proxy>
    # SECTION php_fpm_proxy END.
    # SECTION addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    # SECTION addons END.
EOF
        }
    } else {
        error( 'Unknown PHP SAPI' );
        return 1;
    }

    $phpServer->{'eventManager'}->trigger(
        'afterPhpApache2BuildConfFile', $phpServer, $cfgTpl, $filename, $trgFile, $mdata, $sdata, $sconfig, $params
    );
}

=item afterApache2AddFiles( \%moduleData )

 Event listener that create PHP (phptmp) directory in customer Web folders

 Param hashref \%moduleData Data as provided by te iMSCP::Modules::Alias|iMSCP::Modules::Domain|iMSCP::Modules::Subdomain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub afterApache2AddFiles
{

    my (undef, $moduleData) = @_;

    return 0 unless $moduleData->{'DOMAIN_TYPE'} eq 'dmn';

    eval {
        iMSCP::Dir->new( dirname => "$moduleData->{'WEB_DIR'}/phptmp" )->make( {
            user  => $moduleData->{'USER'},
            group => $moduleData->{'GROUP'},
            mode  => 0750
        } )
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
