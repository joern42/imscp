=head1 NAME

 iMSCP::ConfigProvider::Hash - Configuration provider for Perl hashes

=cut

package iMSCP::ConfigProvider::Hash;

use strict;
use warnings;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Provider that returns the hashref seeded to itself.

 Primary use case is configuration cache-related settings.

=head1 CLASS METHODS

=over 4

=item new( $hash )

 Constructor
 
 Param $hashref $hash A hash reference
 Return iMSCP::ConfigProvider::Hash

=cut

sub new
{
    my ( $self, $hash ) = @_;

    ref $hash eq 'HASH' or die( 'Invalid $hash parameter. HASH reference expected.' );

    $self->SUPER::new( config => $hash );
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref on success, die on failure

=cut

sub __invoke
{
    my ( $self ) = @_;

    $self->{'config'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
