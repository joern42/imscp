=head1 NAME

 iMSCP::Servers::Httpd::Apache2::Debian - i-MSCP (Debian) Apache2 server implementation

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

package iMSCP::Servers::Httpd::Apache2::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Mount' => qw/ umount /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Httpd::Apache2::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Apache2 server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_setupModules();
    $rs ||= $self->_configure();
    $rs ||= $self->_installLogrotate();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'apache2' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->start(); }, 'Apache2' ];
            0;
        },
        3
    );
}

=item uninstall( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->_removeDirs();
    $rs ||= $self->_restoreDefaultConfig();
    $rs ||= $self->SUPER::uninstall();
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    return 0 unless -x '/usr/sbin/apache2ctl';

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'apache2' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'apache2' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'apache2' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'apache2' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item enableSites( @sites )

 See iMSCP::Servers::Httpd::Apache2::Abstract::enableSites()

=cut

sub enableSites
{
    my ($self, @sites) = @_;

    my $rs = execute( [ '/usr/sbin/a2ensite', @sites ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;
    $self->{'reload'} ||= 1;
    0;
}

=item disableSites( @sites )

 See iMSCP::Servers::Httpd::Apache2::Abstract::disableSites()

=cut

sub disableSites
{
    my ($self, @sites) = @_;

    execute( [ '/usr/sbin/a2dissite', @sites ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    debug( $stderr ) if $stderr;
    $self->{'reload'} ||= 1;
    0;
}

=item enableModules( @modules )

 See iMSCP::Servers::Httpd::Apache2::Abstract::enableModules()

=cut

sub enableModules
{
    my ($self, @modules) = @_;

    for ( @modules ) {
        next unless -f "/etc/apache2/mods-available/$_.load";

        my $rs = execute( [ '/usr/sbin/a2enmod', $_ ], \ my $stdout, \ my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    $self->{'restart'} ||= 1;
    0;
}

=item disableModules( @modules )

 See iMSCP::Servers::Httpd::Apache2::Abstract::disableModules()

=cut

sub disableModules
{
    my ($self, @modules) = @_;

    execute( [ '/usr/sbin/a2dismod', @modules ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    debug( $stderr ) if $stderr;
    $self->{'restart'} ||= 1;
    0;
}

=item enableConfs( @conffiles )

 See iMSCP::Servers::Httpd::Apache2::Abstract::enableConfs()

=cut

sub enableConfs
{
    my ($self, @conffiles) = @_;

    my $rs = execute( [ '/usr/sbin/a2enconf', @conffiles ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;
    $self->{'reload'} ||= 1;
    0;
}

=item disableConfs( @conffiles )

 See iMSCP::Servers::Httpd::Apache2::Abstract::disableConfs()

=cut

sub disableConfs
{
    my ($self, @conffiles) = @_;

    execute( [ '/usr/sbin/a2disconf', @conffiles ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    debug( $stderr ) if $stderr;
    $self->{'reload'} ||= 1;
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ '/usr/sbin/apache2ctl', '-v' ], \ my $stdout, \ my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /apache\/([\d.]+)/i ) {
        error( "Couldn't guess Apache2 version from the `/usr/sbin/apache2ctl -v 0>&1` command output" );
        return 1;
    }

    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Apache2 version set to: %s', $1 ));
    0;
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    eval {
        iMSCP::Dir->new( dirname => '/var/log/apache2' )->make( {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ADM_GROUP'},
            mode  => 0750
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }
}

=item _setupModules( )

 Setup Apache2 modules according selected MPM

 return 0 on success, other on failure

=cut

sub _setupModules
{
    my ($self) = @_;

    if ( $self->{'config'}->{'APACHE2_MPM'} eq 'event' ) {
        my $rs = $self->disableModules( qw/ mpm_itk mpm_prefork mpm_worker cgi / );
        $rs ||= $self->enableModules(
            qw/ mpm_event access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
            cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec version /
        );
        return 0;
    }

    if ( $self->{'config'}->{'APACHE2_MPM'} eq 'itk' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_worker cgid suexec / );
        $rs ||= $self->enableModules(
            qw/ mpm_prefork mpm_itk access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host
            authz_user autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl version /
        );
        return 0;
    }

    if ( $self->{'config'}->{'APACHE2_MPM'} eq 'prefork' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_itk mpm_worker cgid / );
        $rs ||= $self->enableModules(
            qw/ mpm_prefork access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user
            autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec version /
        );
        return 0;
    }

    if ( $self->{'config'}->{'APACHE2_MPM'} eq 'worker' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_itk mpm_prefork cgi / );
        $rs ||= $self->enableModules(
            qw/ mpm_worker access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
            cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec version /
        );
        return 0;
    }

    error( 'Unknown Apache2 MPM' );
    1;
}

=item _configure( )

 Configure Apache2

 Return int 0 on success, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeApache2BuildConfFile',
        sub {
            my ($cfgTpl) = @_;
            ${$cfgTpl} =~ s/^NameVirtualHost[^\n]+\n//gim;

            if ( main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ) {
                ${$cfgTpl} =~ s/^(\s*Listen)\s+0.0.0.0:(80|443)/$1 $2\n/gim;
            } else {
                ${$cfgTpl} =~ s/^(\s*Listen)\s+(80|443)\n/$1 0.0.0.0:$2\n/gim;
            }

            0;
        }
    );
    $rs ||= $self->buildConfFile( '/etc/apache2/ports.conf', '/etc/apache2/ports.conf' );

    # Turn off default access log provided by Debian package
    $rs = $self->disableConfs( 'other-vhosts-access-log.conf' );
    return $rs if $rs;

    # Remove default access log file provided by Debian package
    if ( -f "/var/log/apache2/other_vhosts_access.log" ) {
        $rs = iMSCP::File->new( filename => "/var/log/apache2/other_vhosts_access.log" )->delFile();
        return $rs if $rs;
    }

    my $serverData = {
        HTTPD_CUSTOM_SITES_DIR => '/etc/apache2/imscp',
        HTTPD_LOG_DIR          => '/var/log/apache2',
        HTTPD_ROOT_DIR         => '/var/www',
        TRAFF_ROOT_DIR         => $main::imscpConfig{'TRAFF_ROOT_DIR'},
        VLOGGER_CONF_PATH      => "/etc/apache2/vlogger.conf"
    };

    $rs = $self->buildConfFile( '00_nameserver.conf', '/etc/apache2/sites-available/00_nameserver.conf', undef, $serverData );
    $rs ||= $self->enableSites( '00_nameserver.conf' );
    $rs ||= $self->buildConfFile( '00_imscp.conf', '/etc/apache2/conf-available/00_imscp.conf', undef, $serverData );
    $rs ||= $self->enableConfs( '00_imscp.conf' );
    $rs ||= $self->disableSites( 'default', 'default-ssl', '000-default.conf', 'default-ssl.conf' );
}

=item _installLogrotate( )

 Install Apache logrotate file

 Return int 0 on success, other on failure

=cut

sub _installLogrotate
{
    my ($self) = @_;

    $self->buildConfFile( 'logrotate.conf', '/etc/logrotate.d/apache2', undef,
        {
            ROOT_USER     => $main::imscpConfig{'ROOT_USER'},
            ADM_GROUP     => $main::imscpConfig{'ADM_GROUP'},
            HTTPD_LOG_DIR => $self->{'config'}->{'HTTPD_LOG_DIR'}
        }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    my $rs = $self->disableSites( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' );
    return $rs if $rs;

    for ( "$self->{'cfgDir'}/apache.old.data", "$self->{'cfgDir'}/vlogger.conf.tpl", "$self->{'cfgDir'}/vlogger.conf", '/usr/local/sbin/vlogger' ) {
        next unless -f;
        $rs = iMSCP::File->new( filename => $_ )->delFile();
        return $rs if $rs;
    }

    for ( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' ) {
        next unless -f "/etc/apache2/sites-availables/$_";
        $rs = iMSCP::File->new( filename => "/etc/apache2/sites-availables/$_" )->delFile();
        return $rs if $rs;
    }

    eval { iMSCP::Dir->new( dirname => $_ )->remove() for '/var/log/apache2/backup', '/var/log/apache2/users', '/var/www/scoreboards'; };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    for ( glob "$main::imscpConfig{'USER_WEB_DIR'}/*/logs" ) {
        $rs = umount( $_ );
        return $rs if $rs;
    }

    $rs = execute( "rm -f $main::imscpConfig{'USER_WEB_DIR'}/*/logs/*.log", \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=item _removeDirs( )

 Remove non-default Apache2 directories

 Return int 0 on success, other on failure

=cut

sub _removeDirs
{
    eval { iMSCP::Dir->new( dirname => '/etc/apache2/imscp' )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _restoreDefaultConfig( )

 Restore default Apache2 configuration

 Return int 0 on success, other on failure

=cut

sub _restoreDefaultConfig
{
    my ($self) = @_;

    if ( -f '/etc/apache2/vlogger.conf' ) {
        my $rs = iMSCP::File->new( filename => "'/etc/apache2/vlogger.conf'" )->delFile();
        return $rs if $rs;
    }

    if ( -f "/etc/apache2/sites-available/00_nameserver.conf" ) {
        my $rs = $self->disableSites( '00_nameserver.conf' );
        $rs ||= iMSCP::File->new( filename => "/etc/apache2/sites-available/00_nameserver.conf" )->delFile();
        return $rs if $rs;
    }

    my $confDir = -d "/etc/apache2/conf-available" ? "/etc/apache2/conf-available" : "/etc/apache2/conf.d";

    if ( -f "$confDir/00_imscp.conf" ) {
        my $rs = $self->disableConfs( '00_imscp.conf' );
        $rs ||= iMSCP::File->new( filename => "$confDir/00_imscp.conf" )->delFile();
        return $rs if $rs;
    }

    eval {
        for ( glob( "$main::imscpConfig{'USER_WEB_DIR'}/*/domain_disable_page" ) ) {
            iMSCP::Dir->new( dirname => $_ )->remove();
        }

        iMSCP::Dir->new( dirname => '/etc/apache2/imscp' )->remove();
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    for ( '000-default', 'default' ) {
        next unless -f "/etc/apache2/sites-available/$_";
        my $rs = $self->enableSites( $_ );
        return $rs if $rs;
    }

    0;
}
=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'apache2', [ $action, sub { $self->$action(); } ], $priority );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
