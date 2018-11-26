=head1 NAME

 iMSCP::Server::ftpd::vsftpd::uninstaller - i-MSCP VsFTPd server uninstaller

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package iMSCP::Server::ftpd::vsftpd::uninstaller;

use strict;
use warnings;
use File::Basename;
use iMSCP::Config;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Server::ftpd::vsftpd;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP VsFTPd server uninstaller.

=head1 PUBLIC METHODS

=over 4

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    # In setup context, processing must be delayed, else we won't be able to connect to SQL server
    if ( iMSCP::Getopt->context() eq 'installer' ) {
        return $self->{'eventManager'}->register( 'afterSqldPreinstall', sub {
            my $rs ||= $self->_dropSqlUser();
            $rs ||= $self->_removeConfig();
        } );
    }

    my $rs = $self->_dropSqlUser();
    $rs ||= $self->_removeConfig();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Server::ftpd::vsftpd::uninstaller

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'ftpd'} = iMSCP::Server::ftpd::vsftpd->getInstance();
    $self->{'eventManager'} = $self->{'ftpd'}->{'eventManager'};
    $self->{'cfgDir'} = $self->{'ftpd'}->{'cfgDir'};
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'config'} = $self->{'ftpd'}->{'config'};
    $self;
}

=item _dropSqlUser( )

 Drop SQL user

 Return int 0 on success die on failure

=cut

sub _dropSqlUser
{
    my ( $self ) = @_;

    # In setup context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer' ? $::imscpOldConfig{'DATABASE_USER_HOST'} : $::imscpConfig{'DATABASE_USER_HOST'};

    return 0 unless $self->{'config'}->{'DATABASE_USER'} && $dbUserHost;

    iMSCP::Server::sqld->factory()->dropUser( $self->{'config'}->{'DATABASE_USER'}, $dbUserHost );
    0;
}

=item _removeConfig( )

 Remove configuration

 Return int 0 on success, other on failure

=cut

sub _removeConfig
{
    my ( $self ) = @_;

    for ( $self->{'config'}->{'FTPD_CONF_FILE'}, $self->{'config'}->{'FTPD_PAM_CONF_FILE'} ) {
        # Setup context means switching to another FTP server. In such case, we simply delete the files
        if ( iMSCP::Getopt->context() eq 'installer' ) {
            if ( -f $self->{'config'}->{'FTPD_CONF_FILE'} ) {
                my $rs = iMSCP::File->new( filename => $self->{'config'}->{'FTPD_CONF_FILE'} )->delFile();
                return $rs if $rs;
            }

            my $filename = basename( $_ );
            if ( -f "$self->{'bkpDir'}/$filename.system" ) {
                my $rs = iMSCP::File->new( filename => "$self->{'bkpDir'}/$filename.system" )->delFile();
                return $rs if $rs;
            }

            next;
        }

        my $dirname = dirname( $self->{'config'}->{'FTPD_CONF_FILE'} );
        my $filename = basename( $_ );

        if ( -d $dirname && -f "$self->{'bkpDir'}/$filename.system" ) {
            my $rs = iMSCP::File->new( filename => "$self->{'bkpDir'}/$filename.system" )->copyFile(
                $self->{'config'}->{'FTPD_CONF_FILE'}, { preserve => 'no' }
            );
            return $rs if $rs;
        }
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'FTPD_USER_CONF_DIR'} )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
