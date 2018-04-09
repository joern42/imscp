=head1 NAME

 iMSCP::Packages::Abstract - Abstract implementation for i-MSCP packages

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

package iMSCP::Packages::Abstract;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::DistPackageManager /;
use Carp qw/ croak /;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Database;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Template::Processor qw/ processVarsByRef /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 This class provides an abstract implementation for the i-MSCP packages.

=head1 CLASS METHODS

=over 4

=item getPackagePriority( )

 Return the package priority
  
 The package priority determines the priority at which the package will be
 treated by the installer, the backend, and some other scripts.

 Return int Package priority

=cut

sub getPackagePriority
{
    0;
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners
 
 This method is called by the i-MSCP installer and reconfiguration script.
 That is the place where event listeners for setup dialog *MUST* be registered.
 
 Any package relying on i-MSCP setup dialog *MUST* implement this method.

 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;
}

=item preinstall( )

 Process the package pre-installation tasks
 
 This method is called by the i-MSCP installer and reconfiguration script.

 Any package requiring pre-installation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;
}

=item install( )

 Process the package installation tasks

 This method is called by the i-MSCP installer and reconfiguration script.
 
 Any package requiring post-installation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;
}

=item postinstall( )

 Process package post-installation tasks

 This method is called by the i-MSCP installer and reconfiguration script.
 
 Any package requiring post-installation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub postinstall
{
    my ( $self ) = @_;
}

=item preuninstall( )

 Process the package pre-uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any package requiring pre-uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub preuninstall
{
    my ( $self ) = @_;
}

=item uninstall( )

 Process the package uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any package requiring uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;
}

=item postuninstall( )

 Process the package post-uninstallation tasks

 This method is called by the i-MSCP installer and uninstaller.

 Any package requiring post-uninstallation tasks *SHOULD* implement this method.

 Return void, die on failure

=cut

sub postuninstall
{
    my ( $self ) = @_;
}

=item setBackendPermissions( )

 Set backend permissions

 This method is called by the i-MSCP backend permission management script.

 Any package relying on configuration files or scripts *SHOULD* implement this
 method.

 Return void, die on failure

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;
}

=item setFrontendPermissions( )

 Set frontEnd permissions

 This method is called by the i-MSCP frontEnd permission management script.

 Any package managing FrontEnd files *SHOULD* implement this method.

 Return void, die on failure

=cut

sub setFrontendPermissions
{
    my ( $self ) = @_;
}

=item getPackageName( )

 Return internal package name

 Return string internal package name

=cut

sub getPackageName
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getPackageName() method', ref $self ));
}

=item getPackageHumanName( )

 Return humanized package name

 For instance: Roundcube 1.3.4

 Return string Humanized service name

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getPackageHumanName() method', ref $self ));
}

=item getPackageVersion()

 Return package version, generally the version of the service provided by the package but not always

 Return string Service version

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getPackageVersion() method', ref $self ));
}

=item getPackageImplVersion()

 Return the implementation version of this package

 Return string Package implementation version

=cut

sub getPackageImplVersion
{
    my ( $self ) = @_;

    no strict 'refs';
    ${ "@{ [ ref $self ] }::VERSION" } // '0.0.0';
}

=item dpkgPostInvokeTasks()

 Process dpkg(1) post-invoke tasks

 This method is called after each dpkg(1) invocation. This make it possible to
 perform some maintenance tasks such as updating service versions.

 Return void, die on failure

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;
}

=item getDistroPackages( )

 Get list of distribution packages

 Return list List of packages

=cut

sub getDistroPackages
{
    my ( $self ) = @_;

    ();
}

=item buildConfFile( $file, [ $dest = $file [, \%mdata = { } [, \%pdata [, \%params = { } ] ] ] ] )

 Build the given package configuration file
 
 The following events are triggered:
  - onLoadTemplate('<PNAME>', $filename, \$cfgTpl, $mdata, $pdata, $self->{'config'}, $params )
  - before<PNAME>BuildConfFile( \$cfgTpl, $filename, \$dest, $mdata, $pdata, $self->{'config'}, $params )
  - after<PNAME>BuildConfFile( \$cfgTpl, $filename, \$dest, $mdata, $pdata, $self->{'config'}, $params )

  where <PNAME> is the package name as returned by the iMSCP::Packages::Abstract::getPackageName() method.

 Param string|iMSCP::File $file An iMSCP::File object, an absolute filepath or a filepath relative to this package configuration directory
 Param string $dest OPTIONAL Destination file path, default to $file
 Param hashref \%mdata OPTIONAL Data as provided by the iMSCP::Modules::* modules, none if outside of an i-MSCP module context
 Param hashref \%pdata OPTIONAL Package data (Package data have higher precedence than modules data)
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
    my ( $self, $file, $dest, $mdata, $pdata, $params ) = @_;
    $mdata //= {};
    $pdata //= {};
    $params //= {};

    defined $file or croak( 'Missing or undefined $file parameter' );

    # Force interpolation as $file can be a stringyfiable iMSCP::File object
    $dest //= "$file";

    my ( $pname, $cfgTpl ) = ( $self->getPackageName(), undef );
    my ( $filename, $path ) = fileparse( $file );
    $params->{'srcname'} //= $filename;

    if ( $params->{'cached'} && exists $self->{'_templates'}->{"$file"} ) {
        $file = $self->{'_templates'}->{"$file"};
    } else {
        # Trigger the onLoadTemplate event so that 3rd-party components are
        # able to override default template
        $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $pname, $params->{'srcname'}, \$cfgTpl, $mdata, $pdata, $self->{'config'}, $params );

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

    # Triggers the before<PNAME>BuildConfFile event so that 3rd-party
    # components are able to act on the template
    $self->{'eventManager'}->trigger(
        "before${pname}BuildConfFile", $cfgTpl, $params->{'srcname'}, \$dest, $mdata, $pdata, $self->{'config'}, $params
    );

    # Process the template variables with package and module data.
    # Package data have higher priority.
    processVarsByRef( $cfgTpl, $pdata ) if %{ $pdata };
    processVarsByRef( $cfgTpl, $mdata ) if %{ $mdata };

    # Triggers the after<PNAME>BuildConfFile event so that 3rd-party components
    # are able to act on the template
    $self->{'eventManager'}->trigger(
        "after${pname}BuildConfFile", $cfgTpl, $params->{'srcname'}, \$dest, $mdata, $pdata, $self->{'config'}, $params
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
 to be called by the iMSCP::Modules::Abstract class.

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

    # Define the subroutine to prevent further AUTOLOADING
    no strict 'refs';
    *{ $AUTOLOAD } = sub {};

    # Execute the subroutine, erasing AUTOLOAD stack frame without trace
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

    $self->{'dbh'} = iMSCP::Database->getInstance();
    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self;
}

=item _installPackages( @packages )

 Install distribution packages

 Param list @packages List of packages to install
 Return void, die on failure

=cut

sub _installPackages
{
    my ( $self, @packages ) = @_;

    return if iMSCP::Getopt->skippackages || !@packages;

    iMSCP::DistPackageManager->getInstance()->installPackages( @packages );
}

=item _uninstallPackages( @packages )

 Uninstall distribution packages

 Param list @packages Packages to remove
 Return int 0 on success, other on failure

=cut

sub _uninstallPackages
{
    my ( $self, @packages ) = @_;

    return if iMSCP::Getopt->skippackages || !@packages;

    iMSCP::DistPackageManager->getInstance()->uninstallPackages( @packages );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
