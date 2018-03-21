=head1 NAME

 iMSCP::Servers::Abstract - Factory and abstract implementation for i-MSCP servers

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

package iMSCP::Servers::Abstract;

use strict;
use warnings;
use Carp qw/ confess croak /;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug qw/ debug getMessageByType /;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::TemplateParser qw/ processByRef /;
use parent 'iMSCP::Common::Singleton';

# Implicite server instances
# We need keep trace of server instances
# that were loaded implicitly because we need call
# the _shutdown() method on them when the program exit.
# See the END block below for a better understanding.
my %_SERVER_INSTANCES;

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP servers.

=head1 CLASS METHODS

=over 4

=item getPriority( )

 Return the server priority
  
 The server priority determines the priority at which the server will be
 treated by the installer, the database tasks processor, and some other
 scripts. It also determines the priority for the server shutdown tasks
 where the start, restart and reload actions *SHOULD* be triggered.

 Return int Server priority

=cut

sub getPriority
{
    0;
}

=item factory( [ $serverClass = $::imscpConfig{$class} ] )

 Creates and returns an iMSCP::Servers::Abstract server instance

 This method is not intented to be called on final iMSCP::Servers::Abstract
 server classes. if you do so, an error will be raised.

 Param string $serverClass OPTIONAL Server class, default to selected server alternative
 Return iMSCP::Servers::Abstract, die on failure

=cut

sub factory
{
    my ( $class, $serverClass ) = @_;

    # Restrict call of the factory to iMSCP::Servers::* abstract classes
    $class =~ tr/:// < 5 or croak( sprintf( 'The factory() method cannot be called on the %s server class', $class ));

    $serverClass //= $::imscpConfig{$class} || 'iMSCP::Servers::NoServer';

    return $_SERVER_INSTANCES{$class} if exists $_SERVER_INSTANCES{$class} && ref $_SERVER_INSTANCES{$class} eq $serverClass;

    eval "require $serverClass; 1" or confess( $@ );

    if ( $serverClass ne $::imscpConfig{$class} ) {
        # We don't keep trace of server instances that were asked explicitly as
        # this would prevent load of those which are implicit.
        # This also means that the _shutdown() method on these server instances
        # will not be called automatically.
        return $serverClass->getInstance( eventManager => iMSCP::EventManager->getInstance());
    }

    $_SERVER_INSTANCES{$class} = $serverClass->getInstance( eventManager => iMSCP::EventManager->getInstance());
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners
 
 This method is called by the i-MSCP installer and reconfiguration script.
 That is the place where event listeners for setup dialog *MUST* be registered.
 
 Any server relying on i-MSCP setup dialog *MUST* implement this method.

 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;
}

=item preinstall( )

 Process the server pre-installation tasks
 
 This method is called by the i-MSCP installer and reconfiguration script.

 Any server requiring pre-installation tasks *SHOULD* implement this method,
 not forgetting to call it, unless stopping the linked service(s) is not
 desired.

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->stop();
}

=item install( )

 Process the server installation tasks

 This method is called by the i-MSCP installer and reconfiguration script.
 
 Any server requiring post-installation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;
}

=item postinstall( )

 Process server post-installation tasks

 This method is called by the i-MSCP installer and reconfiguration script.
 
 Any server requiring post-installation tasks *SHOULD* implement this method,
 not forgetting to call it, unless starting the linked service(s) is not
 desired.

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices', sub { push @{ $_[0] }, [ sub { $self->start(); }, $self->getHumanServerName() ]; }, $self->getPriority()
    );
}

=item preuninstall( )

 Process the server pre-uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any server requiring pre-uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub preuninstall
{
    my ( $self ) = @_;
}

=item uninstall( )

 Process the server uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any server requiring uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;
}

=item postuninstall( )

 Process the server post-uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any server requiring post-uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub postuninstall
{
    my ( $self ) = @_;
}

=item setEnginePermissions( )

 Sets engine permissions

 This method is called by the i-MSCP engine permission management script.

 Any server relying on configuration files or scripts *SHOULD* implement this
 method.

 Return void, die on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;
}

=item setGuiPermissions( )

 Sets the GUI permissions

 This method is called by the i-MSCP GUI permission management script.

 Any server managing GUI files *SHOULD* implement this method.

 Return void, die on failure

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;
}

