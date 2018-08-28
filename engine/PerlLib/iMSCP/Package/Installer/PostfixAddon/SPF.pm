=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::SPF - Simple Postfix policy server for RFC 4408 SPF checking

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

package iMSCP::Package::Installer::PostfixAddon::SPF;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use iMSCP::File;
use Servers::mta;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Simple Postfix policy server for RFC 4408 SPF checking
 
 postfix-policyd-spf-perl is a basic Postfix SMTP policy server for SPF
 checking.  It is implemented in pure Perl and uses the Mail::SPF module.
 The SPF project web site is http://www.openspf.net/.

 Site: https://launchpad.net/postfix-policyd-spf-perl/

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

    my $postfix = iMSCP::Servers::Mta->factory();
    my $file = iMSCP::File->new( filename => $postfix->{'config'}->{'POSTFIX_MASTER_CONF_FILE'} );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } .= <<"EOF";

# @{ [ __PACKAGE__ ] } begin
policy-spf  unix  -       n       n       -       -       spawn
  user=nobody argv=/usr/sbin/postfix-policyd-spf-perl
# @{ [ __PACKAGE__ ] } ending

EOF
    my $rs = $file->save();
    $rs ||= $postfix->postconf( (
        'policy-spf_time_limit'      => {
            action => 'replace',
            values => [ '3600s' ]
        },
        smtpd_recipient_restrictions => {
            action => 'add',
            before => qr/permit/,
            values => [ 'check_policy_service unix:private/policy-spf' ]
        }
    ));
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

    [ 'postfix-policyd-spf-perl' ];
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
