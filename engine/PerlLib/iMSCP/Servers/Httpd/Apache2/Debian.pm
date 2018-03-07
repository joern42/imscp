=head1 NAME

 iMSCP::Servers::Httpd::Apache2::Debian - i-MSCP (Debian) Apache2 server implementation

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

package iMSCP::Servers::Httpd::Apache2::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Mount' => qw/ isMountpoint /;
use Array::Utils qw/ unique /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::ProgramFinder /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Find qw/ find /;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug error warning getMessageByType /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File::Attributes qw/ :immutable /;
use iMSCP::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Httpd::Apache2::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Apache2 server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();
    $self->_setupModules();
    $self->_configure();
    $self->_installLogrotate();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'apache2' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices', sub { push @{ $_[0] }, [ sub { $self->start(); }, $self->getHumanServerName() ]; }, 3
    );
}

=item uninstall( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->SUPER::uninstall();
    $self->_restoreDefaultConfig();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'apache2' ) if $srvProvider->hasService( 'apache2' ) && $srvProvider->isRunning( 'apache2' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    return unless iMSCP::ProgramFinder::find( 'apache2ctl' );

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'apache2' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'apache2' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'apache2' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'apache2' );
}

=item enableSites( @sites )

 See iMSCP::Servers::Httpd::enableSites()

=cut

sub enableSites
{
    my ( $self, @sites ) = @_;

    for ( unique @sites ) {
        my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix
        my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
        my $lnk = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

        unless ( -e $tgt ) {
            warning( sprintf( '%s is a dangling symlink', $lnk )) if -l $lnk && !-e $lnk;
            die( sprintf( "Site %s doesn't exist", $site ));
        }

        # FIXME: Not sure that this is really needed for a 'site' object but
        # this is done like this in the a2ensite script...
        #$self->_checkModuleDeps( $self->_getModDeps( $tgt ));

        my $check = $self->_checkSymlink( $tgt, $lnk );
        if ( $check eq 'ok' ) {
            debug( sprintf( 'Site %s already enabled', $site ));
        } elsif ( $check eq 'missing' ) {
            debug( sprintf( 'Enabling site %s', $site ));
            $self->_createSymlink( $tgt, $lnk );
            $self->_switchMarker( 'site', 'enable', $site );
        } else {
            die( sprintf( "Site %s isn't properly enabled: %s", $site, $check ));
        }
    }
}

=item disableSites( @sites )

 See iMSCP::Servers::Httpd::disableSites()

=cut

sub disableSites
{
    my ( $self, @sites ) = @_;

    for ( unique @sites ) {
        my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix
        my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
        my $lnk = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

        unless ( -e $tgt ) {
            if ( -l $lnk && !-e $lnk ) {
                debug( sprintf( 'Removing dangling symlink: %s', $lnk ));
                unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
                next;
            }

            # Unlike a2dissite script behavior, we don't raise an error when
            # the site that we try to disable doesn't exists
            $self->_switchMarker( 'site', 'disable', $site ) if $self->{'_remove_obj'};
            debug( sprintf( "Site %s doesn't exist. Skipping...", $site ));
            next;
        }

        if ( -e $lnk || -l $lnk ) {
            debug( sprintf( 'Disabling site %s', $site ));
            $self->_removeSymlink( $lnk );
            $self->_switchMarker( 'site', 'disable', $site );
        } else {
            debug( sprintf( 'Site %s already disabled', $site ));
            $self->_switchMarker( 'site', 'disable', $site ) if $self->{'_remove_obj'};
        }
    }
}

=item removeSites( @sites )

 See iMSCP::Servers::Httpd::removeSites()

=cut

sub removeSites
{
    my ( $self, @sites ) = @_;

    local $self->{'_remove_obj'} = TRUE;

    for ( unique @sites ) {
        my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix

        # Make sure that the site is disabled before removing it
        $self->disableSites( $site );

        my $file = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
        unless ( -f $file ) {
            debug( sprintf( "Conf %s doesn't exist. Skipping...", $site ));
            next;
        }

        debug( sprintf( 'Removing site %s', $site ));
        unlink( $file ) or die( sprintf( "Couldn't remove the %s site: %s", $site, $! ));
    }
}

=item enableConfs( @confs )

 See iMSCP::Servers::Httpd::enableConfs()

=cut

