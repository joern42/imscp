=head1 NAME

 iMSCP::Common::Functor - Functor object base class

=cut

package iMSCP::Common::Functor;

use strict;
use warnings;
use iMSCP::Boolean;
use parent iMSCP::Common::Object;
use overload
    '&{}'    => sub { $_[0]->can( '__invoke' ) or die( sprintf( 'The %s class must implement the __invoke() method', ref $_[0] )); },
    fallback => TRUE;

=head1 DESCRIPTION

 Functor object base class.

=cut

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
