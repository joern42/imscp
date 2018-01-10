=head1 NAME

 iMSCP::Servers::Abstract - Factory and abstract implementation for i-MSCP servers

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

package iMSCP::Servers::Abstract;

use strict;
use warnings;
use Carp qw/ confess croak /;
use File::Spec;
use iMSCP::Debug qw/ debug /;
use iMSCP::EventManager;
use iMSCP::TemplateParser qw/ processByRef /;
use parent 'iMSCP::Common::Singleton';

# Server instances
my %_SERVER_INSTANCES;

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Return the server priority
  
 The server priority determines the priority at which the server will be
 treated by the installer, DB tasks processor and some other scripts. It
 also determines the server's priority for start, restart and reload tasks.

 Return int Server priority

=cut

sub getPriority
{
    0;
}

=item factory( [ $serverClass = $main::imscpConfig{$class} ] )

 Creates and returns a concrete iMSCP::Servers::Abstract ($serverClass) server instance

 This method is not intented to be called on final iMSCP::Servers::Abstract
 server classes.

 Param string $serverClass OPTIONAL Server class, default to selected server alternative
 Return iMSCP::Servers::Abstract, confess on failure

=cut

sub factory
{
    my ($class, $serverClass) = @_;

    # Prevent call of the factory on known iMSCP::Servers::* abstract classes
    $class =~ tr/:// < 5 or croak( sprintf( 'The factory() method cannot be called on the %s server class', $class ));

    $serverClass //= $main::imscpConfig{$class} || 'iMSCP::Servers::Noserver';

    return $_SERVER_INSTANCES{$class} if exists $_SERVER_INSTANCES{$class};

    eval "require $serverClass; 1" or confess( $@ );

    if ( $serverClass ne $main::imscpConfig{$class} ) {
        # We don't keep trace of server instances that were asked explicitly as
        # this would prevent load of those which are implicit
        return $serverClass->getInstance( eventManager => iMSCP::EventManager->getInstance());;
    }

    $_SERVER_INSTANCES{$class} = $serverClass->getInstance( eventManager => iMSCP::EventManager->getInstance());
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners
 
 This method is automatically called by the i-MSCP installer and reconfiguration script.
 That is the place where event listeners for setup dialog should be registered.
 
 Any server relying on i-MSCP setup dialog *MUST* implement this method.

 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    0;
}

=item preinstall( )

 Process the server pre-installation tasks
 
 This method is automatically called by the i-MSCP installer and reconfiguration script.
 Any server requiring pre-installation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    $self->stop();
}

=item install( )

 Process the server installation tasks

 This method is automatically called by the i-MSCP installer and reconfiguration script.
 Any server requiring installation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    0;
}

=item postinstall( )

 Process server post-installation tasks

 This method is automatically called by the i-MSCP installer and reconfiguration script.
 Any server requiring post-installation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->start(); }, $self->getHumanServerName() ];
            0;
        },
        $self->getPriority()
    );

    0;
}

=item preuninstall( )

 Process the server pre-uninstallation tasks

 This method is automatically called by the i-MSCP installer/uninstaller.
 Any server requiring pre-uninstallation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub preuninstall
{
    my ($self) = @_;

    0;
}

=item uninstall( )

 Process the server uninstallation tasks

 This method is automatically called by the i-MSCP installer/uninstaller.
 Any server requiring uninstallation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ($self) = @_;

    0;
}

=item postuninstall( )

 Process the server post-uninstallation tasks

 This method is automatically called by the i-MSCP installer/uninstaller.
 Any server requiring post-uninstallation tasks *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub postuninstall
{
    my ($self) = @_;

    0;
}

=item setEnginePermissions( )

 Sets the server permissions, that is, the permissions on server directories and files

 This method is automatically called by the i-MSCP engine permission management script.
 Any server relying on configuration files or scripts *SHOULD* implement it.

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    0;
}

=item getEventServerName( )

 Return event server name

 This name is most used in abstract classes for event names construction.

 Return string server name for event names construction

=cut

sub getEventServerName
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the getEventServerName() method', ref $self ));
}

=item getHumanServerName( )

 Return the humanized name of this server

 Return string Humanized server name

=cut

sub getHumanServerName
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the getHumanServerName() method', ref $self ));
}

=item getImplVersion()

 Return the implementation version of this server

 Return string Server version

=cut

sub getImplVersion
{
    my ($self) = @_;

    no strict 'refs';
    ${"@{[ ref $self ]}::VERSION"} // '0.0.0';
}

=item getVersion()

 Return the version of this server

 Return string Server version

=cut

sub getVersion
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the getVersion() method', ref $self ));
}

=item start( )

 Start the server

 Return int 0, other on failure

=cut

sub start
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the start() method', ref $self ));
}