sub enableConfs
{
    my ( $self, @confs ) = @_;

    for ( unique @confs ) {
        my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix
        my $tgt = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
        my $lnk = "$self->{'config'}->{'HTTPD_CONF_ENABLED_DIR'}/$conf.conf";

        unless ( -e $tgt ) {
            warning( sprintf( '%s is a dangling symlink', $lnk )) if -l $lnk && !-e $lnk;
            die( sprintf( "Conf %s doesn't exist", $conf ));
        }

        # FIXME: Not sure that this is really needed for a 'conf' object but
        # this is done like this in the a2ensite script...
        #$self->_checkModuleDeps( $self->_getModDeps( $tgt ));

        my $check = $self->_checkSymlink( $tgt, $lnk );
        if ( $check eq 'ok' ) {
            debug( sprintf( 'Conf %s already enabled', $conf ));
        } elsif ( $check eq 'missing' ) {
            debug( sprintf( 'Enabling conf %s', $conf ));
            $self->_createSymlink( $tgt, $lnk );
            $self->_switchMarker( 'conf', 'enable', $conf );
        } else {
            die( sprintf( "Conf %s isn't properly enabled: %s", $conf, $check ));
        }
    }
}

=item disableConfs( @confs )

 See iMSCP::Servers::Httpd::disableConfs()

=cut

sub disableConfs
{
    my ( $self, @confs ) = @_;

    for ( unique @confs ) {
        my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix
        my $tgt = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
        my $lnk = "$self->{'config'}->{'HTTPD_CONF_ENABLED_DIR'}/$conf.conf";

        unless ( -e $tgt ) {
            if ( -l $lnk && !-e $lnk ) {
                debug( sprintf( 'Removing dangling symlink: %s', $lnk ));
                unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
                next;
            }

            # Unlike a2disconf script behavior, we don't raise an error when
            # the configuration that we try to disable doesn't exists
            $self->_switchMarker( 'conf', 'disable', $conf ) if $self->{'_remove_obj'};
            debug( sprintf( "Conf %s doesn't exist. Skipping...", $conf ));
            next;
        }

        if ( -e $lnk || -l $lnk ) {
            debug( sprintf( 'Disabling conf %s', $conf ));
            $self->_removeSymlink( $lnk );
            $self->_switchMarker( 'conf', 'disable', $conf );
        } else {
            debug( sprintf( 'Conf %s already disabled', $conf ));
            $self->_switchMarker( 'conf', 'disable', $conf ) if $self->{'_remove_obj'};
        }
    }
}

=item removeConfs( @confs )

 See iMSCP::Servers::Httpd::removeConfs()

=cut

sub removeConfs
{
    my ( $self, @confs ) = @_;

    local $self->{'_remove_obj'} = TRUE;

    for ( unique @confs ) {
        my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix

        # Make sure that the conf is disabled before removing it
        $self->disableConfs( $conf );

        my $file = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
        unless ( -f $file ) {
            debug( sprintf( "Conf %s doesn't exist. Skipping...", $conf ));
            next;
        }

        debug( sprintf( 'Removing conf %s', $conf ));
        unlink( $file ) or die( sprintf( "Couldn't remove the %s conf: %s", $conf, $! ));
    }
}

=item enableModules( @mods )

 See iMSCP::Servers::Httpd::enableModules()

=cut

sub enableModules
{
    my ( $self, @mods ) = @_;

    for ( unique @mods ) {
        my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix

        if ( $mod eq 'cgi' && grep ( $self->{'config'}->{'HTTPD_MPM'} eq $_, qw/ event worker / ) ) {
            debug( sprintf( "The Apache %s MPM is threaded. Selecting the cgid module instead of the cgi module", $self->{'config'}->{'HTTPD_MPM'} ));
            $mod = 'cgid';
        }

        my $conftgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.conf";
        my $conflink = -e $conftgt ? "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf" : undef;
        my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.load";
        my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.load";

        unless ( -e $tgt ) {
            warning( sprintf( '%s is a dangling symlink', $lnk )) if -l $lnk && !-e $lnk;
            die( sprintf( "Module %s doesn't exist", $mod ));
        }

        # Handle module dependencies
        $self->_doModDeps( 'enable', $mod, $self->_getModDeps( $tgt ));
        $self->_checkModConflicts( $mod, $self->_getModDeps( $tgt, 'Conflicts' ));

        my $check = $self->_checkSymlink( $tgt, $lnk );
        if ( $check eq 'ok' ) {
            if ( $conflink ) {
                # handle module .conf file
                my $confcheck = $self->_checkSymlink( $conftgt, $conflink );
                if ( $confcheck eq 'ok' ) {
                    debug( sprintf( 'Module %s already enabled', $mod ));
                } elsif ( $confcheck eq 'missing' ) {
                    debug( sprintf( 'Enabling config file %s', "$mod.conf" ));
                    $self->_createSymlink( $conftgt, $conflink );
                } else {
                    die( sprintf( "Config file %s isn't properly enabled: %s", "$mod.conf", $confcheck ));
                }
            } else {
                debug( sprintf( 'Module %s already enabled', $mod ));
            }
        } elsif ( $check eq 'missing' ) {
            if ( $conflink ) {
                # handle module .conf file
                my $confcheck = $self->_checkSymlink( $conftgt, $conflink );
                if ( $confcheck eq 'missing' ) {
                    $self->_createSymlink( $conftgt, $conflink );
                } elsif ( $confcheck ne 'ok' ) {
                    die( sprintf( "Config file %s isn't properly enabled: %s", "$mod.conf", $confcheck ));
                }
            }

            debug( sprintf( 'Enabling module %s', $mod ));
            $self->_createSymlink( $tgt, $lnk );
            $self->_switchMarker( 'module', 'enable', $mod );
        } else {
            die( sprintf( "Module %s isn't properly enabled: %s", $mod, $check ));
        }
    }

    $self->{'restart'} ||= 1;
}

