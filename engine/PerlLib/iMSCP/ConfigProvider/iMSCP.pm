=head1 NAME

 iMSCP::ConfigProvider::iMSCP - Configuration provider for i-MSCP configuration files.

=cut

package iMSCP::ConfigProvider::iMSCP;

use strict;
use warnings;
use Carp 'croak';
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::ConfigProvider::JavaProperties;
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
 file with a upstream configuration file, ignoring parameters that don't exist
 in upstream configuration file. Then, the merged configuration is saved and
 returned as a hash tied to an iMSCP::Config object, making consumers able to
 update the configuration parameter values at runtime.
 
 It is possible to exclude some configuration parameters from the merge process
 by passing a Regexp that acts as a filter. If so, any matching parameter is
 discarded from the merge process. This is mostly useful for parameters that
 need to be updated when a new i-MSCP version is released.
 
 The upstream configuration file can make use of template variables to seed
 parameter default values. Template variables are resolved using parameters
 from the production configuration file. If the production file doesn't exist
 or if a parameter is not found, those are set with an empty value.
 
 If the production file doesn't exist, it is created and seed with parameters
 from the upstream configuration file. If that last doesn't exist, an error is
 raised.
 
 Other contexts

 Outside of installer context, this provider loads and return the production
 configuration file as a simple hash. If the file doesn't exist, an error is
 raised.

 Configuration namespace
 
 It is possible to specify a namespace for the returned configuration. This is 
 useful when a provider is part of an aggregate which merge configuration of
 aggregated providers all together to product a single (cached) configuration
 file for production use.

=head1 PUBLIC METHODS

=over 4

=item( UPSTREAM_FILE => <upstream_file>, PRODUCTION_FILE => <production_file> [, NAMESPACE => none ,[ MERGE_EXLUCDE_REGEXP => none ] ] )

 Constructor
 
 Named parameters
  UPSTREAM_FILE        : Upstream configration file path
  PRODUCTION_FILE      : Production configuration file path
  NAMESPACE            : Namespace for the merged configuration, none by default
  MERGE_EXLUCDE_REGEXP : Regexp for parameters exclusion from the merge process, none by default
 Return iMSCP::ConfigProvider::iMSCP

=cut

sub new
{
    my ( $self, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $self->SUPER::new( check( {
        UPSTREAM_FILE        => { default => '', required => iMSCP::Getopt->context() eq 'installer', strict_type => TRUE, },
        PRODUCTION_FILE      => { default => '', required => TRUE, strict_type => TRUE, },
        NAMESPACE            => { default => undef, strict_type => TRUE },
        MERGE_EXLUCDE_REGEXP => { default => undef, strict_type => TRUE },
        IS_INSTALLER_CONTEXT => { default => iMSCP::Getopt->context() eq 'installer', no_override => TRUE }
    }, \%params, TRUE ) or croak( Params::Check::last_error()));
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref on sucess, die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    if ( $self->{'IS_INSTALLER_CONTEXT'} ) {
        $self->_mergeConfig( $self->{'UPSTREAM_FILE'}, $self->{'PRODUCTION_FILE'} );

        tie my %config, 'iMSCP::Config',
            fileName    => $self->{'PRODUCTION_FILE'},
            readonly    => !$self->{'IS_INSTALLER_CONTEXT'},
            nodeferring => $self->{'IS_INSTALLER_CONTEXT'};
        
        return $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => \%config } : \%config;
    }

    my $provider = iMSCP::ConfigProvider::JavaProperties->new(
        GLOB_PATTERN => $self->{'PRODUCTION_FILE'},
        NAMESPACE => $self->{'NAMESPACE'}
    );
    $provider->( $provider );
}

=item _mergeConfig

 Merge production configuration with upstream configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    unless ( -f $self->{'PRODUCTION_FILE'} ) {
        my $file = iMSCP::File->new( filename => $self->{'UPSTREAM_FILE'} );
        defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );

        # For a fresh installation, we seed parameter default values with empty values
        processVarsByRef( $fileC, {}, TRUE );

        $file->{'filename'} = $self->{'PRODUCTION_FILE'};
        $file->save() == 0 or croak( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
        return;
    }

    my $file = iMSCP::File->new( filename => $self->{'UPSTREAM_FILE'} . '.dist' );
    defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );

    my $provider = iMSCP::ConfigProvider::JavaProperties->new( GLOB_PATTERN => $self->{'PRODUCTION_FILE'} );
    my $oldConfig = $provider->( $provider );
    undef $provider;

    # Try to seed parameter default values using parameters from production file
    processByRef( $oldConfig, $fileC, TRUE );

    # Merge production configuration with upstream config
    open my $fh, '+<', $fileC or croak( "Couldn't open file: $!" );
    tie my %newConfig, 'iMSCP::Config', filename => $fh;
    while ( my ( $key, $value ) = each( %{ $oldConfig } ) ) {
        next unless exists $newConfig{$key} && $key !~ /$self->{'MERGE_EXLUCDE_REGEXP'}/;
        $newConfig{$key} = $value;
    }
    untie %newConfig;
    close( $fh );

    # Save merged config
    $file->{'filename'} = $file;
    $file->save() == 0 or croak( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
