=head1 NAME

 iMSCP::Installer::DistAdapter::Abstract - Abstract class for distribution installer adapters.

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
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

package iMSCP::Installer::DistAdapter::Abstract;

use warnings;
use strict;
use Carp 'croak';
use iMSCP::Boolean;
use Params::Check qw/ check last_error /;
use parent 'Common::Object';

=head1 DESCRIPTION

 Abstract class for distribution installer adapters.

=head1 PUBLIC METHODS

=over 4

=item new( INSTALLER => iMSCP::Installer )

 Constructor

 Named parameters
  config       : i-MSCP master configuration
  old_config   : i-MSCP old master configuration
  eventManager : iMSCP::EventManager instance
 Return iMSCP::Installer::DistAdapter::Abstract

=cut

sub new
{
    my ( $class, %params ) = @_;

    local $Params::Check::PRESERVE_CASE = TRUE;
    local $Params::Check::SANITY_CHECK_TEMPLATE = FALSE;

    $class->SUPER::new(
        check(
            {
                config       => { default => {}, required => TRUE, strict_type => TRUE },
                old_config   => { default => {}, required => TRUE, strict_type => TRUE },
                eventManager => { required => TRUE, allow => sub { ref $_[0] eq 'iMSCP::EventManager'; } }
            },
            \%params
        ) or croak( Params::Check::last_error(), $class )
    );
}

=cut

=item install( )

 Process preinstallation tasks

 Return void, croak on failure

=cut

sub install
{
    my ( $self ) = @_;
}

=back

=head1 Author

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
