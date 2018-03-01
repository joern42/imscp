=head1 NAME

 iMSCP::Packages::Webmail::Roundcube::Roundcube - i-MSCP Roundcube package

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

package iMSCP::Packages::Webmail::Roundcube::Roundcube;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::Packages::Webmail::Roundcube::Installer iMSCP::Packages::Webmail::Roundcube::Uninstaller /;
use iMSCP::Config;
use iMSCP::Database;
use iMSCP::Debug qw/ error /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Roundcube package for i-MSCP.

 RoundCube Webmail is a browser-based multilingual IMAP client with an
 application-like user interface. It provides full functionality expected from
 an email client, including MIME support, address book, folder manipulation and
 message filters.

 The user interface is fully skinnable using XHTML and CSS 2.

 Project homepage: http://www.roundcube.net/

=head1 PUBLIC METHODS

=over 4

=item showDialog( \%dialog )

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
    my ( $self, $dialog ) = @_;

    iMSCP::Packages::Webmail::Roundcube::Installer->getInstance( eventManager => $self->{'eventManager'} )->showDialog( $dialog );
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure 

=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::Packages::Webmail::Roundcube::Installer->getInstance( eventManager => $self->{'eventManager'} )->preinstall();
}

=item install( )

 Process install tasks

 Return void, die on failure 

=cut

sub install
{
    my ( $self ) = @_;

    iMSCP::Packages::Webmail::Roundcube::Installer->getInstance( eventManager => $self->{'eventManager'} )->install();
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure 

=cut

sub uninstall
{
    my ( $self ) = @_;

    return if $self->{'skip_uninstall'};

    iMSCP::Packages::Webmail::Roundcube::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
}

=item setGuiPermissions( )

 Set gui permissions

 Return void, die on failure 

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    iMSCP::Packages::Webmail::Roundcube::Installer->getInstance( eventManager => $self->{'eventManager'} )->setGuiPermissions();
}

=item deleteMail( \%data )

 Process deleteMail tasks

 Param hash \%data Mail data
 Return void, die on failure 

=cut

sub deleteMail
{
    my ( undef, $data ) = @_;

    return unless $data->{'MAIL_TYPE'} =~ /_mail/;

    my $db = iMSCP::Database->getInstance();
    my $oldDbName = $db->useDatabase( $::imscpConfig{'DATABASE_NAME'} . '_roundcube' );
    $db->do( 'DELETE FROM users WHERE username = ?', undef, $data->{'MAIL_ADDR'} );
    $db->useDatabase( $oldDbName ) if $oldDbName;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Webmail::Roundcube::Roundcube

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/roundcube";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";

    if ( -f "$self->{'cfgDir'}/roundcube.data" ) {
        tie %{ $self->{'config'} }, 'iMSCP::Config', filename => "$self->{'cfgDir'}/roundcube.data", readonly => 1;
    } else {
        $self->{'config'} = {};
        $self->{'skip_uninstall'} = 1;
    }

    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
