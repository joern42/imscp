=head1 NAME

 iMSCP::ConfigProvider::ImscpJavaProperties - Configuration provider for i-MSCP core configuration files.

=cut

package iMSCP::ConfigProvider::iMSCP;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug 'getMessageByType';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::TemplateParser 'processByRef';
use parent 'Common::Functor';

=head1 DESCRIPTION

 Configuration provider for i-MSCP core configuration files.

=head1 CLASS METHODS

=over 4

=item( $self, $upsrConfigFilePath, $prodConfigFilePath [, $configNamespace [, $mergeExcludeRegexp ] ] )

 Constructor
 
 This provider operate differently, depending on the execution context:
 
 Installer context
 
 In this context, this provider will try to merge a production configuration
 file with a upstream configuration file, ignoring parameters that don't exist
 in upstream configuration file. Once done, the merged configuration will be
 saved and returned as a hash tied to an iMSCP::Config object, making consumers
 able to update the configuration parameter values.
 
 Other contexts

 Outside of the installer context, the provider will load and return the
 production configuration as a hash tied to a readonly iMSCP::Config object. 
 
 Merging process - Excluding parameters
 
 It is possible to exclude some of configuration parameters from the merging
 process by passing a Regexp which will act as a filter. Any matching parameter
 will not be merged. This is mostly useful for upstream parameters for which
 values change with  each new i-MSCP releases.

 Configuration namespace
 
 It is possible to specify a namespace for the configuration. This is mostly
 useful when a provider is part of an aggregate such as an
 iMSCP::ConfigAggregator object which merge configuration of aggregated
 providers all together to product a single (cached) configuration file for
 production use.
 
 Param string $upsrConfigFilePath Distribution configration file path
 Param string $prodConfigFilePath Production configuration file path
 Param string $configNamespace OPTIONAL namespace for the merged configuration
 Param regexp $mergeExcludeRegexp OPTIONAL Regexp for exlusion of configuration parameters from the merge process
 Return iMSCP::ConfigProvider::iMSCP

=cut

sub new
{
    my ( $self, $upsrConfigFilePath, $prodConfigFilePath, $configNamespace, $mergeExcludeRegexp ) = @_;

    !defined $mergeExcludeRegexp || ref $mergeExcludeRegexp eq 'Regexp' or die( 'Invalid $mergeExcludeRegexp. Regexp expected.' );

    $self->SUPER::new(
        upstream_file        => $upsrConfigFilePath,
        production_file      => $prodConfigFilePath,
        config_namespace     => $configNamespace,
        merge_exclude_regexp => $mergeExcludeRegexp,
        is_installer_context => iMSCP::Getopt->context() eq 'installer'
    );
}

=back

=head1 FUNCTOR METHOD

=over 4

=item getConfig

 Get configuration

 Return hashref on success, die on failure

=cut

sub getConfig( )
{
    my ( $self ) = @_;

    $self->_mergeConfig( $self->{'upstream_file'}, $self->{'production_file'} ) if $self->{'is_installer_context'};

    tie my %mergedConfig, 'iMSCP::Config',
        fileName    => $self->{'production_file'},
        readonly    => !$self->{'is_installer_context'},
        nodeferring => $self->{'is_installer_context'};

    return { $self->{'config_namespace'} => \%mergedConfig } if defined $self->{'config_namespace'};
    \%mergedConfig
}

=item __invoke( )

 Functor object implementation

 Return hashref on sucess, die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    $self->getConfig();
}

=back

=head PRIVATE METHODS

=over 4

=item _mergeConfig

 Merge production configuration with upstream configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self, $upsrConfigFilePath, $prodConfigFilePath ) = @_;

    unless ( -f $prodConfigFilePath ) {
        # For a fresh installation, we make the configuration file free of any placeholder
        my $file = iMSCP::File->new( filename => $upsrConfigFilePath );
        defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
        processVarsByRef( $fileC, {}, TRUE );
        $file->{'filename'} = $prodConfigFilePath;
        $file->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
        return;
    }

    tie my %oldConfig, 'iMSCP::Config',
        fileName => $prodConfigFilePath,
        readonly => TRUE,
        # Do not die when accessing an inexistent parameter. Return an
        # empty value instead (see below).
        nodie    => TRUE;

    my $file = iMSCP::File->new( filename => $upsrConfigFilePath . '.dist' );
    defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );

    # Parameters from production configuration can be used to seed default
    # upstream configuration parameters values (e.g new parameters).
    # For instance: FTP_SQL_USER = {DATABASE_USER}
    # Then, the value of the FTP_SQL_USER parameter will be seed using value
    # of the old DATABASE_USER parameter. If the old DATABASE_USER parameter
    # doesn't exist, the FTP_SQL_USER will be set to an empty value.
    processByRef( \%oldConfig, $fileC, TRUE );

    # Open in memory file for reading/writing of merged config
    open my $fh, '+<', $fileC or die $!;
    tie my %newConfig, 'iMSCP::Config', filename => $fh;

    # Merge production config with upstream config
    while ( my ( $key, $value ) = each( %oldConfig ) ) {
        next unless exists $newConfig{$key} && $key !~ /$self->{'merge_exclude_regexp'}/;
        $newConfig{$key} = $value;
    }

    untie %oldConfig;
    close($fh);
    untie %newConfig;

    # Save merged config
    $file->{'filename'} = $file;
    $file->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
