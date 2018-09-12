=head1 NAME

 iMSCP::Package::Installer::ServicesSSL - i-MSCP services SSL

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

package iMSCP::Package::Installer::ServicesSSL;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringNotInList /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::OpenSSL;
use Net::LibIDN 'idn_to_unicode';
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP services SSL.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, sub { $self->_askForServicesSSL( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $sslEnabled = ::setupGetQuestion( 'SERVICES_SSL_ENABLED' );

    if ( $sslEnabled eq 'no' || ::setupGetQuestion( 'SERVICES_SSL_SETUP', 'yes' ) eq 'no' ) {
        if ( $sslEnabled eq 'no' && -f "$::imscpConfig{'CONF_DIR'}/imscp_services.pem" ) {
            my $rs = iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/imscp_services.pem" )->delFile();
            return $rs if $rs;
        }

        return 0;
    }

    if ( ::setupGetQuestion( 'SERVICES_SSL_SELFSIGNED_CERTIFICATE' ) eq 'yes' ) {
        return iMSCP::OpenSSL->new(
            certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
            certificate_chain_name         => 'imscp_services'
        )->createSelfSignedCertificate( {
            common_name => ::setupGetQuestion( 'SERVER_HOSTNAME' ),
            email       => ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' )
        } );
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

=back

=head1 PRIVATE METHODS

=over 4

=item _askForServicesSSL( $dialog )

 Ask for FTP, IMAP/POP and SMTP services SSL

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForServicesSSL
{
    my ( $self, $dialog ) = @_;

    my $hostnameUnicode = idn_to_unicode( ::setupGetQuestion( 'SERVER_HOSTNAME' ), 'utf-8' );
    my $sslEnabled = ::setupGetQuestion( 'SERVICES_SSL_ENABLED' );
    my $selfSignedCertificate = ::setupGetQuestion( 'SERVICES_SSL_SELFSIGNED_CERTIFICATE', 'no' );
    my $privateKeyPath = ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PATH', '/root' );
    my $passphrase = ::setupGetQuestion( 'SERVICES_SSL_PRIVATE_KEY_PASSPHRASE' );
    my $certificatePath = ::setupGetQuestion( 'SERVICES_SSL_CERTIFICATE_PATH', '/root' );
    my $caBundlePath = ::setupGetQuestion( 'SERVICES_SSL_CA_BUNDLE_PATH', '/root' );
    my $openSSL = iMSCP::OpenSSL->new();

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'services_ssl', 'ssl', 'all' ] )
        || isStringNotInList( $sslEnabled, 'yes', 'no' )
        || ( $sslEnabled eq 'yes' && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'server_hostname', 'hostnames' ] ) )
    ) {
        Q1:
        my $rs = $dialog->yesno( <<'EOF', $sslEnabled eq 'no', TRUE );

Do you want to enable SSL for the FTP, IMAP/POP and SMTP services?
EOF
        return $rs unless $rs < 30;

        if ( $rs ) {
            ::setupSetQuestion( 'SERVICES_SSL_ENABLED', 'no' );
            return 0;
        }

        $sslEnabled = 'yes';
        my $msg = '';

        Q2:
        $rs = $dialog->yesno( <<"EOF", $selfSignedCertificate eq 'no', TRUE );

Do you have an SSL certificate for the $hostnameUnicode domain?
EOF
        goto Q1 if $rs == 30;
        return $rs if $rs == 50;

        unless ( $rs ) {
            Q3:
            do {
                ( $rs, $privateKeyPath ) = $dialog->inputbox( <<"EOF", $privateKeyPath );
$msg
Please enter the path to your private key:
EOF
                goto Q2 if $rs == 30;
                return $rs if $rs == 50;

                $msg = length $privateKeyPath && -f $privateKeyPath ? '' : <<'EOF';

\Z1Invalid private key path.\Zn

EOF
            } while length $msg;

            Q4:
            ( $rs, $passphrase ) = $dialog->passwordbox( <<'EOF', $passphrase );

Please enter the passphrase for your private key if any:
EOF
            goto Q3 if $rs == 30;
            return $rs if $rs == 50;

            $openSSL->{'private_key_container_path'} = $privateKeyPath;
            $openSSL->{'private_key_passphrase'} = $passphrase;

            if ( $openSSL->validatePrivateKey() ) {
                debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                $msg = <<'EOF';

\Z1Invalid private key or passphrase.\Zn

EOF
                goto Q3;
            }

            Q5:
            $rs = $dialog->yesno( <<'EOF', FALSE, TRUE );

Do you have a CA bundle (root and intermediate certificates)?
EOF
            goto Q4 if $rs == 30;
            return $rs if $rs == 50;

            if ( $rs ) {
                $openSSL->{'ca_bundle_container_path'} = '';
                goto Q7
            }

            Q6:
            do {
                ( $rs, $caBundlePath ) = $dialog->inputbox( <<"EOF", $caBundlePath );
$msg
Please enter the path to your CA bundle:
EOF
                goto Q5 if $rs == 30;
                return $rs if $rs == 50;

                $msg = length $caBundlePath && -f $caBundlePath ? '' : <<'EOF'

\Z1Invalid CA bundle path.\Zn
EOF
            } while length $msg;

            $openSSL->{'ca_bundle_container_path'} = '';

            Q7:
            do {
                ( $rs, $certificatePath ) = $dialog->inputbox( <<"EOF", $certificatePath );
$msg
Please enter the path to your SSL certificate:
EOF
                $msg = length $certificatePath && -f $certificatePath ? '' : <<'EOF';

\Z1Invalid SSL certificate path.\Zn
EOF
                goto Q6 if $rs == 30;
                return $rs if $rs == 50;
            } while length $msg;

            $openSSL->{'certificate_container_path'} = $certificatePath;

            if ( $openSSL->validateCertificate() ) {
                debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                $msg = "\n\\Z1Invalid SSL certificate.\\Zn\n\nPlease try again.";
                goto Q3;
            }
        } else {
            $selfSignedCertificate = 'yes';
        }
    } elsif ( $sslEnabled eq 'yes' && !iMSCP::Getopt->preseed ) {
        $openSSL->{'private_key_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";
        $openSSL->{'ca_bundle_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";
        $openSSL->{'certificate_container_path'} = "$::imscpConfig{'CONF_DIR'}/imscp_services.pem";

        if ( $openSSL->validateCertificateChain() ) {
            debug( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
            my $rs = $dialog->msgbox( <<'EOF' );

Your SSL certificate for the FTP, IMAP/POP and SMTP servers is missing or invalid.
EOF
            return $rs if $rs == 50;
            iMSCP::Getopt->reconfigure( 'services_ssl', FALSE, TRUE );
            goto &{ askSsl };
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

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