=item getServerName( )

 Return internal CamelCase service name implemented by this server class
 
 Server name must follow CamelCase naming convention such as Apache, Courier,
 Dovecot, LocalServer... See https://en.wikipedia.org/wiki/Camel_case
 
 This method is primarily used for event names construct at runtime, and at
 some other places where the internal server name must be showed such as in
 the engine/tools/imscp-info.pl script.

 Return string CamelCase server name

=cut

sub getServerName
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getServerName() method', ref $self ));
}

=item getHumanServerName( )

 Return the humanized name of the service implemented by this server class

 For instance: Apache 2.4.25 (MPM Event)

 Return string Humanized server name

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getHumanServerName() method', ref $self ));
}

=item getImplVersion()

 Return the implementation version of this server

 Return string Server version

=cut

sub getImplVersion
{
    my ( $self ) = @_;

    no strict 'refs';
    ${ "@{ [ ref $self ] }::VERSION" } // '0.0.0';
}

=item getVersion()

 Return the version of the service implemented by this server class

 Return string Server version

=cut

sub getVersion
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getVersion() method', ref $self ));
}

=item dpkgPostInvokeTasks()

 Process dpkg(1) post-invoke tasks

 This method is called after each dpkg(1) invocation. This make it possible to
 perform some maintenance tasks such as updating server versions.

 Only Debian server implementations *SHOULD* implement that method.

 Return void, die on failure

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;
}

=item getTraffic( \%trafficDb [, $logFile [, \%trafficIndexDb ] ] )

 Get server traffic data

 Any server for which traffic data are available *SHOULD* implement this
 method. By default i-MSCP expects traffic data for FTP, HTTP, SMTP and
 IMAP/POP services.

 Have a look at iMSCP::Servers::Mta::Postfix::Abstract::getTraffic() for an
 implementation example.

 Param hashref \%trafficDb Traffic database
 Param string $logFile OPTIONAL Path to ftpd traffic log file (only when self-called)
 Param hashref \%trafficIndexDb OPTIONAL Traffic index database (only when self-called)
 Return void, die on failure

=cut

sub getTraffic
{
    my ( $self, $trafficDb, $logFile, $trafficIndexDb ) = @_;
}

=item start( )

 Start the server

 Return void, die on failure

=cut

sub start
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the start() method', ref $self ));
}

=item stop( )

 Stop the server

 Return void, die on failure

=cut

sub stop
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the stop() method', ref $self ));
}

=item restart( )

 Restart the server

 Return void, die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the restart() method', ref $self ));
}

=item reload( )

 Reload the server

 Return void, die on failure

=cut

sub reload
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the reload() method', ref $self ));
}

=item buildConfFile( $file, [ $dest = $file [, \%mdata = { } [, \%sdata [, \%params = { } ] ] ] ] )

 Build the given server configuration file
 
 The following events are triggered:
  - onLoadTemplate('<SNAME>', $filename, \$cfgTpl, $mdata, $sdata, $self->{'config'}, $params )
  - before<SNAME>BuildConfFile( \$cfgTpl, $filename, \$dest, $mdata, $sdata, $self->{'config'}, $params )
  - after<SNAME>BuildConfFile( \$cfgTpl, $filename, \$dest, $mdata, $sdata, $self->{'config'}, $params )

  where <SNAME> is the server name as returned by the iMSCP::Servers::Abstract::getServerName() method.

 Param string|iMSCP::File $file An iMSCP::File object, an absolute filepath or a filepath relative to this server configuration directory
 Param string $dest OPTIONAL Destination file path, default to $file
 Param hashref \%mdata OPTIONAL Data as provided by the iMSCP::Modules::* modules, none if outside of an i-MSCP module context
 Param hashref \%sdata OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%params OPTIONAL parameters:
  - umask   : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
  - user    : File owner (default: EUID for a new file, no change for existent file)
  - group   : File group (default: EGID for a new file, no change for existent file)
  - mode    : File mode (default: 0666 & ~(UMASK(2) || 0) for a new file, no change for existent file )
  - cached  : Whether or not loaded file must be cached in memory
  - srcname : Make it possible to override default source filename passed into event listeners. Most used when file is a TMPFILE(3) file
  - create  : Whether $dest must be created when $file doesn't exist and its content is not set (empty). An error is raised by default.
 Return void, die on failure

=cut

