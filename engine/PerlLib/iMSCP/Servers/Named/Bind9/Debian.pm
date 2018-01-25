=head1 NAME

 iMSCP::Servers::Named::Bind9::Debian - i-MSCP (Debian) Bind9 server implementation

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

package iMSCP::Servers::Named::Bind9::Debian;

use strict;
use warnings;
use File::Basename;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Named::Bind9::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Bind9 server implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    0; # We do not want stop the service while installation/reconfiguration
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    return $rs if $rs;

    # Update /etc/default/bind9 file (only if exist)
    if ( -f '/etc/default/bind9' ) {
        $rs = $self->{'eventManager'}->registerOne(
            'beforeBindBuildConfFile',
            sub {
                # Enable/disable local DNS resolver
                ${$_[0]} =~ s/RESOLVCONF=(?:no|yes)/RESOLVCONF=$self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'}/i;

                return 0 unless ${$_[0]} =~ /OPTIONS="(.*)"/;

                # Enable/disable IPV6 support
                ( my $options = $1 ) =~ s/\s*-[46]\s*//g;
                $options = '-4 ' . $options unless $self->{'config'}->{'NAMED_IPV6_SUPPORT'} eq 'yes';
                ${$_[0]} =~ s/OPTIONS=".*"/OPTIONS="$options"/;
                0;
            }
        );
        $rs ||= $self->buildConfFile( '/etc/default/bind9', '/etc/default/bind9' );
        return $rs if $rs;
    }

    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();

        # Fix for #IP-1333
        # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=744304
        if ( $self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'} eq 'yes' ) {
            # Service will be started automatically when Bind9 will be restarted
            $srvProvider->enable( 'bind9-resolvconf' );
        } else {
            $srvProvider->stop( 'bind9-resolvconf' );
            $srvProvider->disable( 'bind9-resolvconf' );
        }

        $srvProvider->enable( 'bind9' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    # We need restart the service since it is already started
    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->restart(); }, $self->getHumanServerName() ];
            0;
        },
        $self->getPriority()
    );
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->_removeConfig();
    return $rs if $rs;

    eval {
        my $srvProvider = iMSCP::Service->getInstance();
        $srvProvider->restart( 'bind9' ) if $srvProvider->hasService( 'bind9' ) && $srvProvider->isRunning( 'bind9' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'bind9' ); };
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

    eval { iMSCP::Service->getInstance()->stop( 'bind9' ); };
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

    eval { iMSCP::Service->getInstance()->restart( 'bind9' ); };
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

    eval { iMSCP::Service->getInstance()->reload( 'bind9' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion()

 See iMSCP::Servers::Named::Bind9::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ '/usr/bin/bind9-config', '--version' ], \ my $stdout, \ my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /version=([\d.]+)/i ) {
        error( "Couldn't guess Bind version from the `/usr/bin/bind9-config --version` command output" );
        return 1;
    }

    $self->{'config'}->{'NAMED_VERSION'} = $1;
    debug( sprintf( 'Bind version set to: %s', $1 ));
    0;
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/bind.old.data" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.old.data" )->delFile();
        return $rs if $rs;
    }

    if ( iMSCP::ProgramFinder::find( 'resolvconf' ) ) {
        my $rs = execute( 'resolvconf -d lo.imscp', \ my $stdout, \ my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    eval { iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_ROOT_DIR'} )->clear( undef, qr/\.db$/ ); };
    if ( $@ ) {
        error( $@ );
        return 1;
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

    iMSCP::Service->getInstance()->registerDelayedAction( 'bind9', [ $action, sub { $self->$action(); } ], $priority );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
