=head1 NAME

 iMSCP::Packages::Setup::ServicesSSL - Setup SSL certificates for various services (FTP, SMTP, IMAP/POP)

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

package iMSCP::Packages::Setup::ServicesSSL;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList /;
use iMSCP::Boolean;
use iMSCP::Debug qw/ getMessageByType /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::OpenSSL;
use Net::LibIDN qw/ idn_to_unicode /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Setup SSL certificates for various services (FTP, SMTP, IMAP/POP)

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 Register setup event listeners

 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->servicesSslDialog( @_ ) }; } );
}

=item serviceSslDialog( \%dialog )

 Ask for services SSL

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub servicesSslDialog
{
    my ( undef, $dialog ) = @_;

    my $hostname = ::setupGetQuestion( 'SERVER_HOSTNAME' );
    my $hostnameUnicode = idn_to_unicode( $hostname, 'utf-8' ) // '';
    my $sslEnabled = ::setupGetQuestion( 'SERVICES_SSL_ENABLED', iMSCP::Getopt->preseed ? 'yes' : '' );
    my $selfSignedCertificate = ::setupGetQuestion( 'SERVICES_SSL_SELFSIGNED_CERTIFICATE', iMSCP::Getopt->preseed ? 'yes' : 'no' );
    my $privateKeyPath = ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PATH', '/root' );
    my $passphrase = ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PASSPHRASE' );
    my $certificatePath = ::setupGetQuestion( 'SERVICES_SSL_CERTIFICATE_PATH', '/root' );
    my $caBundlePath = ::setupGetQuestion( 'SERVICES_SSL_CA_BUNDLE_PATH', '/root' );
    my $openSSL = iMSCP::OpenSSL->new();

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'servers_ssl', 'ssl', 'all', 'forced' ] )
        || $sslEnabled !~ /^(?:yes|no)$/
        || ( $sslEnabled eq 'yes' && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'system_hostname', 'hostnames' ] ) )
    ) {
        my $rs = $dialog->yesno( <<'EOF', $sslEnabled eq 'no', TRUE );
Do you want to enable SSL for FTP, IMAP/POP and SMTP services?
EOF
        return $rs unless $rs < 30;

        if ( $rs == 0 ) {
            $sslEnabled = 'yes';

            $rs = $dialog->yesno( <<"EOF", $selfSignedCertificate eq 'no', TRUE );
Do you have a SSL certificate for the $hostnameUnicode domain?
EOF
            return $rs unless $rs < 30;

            if ( $rs == 0 ) {
                my $msg = '';

                do {
                    $rs = $dialog->msgbox( <<"EOF" );
$msg
Please select your private key in next dialog.
EOF
                    return $rs unless $rs < 30;

                    do {
                        ( $rs, $privateKeyPath ) = $dialog->fselect( $privateKeyPath );
                    } while $rs < 30 && !( length $privateKeyPath && -f $privateKeyPath );

                    return $rs unless $rs < 30;

                    ( $rs, $passphrase ) = $dialog->passwordbox( <<"EOF", $passphrase );
Please enter the passphrase for your private key if any:
\\Z \\Zn
EOF
                    return $rs unless $rs < 30;

                    $openSSL->{'private_key_container_path'} = $privateKeyPath;
                    $openSSL->{'private_key_passphrase'} = $passphrase;

                    $msg = '';
                    unless ( eval { $openSSL->validatePrivateKey(); } ) {
                        getMessageByType( 'error', { amount => 1, remove => TRUE } );
                        $msg = <<"EOF";
\n\\Z1Invalid private key or passphrase.\\Zn
EOF
                    }
                } while $rs < 30 && length $msg;

                return $rs unless $rs < 30;

                $rs = $dialog->yesno( <<'EOF' );
Do you have a SSL CA Bundle?
EOF
                return $rs unless $rs < 30;

                if ( $rs == 0 ) {
                    do {
                        ( $rs, $caBundlePath ) = $dialog->fselect( $caBundlePath );
                    } while $rs < 30 && !( length $caBundlePath && -f $caBundlePath );

                    return $rs unless $rs < 30;

                    $openSSL->{'ca_bundle_container_path'} = $caBundlePath;
                } else {
                    $openSSL->{'ca_bundle_container_path'} = '';
                }

                $rs = $dialog->msgbox( <<'EOF' );
Please select your SSL certificate in next dialog.
EOF
                return $rs unless $rs < 30;

                $rs = TRUE;

                do {
                    $rs = $dialog->msgbox( <<"EOF" ) unless $rs;
\\Z1Invalid SSL certificate.\\Zn
EOF
                    return $rs unless $rs < 30;

                    do {
                        ( $rs, $certificatePath ) = $dialog->fselect( $certificatePath );
                    } while $rs < 30 && !( length $certificatePath && -f $certificatePath );

                    return $rs unless $rs < 30;

                    getMessageByType( 'error', { amount => 1, remove => TRUE } );
                    $openSSL->{'certificate_container_path'} = $certificatePath;
                } while $rs < 30 && !eval { $openSSL->validateCertificate(); };

                return $rs unless $rs < 30;
            } else {
                $selfSignedCertificate = 'yes';
            }
        } else {
            $sslEnabled = 'no';
        }
    } elsif ( $sslEnabled eq 'yes' && !iMSCP::Getopt->preseed ) {
        $openSSL->{'private_key_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";
        $openSSL->{'ca_bundle_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";
        $openSSL->{'certificate_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";

        unless ( eval { $openSSL->validateCertificateChain(); } ) {
            getMessageByType( 'error', { amount => 1, remove => TRUE } );
            $dialog->getInstance()->msgbox( <<'EOF' );
Your SSL certificate for the FTP and MAIL services is missing or invalid.
EOF
            ::setupSetQuestion( 'SERVICES_SSL_ENABLED', '' );
            goto &{ servicesSslDialog };
        }

        # In case the certificate is valid, we skip SSL setup process
        ::setupSetQuestion( 'SERVICES_SSL_SETUP', 'no' );
    }

    ::setupSetQuestion( 'SERVICES_SSL_ENABLED', $sslEnabled );
    ::setupSetQuestion( 'SERVICES_SSL_SELFSIGNED_CERTIFICATE', $selfSignedCertificate );
    ::setupSetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PATH', $privateKeyPath );
    ::setupSetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PASSPHRASE', $passphrase );
    ::setupSetQuestion( 'SERVICES_SSL_CERTIFICATE_PATH', $certificatePath );
    ::setupSetQuestion( 'SERVICES_SSL_CA_BUNDLE_PATH', $caBundlePath );
    0;
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my $sslEnabled = ::setupGetQuestion( 'SERVICES_SSL_ENABLED' );

    if ( $sslEnabled eq 'no' || ::setupGetQuestion( 'SERVICES_SSL_SETUP', 'yes' ) eq 'no' ) {
        iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscp_services.pem" )->remove() if $sslEnabled eq 'no';
        return;
    }

    if ( ::setupGetQuestion( 'SERVICES_SSL_SELFSIGNED_CERTIFICATE' ) eq 'yes' ) {
        iMSCP::OpenSSL->new(
            certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
            certificate_chain_name         => 'imscp_services'
        )->createSelfSignedCertificate(
            {
                common_name => ::setupGetQuestion( 'SERVER_HOSTNAME' ),
                email       => ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' )
            }
        );
        return;
    }

    iMSCP::OpenSSL->new(
        certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
        certificate_chain_name         => 'imscp_services',
        private_key_container_path     => ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PATH' ),
        private_key_passphrase         => ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PASSPHRASE' ),
        certificate_container_path     => ::setupGetQuestion( 'SERVICES_SSL_CERTIFICATE_PATH' ),
        ca_bundle_container_path       => ::setupGetQuestion( 'SERVICES_SSL_CA_BUNDLE_PATH' )
    )->createCertificateChain();
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    150;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
