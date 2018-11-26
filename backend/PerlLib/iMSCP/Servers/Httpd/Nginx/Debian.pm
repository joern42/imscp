=head1 NAME

 iMSCP::Servers::Httpd::Nginx::Debian - i-MSCP (Debian) Nginx server implementation

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

package iMSCP::Servers::Httpd::Nginx::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Mount' => qw/ umount /;
use Class::Autouse qw/ :nostat iMSCP::ProgramFinder /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Httpd::Nginx::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Nginx server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Httpd::Nginx::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_configure();
    $rs ||= $self->_installLogrotate();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'Nginx' ];
            0;
        },
        3
    );
}

=item uninstall( )

 See iMSCP::Servers::Httpd::Nginx::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->_removeDirs();
    $rs ||= $self->_restoreDefaultConfig();
    $rs ||= $self->SUPER::uninstall();
    return $rs if $rs;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();
        $srvProvider->restart( 'nginx' ) if $srvProvider->hasService( 'nginx' ) && $srvProvider->isRunning( 'nginx' );
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
    my ( $self ) = @_;

    return 0 unless iMSCP::ProgramFinder::find( 'nginx' );

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    eval { iMSCP::Service->getInstance()->start( 'nginx' ); };
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
    my ( $self ) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'nginx' ); };
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
    my ( $self ) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'nginx' ); };
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
    my ( $self ) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item enableModules( @modules )

 See iMSCP::Servers::Httpd::Nginx::Abstract::enableModules()

=cut

sub enableModules
{
    my ( $self, @modules ) = @_;

    for ( @modules ) {
        # TODO
    }

    $self->{'restart'} ||= 1;
    0;
}

=item disableModules( @modules )

 See iMSCP::Servers::Httpd::Nginx::Abstract::disableModules()

=cut

sub disableModules
{
    my ( $self, @modules ) = @_;

    # TODO
    $self->{'restart'} ||= 1;
    0;
}

=item enableConfs( @conffiles )

 See iMSCP::Servers::Httpd::Nginx::Abstract::enableConfs()

=cut

sub enableConfs
{
    my ( $self, @conffiles ) = @_;

    # TODO
    $self->{'reload'} ||= 1;
    0;
}

=item disableConfs( @conffiles )

 See iMSCP::Servers::Httpd::Nginx::Abstract::disableConfs()

=cut

sub disableConfs
{
    my ( $self, @conffiles ) = @_;

    # TODO
    $self->{'reload'} ||= 1;
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 See iMSCP::Servers::Httpd::Nginx::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( [ 'nginx', '-v' ], \my $stdout, \my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /nginx\/([\d.]+)/i ) {
        error( "Couldn't guess Nginx version from the `nginx -v` command output" );
        return 1;
    }

    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Nginx version set to: %s', $1 ));
    0;
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    eval {
        iMSCP::Dir->new( dirname => '/var/log/nginx' )->make( {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ADM_GROUP'},
            mode  => 0750
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }
}

=item _configure( )

 Configure Nginx

 Return int 0 on success, other on failure

=cut

sub _configure
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeNginxBuildConfFile',
        sub {
            my ( $cfgTpl ) = @_;
            ${ $cfgTpl } =~ s/^NameVirtualHost[^\n]+\n//gim;

            if ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ) {
                ${ $cfgTpl } =~ s/^(\s*Listen)\s+0.0.0.0:(80|443)/$1 $2\n/gim;
            } else {
                ${ $cfgTpl } =~ s/^(\s*Listen)\s+(80|443)\n/$1 0.0.0.0:$2\n/gim;
            }

            0;
        }
    );
    $rs ||= $self->buildConfFile( '/etc/nginx/ports.conf', '/etc/nginx/ports.conf' );

    # Turn off default access log provided by Debian package
    $rs = $self->disableConfs( 'other-vhosts-access-log.conf' );
    return $rs if $rs;

    # Remove default access log file provided by Debian package
    #iMSCP::File->new( filename => "/var/log/nginx/other_vhosts_access.log" )->remove();

    my $serverData = {
        HTTPD_CUSTOM_SITES_DIR => '/etc/nginx/imscp',
        HTTPD_LOG_DIR          => '/var/log/nginx',
        HTTPD_ROOT_DIR         => '/var/www',
        TRAFF_ROOT_DIR         => "$::imscpConfig{'BACKEND_ROOT_DIR'}/traffic",
        #VLOGGER_CONF_PATH      => '/etc/nginx/vlogger.conf'
    };

    $rs = $self->buildConfFile( '00_nameserver.conf', '/etc/nginx/sites-available/00_nameserver.conf', undef, $serverData );
    $rs ||= $self->enableSites( '00_nameserver.conf' );
    #$rs ||= $self->buildConfFile( '00_imscp.conf', '/etc/nginx/conf-available/00_imscp.conf', undef, $serverData );
    #$rs ||= $self->enableConfs( '00_imscp.conf' );
    #$rs ||= $self->disableSites( 'default', 'default-ssl', '000-default.conf', 'default-ssl.conf' );
}

=item _installLogrotate( )

 Install Apache logrotate file

 Return int 0 on success, other on failure

=cut

sub _installLogrotate
{
    my ( $self ) = @_;

    $self->buildConfFile( 'logrotate.conf', '/etc/logrotate.d/nginx', undef,
        {
            ROOT_USER     => $::imscpConfig{'ROOT_USER'},
            ADM_GROUP     => $::imscpConfig{'ADM_GROUP'},
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
    my ( $self ) = @_;

    return 0 unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    0;
}

=item _removeDirs( )

 Remove non-default Nginx directories

 Return int 0 on success, other on failure

=cut

sub _removeDirs
{
    eval { iMSCP::Dir->new( dirname => '/etc/nginx/imscp' )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _restoreDefaultConfig( )

 Restore default Nginx configuration

 Return int 0 on success, other or die on failure

=cut

sub _restoreDefaultConfig
{
    my ( $self ) = @_;

    #iMSCP::File->new( filename => "'/etc/nginx/vlogger.conf'" )->remove();


    my $rs = $self->disableSites( '00_nameserver.conf' );
    return $rs if $rs;

    iMSCP::File->new( filename => '/etc/nginx/sites-available/00_nameserver.conf' )->remove();

    #my $rs = $self->disableConfs( '00_imscp.conf' );
    #return $rs if $rs;
    #
    #iMSCP::File->new( filename => "'/etc/nginx/conf-available'/00_imscp.conf" )->remove();

    iMSCP::Dir->new( dirname => $_ )->remove() for glob( "$::imscpConfig{'USER_WEB_DIR'}/*/domain_disable_page" );
    iMSCP::Dir->new( dirname => '/etc/nginx/imscp' )->remove();

    #for ( '000-default', 'default' ) {
    #    next unless -f "/etc/nginx/sites-available/$_";
    #
    #    my $rs = $self->enableSites( $_ );
    #    return $rs if $rs;
    #}

    0;
}
=item _shutdown( )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ( $self ) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    $self->$action();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