=item disableModules( @mods )

 See iMSCP::Servers::Httpd::disableModules()

=cut

sub disableModules
{
    my ( $self, @mods ) = @_;

    for ( unique @mods ) {
        my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix
        my $conftgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.conf";
        my $conflink = -e $conftgt ? "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf" : undef;
        my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.load";
        my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.load";

        unless ( -e $tgt ) {
            if ( -l $lnk && !-e $lnk ) {
                debug( sprintf( 'Removing dangling symlink: %s', $lnk ));
                unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));

                # Force a .conf path. It may exist as dangling link, too
                $conflink = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf";
                if ( -l $conflink && !-e $conflink ) {
                    debug( sprintf( 'Removing dangling symlink: %s', $conflink ));
                    unlink( $conflink ) or die( sprintf( "Couldn't remove the %s symlink: %s", $conflink, $! ));
                }

                next;
            }

            # Unlike a2dismod script behavior, we don't raise an error when
            # the module that we try to disable doesn't exists
            $self->_switchMarker( 'module', 'disable', $mod ) if $self->{'_remove_obj'};
            debug( sprintf( "Module %s doesn't exist. Skipping...", $mod ));
            next;
        }

        # Handle module dependencies
        my @deps;
        for ( glob( "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/*.load" ) ) {
            if ( grep ($mod eq $_, $self->_getModDeps( $_ )) ) {
                m%/([^/]+).load$%;
                push @deps, $1;
            }
        }
        if ( scalar @deps ) {
            if ( $self->{'_remove_obj'} ) {
                $self->_doModDeps( 'disable', $mod, @deps );
            } else {
                die( sprintf( "The following modules depend on %s and need to be disabled first: %s\n", $mod, "@deps" ));
            }
        }
        undef @deps;

        if ( -e $lnk || -l $lnk ) {
            debug( sprintf( 'Disabling module %s', $mod ));
            $self->_removeSymlink( $lnk );
            $self->_removeSymlink( $conflink ) if $conflink && -e $conflink;
            $self->_switchMarker( 'module', 'disable', $mod );
        } elsif ( $conflink && -e $conflink ) {
            debug( sprintf( 'Disabling stale config file %s', "$mod.conf" ));
            $self->_removeSymlink( $conflink );
        } else {
            debug( sprintf( 'Module %s already disabled', $mod ));
            $self->_switchMarker( 'module', 'disable', $mod ) if $self->{'_remove_obj'};
        }
    }

    $self->{'restart'} ||= 1;
}

=item removeModules( @mods )

 See iMSCP::Servers::Httpd::removeModules()

=cut

sub removeModules
{
    my ( $self, @mods ) = @_;

    local $self->{'_remove_obj'} = TRUE;

    for ( unique @mods ) {
        my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix

        # Make sure that the module is disabled before removing it
        $self->disableModules( $mod );

        for ( qw/ .load .conf / ) {
            my $file = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod$_";
            unless ( -f $file ) {
                debug( sprintf( "Module %s file doesn't exist. Skipping...", "$mod$_" ));
                next;
            }

            debug( sprintf( 'Removing module %s', $mod ));
            unlink( $file ) or die( sprintf( "Couldn't remove the %s module file: %s", "$mod$_", $! ));
        }
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'_remove_obj'} = FALSE;
    $self->SUPER::_init();
}

