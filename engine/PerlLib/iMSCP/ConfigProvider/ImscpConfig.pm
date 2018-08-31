=head1 NAME

 iMSCP::ConfigProvider::ImscpConfig - Configuration provider for i-MSCP configuration files

=cut

package iMSCP::ConfigProvider::ImscpConfig;

use strict;
use warnings;
use File::Glob ':bsd_glob';
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug 'getMessageByType';
use iMSCP::File;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Configuration provider for i-MSCP configuration files.

=head1 CLASS METHODS

=over 4

=item( $self, $globPattern, $mergedTargetFile, $configNamespace, $mergeExcludePattern)

 Constructor
 
 Return iMSCP::ConfigProvider::ImscpConfig

=cut

sub new
{
    my ( $self, $globPattern, $mergedTargetFile, $configNamespace, $mergeExcludePattern ) = @_;

    $self->SUPER::new(
        file_glob_pattern     => $globPattern,
        merged_target_file    => $mergedTargetFile,
        config_namespace      => $configNamespace,
        merge_exclude_pattern => $mergeExcludePattern
    );
}

=back

=head1 FUNCTOR METHOD

=over 4

=item __invoke()

 Fonctor method

 Return hashref on sucess, die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    my @files = bsd_glob( $self->{'file_glob_pattern'}, GLOB_BRACE );
    my $mergedConfig = File::Temp->new();
    tie my %mergedConfig, 'iMSCP::Config', fileName => $mergedConfig;

    if ( @files ) {
        for my $file ( @files ) {
            tie my %config, 'iMSCP::Config', fileName => $file;

            unless ( %mergedConfig ) {
                %mergedConfig = %config;
                next;
            }

            while ( my ( $k, $v ) = each( %config ) ) {
                next unless exists $mergedConfig{$k} && $k !~ /$self->{'merge_exclude_pattern'}/;
                $mergedConfig{$k} = $v;
            }
        }
    }

    $mergedConfig->close();
    untie %mergedConfig;

    my $file = iMSCP::File->new( filename => "$mergedConfig" );
    $file->moveFile( $self->{ 'merged_target_file' } ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
    tie %mergedConfig, 'iMSCP::Config', fileName => "$file", nodeferring => TRUE;

    return { $self->{'config_namespace'} => \%mergedConfig } if defined $self->{'config_namespace'};
    \%mergedConfig
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
