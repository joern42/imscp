=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::PolicyWeight - Policy-Weight daemon for the Postfix MTA

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

package iMSCP::Package::Installer::PostfixAddon::PolicyWeight;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Debug qw/ error /;
use iMSCP::DistPackageManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::Service;
use Servers::mta;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Provides policy-weight deaemon for the Postfix MTA.

 policyd-weight is intended to eliminate forged envelope senders and HELOs
 (i.e. in bogus mails). It allows you to score DNSBLs (RBL/RHSBL), HELO, MAIL
 FROM and client IP addresses before any queuing is done. It allows you to
 REJECT messages which have a score higher than allowed, providing improved
 blocking of spam and virus mails. policyd-weight caches the most frequent
 client/sender combinations (SPAM as well as HAM) to reduce the number of DNS
 queries.

 Site: http://www.policyd-weight.org/

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

    my $rs = $self->_setupPolicyWeightDaemon();
    $rs ||= iMSCP::Servers::Mta->factory()->postconf( (
        smtpd_recipient_restrictions => {
            action => 'add',
            before => qr/permit/,
            values => [ 'check_policy_service inet:127.0.0.1:12525' ]
        }
    ));
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'policyd-weight' );

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'Policy Weight daemon' ];
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

 Restart the policy-weight daemon
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'policyd-weight' );
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

    [ 'policyd-weight' ];
}

=item _setupPolicyWeightDaemon( )

 Setup policy-weight daemon

 Return int 0 on success, other on failure

=cut

sub _setupPolicyWeightDaemon
{
    my ( $self ) = @_;

    return 0 if -f '/etc/policyd-weight.conf';

    my $rs = execute( 'policyd-weight defaults > /etc/policyd-weight.conf', \my $stdout, \my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
