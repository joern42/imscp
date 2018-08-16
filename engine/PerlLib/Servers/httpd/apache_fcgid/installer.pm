=head1 NAME

 Servers::httpd::apache_fcgid::installer - i-MSCP Apache2/FastCGI Server implementation

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

package Servers::httpd::apache_fcgid::installer;

use strict;
use warnings;
use File::Basename;
use iMSCP::Crypt qw/ ALNUM randomStr /;
use iMSCP::Database;
use iMSCP::Debug;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use iMSCP::TemplateParser;
use Servers::httpd::apache_fcgid;
use Servers::sqld;
use version;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Installer for the i-MSCP Apache2/FastCGI Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->askForPhpConfigLevel( @_ ) };
        0;
    } );
}

=item askForPhpConfigLevel( $dialog )

 Ask for PHP configuration level

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForPhpConfigLevel
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'PHP_CONFIG_LEVEL', $self->{'phpConfig'}->{'PHP_CONFIG_LEVEL'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'php', 'alternatives', 'all' ] ) || $value !~ /^per_(?:site|domain|user)$/ ) {
        my %choices = (
            'per_site', 'Per site PHP configuration (recommended)',
            'per_domain', 'Per domain, including subdomains PHP configuration',
            'per_user', 'Per user PHP configuration'
        );
        ( my $rs, $value ) = $dialog->radiolist( <<'EOF', \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'per_site' );

Please choose the PHP configuration level for the clients:
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'phpConfig'}->{'PHP_CONFIG_LEVEL'} = $value;
    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_setApacheVersion();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_copyDomainDisablePages();
    $rs ||= $self->_buildFastCgiConfFiles();
    $rs ||= $self->_buildApacheConfFiles();
    $rs ||= $self->_installLogrotate();
    $rs ||= $self->_setupVlogger();
    $rs ||= $self->_cleanup();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Servers::httpd::apache_fcgid::installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'httpd'} = Servers::httpd::apache_fcgid->getInstance();
    $self->{'apacheCfgDir'} = $self->{'httpd'}->{'apacheCfgDir'};
    $self->{'config'} = $self->{'httpd'}->{'config'};
    $self->{'phpCfgDir'} = $self->{'httpd'}->{'phpCfgDir'};
    $self->{'phpConfig'} = $self->{'httpd'}->{'phpConfig'};
    $self->guessPhpVariables();
    $self;
}

=item guessPhpVariables( )

 Guess PHP Variables

 Return int 0 on success, die on failure

=cut

sub guessPhpVariables
{
    my ( $self ) = @_;

    ( $self->{'phpConfig'}->{'PHP_VERSION'} ) = `$::imscpConfig{'PHP_SERVER'} -nv 2> /dev/null` =~ /^PHP\s+(\d+.\d+)/ or die(
        "Couldn't guess PHP version"
    );

    my ( $phpConfDir ) = `$::imscpConfig{'PHP_SERVER'} -ni 2> /dev/null | grep '(php.ini) Path'` =~ /([^\s]+)$/ or die(
        "Couldn't guess PHP configuration directory path"
    );

    my $phpConfBaseDir = dirname( $phpConfDir );
    $self->{'phpConfig'}->{'PHP_CONF_DIR_PATH'} = $phpConfBaseDir;
    $self->{'phpConfig'}->{'PHP_FPM_POOL_DIR_PATH'} = "$phpConfBaseDir/fpm/pool.d";

    unless ( -d $self->{'phpConfig'}->{'PHP_FPM_POOL_DIR_PATH'} ) {
        $self->{'phpConfig'}->{'PHP_FPM_POOL_DIR_PATH'} = '';
        die( sprintf( "Couldn't guess '%s' PHP configuration parameter value: directory doesn't exists.", $_ ));
    }

    $self->{'phpConfig'}->{'PHP_CLI_BIN_PATH'} = iMSCP::ProgramFinder::find( "php$self->{'phpConfig'}->{'PHP_VERSION'}" );
    $self->{'phpConfig'}->{'PHP_FCGI_BIN_PATH'} = iMSCP::ProgramFinder::find( "php-cgi$self->{'phpConfig'}->{'PHP_VERSION'}" );
    $self->{'phpConfig'}->{'PHP_FPM_BIN_PATH'} = iMSCP::ProgramFinder::find( "php-fpm$self->{'phpConfig'}->{'PHP_VERSION'}" );

    for ( qw/ PHP_CLI_BIN_PATH PHP_FCGI_BIN_PATH PHP_FPM_BIN_PATH / ) {
        next if $self->{'phpConfig'}->{$_};
        die( sprintf( "Couldn't guess '%s' PHP configuration parameter value.", $_ ));
    }

    0;
}