=item stop( )

 Stop the server

 Return int 0, other on failure

=cut

sub stop
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the stop() method', ref $self ));
}

=item restart( )

 Restart the server

 Return int 0, other on failure

=cut

sub restart
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the restart() method', ref $self ));
}

=item reload( )

 Reload the server

 Return int 0, other on failure

=cut

sub reload
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the reload() method', ref $self ));
}

=item buildConfFile( $srcFile, $trgFile, [, \%mdata = { } [, \%sdata [, \%params = { } ] ] ] )

 Build the given server configuration file
 
 The following events *MUST* be triggered:
  - onLoadTemplate('<SNAME>', $filename, \$cfgTpl, $mdata, $sdata, $self->{'config'}, $params )
  - before<SNAME>BuildConfFile( \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params )
  - after<SNAME>BuildConfFile( \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params )

  where <SNAME> is the server name as returned by the ::getEventServerName() method.

 Param string $srcFile Absolute source filepath or source filepath relative to the i-MSCP server configuration directory
 Param string $trgFile Target file path
 Param hashref \%mdata OPTIONAL Data as provided by the iMSCP::Modules::* modules
 Param hashref \%sdata OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%params OPTIONAL parameters:
  - umask : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal), default to umask()
  - user  : File owner, default: root
  - group : File group, default: root
  - mode  : File mode, default: 0666 & (~umask())
  - cached : Whether or not loaded file must be cached in memory
 Return int 0 on success, other on failure

=cut

sub buildConfFile
{
    my ($self, $srcFile, $trgFile, $mdata, $sdata, $params) = @_;
    $mdata //= {};
    $sdata //= {};
    $params //= {};

    my ($sname, $cfgTpl) = ( $self->getEventServerName(), undef );
    my ($filename, $path) = fileparse( $srcFile );

    if ( $params->{'cached'} && exists $self->{'_templates'}->{$srcFile} ) {
        $cfgTpl = $self->{'_templates'}->{$srcFile};
    } else {
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $sname, $filename, \$cfgTpl, $mdata, $sdata, $self->{'config'}, $params );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $srcFile = File::Spec->canonpath( "$self->{'cfgDir'}/$path/$filename" ) if index( $path, '/' ) != 0;
            $cfgTpl = iMSCP::File->new( filename => $srcFile )->get();
            unless ( defined $cfgTpl ) {
                error( sprintf( "Couldn't read the %s file", $srcFile ));
                return 1;
            }
        }

        $self->{'_templates'}->{$srcFile} = $cfgTpl if $params->{'cached'};
    }

    my $rs = $self->{'eventManager'}->trigger(
        "before${sname}BuildConfFile", \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params
    );
    return $rs if $rs;

    processByRef( $sdata, \$cfgTpl ) if %{$sdata};
    processByRef( $mdata, \$cfgTpl ) if %{$mdata};

    $rs = $self->{'eventManager'}->trigger(
        "after${sname}dBuildConfFile", \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $self->{'config'}, $params
    );
    return $rs if $rs;

    my $fh = iMSCP::File->new( filename => $trgFile );
    $fh->set( $cfgTpl );
    $rs ||= $fh->save( $params->{'umask'} // undef );
    return $rs if $rs;

    if ( exists $params->{'user'} || exists $params->{'group'} ) {
        $rs = $fh->owner( $params->{'user'} // $main::imscpConfig{'ROOT_USER'}, $params->{'group'} // $main::imscpConfig{'ROOT_GROUP'} );
        return $rs if $rs;
    }

    if ( exists $params->{'mode'} ) {
        $rs = $fh->mode( $params->{'mode'} );
        return $rs if $rs;
    }

    0;
}

=item AUTOLOAD()

 Implements autoloading for inexistent methods

 Return int 0

=cut

sub AUTOLOAD
{
    0;
}

=item DESTROY

 Destroy the server instance
 
 Return void

=cut

sub DESTROY
{
    my ($self) = @_;

    debug( sprintf( '%s server instance', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize the server instance

 Return iMSCP::Servers::Php::Abstract, croak on failure

=cut

sub _init
{
    my ($self) = @_;

    return $self unless ref $self eq __PACKAGE__;

    croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));
}

=item _shutdown( $priority )

 Reload or restart the server

 This method is called automatically when the program exits. It *MUST* be
 implemented by all servers that require a reload or restart when their
 configuration has been changed.

 Param int $priority Server priority
 Return void

=cut

sub _shutdown
{
    my ($self) = @_;

    0;
}

=item END

 Calls the _shutdown() method on all servers that implement it

 Return void

=cut

END {
    return if $? || !%_SERVER_INSTANCES || ( defined $main::execmode && $main::execmode eq 'setup' );

    $_->_shutdown( $_->getPriority()) for values %_SERVER_INSTANCES;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
