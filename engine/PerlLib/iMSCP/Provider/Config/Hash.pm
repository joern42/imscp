=head1 NAME

 iMSCP::Provider::Config::Hash - Configuration provider for Perl hashes

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

package iMSCP::Provider::Config::Hash;

use strict;
use warnings;
use iMSCP::Boolean;
use Carp 'croak';
use Params::Check qw/ check last_error /;
use parent 'Common::Functor';

=head1 DESCRIPTION

 Provider that returns the configuration seeded to itself.

 Primary use case is configuration cache-related settings.
 
 It is possible to specify a namespace for the returned configuration. This is 
 useful when the provider is part of an aggregate that merge configuration of
 aggregated providers all together to product a single (cached) configuration
 file for production use.

=head1 PUBLIC METHODS

=over 4

=item new( CONFIG => { } [, NAMESPACE => none ] )
 
 Constructor
 
 Named parameters
  CONFIG    : Hash that hold configuration (required)
  NAMESPACE : Configuration namespace, none by default (optional)
 Return iMSCP::Provider::Config::Hash, croak on failure

=cut

sub new
{
    my ( $self, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $self->SUPER::new( check( {
        CONFIG    => { default => {}, required => TRUE, strict_type => TRUE },
        NAMESPACE => { default => undef, strict_type => TRUE }
    }, \%params, TRUE ) or croak( Params::Check::last_error()));
}

=back

=head1 PRIVATE METHODS

=over 4

=item __invoke( )

 Functor implementation

 Return hashref

=cut

sub __invoke
{
    my ( $self ) = @_;

    defined $self->{'NAMESPACE'} ? { $self->{'NAMESPACE'} => $self->{'CONFIG'} } : $self->{'CONFIG'};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__

# Usage example:

use iMSCP::Provider::Config::Hash;
use Data::Dumper;

my $confHash = {
    param1 => 'value',
    param2 => 'value'
};

my $provider = iMSCP::Provider::Config::iMSCP->new(
    CONFIG     => \$confHash,
    NAMESPACE  => 'master',
);

my $config = $provider->( $provider );
print Dumper( $config );
