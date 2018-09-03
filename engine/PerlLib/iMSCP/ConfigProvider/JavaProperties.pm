=head1 NAME

 iMSCP::ConfigProvider::JavaProperties - Configuration provider for Java-style properties files.

=cut

package iMSCP::ConfigProvider::JavaProperties;

use strict;
use warnings;
use Carp 'croak';
use File::Glob ':bsd_glob';
use iMSCP::Boolean;
use iMSCP::File;
use Params::Check qw/ check last_error /;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Configuration provider for Java-style properties files.
 
 This configuration provider accept a BSD glob(3) pattern for loading and
 merging of several Java-style properties files all together, returning the
 merged configuration as a simple hash. 

 It is possible to specify a namespace for the returned configuration. This is
 useful when the provider is part of an aggregate that merge configuration of
 aggregated providers all together to product a single (cached) configuration
 file for production use.

=head1 PUBLIC METHODS

=over 4

=item new( GLOB_PATTERN => <glob_pattern> [, DELIMITER => '=', [ NAMESPACE => none ] ] )

 Constructor
 
 Named parameters
  GLOB_PATTERN : Glob pattern for Java-style properties files (required).
  DELIMITER    : Delimiter for key/value pairs, default to equals character (=).
  NAMESPACE    : Configuration namespace, none by default
 Return iMSCP::ConfigProvider::JavaProperties, croak on failure

=cut

sub new
{
    my ( $self, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $self->SUPER::new( check( {
        DELIMITER    => { default => '=', allow => [ '=', ':' ], strict_type => TRUE, },
        GLOB_PATTERN => { required => TRUE, defined => TRUE },
        NAMESPACE    => { default => undef, strict_type => TRUE }
    }, \%params, TRUE ) or croak( Params::Check::last_error()));
}

=back

=head1 PRIVATE METHOD

=over 4

=item __invoke()

 Functor implementation

 Return hashref on sucess, croak on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    my ( $config, @files ) = ( {}, bsd_glob( $self->{'GLOB_PATTERN'}, GLOB_BRACE ) );

    return defined $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => $config } : $config unless @files;

    $config = { %{ $config }, %{ $self->_parseFile( $_ ) } } for @files;
    defined $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => $config } : $config;
}

=item _parseFile

 Parse a Java-style properties file

 Note that this implementation doesn't allow usage of delimiter in key names.

 Return hashref on success, croak on failure

=cut

sub _parseFile
{
    my ( $self, $file ) = @_;

    my ( %config, $key, $value, $valueLength, $delimiterPos, $isLineContinuation );

    open my $fh, '<', $file or croak( "Couldn't open file: $!" );
    while ( my $line = <$fh> ) {
        $line =~ s/^\s+|\s+$//g;
        next if !length $line || ( !$isLineContinuation && ( index( $line, '#' ) == 0 || index( $line, '!' ) == 0 ) );

        if ( $isLineContinuation ) {
            $value .= $line;
        } else {
            if ( ( $delimiterPos = index( $line, $self->{'DELIMITER'} ) ) != -1 ) {
                ( $key, $value ) = ( substr( $line, 0, $delimiterPos ), substr( $line, $delimiterPos+1, length $line ) );
            } else {
                ( $key, $value ) = ( $line, '' );
            }
        }

        $valueLength = length( $value )-1;
        if ( $valueLength != -1 && index( $value, '\\' ) == $valueLength ) {
            ( $value, $isLineContinuation ) = ( substr( $value, 0, $valueLength ), TRUE );
        } else {
            $isLineContinuation = FALSE;
        }

        ( $config{$key =~ s/\s+$//gr} = $value ) =~ s/^\s+//g;
    }
    close( $fh );

    \%config;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__

# Usage example:

use iMSCP::ConfigProvider::JavaProperties;
use Data::Dumper;

my $provider = iMSCP::ConfigProvider::iMSCP->new(
    GLOB_PATTERN => 'test/{c,b,a}.{conf.dist,conf}',
    NAMESPACE    => 'testing'
);

my $config = $provider->( $provider );
print Dumper( $config );