=item _setVersion( )

 See iMSCP::Servers::Httpd::Apache2::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( [ 'apache2ctl', '-v' ], \my $stdout, \my $stderr );
    !$rs or die( $stderr || 'Unknown error' ) if $rs;
    $stdout =~ /apache\/([\d.]+)/i or die( "Couldn't guess Apache version from the `apache2ctl -v` command output" );
    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Apache version set to: %s', $1 ));
}

=item _setupModules( )

 Setup Apache modules according selected MPM

 Return void, die on failure

=cut

sub _setupModules
{
    my ( $self ) = @_;

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'event' ) {
        $self->disableModules( qw/ mpm_itk mpm_prefork mpm_worker cgi / );
        $self->enableModules(
            qw/ mpm_event access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
                cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'itk' ) {
        $self->disableModules( qw/ mpm_event mpm_worker cgid suexec / );
        $self->enableModules(
            qw/ mpm_prefork mpm_itk access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host
                authz_user autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl /
        );
        return;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'prefork' ) {
        $self->disableModules( qw/ mpm_event mpm_itk mpm_worker cgid / );
        $self->enableModules(
            qw/ mpm_prefork access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user
                autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'worker' ) {
        $self->disableModules( qw/ mpm_event mpm_itk mpm_prefork cgi / );
        $self->enableModules(
            qw/ mpm_worker access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
                cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return;
    }

    die( 'Unknown Apache MPM' );
}

=item _configure( )

 Configure Apache

 Return void, die on failure

=cut

sub _configure
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeApacheBuildConfFile',
        sub {
            my ( $cfgTpl ) = @_;
            ${ $cfgTpl } =~ s/^NameVirtualHost[^\n]+\n//gim;

            if ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ) {
                ${ $cfgTpl } =~ s/^(\s*Listen)\s+0.0.0.0:(80|443)/$1 $2\n/gim;
            } else {
                ${ $cfgTpl } =~ s/^(\s*Listen)\s+(80|443)\n/$1 0.0.0.0:$2\n/gim;
            }
        }
    );
    $self->buildConfFile( '/etc/apache2/ports.conf' );
    # Turn off default access log provided by Debian package
    $self->disableConfs( 'other-vhosts-access-log.conf' );

    # Remove default access log file provided by Debian package
    iMSCP::File->new( filename => "/var/log/apache2/other_vhosts_access.log" )->remove();

    my $serverData = {
        HTTPD_CUSTOM_SITES_DIR => '/etc/apache2/imscp',
        HTTPD_LOG_DIR          => '/var/log/apache2',
        HTTPD_ROOT_DIR         => '/var/www',
        TRAFF_ROOT_DIR         => $::imscpConfig{'TRAFF_ROOT_DIR'},
        VLOGGER_CONF_PATH      => "/etc/apache2/vlogger.conf"
    };

    $self->buildConfFile( '00_nameserver.conf', '/etc/apache2/sites-available/00_nameserver.conf', undef, $serverData );
    $self->enableSites( '00_nameserver.conf' );
    $self->buildConfFile( '00_imscp.conf', '/etc/apache2/conf-available/00_imscp.conf', undef, $serverData );
    $self->enableConfs( '00_imscp.conf' );
    $self->disableSites( qw/ default default-ssl 000-default / ); # FIXME: 'default' provided by?
}

=item _installLogrotate( )

 Install Apache logrotate file

 Return void, die on failure

=cut

