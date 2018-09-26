=head1 NAME

 iMSCP::Dialog - Proxy to iMSCP::Dialog::DialogAbstract classes

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

package iMSCP::Dialog;

use strict;
use warnings;
use parent 'iMSCP::Common::SingletonClass';

=head1 DESCRIPTION

 Proxy to iMSCP::Dialog::DialogAbstract classes

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::SingletonClass::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'dialog'} = do {
        eval {
            local $@;
            require iMSCP::Dialog::Whiptail;
            iMSCP::Dialog::Whiptail->getInstance();
        } or do {
            require iMSCP::Dialog::Dialog;
            iMSCP::Dialog::Dialog->getInstance();
        }
    };
    
    # Allow localization of wrapper options through this object
    $self->{'_opts'} = $self->{'dialog'}->{'_opts'};
}

=item AUTOLOAD

 Proxy implementation

=cut

sub AUTOLOAD
{
    ( my $method = $iMSCP::Dialog::AUTOLOAD ) =~ s/.*:://;

    my $instance = __PACKAGE__->getInstance()->{'dialog'};
    $method = $instance->can( $method ) or die( sprintf( 'Unknown %s method', $iMSCP::Dialog::AUTOLOAD ));

    no strict 'refs';
    *{ $iMSCP::Dialog::AUTOLOAD } = sub {
        shift;
        $method->( $instance, @_ );
    };

    goto &{ $iMSCP::Dialog::AUTOLOAD };
}

=item DESTROY

 Needed due to autoloading

=cut

sub DESTROY
{

}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
