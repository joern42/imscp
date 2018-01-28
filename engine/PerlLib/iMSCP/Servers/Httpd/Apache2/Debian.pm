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
use Array::Utils qw/ unique /;
use Carp qw/ croak /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Find qw/ find /;
use File::Spec;
use iMSCP::Debug qw/ debug error warning getMessageByType /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
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
            push @{$_[0]}, [ sub { $self->start(); }, $self->getHumanServerName() ];
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

    my $rs = $self->SUPER::uninstall();
    $rs ||= $self->_restoreDefaultConfig();
    return $rs if $rs;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();
        $srvProvider->restart( 'apache2' ) if $srvProvider->hasService( 'apache2' ) && $srvProvider->isRunning( 'apache2' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }
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

 See iMSCP::Servers::Httpd::enableSites()

=cut

sub enableSites
{
    my ($self, @sites) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @sites ) {
            my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix
            my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
            my $lnk = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

            unless ( -e $tgt ) {
                warning( sprintf( '%s is a dangling symlink', $lnk ), $caller ) if -l $lnk && !-e $lnk;
                die( sprintf( "Site %s doesn't exist", $site ), $caller );
            }

            # FIXME: Not sure that this is really needed for a 'site' object but
            # this is done like this in the a2ensite script...
            #$self->_checkModuleDeps( $self->_getModDeps( $tgt ));

            my $check = $self->_checkSymlink( $tgt, $lnk );
            if ( $check eq 'ok' ) {
                debug( sprintf( 'Site %s already enabled', $site ), $caller );
            } elsif ( $check eq 'missing' ) {
                debug( sprintf( 'Enabling site %s', $site ), $caller );
                $self->_createSymlink( $tgt, $lnk );
                $self->_switchMarker( 'site', 'enable', $site );
            } else {
                die( sprintf( "Site %s isn't properly enabled: %s", $site, $check ));
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item disableSites( @sites )

 See iMSCP::Servers::Httpd::disableSites()

=cut

sub disableSites
{
    my ($self, @sites) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @sites ) {
            my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix
            my $tgt = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
            my $lnk = "$self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}/$site.conf";

            unless ( -e $tgt ) {
                if ( -l $lnk && !-e $lnk ) {
                    debug( sprintf( 'Removing dangling symlink: %s', $lnk ), $caller );
                    unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
                    next;
                }

                # Unlike a2dissite script behavior, we don't raise an error when
                # the site that we try to disable doesn't exists
                $self->_switchMarker( 'site', 'disable', $site ) if $self->{'_remove_obj'};
                debug( sprintf( "Site %s doesn't exist. Skipping...", $site ), $caller );
                next;
            }

            if ( -e $lnk || -l $lnk ) {
                debug( sprintf( 'Disabling site %s', $site ), $caller );
                $self->_removeSymlink( $lnk );
                $self->_switchMarker( 'site', 'disable', $site );
            } else {
                debug( sprintf( 'Site %s already disabled', $site ), $caller );
                $self->_switchMarker( 'site', 'disable', $site ) if $self->{'_remove_obj'};
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item removeSites( @sites )

 See iMSCP::Servers::Httpd::removeSites()

=cut

sub removeSites
{
    my ($self, @sites) = @_;

    eval {
        local $self->{'_remove_obj'} = 1;
        my $caller = ( caller( 1 ) )[3];

        for ( unique @sites ) {
            my $site = basename( $_, '.conf' ); # Support input with and without the .conf suffix

            # Make sure that the site is disabled before removing it
            $self->disableSites( $site ) == 0 or die( getMessageByType( 'error ', { amount => 1, remove => 1 } ));

            my $file = "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site.conf";
            unless ( -f $file ) {
                debug( sprintf( "Conf %s doesn't exist. Skipping...", $site ), $caller );
                next;
            }

            debug( sprintf( 'Removing site %s', $site ), $caller );
            unlink( $file ) or die( sprintf( "Couldn't remove the %s site: %s", $site, $! ));
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item enableConfs( @confs )

 See iMSCP::Servers::Httpd::enableConfs()

=cut

sub enableConfs
{
    my ($self, @confs) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @confs ) {
            my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix
            my $tgt = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
            my $lnk = "$self->{'config'}->{'HTTPD_CONF_ENABLED_DIR'}/$conf.conf";

            unless ( -e $tgt ) {
                warning( sprintf( '%s is a dangling symlink', $lnk ), $caller ) if -l $lnk && !-e $lnk;
                die( sprintf( "Conf %s doesn't exist", $conf ));
            }

            # FIXME: Not sure that this is really needed for a 'conf' object but
            # this is done like this in the a2ensite script...
            #$self->_checkModuleDeps( $self->_getModDeps( $tgt ));

            my $check = $self->_checkSymlink( $tgt, $lnk );
            if ( $check eq 'ok' ) {
                debug( sprintf( 'Conf %s already enabled', $conf ), $caller );
            } elsif ( $check eq 'missing' ) {
                debug( sprintf( 'Enabling conf %s', $conf ), $caller );
                $self->_createSymlink( $tgt, $lnk );
                $self->_switchMarker( 'conf', 'enable', $conf );
            } else {
                die( sprintf( "Conf %s isn't properly enabled: %s", $conf, $check ));
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item disableConfs( @confs )

 See iMSCP::Servers::Httpd::disableConfs()

=cut

sub disableConfs
{
    my ($self, @confs) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @confs ) {
            my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix
            my $tgt = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
            my $lnk = "$self->{'config'}->{'HTTPD_CONF_ENABLED_DIR'}/$conf.conf";

            unless ( -e $tgt ) {
                if ( -l $lnk && !-e $lnk ) {
                    debug( sprintf( 'Removing dangling symlink: %s', $lnk ), $caller );
                    unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));
                    next;
                }

                # Unlike a2disconf script behavior, we don't raise an error when
                # the configuration that we try to disable doesn't exists
                $self->_switchMarker( 'conf', 'disable', $conf ) if $self->{'_remove_obj'};
                debug( sprintf( "Conf %s doesn't exist. Skipping...", $conf ), $caller );
                next;
            }

            if ( -e $lnk || -l $lnk ) {
                debug( sprintf( 'Disabling conf %s', $conf ), $caller );
                $self->_removeSymlink( $lnk );
                $self->_switchMarker( 'conf', 'disable', $conf );
            } else {
                debug( sprintf( 'Conf %s already disabled', $conf ), $caller );
                $self->_switchMarker( 'conf', 'disable', $conf ) if $self->{'_remove_obj'};
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item removeConfs( @confs )

 See iMSCP::Servers::Httpd::removeConfs()

=cut

sub removeConfs
{
    my ($self, @confs) = @_;

    eval {
        local $self->{'_remove_obj'} = 1;
        my $caller = ( caller( 1 ) )[3];

        for ( unique @confs ) {
            my $conf = basename( $_, '.conf' ); # Support input with and without the .conf suffix

            # Make sure that the conf is disabled before removing it
            $self->disableConfs( $conf ) or die( getMessageByType( 'error ', { amount => 1, remove => 1 } ));

            my $file = "$self->{'config'}->{'HTTPD_CONF_AVAILABLE_DIR'}/$conf.conf";
            unless ( -f $file ) {
                debug( sprintf( "Conf %s doesn't exist. Skipping...", $conf ), $caller );
                next;
            }

            debug( sprintf( 'Removing conf %s', $conf ), $caller );
            unlink( $file ) or die( sprintf( "Couldn't remove the %s conf: %s", $conf, $! ));
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item enableModules( @mods )

 See iMSCP::Servers::Httpd::enableModules()

=cut

sub enableModules
{
    my ($self, @mods) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @mods ) {
            my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix

            if ( $mod eq 'cgi' && grep( $self->{'config'}->{'HTTPD_MPM'} eq $_, qw/ event worker / ) ) {
                debug( sprintf(
                        "The Apache %s MPM is threaded. Selecting the cgid module instead of the cgi module", $self->{'config'}->{'HTTPD_MPM'}
                    ), $caller );
                $mod = 'cgid';
            }

            my $conftgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.conf";
            my $conflink = -e $conftgt ? "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf" : undef;
            my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.load";
            my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.load";

            unless ( -e $tgt ) {
                warning( sprintf( '%s is a dangling symlink', $lnk )) if -l $lnk && !-e $lnk;
                die( sprintf( "Module %s doesn't exist", $mod ), $caller );
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
                        debug( sprintf( 'Module %s already enabled', $mod ), $caller );
                    } elsif ( $confcheck eq 'missing' ) {
                        debug( sprintf( 'Enabling config file %s', "$mod.conf" ), $caller );
                        $self->_createSymlink( $conftgt, $conflink );
                    } else {
                        die( sprintf( "Config file %s isn't properly enabled: %s", "$mod.conf", $confcheck ));
                    }
                } else {
                    debug( sprintf( 'Module %s already enabled', $mod ), $caller );
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

                debug( sprintf( 'Enabling module %s', $mod ), $caller );
                $self->_createSymlink( $tgt, $lnk );
                $self->_switchMarker( 'module', 'enable', $mod );
            } else {
                die( sprintf( "Module %s isn't properly enabled: %s", $mod, $check ));
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'restart'} ||= 1;
    0;
}

=item disableModules( @mods )

 See iMSCP::Servers::Httpd::disableModules()

=cut

sub disableModules
{
    my ($self, @mods) = @_;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( unique @mods ) {
            my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix
            my $conftgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.conf";
            my $conflink = -e $conftgt ? "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf" : undef;
            my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod.load";
            my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.load";

            unless ( -e $tgt ) {
                if ( -l $lnk && !-e $lnk ) {
                    debug( sprintf( 'Removing dangling symlink: %s', $lnk ), $caller );
                    unlink( $lnk ) or die( sprintf( "Couldn't remove the %s symlink: %s", $lnk, $! ));

                    # Force a .conf path. It may exist as dangling link, too
                    $conflink = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$mod.conf";
                    if ( -l $conflink && !-e $conflink ) {
                        debug( sprintf( 'Removing dangling symlink: %s', $conflink ), $caller );
                        unlink( $conflink ) or die( sprintf( "Couldn't remove the %s symlink: %s", $conflink, $! ));
                    }

                    next;
                }

                # Unlike a2dismod script behavior, we don't raise an error when
                # the module that we try to disable doesn't exists
                $self->_switchMarker( 'module', 'disable', $mod ) if $self->{'_remove_obj'};
                debug( sprintf( "Module %s doesn't exist. Skipping...", $mod ), $caller );
                next;
            }

            # Handle module dependencies
            my @deps;
            for ( glob( "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/*.load" ) ) {
                if ( grep($mod eq $_, $self->_getModDeps( $_ )) ) {
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
                debug( sprintf( 'Disabling module %s', $mod ), $caller );
                $self->_removeSymlink( $lnk );
                $self->_removeSymlink( $conflink ) if $conflink && -e $conflink;
                $self->_switchMarker( 'module', 'disable', $mod );
            } elsif ( $conflink && -e $conflink ) {
                debug( sprintf( 'Disabling stale config file %s', "$mod.conf" ), $caller );
                $self->_removeSymlink( $conflink );
            } else {
                debug( sprintf( 'Module %s already disabled', $mod ), $caller );
                $self->_switchMarker( 'module', 'disable', $mod ) if $self->{'_remove_obj'};
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'restart'} ||= 1;
    0;
}

=item removeModules( @mods )

 See iMSCP::Servers::Httpd::removeModules()

=cut

sub removeModules
{
    my ($self, @mods) = @_;

    eval {
        local $self->{'_remove_obj'} = 1;
        my $caller = ( caller( 1 ) )[3];

        for ( unique @mods ) {
            my $mod = basename( $_, '.load' ); # Support input with and without the .load suffix

            # Make sure that the module is disabled before removing it
            $self->disableModules( $mod ) or die( getMessageByType( 'error ', { amount => 1, remove => 1 } ));

            for ( qw / .load .conf / ) {
                my $file = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$mod$_";
                unless ( -f $file ) {
                    debug( sprintf( "Module %s file doesn't exist. Skipping...", "$mod$_" ), $caller );
                    next;
                }

                debug( sprintf( 'Removing module %s', $mod ), $caller );
                unlink( $file ) or die( sprintf( "Couldn't remove the %s module file: %s", "$mod$_", $! ));
            }
        }
    };
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

 See iMSCP::Servers::Httpd::_init()

=cut

sub _init
{
    my ($self) = @_;

    $self->{'_remove_obj'} = 0;
    $self->SUPER::_init();
}

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
        error( "Couldn't guess Apache version from the `/usr/sbin/apache2ctl -v` command output" );
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

 Setup Apache modules according selected MPM

 return 0 on success, other on failure

=cut

sub _setupModules
{
    my ($self) = @_;

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'event' ) {
        my $rs = $self->disableModules( qw/ mpm_itk mpm_prefork mpm_worker cgi / );
        $rs ||= $self->enableModules(
            qw/ mpm_event access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
            cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return $rs;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'itk' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_worker cgid suexec / );
        $rs ||= $self->enableModules(
            qw/ mpm_prefork mpm_itk access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host
            authz_user autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl /
        );
        return $rs;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'prefork' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_itk mpm_worker cgid / );
        $rs ||= $self->enableModules(
            qw/ mpm_prefork access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user
            autoindex cgi deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return $rs;
    }

    if ( $self->{'config'}->{'HTTPD_MPM'} eq 'worker' ) {
        my $rs = $self->disableModules( qw/ mpm_event mpm_itk mpm_prefork cgi / );
        $rs ||= $self->enableModules(
            qw/ mpm_worker access_compat alias auth_basic auth_digest authn_core authn_file authz_core authz_groupfile authz_host authz_user autoindex
            cgid deflate dir env expires headers mime mime_magic negotiation proxy proxy_http rewrite ssl suexec /
        );
        return $rs;
    }

    error( 'Unknown Apache MPM' );
    1;
}

=item _configure( )

 Configure Apache

 Return int 0 on success, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeApacheBuildConfFile',
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
    $rs ||= $self->disableSites( qw/ default default-ssl 000-default / ); # FIXME: 'default' provided by?
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

    if ( -f "$self->{'cfgDir'}/vlogger.conf" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/vlogger.conf" )->delFile();
        return $rs if $rs;
    }

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

=item _restoreDefaultConfig( )

 Restore default Apache configuration

 Return int 0 on success, other on failure

=cut

sub _restoreDefaultConfig
{
    my ($self) = @_;

    eval { iMSCP::Dir->new( dirname => '/etc/apache2/imscp' )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    if ( -f '/etc/apache2/vlogger.conf' ) {
        my $rs = iMSCP::File->new( filename => '/etc/apache2/vlogger.conf' )->delFile();
        return $rs if $rs;
    }

    if ( -f '/etc/apache2/sites-available/00_nameserver.conf' ) {
        my $rs = $self->disableSites( '00_nameserver.conf' );
        $rs ||= iMSCP::File->new( filename => '/etc/apache2/sites-available/00_nameserver.conf' )->delFile();
        return $rs if $rs;
    }

    my $confDir = -d '/etc/apache2/conf-available' ? '/etc/apache2/conf-available' : 'etc/apache2/conf.d';

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

=item _checkSymlink( $tgt, $lnk )

 Check the given symlink
 
 Param $string $tgt Link target
 Param $string $lnk Link path
 Return symlink state on success, die on failure

=cut

sub _checkSymlink
{
    my (undef, $tgt, $lnk) = @_;

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
 Return int 0 on success, die on failure

=cut

sub _createSymlink
{
    my ($self, $tgt, $lnk) = @_;

    symlink( File::Spec->abs2rel( $tgt, dirname( $lnk )), $lnk ) or die(
        sprintf( "Couldn't create the %s symlink: %s", $lnk, $! )
    );

    $self->{'reload'} ||= 1;
    0;
}

=item _removeSymlink( $lnk )

 Remove the given symlink

 Param $string $lnk Link path
 Return void, raise a warning if $lnk is not a symlink, die on failure

=cut

sub _removeSymlink
{
    my ($self, $lnk) = @_;

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
    my ($self, $which, $what, $name) = @_;

    defined $which or die( 'Undefined $which parameter' );
    defined $what or die( 'Undefined $what parameter' );
    defined $name or die( 'Undefined $name parameter' );

    return unless $main::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && $self->getServerName() eq 'Apache';

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

    iMSCP::File->new( filename => $stateMarker )->save() == 0 or die( sprintf(
        "Failed to create the %s marker: %s",
        $stateMarker,
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    ));
}

=item _getModDeps( $file [, $type = 'Depends' ] )

 Return list of dependencies for the given module

 Param string $file Module .load file path
 Param string $type Dependency type (Depends, Conflicts)
 Return List of dependencies for the given module, die on failure

=cut

sub _getModDeps
{
    my (undef, $file, $type) = @_;
    $type //= 'Depends';

    defined $file or die( 'Undefined $file parameter' );
    grep( $type eq $_, 'Depends', 'Conflicts' ) or die( 'Invalid $type parameter' );

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
    my ($self, $context, $mod, @deps) = @_;

    defined $context && grep( $context eq $_, 'enable', 'disable' ) or die( 'Undefined or invalid $context parameter' );
    defined $mod or die( 'Undefined $mod parameter' );

    for ( @deps ) {
        debug( sprintf( 'Considering dependency %s for %s', $_, $mod ));

        ( $context eq 'enable' ? $self->enableModules( $_ ) : $self->disableModules( $_ ) ) == 0 or die(
            sprintf( "Couldn't %s dependency %s for %s", $context, $_, $mod )
        );
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
    my ($self, $mod, @deps) = @_;

    defined $mod or die( 'Undefined $mod parameter' );

    for ( @deps ) {
        debug( sprintf( 'Checking dependency %s for the %s module', $_, $mod ));
        -e "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$_.load" or die(
            sprintf( "The module %s is not enabled, but %s depends on it." )
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
    my ($self, $mod, @conflicts) = @_;

    defined $mod or die( 'Undefined $mod parameter' );

    my $countErrors = 0;

    eval {
        my $caller = ( caller( 1 ) )[3];

        for ( @conflicts ) {
            debug( sprintf( "Considering conflict %s for %s", $_, $mod ), $caller );

            my $tgt = "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$_.load";
            my $lnk = "$self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'}/$_.load";

            if ( $self->_checkSymlink( $tgt, $lnk ) eq 'ok' ) {
                error( sprintf( 'The module %s conflict with the %s module. It needs to be disabled first.', $_, $mod ), $caller );
                $countErrors++;
            }
        }
    };
    !$@ or die( getMessageByType( 'error', { amount => $countErrors, remove => 1 } ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
