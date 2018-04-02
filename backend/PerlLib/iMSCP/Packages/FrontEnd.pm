=head1 NAME

 iMSCP::Packages::FrontEnd - i-MSCP FrontEnd package

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

package iMSCP::Packages::FrontEnd;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Packages::FrontEnd::Installer iMSCP::Packages::FrontEnd::Uninstaller /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Getopt;
use iMSCP::Service;
use iMSCP::SystemUser;
use iMSCP::TemplateParser qw/ processByRef /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP FrontEnd package.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    100;
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners

 Param iMSCP::EventManager \%eventManager
 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->registerSetupListeners();
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndPreInstall' );
    $self->stopNginx();
    $self->stopPhpFpm();
    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->preinstall();
    $self->{'eventManager'}->trigger( 'afterFrontEndPreInstall' );
}

=item install( )

 Process install tasks

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndInstall' );
    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->install();
    $self->{'eventManager'}->trigger( 'afterFrontEndInstall' );
}

=item postinstall( )

 Process postinstall tasks

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndPostInstall' );
    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->postinstall();

    my $srvProvider = iMSCP::Service->getInstance( eventManager => $self->{'eventManager'} );
    $srvProvider->enable( 'nginx' );
    $srvProvider->enable( 'imscp_panel' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->startNginx(); }, 'Nginx' ];
            push @{ $_[0] }, [ sub { $self->startPhpFpm(); }, 'i-MSCP panel (PHP FastCGI process manager)' ];
        },
        2
    );
    $self->{'eventManager'}->trigger( 'afterFrontEndPostInstall' );
}

=item dpkgPostInvokeTasks( )

 Process postinstall tasks

 Return void, die on failure

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndDpkgPostInvokeTasks' );
    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->dpkgPostInvokeTasks();
    $self->{'eventManager'}->trigger( 'afterFrontEndDpkgPostInvokeTasks' );
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndUninstall' );
    iMSCP::Packages::FrontEnd::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
    $self->{'eventManager'}->trigger( 'afterFrontEndUninstall' );
}

=item setBackendPermissions( )

 Set backend permissions

 Return void, die on failure

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( $self->{'config'}->{'HTTPD_CONF_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0644',
        recursive => TRUE
    } );
    setRights( $self->{'config'}->{'HTTPD_LOG_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0640',
        recursive => TRUE
    } );

    # Temporary directories as provided by nginx package (from Debian Team)
    if ( -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}" ) {
        setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}, {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'}
        } );

        for my $tmp ( 'body', 'fastcgi', 'proxy', 'scgi', 'uwsgi' ) {
            next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp";

            setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user      => $self->{'config'}->{'HTTPD_USER'},
                group     => $self->{'config'}->{'HTTPD_GROUP'},
                dirnmode  => '0700',
                filemode  => '0640',
                recursive => TRUE
            } );
            setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user  => $self->{'config'}->{'HTTPD_USER'},
                group => $::imscpConfig{'ROOT_GROUP'},
                mode  => '0700'
            } );
        }
    }

    # Temporary directories as provided by nginx package (from nginx Team)
    return unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}";

    setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'}
    } );

    for my $tmp ( 'client_temp', 'fastcgi_temp', 'proxy_temp', 'scgi_temp', 'uwsgi_temp' ) {
        next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp";

        setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user      => $self->{'config'}->{'HTTPD_USER'},
            group     => $self->{'config'}->{'HTTPD_GROUP'},
            dirnmode  => '0700',
            filemode  => '0640',
            recursive => TRUE
        } );
        setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user  => $self->{'config'}->{'HTTPD_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0700'
        } );
    }
}

=item setGuiPermissions( )

 Set gui permissions

 Return void, die on failure

=cut

sub setGuiPermissions
{
    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    setRights( $::imscpConfig{'GUI_ROOT_DIR'}, {
        user      => $usergroup,
        group     => $usergroup,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item addUser( \%data )

 Process addUser tasks

 Param hash \%data user data as provided by Modules::User module
 Return void, die on failure

=cut

sub addUser
{
    my ( undef, $data ) = @_;

    return if $data->{'STATUS'} eq 'tochangepwd';

    iMSCP::SystemUser->new( username => $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} )->addToGroup(
        $data->{'GROUP'}
    );
}

=item enableSites( @sites )

 Enable the given site(s)

 Param array @sites List of sites to enable
 Return void, die on failure

=cut

sub enableSites
{
    my ( $self, @sites ) = @_;

    for my $site ( @sites ) {
        my $target = File::Spec->canonpath( "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site" );
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));
        -f $target or die( sprintf( "Site `%s` doesn't exist", $site ));
        next if -l $symlink && realpath( $symlink ) eq $target;
        unlink $symlink or die( sprintf( "Couldn't unlink the %s file: %s", $! )) if -e _;
        symlink File::Spec->abs2rel( $target, $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} ), $symlink or die(
            sprintf( "Couldn't enable the `%s` site: %s", $site, $! )
        );

        $self->{'reload'} ||= TRUE;
    }
}

=item disableSites( @sites )

 Disable the given site(s)

 Param array @sites List of sites to disable
 Return void, die on failure

=cut

sub disableSites
{
    my ( $self, @sites ) = @_;

    for my $site ( @sites ) {
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));
        next unless -e $symlink;
        unlink( $symlink ) or die( sprintf( "Couldn't unlink the %s file: %s", $! ));
        $self->{'reload'} ||= TRUE;
    }
}

