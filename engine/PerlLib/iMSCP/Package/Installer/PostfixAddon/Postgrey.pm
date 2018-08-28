=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::Postgrey - Postgrey policy server for Postfix

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

package iMSCP::Package::Installer::PostfixAddon::Postgrey;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Debug qw/ error /;
use iMSCP::DistPackageManager;
use iMSCP::Service;
use Servers::mta;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Provides a policy server for Postfix to implement "greylisting".
 
 Greylisting is a spam filtering method that rejects email from external
 servers on the first try. Spammers don't usually retry sending their
 messages, whereas legitimate mail servers do. 

 Site: http://postgrey.schweikert.ch/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()
 
=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance->installPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    iMSCP::Servers::Mta->factory()->postconf( (
        smtpd_recipient_restrictions => {
            action => 'add',
            before => qr/permit/,
            values => [ 'check_policy_service inet:127.0.0.1:10023' ]
        }
    ));
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'postgrey' );

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'Posgrey policy daemon' ];
            0;
        },
        $self->getPriority()
    );
}

=item postuninstall( )

 See iMSCP::AbstractUninstallerActions::postuninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance->uninstallPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item restart( )

 Restart postgrey policy server
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'postgrey' );
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _getDistPackages( )

 Get list of distribution packages to install or uninstall, depending on context

 Return array List of distribution packages

=cut

sub _getDistPackages
{
    my ( $self ) = @_;

    [ 'postgrey' ];
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
