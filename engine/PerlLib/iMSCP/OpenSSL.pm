=head1 NAME

iMSCP::OpenSSL - i-MSCP OpenSSL library

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

package iMSCP::OpenSSL;

use strict;
use warnings;
use Carp qw/ croak /;
use File::Temp;
use Date::Parse;
use iMSCP::Debug qw/ error debug /;
use iMSCP::Execute qw/ execute escapeShell /;
use iMSCP::File;
use iMSCP::TemplateParser;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Library allowing to check and import SSL certificates in single container (PEM).

=head1 PUBLIC METHODS

=over 4

=item validatePrivateKey( )

 Validate private key

 Return self, die on failure

=cut

sub validatePrivateKey
{
    my ( $self ) = @_;

    $self->{'private_key_container_path'} or croak( 'Path to SSL private key is not set' );
    -f $self->{'private_key_container_path'} or croak( sprintf( "%s SSL private key doesn't exist", $self->{'private_key_container_path'} ));

    my $passphraseFile;
    if ( $self->{'private_key_passphrase'} ) {
        # Write SSL private key passphrase into temporary file, which is only readable by root
        $passphraseFile = File::Temp->new();
        print $passphraseFile $self->{'private_key_passphrase'};
        $passphraseFile->close();
    }

    my $cmd = [
        'openssl', 'pkey', '-in', $self->{'private_key_container_path'}, '-noout',
        ( ( $passphraseFile ) ? ( '-passin', 'file:' . $passphraseFile->filename ) : () )
    ];
    my $rs = execute( $cmd, \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die(
        sprintf(
            "Couldn't import SSL private key from %s file: %s",
            $self->{'private_key_container_path'},
            $stderr || 'unknown error'
        )
    );
    $self;
}

=item validateCertificate( )

 Validate certificate

 If a CA Bundle (intermediate certificate(s)) is set, the whole certificate chain will be checked

 Return self, die on failure

=cut

sub validateCertificate
{
    my ( $self ) = @_;

    $self->{'certificate_container_path'} or croak( 'Path to SSL certificate is not set' );
    -f $self->{'certificate_container_path'} or croak( sprintf( "%s SSL certificate doesn't exist", $self->{'certificate_container_path'} ));

    my $caBundle = 0;
    if ( $self->{'ca_bundle_container_path'} ) {
        -f $self->{'ca_bundle_container_path'} or croak( sprintf( "%s SSL CA Bundle doesn't exist", $self->{'ca_bundle_container_path'} ));
        $caBundle = 1;
    } else {
        # We asssume a self-signed SSL certificate.
        # We need trust the self-signed SSL certificate for validation time, else
        # the 18 at 0 depth lookup: self signed certificate' error is raised (openssl >= 1.1.0)
        $self->{'ca_bundle_container_path'} = $self->{'certificate_container_path'};
    }

    my $cmd = [
        'openssl', 'verify',
        ( ( length $self->{'ca_bundle_container_path'} ) ? ( '-CAfile', $self->{'ca_bundle_container_path'} ) : () ),
        '-purpose', 'sslserver', $self->{'certificate_container_path'}
    ];
    my $rs = execute( $cmd, \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf(
        "SSL certificate is not valid: %s", ( $stderr || $stdout || 'Unknown error' ) =~ s/$self->{'certificate_container_path'}:\s+//r
    ));
    $self->{'ca_bundle_container_path'} = '' unless $caBundle;
    $self;
}

=item validateCertificateChain( )

 Validate certificate chain

 Return self, die on failure

=cut

sub validateCertificateChain
{
    my ( $self ) = @_;

    $self->validatePrivateKey()->validateCertificate();
}

=item importPrivateKey( )

 Import private key in certificate chain container

 Return self, die on failure

=cut

sub importPrivateKey
{
    my ( $self ) = @_;

    my $passphraseFile;
    if ( $self->{'private_key_passphrase'} ) {
        # Write SSL private key passphrase into temporary file, which is only readable by root
        $passphraseFile = File::Temp->new();
        print $passphraseFile $self->{'private_key_passphrase'};
        $passphraseFile->close();
    }

    my $cmd = [
        'openssl', 'pkey', '-in', $self->{'private_key_container_path'},
        '-out', "$self->{'certificate_chains_storage_dir'}/$self->{'certificate_chain_name'}.pem",
        ( ( $passphraseFile ) ? ( '-passin', 'file:' . $passphraseFile->filename ) : () )
    ];
    my $rs = execute( $cmd, \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf( "Couldn't import SSL private key: %s", $stderr || 'unknown error' ));
    $self;
}

=item importCertificate( )

 Import certificate in certificate chain container

 Return self, die on failure

=cut

sub importCertificate
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => $self->{'certificate_container_path'} );
    my $certificateRef = $file->getAsRef();
    ${ $certificateRef } =~ s/^(?:\015?\012)+|(?:\015?\012)+$//g;
    ${ $certificateRef } .= "\n";
    $file->save();

    my @cmd = (
        '/bin/cat', escapeShell( $self->{'certificate_container_path'} ),
        '>>', escapeShell( "$self->{'certificate_chains_storage_dir'}/$self->{'certificate_chain_name'}.pem" )
    );
    my $rs = execute( "@cmd", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf( "Couldn't import SSL certificate: %s", $stderr || 'unknown error' ));
    $self;
}