sub _installLogrotate
{
    my ( $self ) = @_;

    $self->buildConfFile( 'logrotate.conf', '/etc/logrotate.d/apache2', undef,
        {
            ROOT_USER     => $::imscpConfig{'ROOT_USER'},
            ADM_GROUP     => $::imscpConfig{'ADM_GROUP'},
            HTTPD_LOG_DIR => $self->{'config'}->{'HTTPD_LOG_DIR'}
        }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/vlogger.conf" )->remove();

    $self->disableSites( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' );

    for ( "$self->{'cfgDir'}/apache.old.data", "$self->{'cfgDir'}/vlogger.conf.tpl", "$self->{'cfgDir'}/vlogger.conf", '/usr/local/sbin/vlogger' ) {
        iMSCP::File->new( filename => $_ )->remove();
    }

    for ( 'imscp.conf', '00_modcband.conf', '00_master.conf', '00_master_ssl.conf' ) {
        iMSCP::File->new( filename => "/etc/apache2/sites-availables/$_" )->remove();
    }

    iMSCP::Dir->new( dirname => $_ )->remove() for '/var/log/apache2/backup', '/var/log/apache2/users', '/var/www/scoreboards';

    for my $dir ( iMSCP::Dir->new( dirname => $::imscpConfig{'USER_WEB_DIR'} )->getDirs() ) {
        my $isImmutable = isImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" );
        clearImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" ) if $isImmutable;

        # Remove deprecated plain HTTPD log files inside customers root Web folder
        # FIXME: only operate when logs is not a mountpoint
        if ( -d "$::imscpConfig{'USER_WEB_DIR'}/$dir/logs" && !isMountpoint( "$::imscpConfig{'USER_WEB_DIR'}/$dir/logs" ) ) {
            iMSCP::Dir->new( dirname => "$::imscpConfig{'USER_WEB_DIR'}/$dir/logs" )->clear( qr/.*\.log$/ );
        }

        # Remove deprecated `domain_disable_page' directory inside customers root Web folder
        iMSCP::Dir->new( dirname => "$::imscpConfig{'USER_WEB_DIR'}/$dir/domain_disable_page" )->remove();

        setImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" ) if $isImmutable;
    }
}

=item _restoreDefaultConfig( )

 Restore default Apache configuration

 Return void, die on failure

=cut

sub _restoreDefaultConfig
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => '/etc/apache2/imscp' )->remove();
    iMSCP::File->new( filename => '/etc/apache2/vlogger.conf' )->remove();
    $self->disableSites( '00_nameserver.conf' );
    iMSCP::File->new( filename => '/etc/apache2/sites-available/00_nameserver.conf' )->remove();
    $self->disableConfs( '00_imscp.conf' );
    iMSCP::File->new( filename => "/etc/apache2/conf-available/00_imscp.conf" )->remove();
    iMSCP::Dir->new( dirname => $_ )->remove() for glob( "$::imscpConfig{'USER_WEB_DIR'}/*/domain_disable_page" );
    iMSCP::Dir->new( dirname => '/etc/apache2/imscp' )->remove();

    for my $file ( '000-default', 'default' ) {
        next unless -f "/etc/apache2/sites-available/$file";
        $self->enableSites( $file );
    }
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ( $self, $priority ) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'apache2', [ $action, sub { $self->$action(); } ], $priority );
}

=item _checkSymlink( $tgt, $lnk )

 Check the given symlink
 
 Param $string $tgt Link target
 Param $string $lnk Link path
 Return symlink state on success, die on failure

=cut

sub _checkSymlink
{
    my ( undef, $tgt, $lnk ) = @_;

    unless ( -e $lnk ) {
        if ( -l $lnk ) {
            debug( sprintf( 'Removing dangling symlink %s', $lnk ));
            unlink $lnk or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
        }

        return 'missing';
    }

    return sprintf( '%s is a real file, not touching it', $lnk ) if -e $lnk && !-l $lnk;
    return sprintf( "The %s symlink exists but doesn't point to %s, not touching it", $lnk, $tgt ) if realpath( $lnk ) ne realpath( $tgt );
    'ok';
}

=item _createSymlink( $tgt, $lnk )

 Add the given symlink

 Code upon based on a2enmod script by Stefan Fritsch <sf@debian.org>

 Param $string $tgt Link target
 Param $string $lnk Link path
 Return void, die on failure

=cut

sub _createSymlink
{
    my ( $self, $tgt, $lnk ) = @_;

    symlink( File::Spec->abs2rel( $tgt, dirname( $lnk )), $lnk ) or die( sprintf( "Couldn't create the %s symlink: %s", $lnk, $! ));
    $self->{'reload'} ||= 1;
}

=item _removeSymlink( $lnk )

 Remove the given symlink

 Param $string $lnk Link path
 Return void, raise a warning if $lnk is not a symlink, die on failure

=cut

sub _removeSymlink
{
    my ( $self, $lnk ) = @_;

    if ( -l $lnk ) {
        unlink $lnk or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
    } elsif ( -e $lnk ) {
        warning( sprintf( "%s isn't a symlink, not deleting", $lnk ));
        return;
    }

    $self->{'reload'} ||= 1;
}

=item _switchMarker()

 Create or delete marker for the given object
 
 Param string $which (conf|module|site)
 Param string $what (enable|disable)
 param $string $name Name
 Return void, die on failure

=cut