=item _setApacheVersion( )

 Set Apache version

 Return int 0 on success, other on failure

=cut

sub _setApacheVersion
{
    my ( $self ) = @_;

    my $rs = execute( 'apache2ctl -v', \my $stdout, \my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ m%Apache/([\d.]+)% ) {
        error( "Couldnt' guess Apache version" );
        return 1;
    }

    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Apache version set to: %s', $1 ));
    0;
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeHttpdMakeDirs' );
    return $rs if $rs;

    # Remove any older fcgi starter directory (prevent possible orphaned file when changing PHP configuration level)
    iMSCP::Dir->new( dirname => $self->{'phpConfig'}->{'PHP_FCGI_STARTER_DIR'} )->remove();

    for (
        [ $self->{'config'}->{'HTTPD_LOG_DIR'}, $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ADM_GROUP'}, 0750 ],
        [ $self->{'phpConfig'}->{'PHP_FCGI_STARTER_DIR'}, $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'}, 0555 ]
    ) {
        iMSCP::Dir->new( dirname => $_->[0] )->make( {
            user  => $_->[1],
            group => $_->[2],
            mode  => $_->[3]
        } );
    }

    $self->{'eventManager'}->trigger( 'afterHttpdMakeDirs' );
}

=item _copyDomainDisablePages( )

 Copy pages for disabled domains

 Return int 0 on success, other on failure

=cut

sub _copyDomainDisablePages
{
    iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/skel/domain_disabled_pages" )->rcopy(
        "$::imscpConfig{'USER_WEB_DIR'}/domain_disabled_pages", { preserve => 'no' }
    );
    0;
}

=item _buildFastCgiConfFiles( )

 Build FastCGI configuration files

 Return int 0 on success, other on failure

=cut

sub _buildFastCgiConfFiles
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeHttpdBuildFastCgiConfFiles' );

    $self->{'httpd'}->setData( {
        SYSTEM_USER_PREFIX   => $::imscpConfig{'SYSTEM_USER_PREFIX'},
        SYSTEM_USER_MIN_UID  => $::imscpConfig{'SYSTEM_USER_MIN_UID'},
        PHP_FCGI_STARTER_DIR => $self->{'phpConfig'}->{'PHP_FCGI_STARTER_DIR'}
    } );

    $rs = $self->{'httpd'}->buildConfFile( "$self->{'phpCfgDir'}/fcgi/apache_fcgid_module.conf", {}, {
        destination => "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.conf"
    } );
    return $rs if $rs;

    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid.load" );

    my $cfgTpl = $file->get();
    unless ( defined $cfgTpl ) {
        error( sprintf( "Couldn't read %s file", $file->{'filename'} ));
        return 1;
    }

    $file = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/fcgid_imscp.load" );
    $cfgTpl = "<IfModule !mod_fcgid.c>\n" . $cfgTpl . "</IfModule>\n";

    $file->set( $cfgTpl );

    $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0644 );

    # Retrieve list of available Apache2 PHP modules
    $_ = basename( $_, '.load' ) for my @phpMods = glob "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/php*.load";

    # Retrieve list of available Apache2 MPM modules
    $_ = basename( $_, '.load' ) for my @mpmMods = glob "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/mpm_*.load";

    # Disable unwanted Apache2 modules
    $rs = $self->{'httpd'}->disableModules( 'actions', 'fastcgi', 'fcgid', 'fcgid_imscp', @phpMods, 'proxy_fcgi', 'proxy_handler', @mpmMods );

    # Enable required Apache2 modules
    $rs ||= $self->{'httpd'}->enableModules( 'actions', 'authz_groupfile', 'fcgid_imscp', 'mpm_event', 'version' );
    $rs ||= $self->{'eventManager'}->trigger( 'afterHttpdBuildFastCgiConfFiles' );
}

=item _buildApacheConfFiles( )

 Build Apache configuration files

 Return int 0 on success, other on failure

=cut