=item importCaBundle( )

 Import the CA Bundle in certificate chain container if any

 Return self, die on failure

=cut

sub importCaBundle
{
    my ( $self ) = @_;

    return $self unless $self->{'ca_bundle_container_path'};

    my $file = iMSCP::File->new( filename => $self->{'ca_bundle_container_path'} );
    my $caBundleRef = $file->getAsRef();
    ${ $caBundleRef } =~ s/^(?:\015?\012)+|(?:\015?\012)+$//g;
    ${ $caBundleRef } .= "\n";
    $file->save();

    my @cmd = (
        '/bin/cat', escapeShell( $self->{'ca_bundle_container_path'} ),
        '>>', escapeShell( "$self->{'certificate_chains_storage_dir'}/$self->{'certificate_chain_name'}.pem" )
    );
    my $rs = execute( "@cmd", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf( "Couldn't import SSL CA Bundle: %s", $stderr || 'unknown error' ));
    $self;
}

=item createSelfSignedCertificate( \%data )

 Generate a self-signed SSL certificate

 Param hash \%data Certificate data (common_name, email, wildcard = false)
 Param bool $wildcardSSL OPTIONAL Does a wildcard SSL certificate must be generated (default FALSE)
 Return self, die on failure

=cut

sub createSelfSignedCertificate
{
    my ( $self, $data ) = @_;

    ref $data eq 'HASH' or croak( 'Wrong $data parameter. Hash expected' );
    $data->{'common_name'} or croak( 'Missing common_name parameter' );
    $data->{'email'} or croak( 'Missing email parameter' );

    my $openSSLConffileTpl = "$::imscpConfig{'CONF_DIR'}/openssl/openssl.cnf.tpl";
    my $commonName = $data->{'wildcard'} ? '*.' . $data->{'common_name'} : $data->{'common_name'};

    # Load openssl configuration template file for self-signed SSL certificates
    my $openSSLConffileTplContent = iMSCP::File->new( filename => $openSSLConffileTpl )->get();

    # Write openssl configuration file into temporary file
    my $openSSLConffile = File::Temp->new();
    print $openSSLConffile process(
        {
            COMMON_NAME   => $commonName,
            EMAIL_ADDRESS => $data->{'email'},
            ALT_NAMES     => ( $data->{'wildcard'} ? "DNS.1 = $commonName\n" : "DNS.1 = $commonName\nDNS.2 = www.$commonName\n" )
        },
        $openSSLConffileTplContent
    );
    $openSSLConffile->close();

    my $cmd = [
        'openssl', 'req', '-x509', '-nodes', '-days', '365', '-config', $openSSLConffile->filename, '-newkey', 'rsa',
        '-keyout', "$self->{'certificate_chains_storage_dir'}/$self->{'certificate_chain_name'}.pem",
        '-out', "$self->{'certificate_chains_storage_dir'}/$self->{'certificate_chain_name'}.pem"
    ];
    my $rs = execute( $cmd, \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( sprintf( "Couldn't generate self-signed certificate: %s", $stderr || 'unknown error' ));
    $self;
}

=item createCertificateChain( )

 Create certificate chain (import private key, certificate and CA Bundle)

 Return self, die on failure

=cut

sub createCertificateChain
{
    my ( $self ) = @_;

    $self->importPrivateKey();
    $self->importCertificate();
    $self->importCaBundle();
}

=item getCertificateExpiryTime( [ certificatePath = $self->{'certificate_container_path'} ] )

 Get SSL certificate expiry time

 Param string certificatePath Path to SSL certificate (default: $self->{'certificate_container_path'})
 Return timestamp, die on failure

=cut

sub getCertificateExpiryTime
{
    my ( $self, $certificatePath ) = @_;
    $certificatePath ||= $self->{'certificate_container_path'};
    $certificatePath or croak( 'Invalide SSL certificate path provided' );

    my $rs = execute( [ 'openssl', 'x509', '-enddate', '-noout', '-in', $certificatePath ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs && $stdout =~ /^notAfter=(.*)/i or die( sprintf( "Couldn't get SSL certificate expiry time: %s", $stderr || 'unknown error' ));

    str2time( $1 );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::OpenSSL

=cut

sub _init
{
    my ( $self ) = @_;

    # Full path to the certificate chains storage directory
    $self->{'certificate_chains_storage_dir'} //= '';
    # Certificate chain name
    $self->{'certificate_chain_name'} //= '';
    # Full path to the private key container
    $self->{'private_key_container_path'} //= '';
    # Private key passphrase if any
    $self->{'private_key_passphrase'} //= '';
    # Full path to the SSL certificate container
    $self->{'certificate_container_path'} //= '';
    # Full path to the CA Bundle container (Container which contain one or many intermediate certificates)
    $self->{'ca_bundle_container_path'} //= '';
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
