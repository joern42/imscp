=head1 NAME

iMSCP::Packages::Webstats::Awstats::Uninstaller - i-MSCP AWStats package uninstaller

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Packages::Webstats::Awstats::Uninstaller;

use strict;
use warnings;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Servers::Cron;
use iMSCP::Servers::Httpd;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 This is the uninstaller for the i-MSCP Awstats package.

=head1 PUBLIC METHODS

=over 4

=item uninstall( )

 Process AWStats package uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ($self) = @_;

    $self->_deleteFiles();
    $self->_removeVhost();
    $self->_restoreDebianConfig();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _deleteFiles( )

 Delete files

 Return void, die on failure

=cut

sub _deleteFiles
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" )->remove();
    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'} )->remove();

    return unless -d $::imscpConfig{'AWSTATS_CONFIG_DIR'};

    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CONFIG_DIR'} )->clear( qr/^awstats.*\.conf$/ );
}

=item _removeVhost( )

 Remove global vhost file if any

 Return void, die on failure

=cut

sub _removeVhost
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    $httpd->disableSites( '01_awstats.conf' );

    iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/01_awstats.conf" )->remove();
}

=item _restoreDebianConfig( )

 Restore default configuration

 Return void, die on failure

=cut

sub _restoreDebianConfig
{
    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';

    if ( -f "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" ) {
        iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" )->move(
            "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf"
        );
    }

    iMSCP::Servers::Cron->factory()->enableSystemTask( 'awstats', 'cron.d' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
