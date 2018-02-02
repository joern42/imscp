=head1 NAME

 iMSCP::Packages::FrontEnd::Uninstaller - i-MSCP FrontEnd package Uninstaller

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

package iMSCP::Packages::FrontEnd::Uninstaller;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::SystemUser;
use iMSCP::SystemGroup;
use iMSCP::Service;
use iMSCP::Packages::FrontEnd;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP FrontEnd package uninstaller.

=head1 PUBLIC METHODS

=over 4

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ($self) = @_;

    $self->_deleteSystemFiles();
    $self->_deconfigurePHP();
    $self->_deconfigureHTTPD();
    $self->_deleteMasterWebUser();
    $self->{'frontend'}->restartNginx() if iMSCP::Service->getInstance()->hasService( 'nginx' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::FrontEnd::Uninstaller

=cut

sub _init
{
    my ($self) = @_;

    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self->{'config'} = $self->{'frontend'}->{'config'};
    $self;
}

=item _deleteSystemFiles()

 Delete system files

 Return void, die on failure

=cut

sub _deleteSystemFiles
{
    iMSCP::File->new( filename => "/etc/$_/imscp_frontend" )->remove() for 'cron.daily', 'logrotate.d';
}

=item _deconfigurePHP( )

 Deconfigure PHP (imscp_panel service)

 Return void, die on failure

=cut

sub _deconfigurePHP
{
    iMSCP::Service->getInstance()->remove( 'imscp_panel' );

    for ( '/etc/default/imscp_panel', '/etc/tmpfiles.d/imscp_panel.conf', "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp_panel",
        '/usr/local/sbin/imscp_panel', '/var/log/imscp_panel.log'
    ) {
        iMSCP::File->new( filename => $_ )->remove();
    }

    iMSCP::Dir->new( dirname => '/usr/local/lib/imscp_panel' )->remove();
    iMSCP::Dir->new( dirname => '/usr/local/etc/imscp_panel' )->remove();
    iMSCP::Dir->new( dirname => '/var/run/imscp' )->remove();
}

=item _deconfigureHTTPD( )

 Deconfigure HTTPD (nginx)

 Return void, die on failure

=cut

sub _deconfigureHTTPD
{
    my ($self) = @_;

    $self->{'frontend'}->disableSites( '00_master.conf' );

    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" )->remove();
    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf" )->remove();
    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf" )->remove();

    if ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/default" ) {
        # Nginx as provided by Debian
        $self->{'frontend'}->enableSites( 'default' );
        return;
    }

    if ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled" ) {
        # Nginx package as provided by Nginx
        iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled" )->move(
            "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf"
        );
    }
}

=item _deleteMasterWebUser( )

 Delete i-MSCP master Web user

 Return int 0 on success, other on failure

=cut

sub _deleteMasterWebUser
{
    iMSCP::SystemUser->new( force => 'yes' )->delSystemUser( $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'} );
    iMSCP::SystemGroup->getInstance()->delSystemGroup( $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
