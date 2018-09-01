=head1 NAME

 iMSCP::ConfigProvider::JavaProperties - Configuration provider for Java-style properties files.

=cut

package iMSCP::ConfigProvider::JavaProperties;

use strict;
use warnings;
use File::Glob ':bsd_glob';
use iMSCP::Boolean;
use iMSCP::File;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Configuration provider for Java-style properties files.

=head1 CLASS METHODS

=over 4

=item new( $globPattern [, $delimiter = ':' [, $trimWhitespace = FALSE ] ] )

 Constructor
 
 Param string $string Glob pattern for Java-style properties files.
 Param string $delimiter OPTIONAL Delimiter for key/value pairs.
 Param bool $trimWhitespace OPTIONAL Whether or not to trim whitespace from discovered keys and values
 Return iMSCP::ConfigProvider::JavaProperties

=cut

sub new
{
    my ( $self, $globPattern, $delimiter, $trimWhitespace ) = @_;

    $delimiter //= ':';
    $trimWhitespace //= FALSE;
    $delimiter ne '' or die( 'Invalid $delimiter parameter. No empty string expected.' );

    $self->SUPER::new(
        glob_pattern   => $globPattern,
        delimiter      => $delimiter,
        trimWhitespace => $trimWhitespace
    );
}

=back

=head1 PRIVATE METHOD

=over 4

=item __invoke()

 Fonctor method

 Return hashref on sucess, die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    my @files = bsd_glob( $self->{'glob_pattern'}, GLOB_BRACE );
    my $config = {};

    return $config unless @files;

    $config = $self->_parseFile( shift @files );
    $self->_hash_replace_recursive( $config, $self->_parseFile( $_ )) for @files;
    $config;
}

=item _parseFile

 Parse Java-style properties file

 Return hashref on success, die on failure

=cut

sub _parseFile
{
    my ( $self, $file ) = @_;

    my ( $delimLength, $isMultiLines, $result, $key, $value, $valueLength ) = ( length $self->{'delimiter'}, FALSE, {} );

    open my $fh, '<', $file or die( sprintf( "Couldn't open file: %s", $! || 'Unknown error' ));

    while ( my $line = <$fh> ) {
        chomp( $line );
        next if !length $line || ( !$isMultiLines && ( index( $line, '#' ) == 0 || index( $line, '!' ) == 0 ) );

        unless ( $isMultiLines ) {
            $key = substr( $line, 0, index( $line, $self->{'delimiter'} ));
            $value = substr( $line, index( $line, $self->{'delimiter'} )+$delimLength, length( $line ));
        } else {
            $value .= $line;
        }

        $valueLength = length( $value )-1;
        if ( index( $value, '\\' ) == $valueLength ) {
            $value = substr( $value, 0, $valueLength );
            $isMultiLines = TRUE;
        } else {
            $isMultiLines = FALSE;
        }

        $key =~ s/^\s+|\s+$//g if $self->{'trimWhitespace'};
        $value =~ s/^\s+|\s+$//g if $self->{'trimWhitespace'} && !$isMultiLines;
        ( $result->{$key} = $value ) =~ s/\\([^\\])/$1/g;
    }

    close( $fh );

    $result;
}

=item _hash_replace_recursive( $hashA, $hashB )

 Replaces elements from second hash into the first hash recursively

 Return void

=cut

sub _hash_replace_recursive
{
    my ( $self, $hashA, $hashB ) = @_;

    while ( my ( $key, $value ) = each( %{ $hashB } ) ) {
        if ( exists $hashA->{$key} && ref $value eq 'HASH' && ref $hashA->{$key} ) {
            $self->_hash_replace_recursive( $hashA->{$key}, $value );
            next;
        }

        $hashA->{$key} = $value;
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
