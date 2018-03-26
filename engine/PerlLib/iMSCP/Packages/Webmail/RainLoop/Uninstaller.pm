=head1 NAME

 iMSCP::Packages::Webmail::RainLoop::Uninstaller - i-MSCP RainLoop package uninstaller

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

package iMSCP::Packages::Webmail::RainLoop::Uninstaller;

use strict;
use warnings;
use iMSCP::Database;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Packages::FrontEnd;
use iMSCP::Packages::Webmail::RainLoop::RainLoop;
use iMSCP::Servers::Sqld;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP RainLoop package uninstaller.

=head1 PUBLIC METHODS

=over 4

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure 

=cut

sub uninstall
{
    my ( $self ) = @_;

    return unless %{ $self->{'config'} };

    $self->_removeSqlUser();
    $self->_removeSqlDatabase();
    $self->_unregisterConfig();
    $self->_removeFiles();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Webmail::RainLoop::Uninstaller

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'rainloop'} = iMSCP::Packages::Webmail::RainLoop::RainLoop->getInstance();
    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self->{'db'} = iMSCP::Database->getInstance();
    $self->{'config'} = $self->{'rainloop'}->{'config'};
    $self;
}

=item _removeSqlUser( )

 Remove SQL user

 Return void, die on failure 

=cut

sub _removeSqlUser
{
    my ( $self ) = @_;

    my $sqlServer = iMSCP::Servers::Sqld->factory();
    return unless $self->{'config'}->{'DATABASE_USER'};

    for my $user ( $::imscpConfig{'DATABASE_USER_HOST'}, $::imscpConfig{'BASE_SERVER_IP'}, 'localhost', '127.0.0.1', '%' ) {
        next unless length $user;
        $sqlServer->dropUser( $self->{'config'}->{'DATABASE_USER'}, $user );
    }
}

=item _removeSqlDatabase( )

 Remove database

 Return void, die on failure 

=cut

sub _removeSqlDatabase
{
    my ( $self ) = @_;

    $self->{'db'}->do( 'DROP DATABASE IF EXISTS ' . $self->{'db'}->quote_identifier( $::imscpConfig{'DATABASE_NAME'} . '_rainloop' ));
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return void, die on failure 

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/[\t ]*include imscp_rainloop.conf;\n//;
    $file->save();

    $self->{'frontend'}->{'reload'} ||= 1;
}

=item _removeFiles( )

 Remove files

 Return void, die on failure 

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_rainloop.conf" )->remove();
    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop" )->remove();
    iMSCP::Dir->new( dirname => $self->{'rainloop'}->{'cfgDir'} )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
