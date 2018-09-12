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
use parent 'Common::Functor';

=head1 DESCRIPTION

 Configuration provider for i-MSCP configuration files.
 
 This provider operate differently, depending on the execution context:
 
 Installer context
 
 In installer context, this provider try to merge a production configuration
 file with a distribution configuration file, ignoring parameters that don't
 exist in that last. Then, the merged configuration is saved and returned as a
 hash tied to an iMSCP::Config object, making consumers able to update the
 parameter values at runtime.
 
 It is possible to exclude some parameters from the merge process by passing a
 Regexp that acts as a filter. If so, any matching parameter is discarded. This
 is useful for parameters that need to be updated when a new i-MSCP version is
 released.
 
 The distribution configuration file can make use of template variables to seed
 parameter default values. Template variables are resolved using parameters
 from the production configuration file. If the production file doesn't exist
 or if some parameters are not found, those are set with an empty value.
 
 If the production file doesn't exist, it is created and seed with parameters
 from the upstream configuration file. If that last doesn't exist, an error is
 raised.
 
 Other contexts

 Outside of installer context, this provider loads and return the production
 configuration as a simple hash. If the production configuration file doesn't
 exist, an error is raised.

 Configuration namespace
 
 It is possible to specify a namespace for the returned configuration. This is 
 useful when the provider is part of an aggregate that merge configuration of
 aggregated providers all together to product a single (cached) configuration
 file for production use.

=head1 PUBLIC METHODS

=over 4

=item( PRODUCTION_FILE => <production_file> [, DISTRIBUTION_FILE => <upstream_file>, [, NAMESPACE => none [, EXCLUDE_REGEXP => none ] ] ] )

 Constructor
 
 Named parameters
  PRODUCTION_FILE   : Production configuration file path (required)
  DISTRIBUTION_FILE : Distribution configration file path (required in installer context)
  DESTDIR           : Path prepended to production file path before saving merged configuration (installer context)
  NAMESPACE         : Configuration namespace, none by default (optional)
  EXCLUDE_REGEXP    : Regexp for parameters exclusion from the merge process, none by default (optional)
 Return iMSCP::Provider::Config::iMSCP, croak on failure

=cut

sub new
{
    my ( $self, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $self->SUPER::new( check( {
        DISTRIBUTION_FILE    => { default => '', defined => TRUE, strict_type => TRUE },
        PRODUCTION_FILE      => { default => '', required => TRUE, strict_type => TRUE },
        DESTDIR              => { default => '', allow => sub { -d $_[0] }, strict_type => TRUE },
        NAMESPACE            => { default => undef, defined => TRUE, strict_type => TRUE },
        EXCLUDE_REGEXP       => { default => undef, defined => TRUE, allow => sub { ref $_[0] eq 'Regexp' } },
        IS_INSTALLER_CONTEXT => { default => iMSCP::Getopt->context() eq 'installer', no_override => TRUE }
    }, \%params, TRUE ) or croak( Params::Check::last_error()));
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref on sucess, croak on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    if ( $self->{'IS_INSTALLER_CONTEXT'} ) {
        if(defined $self->{'DISTRIBUTION_FILE'}) {
            $self->_mergeConfig( $self->{'DISTRIBUTION_FILE'}, $self->{'PRODUCTION_FILE'} );
        }

        tie my %config, 'iMSCP::Config',
            fileName    => $self->{'PRODUCTION_FILE'},
            readonly    => !$self->{'IS_INSTALLER_CONTEXT'},
            nodeferring => $self->{'IS_INSTALLER_CONTEXT'};

        return $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => \%config } : \%config;
    }

    my $provider = iMSCP::Provider::Config::JavaProperties->new(
        GLOB_PATTERN => $self->{'PRODUCTION_FILE'},
        NAMESPACE    => $self->{'NAMESPACE'}
    );
    $provider->( $provider );
}

=item _mergeConfig

 Merge production file configuration with upstream configuration file

 Return void, croak on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => $self->{'DISTRIBUTION_FILE'} );
    defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );

    unless ( -f $self->{'PRODUCTION_FILE'} ) {
        $self->{'PRODUCTION_FILE'} = File::Spec->canonpath( $self->{'DESTDIR'} . '/' . $self->{'PRODUCTION_FILE'} ) if $self->{'DESTDIR'} ne '';

        # If the production file doesn't exist, we create it and we seed
        # parameter default values with empty values
        processByRef( {}, $fileC, TRUE );

        $file->{'filename'} = $self->{'PRODUCTION_FILE'};
        $file->save() == 0 or croak( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
        return;
    }

    my $provider = iMSCP::Provider::Config::JavaProperties->new( GLOB_PATTERN => $self->{'PRODUCTION_FILE'} );
    my $productionConfig = $provider->( $provider );
    undef $provider;

    # Seed parameter default values using parameters from production file
    processByRef( $productionConfig, $fileC, TRUE );

    # Merge production configuration with upstream config
    open my $fh, '+<', $fileC or croak( "Couldn't open in memory file: $!" );
    tie my %upstreamConfig, 'iMSCP::Config', fileName => $fh;
    while ( my ( $key, $value ) = each( %{ $productionConfig } ) ) {
        next unless exists $upstreamConfig{$key} && ( !$self->{'EXCLUDE_REGEXP'} || $key !~ /$self->{'EXCLUDE_REGEXP'}/ );
        $upstreamConfig{$key} = $value;
    }
    untie %upstreamConfig;
    close( $fh );

    # Save merged configuration
    $self->{'PRODUCTION_FILE'} = File::Spec->canonpath( $self->{'DESTDIR'} . '/' . $self->{'PRODUCTION_FILE'} ) if $self->{'DESTDIR'} ne '';
    $file->{'filename'} = $self->{'PRODUCTION_FILE'};
    $file->save() == 0 or croak( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
    return;
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
