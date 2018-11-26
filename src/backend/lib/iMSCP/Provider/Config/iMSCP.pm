=head1 NAME

 iMSCP::Provider::Config::iMSCP - Configuration provider for i-MSCP configuration files.

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

package iMSCP::Provider::Config::iMSCP;

use strict;
use warnings;
use Carp 'croak';
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Provider::Config::JavaProperties;
use iMSCP::Debug 'getMessageByType';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::TemplateParser 'processByRef';
use Params::Check qw/ check last_error /;
use parent 'iMSCP::Common::Functor';

=head1 DESCRIPTION

 Configuration provider for i-MSCP configuration files.
 
 This provider operate differently, depending on the execution context:
 
 Distribution installer context
 
 The provider merge a production configuration file with a distribution
 configuration file, ignoring parameters that don't exist in that last. Then,
 the merged configuration is saved and returned as a hash tied to a writable
 iMSCP::Config object, making consumers able to update the parameter values at
 runtime.
 
 It is possible to exclude some parameters from the merge process by passing a
 Regexp that acts as a filter. If so, any matching parameter is discarded. This
 is useful for parameters that need to be updated when a new i-MSCP version is
 released.
 
 The distribution configuration file can make use of template variables to seed
 parameter default values. Template variables are resolved using passed-in
 variables and/or parameters from the production configuration file. If some
 of variables cannot be resolved, those are emptied.
 
 If the production file doesn't exist, it is created and seed with parameters
 from the distribution configuration file. If that last is not found, an error
 is raised.
 
 Installer context
 
 The provider load a production configuration file and return it as a hash tied
 to a writable iMSCP::Config object, making consumers able to update the parameter
 values at runtime. If the file is not found, an error is raised.
 
 Other contexts

 The provider loads and return the production configuration file as a readonly
 hash. If file is not found, an error is raised.

 All contexts
 
 It is possible to specify a namespace for the returned configuration. This is 
 useful when the provider is part of an aggregate that merge configuration of
 aggregated providers all together to product a single (cached) configuration
 file for production use.

=head1 PUBLIC METHODS

=over 4

=item( PRODUCTION_FILE => <production_file> [, DISTRIBUTION_FILE => <upstream_file>, [ DESTDIR = PRODUCTION_FILE  [, NAMESPACE => none
      [, EXCLUDE_REGEXP => none [, VARIABLES = { }]] ] ] ] )

 Constructor
 
 Named parameters
  PRODUCTION_FILE   : Production configuration file path (always required)
  DISTRIBUTION_FILE : Distribution configration file path (required in distribution installer context, ignored in other context)
  DESTDIR           : Path prepended to production file path before saving merged configuration (optional)
  NAMESPACE         : Configuration namespace, none by default (optional)
  EXCLUDE_REGEXP    : Regexp for parameters exclusion from the merge process, none by default (optional)
  VARIABLES         : Variables for seeding of default parameter values, none by default (optional, (distribution installer context only))
 Return iMSCP::Provider::Config::iMSCP, croak on failure

=cut

sub new
{
    my ( $self, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $self->SUPER::new( check( {
        PRODUCTION_FILE   => { default => '', required => TRUE, strict_type => TRUE },
        DISTRIBUTION_FILE => { default => undef, defined => TRUE, allow => sub { length $_[0] }, strict_type => TRUE },
        DESTDIR           => { default => '/', defined => TRUE, allow => sub { length $_[0] }, strict_type => TRUE },
        NAMESPACE         => { default => undef, defined => TRUE, strict_type => TRUE },
        EXCLUDE_REGEXP    => { default => undef, defined => TRUE, allow => sub { ref $_[0] eq 'Regexp' } },
        VARIABLES         => { default => {}, defined => TRUE, strict_type => TRUE }
    }, \%params, TRUE ) or croak( Params::Check::last_error()));
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref on success, croak or die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    # Merge both the production configuration file and the distribution
    # configuration file
    $self->_mergeConfig() if $ENV{'IMSCP_DIST_INSTALLER'};

    if ( iMSCP::Getopt->context() eq 'installer' ) {
        # Load the production configuration file and return it as a hash tied
        # to a writable iMSCP::Config object
        tie my %config, 'iMSCP::Config', fileName => $self->{'PRODUCTION_FILE'}, readonly => FALSE, nodeferring => TRUE;
        return $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => \%config } : \%config;
    }

    # Load the production configuration file and return it as as a readonly
    # hash
    my $provider = iMSCP::Provider::Config::JavaProperties->new(
        GLOB_PATTERN => $self->{'PRODUCTION_FILE'},
        NAMESPACE    => $self->{'NAMESPACE'},
        READONLY     => TRUE,
    );
    $provider->( $provider );
}

=item _mergeConfig

 Merge production file configuration with upstream configuration file

 Return void, croak or die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => $self->{'DISTRIBUTION_FILE'} );
    my $fileC = $file->getAsRef();

    unless ( -f $self->{'PRODUCTION_FILE'} ) {
        # We seed new production configuration file default parameter values
        # with passed-in variables. If some variables are not found, they are
        # emptied.
        processByRef( $self->{'VARIABLES'}, $fileC, TRUE ) if %{ $self->{'VARIABLES'} };

        $file->{'filename'} = File::Spec->canonpath( $self->{'DESTDIR'} . $self->{'PRODUCTION_FILE'} );
        $file->save();
        return;
    }

    my $provider = iMSCP::Provider::Config::JavaProperties->new( GLOB_PATTERN => $self->{'PRODUCTION_FILE'} );
    my $prodConfig = $provider->( $provider );
    undef $provider;

    # Seed distribution configuration file parameter default values with
    # passed-in variables and parameter values from production file
    processByRef( $self->{'VARIABLES'}, $fileC, TRUE ) if %{ $self->{'VARIABLES'} };
    processByRef( $prodConfig, $fileC, TRUE );

    # Merges production and distribution configuration files
    open my $fh, '+<', $fileC or die( "Couldn't open in memory file: $!" );
    tie my %distConfig, 'iMSCP::Config', fileName => $fh;

    # Seed parameter default values using parameters from distribution file
    #processByRef( \%distConfig, $fileC, TRUE );

    # Override parameter values from distribution configuration file with
    # parameter values from production configuration file, excluding those
    # matching with the EXCLUDE_REGEXP regexp if any  
    while ( my ( $key, $value ) = each( %{ $prodConfig } ) ) {
        next unless exists $distConfig{$key} && ( !$self->{'EXCLUDE_REGEXP'} || $key !~ /$self->{'EXCLUDE_REGEXP'}/ );
        $distConfig{$key} = $value;
    }
    untie %distConfig;
    close( $fh );

    # Save the merged configuration (new production configuration file)
    $file->{'filename'} = File::Spec->canonpath( $self->{'DESTDIR'} . $self->{'PRODUCTION_FILE'} );
    $file->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__

# Usage example:

use iMSCP::Provider::Config::iMSCP;
use iMSCP::Getopt;
use Data::Dumper;

iMSCP::Getopt->context( 'installer' );

my $provider = iMSCP::Provider::Config::iMSCP->new(
    PRODUCTION_FILE => 'test/imscp.conf',
    UPSTREAM_FILE   => 'test/imscp.conf.dist',
    NAMESPACE       => 'master',
    EXCLUDE_REGEXP  => qr/^(?:BuildDate|Version|CodeName|PluginApi)$/
);

my $config = $provider->( $provider );
print Dumper( $config );