sub _buildApacheConfFiles
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeHttpdBuildApacheConfFiles' );
    return $rs if $rs;

    if ( -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf" ) {
        $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'apache_fcgid', 'ports.conf', \my $cfgTpl, {} );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $cfgTpl = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf" )->get();
            unless ( defined $cfgTpl ) {
                error( sprintf( "Couldn't read %s file", "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf" ));
                return 1;
            }
        }

        $rs = $self->{'eventManager'}->trigger( 'beforeHttpdBuildConfFile', \$cfgTpl, 'ports.conf' );
        return $rs if $rs;

        $cfgTpl =~ s/^NameVirtualHost[^\n]+\n//gim;

        $rs = $self->{'eventManager'}->trigger( 'afterHttpdBuildConfFile', \$cfgTpl, 'ports.conf' );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf" );
        $file->set( $cfgTpl );

        $rs = $file->save();
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;
    }

    # Turn off default access log provided by Debian package
    $rs = $self->{'httpd'}->disableConfs( 'other-vhosts-access-log' );
    return $rs if $rs;

    # Remove default access log file provided by Debian package
    if ( -f "$self->{'config'}->{'HTTPD_LOG_DIR'}/other_vhosts_access.log" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_LOG_DIR'}/other_vhosts_access.log" )->delFile();
        return $rs if $rs;
    }

    $self->{'httpd'}->setData( {
        HTTPD_CUSTOM_SITES_DIR => $self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'},
        HTTPD_LOG_DIR          => $self->{'config'}->{'HTTPD_LOG_DIR'},
        HTTPD_ROOT_DIR         => $self->{'config'}->{'HTTPD_ROOT_DIR'},
        VLOGGER_CONF           => "$self->{'apacheCfgDir'}/vlogger.conf"
    } );
    $rs ||= $self->{'httpd'}->buildConfFile( '00_nameserver.conf' );
    $rs ||= $self->{'httpd'}->buildConfFile( '00_imscp.conf', {}, {
        destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf-available/00_imscp.conf"
    } );
    $rs ||= $self->{'httpd'}->enableModules( 'cgid', 'headers', 'proxy', 'proxy_http', 'rewrite', 'setenvif', 'ssl', 'suexec' );
    $rs ||= $self->{'httpd'}->enableSites( '00_nameserver.conf' );
    $rs ||= $self->{'httpd'}->enableConfs( '00_imscp' );

    # Retrieve list of configuration files for PHP
    $_ = basename( $_, '.conf' ) for my @phpConfs = glob "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/php*.conf";

    $rs ||= $self->{'httpd'}->disableConfs( @phpConfs, 'serve-cgi-bin' );
    $rs ||= $self->{'httpd'}->disableSites( 'default', 'default-ssl', '000-default.conf', 'default-ssl.conf' );
    $rs ||= $self->{'eventManager'}->trigger( 'afterHttpdBuildApacheConfFiles' );
}

=item _installLogrotate( )

 Install Apache logrotate file

 Return int 0 on success, other on failure

=cut