sub buildConfFile
{
    my ( $self, $file, $dest, $mdata, $sdata, $params ) = @_;
    $mdata //= {};
    $sdata //= {};
    $params //= {};

    defined $file or croak( 'Missing or undefined $file parameter' );

    # Force interpolation as $file can be a stringyfiable iMSCP::File object
    $dest //= "$file";

    my ( $sname, $cfgTpl ) = ( $self->getServerName(), undef );
    my ( $filename, $path ) = fileparse( $file );
    $params->{'srcname'} //= $filename;

    if ( $params->{'cached'} && exists $self->{'_templates'}->{"$file"} ) {
        $file = $self->{'_templates'}->{"$file"};
    } else {
        # Trigger the onLoadTemplate event so that 3rd-party components are
        # able to override default template
        $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $sname, $params->{'srcname'}, \$cfgTpl, $mdata, $sdata, $self->{'config'}, $params );

        if ( length $cfgTpl ) {
            # Template has been overridden by an event listener
            if ( ref $file eq 'iMSCP::File' ) {
                $file->set( $cfgTpl );
            } else {
                $file = iMSCP::File->new( filename => $file )->set( $cfgTpl );
            }

            undef $cfgTpl;
        } elsif ( ref $file ne 'iMSCP::File' ) {
            $file = iMSCP::File->new( filename => index( $path, '/' ) != 0 ? File::Spec->canonpath( "$self->{'cfgDir'}/$path/$filename" ) : $file );
        }

        $self->{'_templates'}->{"$file"} = $file if $params->{'cached'};
    }

    # Localizes the changes as we want keep the template clean (template caching)
    local $file->{'file_content'} if $params->{'cached'};

    # If $file doesn't exist and its content is not set (empty),
    # raise an error, unless caller asked for $dest creation.
    $cfgTpl = $file->getAsRef( !$params->{'create'} ? FALSE : !-f $file );

    # Triggers the before<SNAME>BuildConfFile event so that 3rd-party
    # components are able to act on the template
    $self->{'eventManager'}->trigger(
        "before${sname}BuildConfFile", $cfgTpl, $params->{'srcname'}, \$dest, $mdata, $sdata, $self->{'config'}, $params
    );

    # Expands the template variables using server and module data.
    # Server data have higher priority.
    processByRef( $sdata, $cfgTpl ) if %{ $sdata };
    processByRef( $mdata, $cfgTpl ) if %{ $mdata };

    # Triggers the after<SNAME>BuildConfFile event so that 3rd-party components
    # are able to act on the template
    $self->{'eventManager'}->trigger(
        "after${sname}BuildConfFile", $cfgTpl, $params->{'srcname'}, \$dest, $mdata, $sdata, $self->{'config'}, $params
    );

    # Locally update the file path according to the desired destination if
    # needed. We operate locally because the caller can have provided an
    # iMSCP::File object, in which case it is not desirable to propagate the
    # change.
    local $file->{'filename'} = File::Spec->canonpath( $dest ) unless "$file" eq $dest;

    $file->save( $params->{'umask'} );
    $file->owner( $params->{'user'} // -1, $params->{'group'} // -1 ) if defined $params->{'user'} || defined $params->{'group'};
    $file->mode( $params->{'mode'} ) if defined $params->{'mode'};
}

=item AUTOLOAD()

 Implements autoloading for undefined methods

 The default implementation will raise an error for any method that is not known
 to be called by the iMSCP::Modules::* modules.

 Return void, die on failure

=cut

sub AUTOLOAD
{
    ( my $method = our $AUTOLOAD ) =~ s/.*:://;

    $method =~ /^
        (?:pre|post)?
        (?:add|disable|restore|delete)
        (?:Domain|CustomDNS|FtpUser|Htaccess|Htgroup|Htpasswd|IpAddr|Mail|SSLcertificate|Subdomain|User)
        $/x or die( sprintf( 'Unknown %s method', $AUTOLOAD ));

    # Define the subroutine to prevent further evaluation
    no strict 'refs';
    *{ $AUTOLOAD } = sub {};

    # Erase the stack frame
    goto &{ $AUTOLOAD };
}

=item DESTROY( )

 Destroy tasks

=cut

sub DESTROY
{
    # Needed due to AUTOLOAD
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::Singleton::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->_loadConfig();
    $self;
}

