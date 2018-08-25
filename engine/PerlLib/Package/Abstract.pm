=head1 NAME

 Package::Abstract - Abstract class for i-MSCP packages

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

package Package::Abstract;

use strict;
use warnings;
use Carp qw/ confess /;
use iMSCP::Database;
use iMSCP::EventManager;
use parent qw/ Common::SingletonClass iMSCP::AbstractInstallerActions iMSCP::AbstractUninstallerActions iMSCP::AbstractModuleActions /;

=head1 DESCRIPTION

 Abstract class for i-MSCP packages.

 i-MSCP packages extend/implement core features or provide additional features
 and/or services.

 This class is meant to be subclassed by i-MSCP package classes.

=head1 CLASS METHODS

=over 4

=item getPriority( \%data )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    my ( $class ) = @_;

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See Common::SingletonClass::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or confess( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'dbh'} = iMSCP::Database->factory();
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
