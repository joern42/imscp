=head1 NAME

 Package::Installer::PostfixAddon::SRS - Postfix SRS daemon

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

package Package::Installer::PostfixAddon::SRS;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use iMSCP::File;
use LsbRelease;
use iMSCP::Service;
use Servers::mta;
use parent 'Package::Abstract';

=head1 DESCRIPTION

 Provides Sender Rewriting Scheme (SRS) support for Postfix via TCP-based lookup tables.

 Project homepage: https://github.com/roehling/postsrsd

=head1 CLASS METHODS

=over 4

=item getPriority( )

 See Package::Abstract::getPriority()

=cut

sub getPriority
{
    my ( $self ) = @_;

    7;
}

=item checkRequirements

 See Package::Abstract::checkRequirements()

=cut

sub checkRequirements
{
    my ( $self ) = @_;

    # The postsrsd distribution package is not available in Ubuntu Trusty Thar
    # (14.04) repositories
    lc iMSCP::LsbRelease->getInstance->getCodename( TRUE ) ne 'trusty';
}

=back

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()
 
=cut

sub preinstall
{
    my ( $self ) = @_;

    if ( iMSCP::LsbRelease->getInstance->getCodename( TRUE ) eq 'jessie' ) {
        # The postsrsd distribution package is made available through backports
        iMSCP::DistPackageManager->getInstance()
            ->addRepositories( [ { repository => "deb http://deb.debian.org/debian jessie-backports main", } ], TRUE )
            ->addAptPreferences(
            [
                {
                    pinning_package      => 'postsrsd',
                    pinning_pin          => "release o=Debian,n=jessie-backports",
                    pinning_pin_priority => '1001'
                }
            ],
            TRUE
        )
    }

    iMSCP::DistPackageManager->getInstance->installPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_setupPostsrsDaemon();
    $rs ||= Servers::mta->factory()->postconf( (
        sender_canonical_maps       => {
            action => 'add',
            values => [ 'tcp:127.0.0.1:10001' ]
        },
        sender_canonical_classes    => {
            action => 'replace',
            values => [ 'envelope_sender' ]
        },
        recipient_canonical_maps    => {
            action => 'add',
            values => [ 'tcp:127.0.0.1:10002' ]
        },
        recipient_canonical_classes => {
            action => 'add',
            values => [ 'envelope_recipient', 'header_recipient' ]
        }
    ));
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'postsrsd' );

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'Postfix SRS daemon' ];
            0;
        },
        $self->getPriority()
    );
}

=item postuninstall

 See iMSCP::AbstractUninstallerActions::postuninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance->uninstallPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item restart( )

 Restart Postfix SRS service
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'postsrsd' );
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

    [ 'postsrsd' ];
}

=item _setupPostsrsDaemon( )

 Setup postsrs daemon

 Return int 0 on success, other on failure

=cut

sub _setupPostsrsDaemon
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => '/etc/default/postsrsd' );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/^(SRS_DOMAIN\s*=)[^\n]+/$1 $::imscpConfig{'SERVER_HOSTNAME'}/m;
    $file->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
