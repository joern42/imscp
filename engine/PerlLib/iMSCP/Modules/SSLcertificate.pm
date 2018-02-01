=head1 NAME

 iMSCP::Modules::SSLcertificate - Module for processing of SSL certificate entities

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

package iMSCP::Modules::SSLcertificate;

use strict;
use warnings;
use File::Temp;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::OpenSSL;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of SSL certificate entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'SSLcertificate';
}

=item add()

 Add or change the SSL certificate

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval {
        # Remove previous SSL certificate if any
        $self->SUPER::delete();
        iMSCP::File->new( filename => "$self->{'certsDir'}/$self->{'domain_name'}.pem" )->remove();

        my $privateKeyContainer = File::Temp->new();
        print $privateKeyContainer $self->{'private_key'};
        $privateKeyContainer->close();

        my $certificateContainer = File::Temp->new();
        print $certificateContainer $self->{'certificate'};
        $certificateContainer->close();

        my $caBundleContainer;
        if ( $self->{'ca_bundle'} ) {
            $caBundleContainer = File::Temp->new();
            print $caBundleContainer $self->{'ca_bundle'};
            $caBundleContainer->close();
        }

        my $openSSL = iMSCP::OpenSSL->new(
            certificate_chains_storage_dir => $self->{'certsDir'},
            certificate_chain_name         => $self->{'domain_name'},
            private_key_container_path     => $privateKeyContainer->filename,
            certificate_container_path     => $certificateContainer->filename,
            ca_bundle_container_path       => $caBundleContainer ? $caBundleContainer->filename : ''
        );

        $openSSL->validateCertificateChain();
        $openSSL->createCertificateChain();
        $self->SUPER::add();
    };

    $self->{'_dbh'}->do(
        'UPDATE ssl_certs SET status = ? WHERE cert_id = ?', undef, $@ ? $@ =~ s/iMSCP::OpenSSL::validateCertificate:\s+//r : 'ok', $self->{'cert_id'}
    );
    $self;
}

=item delete()

 Delete the SSL certificate

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval {
        $self->SUPER::delete();
        iMSCP::File->new( filename => "$self->{'certsDir'}/$self->{'domain_name'}.pem" )->remove();
    };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE ssl_certs SET status = ? WHERE cert_id = ?', undef, $@, $self->{'cert_id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM ssl_certs WHERE cert_id = ?', undef, $self->{'cert_id'} );
    $self;
}

=item handleEntity( $certificateId )

 Handle the given SSL certificate entity

 Param int $certificateId SSL certificate unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $certificateId) = @_;

    $self->_loadData( $certificateId );

    # Handle case of orphaned SSL certificate which has been removed
    return $self unless $self->{'domain_name'};

    if ( $self->{'status'} =~ /^to(?:add|change)$/ ) {
        $self->add();
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $self->delete();
    } else {
        die( sprintf( 'Unknown action (%s) for SSL certificate (ID %d)', $self->{'status'}, $certificateId ));
    }

    # (since 1.2.16 - See #IP-1500)
    # On toadd and to change actions, return 0 to avoid any failure on update when a customer's SSL certificate is
    # expired or invalid. It is the customer responsability to update the certificate throught his interface
    #( $self->{'status'} =~ /^to(?:add|change)$/ ) ? 0 : $rs;
    $self;
}

=back

=head1 PRIVATES METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Modules::SSLcertificate, die on failure

=cut

sub _init
{
    my ($self) = @_;

    $self->{'certsDir'} = "$main::imscpConfig{'GUI_ROOT_DIR'}/data/certs";

    #iMSCP::Dir->new( dirname => $self->{'certsDir'} )->make( {
    #    user  => $main::imscpConfig{'ROOT_USER'},
    #    group => $main::imscpConfig{'ROOT_GROUP'},
    #    mode  => 0750
    #} );

    $self->SUPER::_init();
}

=item _loadData( $certificateId )

 Load data

 Param int $certificateId SSL certificate unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $certificateId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref( 'SELECT * FROM ssl_certs WHERE cert_id = ?', undef, $certificateId );
    $row or die( sprintf( 'Data not found for SSL certificate (ID %d)', $certificateId ));
    %{$self} = ( %{$self}, %{$row} );

    if ( $self->{'domain_type'} eq 'dmn' ) {
        $row = $self->{'_dbh'}->selectrow_hashref( 'SELECT domain_name FROM domain WHERE domain_id = ?', undef, $self->{'domain_id'} );
    } elsif ( $self->{'domain_type'} eq 'als' ) {
        $row = $self->{'_dbh'}->selectrow_hashref(
            'SELECT alias_name AS domain_name FROM domain_aliasses WHERE alias_id = ?', undef, $self->{'domain_id'}
        );
    } elsif ( $self->{'domain_type'} eq 'sub' ) {
        $row = $self->{'_dbh'}->selectrow_hashref(
            "SELECT CONCAT(subdomain_name, '.', domain_name) AS domain_name FROM subdomain JOIN domain USING(domain_id) WHERE subdomain_id = ?",
            undef, $self->{'domain_id'}
        );
    } else {
        $row = $self->{'_dbh'}->selectrow_hashref(
            "
                SELECT CONCAT(subdomain_alias_name, '.', alias_name) AS domain_name
                FROM subdomain_alias
                JOIN domain_aliasses USING(alias_id)
                WHERE subdomain_alias_id = ?
            ",
            undef, $self->{'domain_id'}
        );
    }

    unless ( $row ) {
        # Delete orphaned SSL certificate
        $self->{'_dbh'}->do( 'DELETE FROM FROM ssl_certs WHERE cert_id = ?', undef, $certificateId );
        return;
    }

    %{$self} = ( %{$self}, %{$row} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