=item start( )

 Start frontEnd

 Return void, die on failure

=cut

sub start
{
    my ( $self ) = @_;

    $self->startPhpFpm();
    $self->startNginx();
}

=item stop( )

 Stop frontEnd

 Return void, die on failure

=cut

sub stop
{
    my ( $self ) = @_;

    $self->stopPhpFpm();
    $self->stopNginx();
}

=item reload( )

 Reload frontEnd

 Return void, die on failure

=cut

sub reload
{
    my ( $self ) = @_;

    $self->reloadPhpFpm();
    $self->reloadNginx();
}

=item restart( )

 Restart frontEnd

 Return void, die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    $self->restartPhpFpm();
    $self->restartNginx();
}

=item startNginx( )

 Start frontEnd (Nginx only)

 Return void, die on failure

=cut

sub startNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item stopNginx( )

 Stop frontEnd (Nginx only)

 Return void, die on failure

=cut

sub stopNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( "$self->{'config'}->{'HTTPD_SNAME'}" );
}

=item reloadNginx( )

 Reload frontEnd (Nginx only)

 Return void, die on failure

=cut

sub reloadNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item restartNginx( )

 Restart frontEnd (Nginx only)

 Return void, die on failure

=cut

sub restartNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item startPhpFpm( )

 Start frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub startPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'imscp_panel' );
}

=item stopPhpFpm( )

 Stop frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub stopPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'imscp_panel' );
}

=item reloadPhpFpm( )

 Reload frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub reloadPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'imscp_panel' );
}

=item restartPhpFpm( )

 Restart frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub restartPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'imscp_panel' );
}

=item buildConfFile( $file [, \%tplVars = { } [, \%options = { } ] ] )

 Build the given configuration file

 Param string $file Absolute filepath or filepath relative to the frontend configuration directory
 Param hash \%tplVars OPTIONAL Template variables
 Param hash \%options OPTIONAL Options such as destination, mode, user and group for final file
 Return void, die on failure

=cut

sub buildConfFile
{
    my ( $self, $file, $tplVars, $options ) = @_;

    $tplVars ||= {};
    $options ||= {};

    my ( $filename, $path ) = fileparse( $file );
    $file = File::Spec->canonpath( "$self->{'cfgDir'}/$path/$filename" ) if index( $path, '/' ) != 0;
    $file = iMSCP::File->new( filename => $file );

    my $cfgTpl = $file->getAsRef( TRUE );
    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'frontend', $filename, $cfgTpl, $tplVars );
    $file->getAsRef();

    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConfFile', $cfgTpl, $filename, $tplVars, $options );
    $self->_buildConf( $cfgTpl, $filename, $tplVars );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildConfFile', $cfgTpl, $filename, $tplVars, $options );

    ${ $cfgTpl } =~ s/^\s*(?:[#;].*)?\n//gmi; # Final cleanup

    $file->{'filename'} = $options->{'destination'} // "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$filename";
    $file->save()->owner( $options->{'user'}, $options->{'group'} )->mode( $options->{'mode'} );
}

=item getComposer( )

 Get iMSCP::Composer instance associated to this package

 Return iMSCP::Composer

=cut

sub getComposer
{
    my ( $self ) = @_;

    iMSCP::Packages::FrontEnd::Installer->getInstance( eventManager => $self->{'eventManager'} )->getComposer();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::FrontEnd

=cut

sub _init
{
    my ( $self ) = @_;

    @{ $self }{qw/ start reload restart cfgDir / } = ( FALSE, FALSE, FALSE, "$::imscpConfig{'CONF_DIR'}/frontend" );
    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/frontend.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        filename    => "$self->{'cfgDir'}/frontend.data",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer';
    $self;
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/frontend.data" ) {
        tie my %newConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/frontend.data.dist";
        tie my %oldConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/frontend.data", readonly => 1;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/frontend.data.dist" )->move( "$self->{'cfgDir'}/frontend.data" );
}

=item _buildConf( \$cfgTpl, $filename [, \%tplVars ] )

 Build the given configuration template

 Param scalarref \$cfgTpl Reference to Temmplate's content
 Param string $filename Template filename
 Param hash OPTIONAL \%tplVars Template variables
 Return void, die on failure

=cut

sub _buildConf
{
    my ( $self, $cfgTpl, $filename, $tplVars ) = @_;

    $tplVars ||= {};
    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConf', $cfgTpl, $filename, $tplVars );
    processByRef( $tplVars, $cfgTpl );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildConf', $cfgTpl, $filename, $tplVars );
}

=item END

 Start, restart or reload frontEnd services: nginx or/and imscp_panel when required

 Return int Exit code

=cut

END
    {
        return if $? || iMSCP::Getopt->context() eq 'installer';

        my $instance = __PACKAGE__->hasInstance();

        return unless $instance && ( my $action = $instance->{'restart'}
            ? 'restart' : ( $instance->{'reload'} ? 'reload' : ( $instance->{'start'} ? ' start' : undef ) ) );

        my $nginxAction = "${action}Nginx";
        my $fpmAction = "${action}PhpFpm";

        iMSCP::Service->getInstance()->registerDelayedAction( "nginx", [ $action, sub { $instance->$nginxAction(); } ], __PACKAGE__->getPriority());

        iMSCP::Service->getInstance()->registerDelayedAction(
            "imscp_panel", [ $action, sub { $instance->$fpmAction(); } ], __PACKAGE__->getPriority()
        );
    }

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