=item _loadConfig( [ $filename = lc( $self->getServerName() . 'data ) ] )

 Load the server configuration
 
 In installer context, also merge the old configuration with new configuration and make
 old configuration available through the 'old_config' attribute.

 Param string $filename OPTIONAL i-MSCP server configuration filename
 Return void, die on failure

=cut

sub _loadConfig
{
    my ( $self, $filename ) = @_;
    $filename //= lc( $self->getServerName() . '.data' );

    defined $filename or croak( 'Missing $filename parameter' );
    defined $self->{'cfgDir'} or croak( sprintf( "The %s class must define the 'cfgDir' property", ref $self ));

    if ( iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/$filename.dist" ) {
        if ( -f "$self->{'cfgDir'}/$filename" ) {
            debug( sprintf( 'Merging old %s server configuration with new %s server configuration...', $filename, "$filename.dist" ));

            tie my %oldConfig, 'iMSCP::Config',
                filename => "$self->{'cfgDir'}/$filename",
                readonly => TRUE,
                # We do not want croak when accessing non-existing parameters
                # in old configuration file. The new configuration file can
                # refers to old parameters for new parameter values but in case
                # the parameter doesn't exist in old conffile, we want simply
                # an empty value. 
                nocroak  => TRUE;

            # Sometime, a configuration parameter get renamed. In such case the
            # developer could want set the new parameter value with the old
            # parameter name as a placeholder. For instance:
            #
            # Old parameter: DATABASE_USER
            # New parameter: FTP_SQL_USER
            #
            # The value of the new parameter should be set as follows in the
            # configuration file:
            #
            #   FTP_SQL_USER = {DATABASE_USER}
            #
            # By doing this, the value of the old DATABASE_USER parameter will
            # be automatically used as value for the new FTP_SQL_USER parameter.
            my $file = iMSCP::File->new( filename => "$self->{'cfgDir'}/$filename.dist" );
            processByRef( \%oldConfig, $file->getAsRef(), TRUE );
            $file->save();
            undef( $file );

            tie my %newConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/$filename.dist";

            while ( my ( $key, $value ) = each( %oldConfig ) ) {
                $newConfig{$key} = $value if exists $newConfig{$key};
            }

            # Make the old configuration available through the 'old_config' property
            %{ $self->{'old_config'} } = %oldConfig;

            untie %newConfig;
            untie %oldConfig;
        } else {
            # For a fresh installation, we make the configuration file free of any placeholder
            my $file = iMSCP::File->new( filename => "$self->{'cfgDir'}/$filename.dist" );
            processByRef( {}, $file->getAsRef(), TRUE );
            $file->save();
            undef( $file );
        }

        iMSCP::File->new( filename => "$self->{'cfgDir'}/$filename.dist" )->move( "$self->{'cfgDir'}/$filename" );
    }

    debug( sprintf( 'Loading %s server configuration...', $self->getServerName()));

    tie %{ $self->{'config'} },
        'iMSCP::Config',
        filename    => "$self->{'cfgDir'}/$filename",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer';

    # Make the new configuration also available through the 'old_config'
    # property, unless the property is alreadys set, or if we are not in installer context
    %{ $self->{'old_config'} } = %{ $self->{'config'} } unless exists $self->{'old_config'} || iMSCP::Getopt->context() ne 'installer';
}

=item _shutdown( )

 Execute the server shutdown tasks

 This method is called automatically as late as possible, before the program exits.
 
 Any i-MSCP server that require a reload or restart when their
 configuration has been changed *MUST* implement this method.
 
 Note that this doesn't limit to reload and restart tasks. One i-MSCP server can
 rely on that method to do specific tasks at the very end of the program. For
 instance, that is the case of the i-MSCP Postfix server which need create or
 update the lookup tables before the program exit.

 Return void

=cut

sub _shutdown
{
    my ( $self ) = @_;
}

=item END

 Calls the _shutdown() method on all servers
 
 The shutdown tasks are executed in descending order of server priorities
 (highest to lowest priority).

 Note that if the program is being to exit with an error status code, or if it
 is in installer context, the shutdown tasks are skipped.
 
 It is the responsability to server installation routines to make sure that the
 services they implement will be up and running after the installation.

=cut

END {
    return if $? || !%_SERVER_INSTANCES || iMSCP::Getopt->context() eq 'installer';

    $_->_shutdown() for sort { $b->getPriority() <=> $a->getPriority() } values %_SERVER_INSTANCES;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
