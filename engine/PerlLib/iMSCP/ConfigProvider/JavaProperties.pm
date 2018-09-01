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

    for my $file ( @files ) {
        unless ( %{ $config } ) {
            $config = $self->_parseFile( $file );
            next;
        }

        $self->_hash_replace_recursive( $config, $self->_parseFile( $file ));
    }

    $config;
}

=item _process( $data )

 Process the given hash for @include

 Param $hashref
 Return void

=cut

=item _parseFile

 Parse Java-style properties file

 Return hashref on success, die on failure

=cut

sub _parseFile
{
    my ( $self, $file ) = @_;

    my ( $delimLength, $key, $isWaitingOtherLine, $result, $value, $valueLength ) = (
        length $self->{'delimiter'}, '', FALSE, {}, undef, undef,
    );

    open my $fh, '<', $file or die( sprintf( "Couldn't open file: %s", $! || 'Unknown error' ));

    while ( my $line = <$fh> ) {
        chomp( $line );
        next if !length $line || ( !$isWaitingOtherLine && ( index( $line, '#' ) == 0 || index( $line, '!' ) == 0 ) );

        unless ( $isWaitingOtherLine ) {
            $key = substr( $line, 0, index( $line, $self->{'delimiter'} ));
            $value = substr( $line, index( $line, $self->{'delimiter'} )+$delimLength, length( $line ));
        } else {
            $value .= $line;
        }

        $valueLength = length( $value )-1;
        if ( index( $value, '\\' ) == $valueLength ) {
            $value = substr( $value, 0, $valueLength );
            $isWaitingOtherLine = TRUE;
        } else {
            $isWaitingOtherLine = FALSE;
        }

        $key =~ s/^\s+|\s+$//g if $self->{'trimWhitespace'};
        $value =~ s/^\s+|\s+$//g if $self->{'trimWhitespace'} && !$isWaitingOtherLine;
        ( $result->{$key} = $value ) =~ s/\\([^\\])/$1/g;
    }

    close( $fh );

    $result;
}

=item _hash_replace_recursive( $hashA, $hashB )

 Replaces elements from passed hashes into the first hash recursively

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