sub _installLogrotate
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeHttpdInstallLogrotate', 'apache2' );

    $self->{'httpd'}->setData( {
        ROOT_USER     => $::imscpConfig{'ROOT_USER'},
        ADM_GROUP     => $::imscpConfig{'ADM_GROUP'},
        HTTPD_LOG_DIR => $self->{'config'}->{'HTTPD_LOG_DIR'},
        PHP_VERSION   => $self->{'CONFIG'}->{'PHP_VERSION'}
    } );

    $rs ||= $self->{'httpd'}->buildConfFile( 'logrotate.conf', {}, {
        destination => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/apache2"
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterHttpdInstallLogrotate', 'apache2' );
}

=item _setupVlogger( )

 Setup vlogger

 Return int 0 on success, other on failure

=cut

sub _setupVlogger
{
    my ( $self ) = @_;

    my $host = ::setupGetQuestion( 'DATABASE_HOST' );
    $host = $host eq 'localhost' ? '127.0.0.1' : $host;
    my $port = ::setupGetQuestion( 'DATABASE_PORT' );
    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $user = 'vlogger_user';
    my $userHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    $userHost = '127.0.0.1' if $userHost eq 'localhost';
    my $oldUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $pass = randomStr( 16, ALNUM );

    my $db = iMSCP::Database->factory();
    my $rs = ::setupImportSqlSchema( $db, "$self->{'apacheCfgDir'}/vlogger.sql" );
    return $rs if $rs;

    local $@;
    eval {
        my $sqlServer = Servers::sqld->factory();

        for ( $userHost, $oldUserHost, 'localhost' ) {
            next unless $_;
            $sqlServer->dropUser( $user, $_ );
        }

        $sqlServer->createUser( $user, $userHost, $pass );

        my $dbh = iMSCP::Database->factory()->getRawDb();
        local $dbh->{'RaiseError'} = 1;

        # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
        my $qDbName = $dbh->quote_identifier( $dbName );
        $dbh->do( "GRANT SELECT, INSERT, UPDATE ON $qDbName.httpd_vlogger TO ?\@?", undef, $user, $userHost );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'httpd'}->setData( {
        DATABASE_NAME     => $dbName,
        DATABASE_HOST     => $host,
        DATABASE_PORT     => $port,
        DATABASE_USER     => $user,
        DATABASE_PASSWORD => $pass
    } );

    $self->{'httpd'}->buildConfFile(
        "$self->{'apacheCfgDir'}/vlogger.conf.tpl",
        { SKIP_TEMPLATE_CLEANER => 1 },
        { destination => "$self->{'apacheCfgDir'}/vlogger.conf" }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeHttpdCleanup' );
    $rs ||= $self->{'httpd'}->disableSites( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' );
    return $rs if $rs;

    if ( -f "$self->{'apacheCfgDir'}/apache.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'apacheCfgDir'}/apache.old.data" )->delFile();
        return $rs if $rs;
    }

    if ( -f "$self->{'phpCfgDir'}/php.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'phpCfgDir'}/php.old.data" )->delFile();
        return $rs if $rs;
    }

    for ( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' ) {
        next unless -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_";
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_" )->delFile();
        return $rs if $rs;
    }

    $rs = $self->{'httpd'}->disableModules( 'php_fpm_imscp', 'fastcgi_imscp' );
    return $rs if $rs;

    for ( 'fastcgi_imscp.conf', 'fastcgi_imscp.load', 'php_fpm_imscp.conf', 'php_fpm_imscp.load' ) {
        next unless -f "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_";
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_" )->delFile();
        return $rs if $rs;
    }

    if ( -d $self->{'phpConfig'}->{'PHP_FCGI_STARTER_DIR'} ) {
        $rs = execute(
            "rm -f $self->{'phpConfig'}->{'PHP_FCGI_STARTER_DIR'}/*/php5-fastcgi-starter", \my $stdout, \my $stderr
        );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    for ( '/var/log/apache2/backup', '/var/log/apache2/users', '/var/www/scoreboards' ) {
        iMSCP::Dir->new( dirname => $_ )->remove();
    }

    # Remove customer's logs file if any (no longer needed since we are now use bind mount)
    $rs = execute( "rm -f $::imscpConfig{'USER_WEB_DIR'}/*/logs/*.log", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    #
    ## Cleanup and disable unused PHP Versions/SAPIs
    #

    if ( -f "$::imscpConfig{'LOGROTATE_CONF_DIR'}/php5-fpm" ) {
        $rs = iMSCP::File->new( filename => "$::imscpConfig{'LOGROTATE_CONF_DIR'}/php5-fpm" )->delFile();
        return $rs if $rs;
    }

    iMSCP::Dir->new( dirname => '/etc/php5' )->remove();

    # Some of PHP individual packages install their INI file once for all build
    # variants, including for those not installed yet. Therefore, removing
    # configuration directory for unused build variants is a mistake because
    # when switching to one of them, INI files from individual packages won't
    # be reinstalled.
    # See https://github.com/oerdnj/deb.sury.org/issues/660
    #for(grep!/^$self->{'phpConfig'}->{'PHP_CONF_DIR_PATH'}$/,
    #    glob dirname($self->{'phpConfig'}->{'PHP_CONF_DIR_PATH'}).'/*'
    #) {
    #    iMSCP::Dir->new( dirname => $_ )->remove( );
    #}

    # FPM
    unlink grep !/www\.conf$/, glob "$self->{'phpConfig'}->{'PHP_FPM_POOL_DIR_PATH'}/*.conf";
    local $@;
    eval {
        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->stop( sprintf( 'php%s-fpm', $self->{'phpConfig'}->{'PHP_VERSION'} ));
        $serviceMngr->disable( sprintf( 'php%s-fpm', $self->{'phpConfig'}->{'PHP_VERSION'} ));
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterHttpdCleanup' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
