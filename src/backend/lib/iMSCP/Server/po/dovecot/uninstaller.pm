=head1 NAME

 iMSCP::Server::po::dovecot::uninstaller - i-MSCP Dovecot server uninstaller

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

package iMSCP::Server::po::dovecot::uninstaller;

use strict;
use warnings;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Server::mta;
use iMSCP::Server::po::dovecot;
use iMSCP::Server::sqld;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP Dovecot server uninstaller.

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

 Return iMSCP::Server::po::dovecot::uninstaller

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'po'} = iMSCP::Server::po::dovecot->getInstance();
    $self->{'eventManager'} = $self->{'po'}->{'eventManager'};
    $self->{'mta'} = iMSCP::Server::mta->factory();
    $self->{'cfgDir'} = $self->{'po'}->{'cfgDir'};
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'config'} = $self->{'po'}->{'config'};
    $self;
}

=item _dropSqlUser( )

 Drop SQL user

 Return int 0 on success, die on failure

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

    return 0 unless -d $self->{'config'}->{'DOVECOT_CONF_DIR'};

    for my $file ( 'dovecot.conf', 'dovecot-sql.conf' ) {
        next unless -f "$self->{'bkpDir'}/$file.system";

        my $rs = iMSCP::File->new( filename => "$self->{'bkpDir'}/$file.system" )->copyFile(
            "$self->{'config'}->{'DOVECOT_CONF_DIR'}/$file", { preserve => 'no' }
        );
        return $rs if $rs;
    }

    if ( -f "$self->{'config'}->{'DOVECOT_CONF_DIR'}/dovecot-sql.conf" ) {
        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'DOVECOT_CONF_DIR'}/dovecot-sql.conf" );
        my $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} );
        $rs ||= $file->mode( 0644 );
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