sub _switchMarker
{
    my ( $self, $which, $what, $name ) = @_;

    defined $which or die( 'Undefined $which parameter' );
    defined $what or die( 'Undefined $what parameter' );
    defined $name or die( 'Undefined $name parameter' );

    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && $self->getServerName() eq 'Apache';

    my $stateMarkerDir = "$self->{'config'}->{'HTTPD_STATE_DIR'}/$which/${what}d_by_admin";
    my $stateMarker = "$stateMarkerDir/$name";

    unless ( -d $stateMarkerDir ) {
        eval { iMSCP::Dir->new( dirname => $stateMarkerDir )->make( { umask => 0022 } ); };
        !$@ or die( sprintf( "Failed to create the %s marker directory: %s", $stateMarkerDir, $@ ));
    }

    {
        local $SIG{'__WARN__'} = sub { die @_ };

        find(
            sub {
                return unless $_ eq $name && -f;
                unlink or die( sprintf( "Failed to remove old %s marker: %s", $File::Find::name, $! ));
            },
            "$self->{'config'}->{'HTTPD_STATE_DIR'}/$which"
        );
    }

    return if $self->{'_remove_obj'};

    iMSCP::File->new( filename => $stateMarker )->save();
}

=item _getModDeps( $file [, $type = 'Depends' ] )

 Return list of dependencies for the given module

 Param string $file Module .load file path
 Param string $type Dependency type (Depends, Conflicts)
 Return List of dependencies for the given module, die on failure

=cut

sub _getModDeps
{
    my ( undef, $file, $type ) = @_;
    $type //= 'Depends';

    defined $file or die( 'Undefined $file parameter' );
    grep ( $type eq $_, 'Depends', 'Conflicts' ) or die( 'Invalid $type parameter' );

    open( my $fd, '<', $file ) or die( sprintf( "Couldn't open the %s file: %s", $file, $! ));
    while ( my $line = <$fd> ) {
        chomp $line;
        return split /[\n\s]+/, $1 if $line =~ /^# $type:\s+(.*?)\s*$/;
        # Only check until the first non-empty non-comment line
        last if $line !~ /^\s*(?:#.*)?$/;
    }

    return;
}

=item _doModDeps($context, $mod, @deps)

 Process dependencies for the given module

 Param string $context Context (enable|disable)
 Param string $mod Module name
 Param list @deps List of dependencies to process
 Return void, die on failure

=cut

sub _doModDeps
{
    my ( $self, $context, $mod, @deps ) = @_;

    defined $context && grep ( $context eq $_, 'enable', 'disable' ) or die( 'Undefined or invalid $context parameter' );
    defined $mod or die( 'Undefined $mod parameter' );

    for ( @deps ) {
        debug( sprintf( 'Considering dependency %s for %s', $_, $mod ));
        eval { ( $context eq 'enable' ? $self->enableModules( $_ ) : $self->disableModules( $_ ) ); };
        !$@ or die( sprintf( "Couldn't %s dependency %s for %s", $context, $_, $mod ));
    }
}

=item _checkModuleDeps( $mod, @deps)

 Check dependencies for the given Apache module

 Param string Module for which dependencies must be checked
 Param list @deps List of dependencies for the given module
 Return void, die on failure

=cut

sub _checkModuleDeps
{
    my ( $self, $mod, @deps ) = @_;

    defined $mod or die( 'Undefined $mod parameter' );

    for ( @deps ) {
        debug( sprintf( 'Checking dependency %s for the %s module', $_, $mod ));
        -e "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$_.load" or die(
            sprintf( 'The module %s is not enabled, but %s depends on it.', $_, $mod )
        );
    }
}

=item _checkModConflicts( $mod, @conflicts )

 Check conflicts for the given Apache module

 Param string $mod Module for which conflicts must be checked
 Param list @conflicts List of conflicts for the given modules
 Return void, die on failure

=cut

sub _checkModConflicts
{
    my ( $self, $mod, @conflicts ) = @_;

    defined $mod or die( 'Undefined $mod parameter' );

    my $countErrors = 0;

    eval {
        for ( @conflicts ) {
            debug( sprintf( "Considering conflict %s for %s", $_, $mod ));

            my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_.load";
            my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$_.load";

            if ( $self->_checkSymlink( $tgt, $lnk ) eq 'ok' ) {
                error( sprintf( 'The module %s conflict with the %s module. It needs to be disabled first.', $_, $mod ));
                $countErrors++;
            }
        }
    };
    !$@ or die( getMessageByType( 'error', { amount => $countErrors, remove => TRUE } ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
