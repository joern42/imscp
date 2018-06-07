=head1 NAME

 iMSCP::Packages::Setup::FrontEnd - i-MSCP FrontEnd package

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

package iMSCP::Packages::Setup::FrontEnd;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Config;
use iMSCP::Crypt qw/ apr1MD5 randomStr ALNUM /;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dialog::InputValidation qw/
    isNumber isNumberInRange isOneOfStringsInList isStringInList isStringNotInList isValidDomain isValidEmail isValidPassword isValidUsername
/;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Net;
use iMSCP::OpenSSL;
use iMSCP::Servers::Mta;
use iMSCP::Servers::Named;
use iMSCP::Service;
use iMSCP::Stepper qw/ step startDetail endDetail /;
use iMSCP::SystemGroup;
use iMSCP::SystemUser;
use iMSCP::Template::Processor qw/ processBlocByRef processVarsByRef /;
use Net::LibIDN qw/ idn_to_ascii idn_to_unicode /;
use version;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP FrontEnd package.

=head1 CLASS METHODS

=over 4

=item getPackagePriority( )

 See iMSCP::Packages::Abstract::getPackagePriority()

=cut

sub getPackagePriority
{
    100;
}

=back

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Packages::Abstract::registerSetupListeners()

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub {
        push @{ $_[0] },
            sub { $self->askMasterAdminCredentials( @_ ) },
            sub { $self->askMasterAdminEmail( @_ ) },
            sub { $self->askDomain( @_ ) },
            sub { $self->askSsl( @_ ) },
            sub { $self->askDefaultAccessMode( @_ ) },
            sub { $self->askHttpPorts( @_ ) },
            sub { $self->askAltUrlsFeature( @_ ) };
    } )->registerOne( 'beforeSetupPreInstallServers', sub {
        $self->_createMasterWebUser();
        $self->setFrontendPermissions();

        my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
        my $composer = iMSCP::Composer->new(
            user          => $usergroup,
            group         => $usergroup,
            home_dir      => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/persistent/frontend",
            working_dir   => $::imscpConfig{'FRONTEND_ROOT_DIR'},
            composer_json => iMSCP::File->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/composer.json" )->get(),
            composer_path => '/usr/local/bin/composer'
        );
        @{ $composer->getComposerJson( TRUE )->{'config'} }{ qw/ cafile capath / } = (
            $::imscpConfig{'DISTRO_CA_BUNDLE'}, $::imscpConfig{'DISTRO_CA_PATH'}
        );
        startDetail;
        $composer->setStdRoutines( sub {}, sub {
            ( my $stdout = $_[0] ) =~ s/^\s+|\s+$//g;
            return unless length $stdout;

            step( undef, <<"EOT", 1, 1 )
Installing/Updating i-MSCP frontEnd (dependencies) composer packages...

$stdout

Depending on your connection speed, this may take few minutes...
EOT
        } )->installPackages();
        endDetail;
    } );
}

=item askMasterAdminCredentials( \%dialog )

 Ask for master administrator credentials

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askMasterAdminCredentials
{
    my ( $self, $dialog ) = @_;

    my ( $username, $password, $freshInstall ) = ( '', '', TRUE );

    if ( iMSCP::Getopt->preseed ) {
        $username = ::setupGetQuestion( 'ADMIN_LOGIN_NAME', 'admin' );
        $password = ::setupGetQuestion( 'ADMIN_PASSWORD' );
    } elsif ( eval {
        $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));
        TRUE;
    } ) {
        $freshInstall = FALSE;

        my $row = $self->{'dbh'}->selectrow_hashref( "SELECT admin_name, admin_pass FROM admin WHERE created_by = 0 AND admin_type = 'admin'" );
        if ( $row ) {
            $username = $row->{'admin_name'} // '';
            $password = $row->{'admin_pass'} // '';
        }
    }

    ::setupSetQuestion( 'ADMIN_OLD_LOGIN_NAME', $username );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'admin', 'admin_credentials', 'all', 'forced' ] ) || !isValidUsername( $username )
        || !length $password
    ) {
        $password = '';
        my $rs = 0;

        Q1:
        do {
            unless ( length $username ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $username = 'admin';
            }

            ( $rs, $username ) = $dialog->inputbox( <<"EOF", $username );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the master administrator (leave empty for default):
\\Z \\Zn
EOF
            if ( isValidUsername( $username ) ) {
                unless ( $freshInstall ) {
                    my $row = $self->{'dbh'}->selectrow_hashref( 'SELECT 1 FROM admin WHERE admin_name = ? AND created_by <> 0', undef, $username );
                    if ( $row ) {
                        $iMSCP::Dialog::InputValidation::lastValidationError = <<"EOF";
\\Z1This username is not available.\\Zn
EOF
                    }
                }
            }
        } while $rs < 30 && $iMSCP::Dialog::InputValidation::lastValidationError;

        return $rs unless $rs < 30;

        do {
            unless ( length $password ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $password = randomStr( 16, ALNUM );
            }

            ( $rs, $password ) = $dialog->inputbox( <<"EOF", $password );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the master administrator (leave empty for autogeneration):
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidPassword( $password );

        goto Q1 if $rs == 30;
        return $rs if $rs == 50;
    } else {
        $password = '' unless iMSCP::Getopt->preseed
    }

    ::setupSetQuestion( 'ADMIN_LOGIN_NAME', $username );
    ::setupSetQuestion( 'ADMIN_PASSWORD', $password );
    0;
}

=item askMasterAdminEmail( \%dialog )

 Ask for master administrator email address

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askMasterAdminEmail
{
    my ( $self, $dialog ) = @_;

    my $email = ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'admin', 'admin_email', 'all', 'forced' ] ) || !isValidEmail( $email ) ) {
        my $rs = 0;
        $iMSCP::Dialog::InputValidation::lastValidationError = '' unless length $email;

        do {
            ( $rs, $email ) = $dialog->inputbox( <<"EOF", $email );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter an email address for the master administrator:
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidEmail( $email );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'DEFAULT_ADMIN_ADDRESS', $email );
    0;
}

=item askDomain( \%dialog )

 Show for frontEnd domain name

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askDomain
{
    my ( $self, $dialog ) = @_;

    my $domainName = ::setupGetQuestion( 'BASE_SERVER_VHOST', ( iMSCP::Getopt->preseed ? do {
        my @labels = split /\./, ::setupGetQuestion( 'SERVER_HOSTNAME' );
        'panel.' . join( '.', @labels[1 .. $#labels] );
    } : '' ));

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'panel_hostname', 'hostnames', 'all', 'forced' ] )
        || !isValidDomain( $domainName )
    ) {
        unless ( length $domainName ) {
            $iMSCP::Dialog::InputValidation::lastValidationError = '';
            my @labels = split /\./, ::setupGetQuestion( 'SERVER_HOSTNAME' );
            $domainName = 'panel.' . join( '.', @labels[1 .. $#labels] );
        }

        $domainName = idn_to_unicode( $domainName, 'utf-8' ) // '';

        my $rs = 0;

        do {
            ( $rs, $domainName ) = $dialog->inputbox( <<"EOF", $domainName );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a domain name for the control panel: (leave empty for autodetection)
\\Z \\Zn
EOF
        } while $rs < 30 && !isValidDomain( $domainName );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST', idn_to_ascii( $domainName, 'utf-8' ) // '' );
    0;
}

=item askSsl( \%dialog )

 Ask for frontEnd SSL certificate

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askSsl
{
    my ( $self, $dialog ) = @_;

    my $domainName = ::setupGetQuestion( 'BASE_SERVER_VHOST' );
    my $domainNameUnicode = idn_to_unicode( $domainName, 'utf-8' ) // $domainName;
    my $sslEnabled = ::setupGetQuestion( 'PANEL_SSL_ENABLED', iMSCP::Getopt->preseed ? 'yes' : '' );
    my $selfSignedCertificate = ::setupGetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE', iMSCP::Getopt->preseed ? 'yes' : 'no' );
    my $privateKeyPath = ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH' );
    my $passphrase = ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE' );
    my $caBundlePath = ::setupGetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH' );
    my $certificatePath = ::setupGetQuestion( 'PANEL_SSL_CERTIFICATE_PATH' );
    my $fselectRootDir = ( length $privateKeyPath ? dirname( $privateKeyPath ) // '/root' : '/root' ) . '/';
    my $openSSL = iMSCP::OpenSSL->new();

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'panel_ssl', 'ssl', 'all', 'forced' ] )
        || !isStringInList( $sslEnabled, 'yes', 'no' )
        || ( $sslEnabled eq 'yes' && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel_hostname', 'hostnames' ] ) )
        || ( $sslEnabled eq 'yes' && iMSCP::Getopt->preseed && !$selfSignedCertificate && ( !length $privateKeyPath || !length $certificatePath
        || !eval {
        local $openSSL->{'private_key_container_path'} = $privateKeyPath;
        local $openSSL->{'ca_bundle_container_path'} = $caBundlePath;
        local $openSSL->{'certificate_container_path'} = $certificatePath;
        $openSSL->validateCertificateChain();
    } ) ) ) {
        my $msg = '';

        Q1:
        my $rs = $dialog->yesno( <<'EOF', $sslEnabled eq 'no', TRUE );

Do you want to enable SSL for the control panel?
EOF
        return $rs unless $rs < 30;

        if ( $rs ) {
            ::setupSetQuestion( 'PANEL_SSL_ENABLED', 'no' );
            return 0; # SSL disabled; return early
        }

        $sslEnabled = 'yes';

        Q2:
        $rs = $dialog->yesno( <<"EOF", $selfSignedCertificate eq 'no', TRUE );

Do you have an SSL certificate for the $domainNameUnicode domain?
EOF
        goto Q1 if $rs == 30;
        return $rs if $rs == 50;

        unless ( $rs ) {
            Q3:
            $rs = $dialog->msgbox( <<"EOF" );
$msg
Please select the private key associated to your SSL certificate in next dialog.
EOF
            return $rs unless $rs < 50;

            do {
                ( $rs, $privateKeyPath ) = $dialog->fselect( length $privateKeyPath ? $privateKeyPath : $fselectRootDir );
            } while $rs < 30 && !( length $privateKeyPath && -f $privateKeyPath );

            goto Q2 if $rs == 30;
            return $rs if $rs == 50;

            Q4:
            ( $rs, $passphrase ) = $dialog->passwordbox( <<"EOF", $passphrase );

Please enter the passphrase for your private key if any:
\\Z \\Zn
EOF
            goto Q3 if $rs == 30;
            return $rs if $rs == 50;

            $openSSL->{'private_key_container_path'} = $privateKeyPath;
            $openSSL->{'private_key_passphrase'} = $passphrase;

            $msg = eval { $openSSL->validatePrivateKey(); } ? '' : <<"EOF";
\\Z1Invalid private key or passphrase.\\Zn
EOF
            goto Q4 if length $msg;

            Q5:
            $rs = $dialog->yesno( <<'EOF', FALSE, TRUE );

Do you have a CA bundle (file containing root and intermediate certificates)?
EOF
            return $rs if $rs == 50;
            goto Q4 if $rs == 30;

            Q6:
            unless ( $rs ) {
                do {
                    ( $rs, $caBundlePath ) = $dialog->fselect( length $caBundlePath ? $caBundlePath : $fselectRootDir );
                } while $rs < 30 && !( length $caBundlePath && -f $caBundlePath );

                goto Q5 if $rs == 30;
                return $rs if $rs == 50;

                $openSSL->{'ca_bundle_container_path'} = $caBundlePath;
            } else {
                $openSSL->{'ca_bundle_container_path'} = '';
            }

            Q7:
            $rs = $dialog->msgbox( <<"EOF" );
$msg
Please select your SSL certificate in next dialog.
EOF
            return $rs if $rs == 50;

            do {
                ( $rs, $certificatePath ) = $dialog->fselect( length $certificatePath ? $certificatePath : $fselectRootDir );
            } while $rs < 30 && !( length $certificatePath && -f $certificatePath );

            goto Q6 if $rs == 30;
            return $rs if $rs == 50;

            $openSSL->{'certificate_container_path'} = $certificatePath;
            $msg = eval { $openSSL->validateCertificate(); } ? '' : <<"EOF";
\\Z1Invalid SSL certificate.\\Zn
EOF
            goto Q7 if length $msg;
        } else {
            $selfSignedCertificate = 'yes';
        }
    } elsif ( $sslEnabled eq 'yes' && !iMSCP::Getopt->preseed && !eval {
        $openSSL->{'private_key_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";
        $openSSL->{'ca_bundle_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";
        $openSSL->{'certificate_container_path'} = "$::imscpConfig{'CONF_DIR'}/$domainName.pem";
        $openSSL->validateCertificateChain();
        # The SSL certificate is valid so we skip SSL setup
        ::setupSetQuestion( 'PANEL_SSL_SETUP', 'no' );
    } ) {
        $dialog->msgbox( <<'EOF' );

Your SSL certificate for the control panel is missing or invalid.
EOF
        ::setupSetQuestion( 'PANEL_SSL_ENABLED', '' );
        goto &{ askSsl };
    }

    ::setupSetQuestion( 'PANEL_SSL_ENABLED', $sslEnabled );
    ::setupSetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE', $selfSignedCertificate );
    ::setupSetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH', $privateKeyPath );
    ::setupSetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE', $passphrase );
    ::setupSetQuestion( 'PANEL_SSL_CERTIFICATE_PATH', $certificatePath );
    ::setupSetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH', $caBundlePath );
    0;
}

=item askDefaultAccessMode()

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askDefaultAccessMode
{
    my ( $self, $dialog ) = @_;

    unless ( ::setupGetQuestion( 'PANEL_SSL_ENABLED' ) eq 'yes' ) {
        ::setupSetQuestion( 'BASE_SERVER_VHOST_PREFIX', 'http://' );
        return 0;
    }

    my $scheme = ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX', iMSCP::Getopt->preseed ? 'http://' : '' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'panel_ssl', 'ssl', 'all', 'forced' ] )
        || !isStringInList( $scheme, 'http://', 'https://' )
    ) {
        my %choices = ( 'http://', 'No secure access (No SSL)', 'https://', 'Secure access (SSL)' );
        ( my $rs, $scheme ) = $dialog->radiolist(
            <<"EOF", \%choices, ( grep ( $scheme eq $_, keys %choices ) )[0] || 'https://' );

Please choose the default access mode for the control panel:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST_PREFIX', $scheme );
    0;
}

=item askHttpPorts( \%dialog )

 Ask for frontEnd http ports

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askHttpPorts
{
    my ( $self, $dialog ) = @_;

    my $httpPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT', iMSCP::Getopt->preseed ? 8880 : '' );
    my $httpsPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT', iMSCP::Getopt->preseed ? 8443 : '' );
    my $sslEnabled = ::setupGetQuestion( 'PANEL_SSL_ENABLED', iMSCP::Getopt->preseed ? 'yes' : '' );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'panel_ports', 'all', 'forced' ] )
        || !isNumber( $httpPort ) || !isNumberInRange( $httpPort, 1025, 65535 )
    ) {
        my $rs = 0;

        do {
            unless ( length $httpPort ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $httpPort = 8880;
            }

            ( $rs, $httpPort ) = $dialog->inputbox( <<"EOF", $httpPort );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the HTTP port for the control panel:
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isNumber( $httpPort ) || !isNumberInRange( $httpPort, 1025, 65535 ) );

        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT', $httpPort );

    if ( $sslEnabled eq 'yes' ) {
        if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'panel_ports', 'panel_ssl', 'ssl', 'all', 'forced' ] )
            || !isNumber( $httpsPort ) || !isNumberInRange( $httpsPort, 1025, 65535 ) || !isStringNotInList( $httpsPort, $httpPort )
        ) {
            my $rs = 0;

            do {
                unless ( length $httpsPort ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $httpsPort = 8443;
                }

                ( $rs, $httpsPort ) = $dialog->inputbox( <<"EOF", $httpsPort );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the HTTPS port for the control panel:
\\Z \\Zn
EOF
            } while $rs < 30 && ( !isNumber( $httpsPort ) || !isNumberInRange( $httpsPort, 1025, 65535 )
                || !isStringNotInList( $httpsPort, $httpPort ) );

            return $rs unless $rs < 30;
        }
    } else {
        $httpsPort = '';
    }

    ::setupSetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT', $httpsPort );
    0;
}

=item askAltUrlsFeature( \%dialog )

 Ask for alternative URL feature

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askAltUrlsFeature
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'CLIENT_DOMAIN_ALT_URLS', iMSCP::Getopt->preseed ? 'yes' : '' );
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'panel', 'alt_urls', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'yes' );

Do you want to enable the alternative URLs feature for client domains?

This feature allows the clients to access their websites through alternative URLs such as http://dmn1.panel.domain.tld
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'CLIENT_DOMAIN_ALT_URLS', $value );
    0;
}

=item preinstall( )

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->stopNginx();
    $self->stopPhpFpm();
    $self->{'eventManager'}->registerOne(
        'afterSetupPreInstallPackages',
        sub {
            eval {
                my ( $composer, $step ) = ( $self->getComposer(), 0 );
                my $stdRoutine = sub {
                    ( my $stdout = $_[0] ) =~ s/^\s+|\s+$//g;
                    return unless length $stdout;

                    step( undef, <<"EOT", 3, $step )
Installing/Updating i-MSCP frontEnd (tools) composer packages...

$stdout

Depending on your connection speed, this may take few minutes...
EOT
                };

                startDetail;

                if ( iMSCP::Getopt->clearPackageCache ) {
                    $step++;
                    $composer->setStdRoutines( sub {}, $stdRoutine )->clearPackageCache();
                }

                if ( iMSCP::Getopt->skipPackageUpdate ) {
                    $step++;
                    eval {
                        $composer->setStdRoutines( $stdRoutine, sub {} )->checkPackageRequirements();
                    };
                    die( "Unmet requirements. Please rerun the the installer without the '-a' option." ) if $@;
                    endDetail;
                    return;
                }

                $step++;
                $composer->setStdRoutines( sub {}, $stdRoutine )->updatePackages( undef, 'skip-autoloader' );
                undef $self->{'_composer'};
                endDetail;
            };
            if ( $@ ) {
                endDetail;
                die;
            }
        }
    );
}

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setupMasterAdmin();
    $self->_setupSsl();
    $self->_setHttpdVersion();
    $self->_addMasterWebUser();
    $self->_makeDirs();
    $self->_copyPhpBinary();
    $self->_buildPhpConfig();
    $self->_buildHttpdConfig();
    $self->_addDnsZone();
    #$self->_addMailDomain(); # FIXME Needed or not?
    $self->_installSystemFiles();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Packages::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $stderr;
    execute( "perl $::imscpConfig{'BACKEND_ROOT_DIR'}/tools/imscp-info.pl -j", \my $stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
    chomp( $stdout );

    $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));
    $self->{'dbh'}->do( 'REPLACE INTO config VALUES(?,?)', undef, 'iMSCP_INFO', $stdout );

    my $srvProvider = iMSCP::Service->getInstance( eventManager => $self->{'eventManager'} );
    $srvProvider->enable( 'nginx' );
    $srvProvider->enable( 'imscp_panel' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->startNginx(); }, 'Nginx' ];
            push @{ $_[0] }, [ sub { $self->startPhpFpm(); }, 'i-MSCP panel (PHP FastCGI process manager)' ];
        },
        2
    );
}

=item uninstall( )

 See iMSCP::Packages::Abstract::()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_deleteSystemFiles();
    $self->_deconfigurePHP();
    $self->_deconfigureHTTPD();
    $self->_deleteMasterWebUser();
    $self->restartNginx() if iMSCP::Service->getInstance()->hasService( 'nginx' );
}

=item dpkgPostInvokeTasks( )

 See iMSCP::Packages::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    if ( -f '/usr/local/sbin/imscp_panel' ) {
        unless ( -f $self->{'config'}->{'PHP_FPM_BIN_PATH'} ) {
            # Cover case where administrator removed the package
            $self->stop();
            iMSCP::File->new( filename => '/usr/local/sbin/imscp_panel' )->remove();
        }

        my $v1 = $self->_getFullPhpVersionFor( $self->{'config'}->{'PHP_FPM_BIN_PATH'} );
        my $v2 = $self->_getFullPhpVersionFor( '/usr/local/sbin/imscp_panel' );
        return unless defined $v1 && defined $v2 && $v1 ne $v2; # Don't act when not necessary
        debug( sprintf( "Updating i-MSCP frontEnd PHP-FPM binary from version %s to version %s", $v2, $v1 ));
    }

    $self->stopPhpFpm();
    $self->_copyPhpBinary();

    return unless -f '/usr/local/etc/imscp_panel/php-fpm.conf';

    $self->startPhpFpm();
}

=item setBackendPermissions( )

 See iMSCP::Packages::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( $self->{'config'}->{'HTTPD_CONF_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0644',
        recursive => TRUE
    } );
    setRights( $self->{'config'}->{'HTTPD_LOG_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0640',
        recursive => TRUE
    } );

    # Temporary directories as provided by nginx package (from Debian Team)
    if ( -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}" ) {
        setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}, {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ROOT_GROUP'}
        } );

        for my $tmp ( 'body', 'fastcgi', 'proxy', 'scgi', 'uwsgi' ) {
            next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp";

            setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user      => $self->{'config'}->{'HTTPD_USER'},
                group     => $self->{'config'}->{'HTTPD_GROUP'},
                dirnmode  => '0700',
                filemode  => '0640',
                recursive => TRUE
            } );
            setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'}/$tmp", {
                user  => $self->{'config'}->{'HTTPD_USER'},
                group => $::imscpConfig{'ROOT_GROUP'},
                mode  => '0700'
            } );
        }
    }

    # Temporary directories as provided by nginx package (from nginx Team)
    return unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}";

    setRights( $self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'}
    } );

    for my $tmp ( 'client_temp', 'fastcgi_temp', 'proxy_temp', 'scgi_temp', 'uwsgi_temp' ) {
        next unless -d "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp";

        setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user      => $self->{'config'}->{'HTTPD_USER'},
            group     => $self->{'config'}->{'HTTPD_GROUP'},
            dirnmode  => '0700',
            filemode  => '0640',
            recursive => TRUE
        } );
        setRights( "$self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'}/$tmp", {
            user  => $self->{'config'}->{'HTTPD_USER'},
            group => $::imscpConfig{'ROOT_GROUP'},
            mode  => '0700'
        } );
    }
}

=item setFrontendPermissions( )

 See iMSCP::Packages::Abstract::setFrontendPermissions()

=cut

sub setFrontendPermissions
{
    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    setRights( $::imscpConfig{'FRONTEND_ROOT_DIR'}, {
        user      => $usergroup,
        group     => $usergroup,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'FrontEnd';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'i-MSCP FrontEnd (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $self->getPackageImplVersion();
}

=item getComposer( )

 Get iMSCP::Composer instance used for FrontEnd tools installation

 Return iMSCP::Composer

=cut

sub getComposer
{
    my ( $self ) = @_;

    $self->{'_composer'} ||= iMSCP::Composer->new(
        user          => $::imscpConfig{'IMSCP_USER'},
        group         => $::imscpConfig{'IMSCP_GROUP'},
        working_dir   => "$::imscpConfig{'IMSCP_HOMEDIR'}/packages",
        composer_path => '/usr/local/bin/composer'
    );
}

=item addUser( \%data )

 Process addUser tasks

 Param hashref \%data user data as provided by Modules::User module
 Return void, die on failure

=cut

sub addUser
{
    my ( $self, $data ) = @_;

    return if $data->{'STATUS'} eq 'tochangepwd';

    iMSCP::SystemUser->new()->addToGroup( $data->{'GROUP'}, $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} );
}

=item enableSites( @sites )

 Enable the given site(s)

 Param array @sites List of sites to enable
 Return void, die on failure

=cut

sub enableSites
{
    my ( $self, @sites ) = @_;

    for my $site ( @sites ) {
        my $target = File::Spec->canonpath( "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site" );
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));
        -f $target or die( sprintf( "Site '%s' doesn't exist", $site ));
        next if -l $symlink && realpath( $symlink ) eq $target;
        unlink $symlink or die( sprintf( "Couldn't unlink the %s file: %s", $! )) if -e _;
        symlink File::Spec->abs2rel( $target, $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} ), $symlink or die(
            sprintf( "Couldn't enable the `%s` site: %s", $site, $! )
        );
        $self->{'reload'} ||= TRUE;
    }
}

=item disableSites( @sites )

 Disable the given site(s)

 Param array @sites List of sites to disable
 Return void, die on failure

=cut

sub disableSites
{
    my ( $self, @sites ) = @_;

    for my $site ( @sites ) {
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));
        next unless -e $symlink;
        unlink( $symlink ) or die( sprintf( "Couldn't unlink the %s file: %s", $! ));
        $self->{'reload'} ||= TRUE;
    }
}

=item start( )

 Start frontEnd

 Return void, die on failure

=cut

sub start
{
    my ( $self ) = @_;

    $self->startPhpFpm();
    $self->startNginx();
}

=item stop( )

 Stop frontEnd

 Return void, die on failure

=cut

sub stop
{
    my ( $self ) = @_;

    $self->stopPhpFpm();
    $self->stopNginx();
}

=item reload( )

 Reload frontEnd

 Return void, die on failure

=cut

sub reload
{
    my ( $self ) = @_;

    $self->reloadPhpFpm();
    $self->reloadNginx();
}

=item restart( )

 Restart frontEnd

 Return void, die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    $self->restartPhpFpm();
    $self->restartNginx();
}

=item startNginx( )

 Start frontEnd (Nginx only)

 Return void, die on failure

=cut

sub startNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item stopNginx( )

 Stop frontEnd (Nginx only)

 Return void, die on failure

=cut

sub stopNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( "$self->{'config'}->{'HTTPD_SNAME'}" );
}

=item reloadNginx( )

 Reload frontEnd (Nginx only)

 Return void, die on failure

=cut

sub reloadNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item restartNginx( )

 Restart frontEnd (Nginx only)

 Return void, die on failure

=cut

sub restartNginx
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( $self->{'config'}->{'HTTPD_SNAME'} );
}

=item startPhpFpm( )

 Start frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub startPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'imscp_panel' );
}

=item stopPhpFpm( )

 Stop frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub stopPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'imscp_panel' );
}

=item reloadPhpFpm( )

 Reload frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub reloadPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'imscp_panel' );
}

=item restartPhpFpm( )

 Restart frontEnd (PHP-FPM instance only)

 Return void, die on failure

=cut

sub restartPhpFpm
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'imscp_panel' );
}

=item buildConfFile( $file [, \%tplVars = { } [, \%options = { } ] ] )

 Build the given configuration file

 Param string $file Absolute filepath or filepath relative to the frontend configuration directory
 Param hashref \%tplVars OPTIONAL Template variables
 Param hashref \%options OPTIONAL Options such as destination, mode, user and group for final file
 Return void, die on failure

=cut

sub buildConfFile
{
    my ( $self, $file, $tplVars, $options ) = @_;

    $tplVars ||= {};
    $options ||= {};

    my ( $filename, $path ) = fileparse( $file );
    $file = File::Spec->canonpath( "$self->{'cfgDir'}/$path/$filename" ) if index( $path, '/' ) != 0;
    $file = iMSCP::File->new( filename => $file );

    my $cfgTpl = $file->getAsRef( TRUE );
    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'frontend', $filename, $cfgTpl, $tplVars );
    $file->getAsRef();

    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConfFile', $cfgTpl, $filename, $tplVars, $options );
    $self->_buildConf( $cfgTpl, $filename, $tplVars );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildConfFile', $cfgTpl, $filename, $tplVars, $options );

    ${ $cfgTpl } =~ s/^\s*(?:[#;].*)?\n//gmi; # Final cleanup

    $file->{'filename'} = $options->{'destination'} // "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$filename";
    $file->save()->owner( $options->{'user'}, $options->{'group'} )->mode( $options->{'mode'} );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Setup::FrontEnd

=cut

sub _init
{
    my ( $self ) = @_;

    @{ $self }{qw/ start reload restart cfgDir / } = ( FALSE, FALSE, FALSE, "$::imscpConfig{'CONF_DIR'}/frontend" );
    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/frontend.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        filename    => "$self->{'cfgDir'}/frontend.data",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer';
    $self->SUPER::_init();
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/frontend.data" ) {
        tie my %newConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/frontend.data.dist";
        tie my %oldConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/frontend.data", readonly => 1;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/frontend.data.dist" )->move( "$self->{'cfgDir'}/frontend.data" );
}

=item _createMasterWebUser

 Create master (control panel) Web user

 Return void, die on failure

=cut

sub _createMasterWebUser
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    iMSCP::SystemUser->new(
        comment        => 'i-MSCP Control Panel Web User',
        home           => $::imscpConfig{'FRONTEND_ROOT_DIR'},
        skipCreateHome => TRUE
    )->addSystemUser( $usergroup, $usergroup );

    # Add the panel user (vu2000) into the i-MSCP backend group
    # FIXME: This is needed for?
    iMSCP::SystemUser->new()->addToGroup( $::imscpConfig{'IMSCP_GROUP'}, $usergroup );

    # Add panel user (vu2000) into the mailbox group (e.g: mail)
    # Control panel need access to customer maildirsize files to calculate quota (realtime quota)
    iMSCP::SystemUser->new()->addToGroup( iMSCP::Servers::Mta->factory()->{'config'}->{'MTA_MAILBOX_GID_NAME'}, $usergroup );

    # Add panel Web user (vu2000) into the Web server group
    # FIXME: This is needed for?
    iMSCP::SystemUser->new()->addToGroup( $usergroup, $self->{'config'}->{'HTTPD_USER'} );
}

=item _setupMasterAdmin( )

 Setup master administrator

 Return void, die on failure

=cut

sub _setupMasterAdmin
{
    my ( $self ) = @_;

    my $login = ::setupGetQuestion( 'ADMIN_LOGIN_NAME' );
    my $loginOld = ::setupGetQuestion( 'ADMIN_OLD_LOGIN_NAME' );
    my $password = ::setupGetQuestion( 'ADMIN_PASSWORD' );
    my $email = ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' );

    return unless length $password;

    $password = apr1MD5( $password );

    my $oldDbName = $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));

    eval {
        $self->{'dbh'}->begin_work();

        my $row = $self->{'dbh'}->selectrow_hashref( "SELECT admin_id FROM admin WHERE admin_name = ?", undef, $loginOld );
        if ( $row ) {
            $self->{'dbh'}->do(
                'UPDATE admin SET admin_name = ?, admin_pass = ?, email = ? WHERE admin_id = ?', undef, $login, $password, $email, $row->{'admin_id'}
            );
        } else {
            $self->{'dbh'}->do(
                'INSERT INTO admin (admin_name, admin_pass, admin_type, email) VALUES (?, ?, ?, ?)', undef, $login, $password, 'admin', $email
            );
            $self->{'dbh'}->do( 'INSERT INTO user_gui_props SET user_id = LAST_INSERT_ID()' );
        }

        $self->{'dbh'}->commit();
    };
    if ( $@ ) {
        $self->{'dbh'}->rollback();
        die
    }

    $self->{'dbh'}->useDatabase( $oldDbName ) if length $oldDbName;
}

=item _setupSsl( )

 Setup SSL

 Return void, die on failure

=cut

sub _setupSsl
{
    my $sslEnabled = ::setupGetQuestion( 'PANEL_SSL_ENABLED' );
    my $oldCertificate = $::imscpOldConfig{'BASE_SERVER_VHOST'};
    my $domainName = ::setupGetQuestion( 'BASE_SERVER_VHOST' );

    # Remove old certificate if any (handle case where panel hostname has been changed)
    if ( length $oldCertificate && $oldCertificate ne "$domainName.pem" ) {
        iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/$oldCertificate" )->remove();
    }

    if ( $sslEnabled eq 'no' || ::setupGetQuestion( 'PANEL_SSL_SETUP', 'yes' ) eq 'no' ) {
        iMSCP::File->new( filename => "$::imscpConfig{'CONF_DIR'}/$domainName.pem" )->remove() if $sslEnabled eq 'no';
        return;
    }

    if ( ::setupGetQuestion( 'PANEL_SSL_SELFSIGNED_CERTIFICATE' ) eq 'yes' ) {
        iMSCP::OpenSSL->new(
            certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
            certificate_chain_name         => $domainName
        )->createSelfSignedCertificate( {
            common_name => $domainName,
            email       => ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' )
        } );
        return;
    }

    iMSCP::OpenSSL->new(
        certificate_chains_storage_dir => $::imscpConfig{'CONF_DIR'},
        certificate_chain_name         => $domainName,
        private_key_container_path     => ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PATH' ),
        private_key_passphrase         => ::setupGetQuestion( 'PANEL_SSL_PRIVATE_KEY_PASSPHRASE' ),
        certificate_container_path     => ::setupGetQuestion( 'PANEL_SSL_CERTIFICATE_PATH' ),
        ca_bundle_container_path       => ::setupGetQuestion( 'PANEL_SSL_CA_BUNDLE_PATH' )
    )->createCertificateChain();
}

=item _setHttpdVersion( )

 Set httpd version

 Return void, die on failure

=cut

sub _setHttpdVersion( )
{
    my ( $self ) = @_;

    my $rs = execute( 'nginx -v', \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    $rs == 0 or die( $stderr || 'Unknown error' ) if $rs;
    $stderr =~ m%nginx/([\d.]+)% or die( "Couldn't guess Nginx version" );
    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Nginx version set to: %s', $1 ));
}

=item _addMasterWebUser( )

 Add master Web user

 Return void, die on failure

=cut

sub _addMasterWebUser
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndAddUser' );

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};
    my ( $uid, $gid ) = ( getpwnam( $usergroup ) )[2, 3];

    $self->{'dbh'}->useDatabase( ::setupGetQuestion( 'DATABASE_NAME' ));
    $self->{'dbh'}->do(
        "UPDATE admin SET admin_sys_name = ?, admin_sys_uid = ?, admin_sys_gname = ?, admin_sys_gid = ? WHERE admin_type = 'admin'",
        undef, $usergroup, $uid, $usergroup, $gid
    );

    $self->{'eventManager'}->trigger( 'afterFrontEndAddUser' );
}

=item _makeDirs( )

 Create directories

 Return void, die on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeFrontEndMakeDirs' );

    my $rootUName = $::imscpConfig{'ROOT_USER'};
    my $rootGName = $::imscpConfig{'ROOT_GROUP'};

    my $nginxTmpDir = $self->{'config'}->{'HTTPD_CACHE_DIR_DEBIAN'};
    $nginxTmpDir = $self->{'config'}->{'HTTPD_CACHE_DIR_NGINX'} unless -d $nginxTmpDir;

    # Force re-creation of cache directory tree (needed to prevent any permissions problem from an old installation)
    # See #IP-1530
    iMSCP::Dir->new( dirname => $nginxTmpDir )->remove();

    for my $dir ( [ $nginxTmpDir, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_CONF_DIR'}, $rootUName, $rootGName, 0755 ],
        [ "$self->{'config'}->{'HTTPD_LOG_DIR'}/@{ [ ::setupGetQuestion( 'BASE_SERVER_VHOST' ) ] }", $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}, $rootUName, $rootGName, 0755 ],
        [ $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}, $rootUName, $rootGName, 0755 ]
    ) {
        iMSCP::Dir->new( dirname => $dir->[0] )->make( {
            user  => $dir->[1],
            group => $dir->[2],
            mode  => $dir->[3]
        } );
    }

    if ( iMSCP::Service->getInstance->isSystemd() ) {
        iMSCP::Dir->new( dirname => '/run/imscp' )->make( {
            user  => $self->{'config'}->{'HTTPD_USER'},
            group => $self->{'config'}->{'HTTPD_GROUP'},
            mode  => 0755
        } );
    }

    $self->{'eventManager'}->trigger( 'afterFrontEndMakeDirs' );
}

=item _copyPhpBinary( )

 Copy system PHP-FPM binary for imscp_panel service

 Return void, die on failure

=cut

sub _copyPhpBinary
{
    my ( $self ) = @_;

    length $self->{'config'}->{'PHP_FPM_BIN_PATH'} or die( "PHP 'PHP_FPM_BIN_PATH' configuration parameter is not set." );

    iMSCP::File->new( filename => $self->{'config'}->{'PHP_FPM_BIN_PATH'} )->copy( '/usr/local/sbin/imscp_panel', { preserve => TRUE } );
}

=item _buildPhpConfig( )

 Build PHP configuration

 Return void, die on failure

=cut

sub _buildPhpConfig
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    $self->buildConfFile( "$self->{'cfgDir'}/php-fpm.conf",
        {
            # FPM configuration
            PHP_FPM_LOG_LEVEL                   => $self->{'config'}->{'PHP_FPM_LOG_LEVEL'},
            PHP_FPM_EMERGENCY_RESTART_THRESHOLD => $self->{'config'}->{'PHP_FPM_EMERGENCY_RESTART_THRESHOLD'},
            PHP_FPM_EMERGENCY_RESTART_INTERVAL  => $self->{'config'}->{'PHP_FPM_EMERGENCY_RESTART_INTERVAL'},
            PHP_FPM_PROCESS_CONTROL_TIMEOUT     => $self->{'config'}->{'PHP_FPM_PROCESS_CONTROL_TIMEOUT'},
            PHP_FPM_PROCESS_MAX                 => $self->{'config'}->{'PHP_FPM_PROCESS_MAX'},
            PHP_FPM_RLIMIT_FILES                => $self->{'config'}->{'PHP_FPM_RLIMIT_FILES'},
            # FPM imscp_panel pool configuration
            USER                                => $usergroup,
            GROUP                               => $usergroup,
            PHP_FPM_PROCESS_MANAGER_MODE        => $self->{'config'}->{'PHP_FPM_PROCESS_MANAGER_MODE'},
            PHP_FPM_MAX_CHILDREN                => $self->{'config'}->{'PHP_FPM_MAX_CHILDREN'},
            PHP_FPM_START_SERVERS               => $self->{'config'}->{'PHP_FPM_START_SERVERS'},
            PHP_FPM_MIN_SPARE_SERVERS           => $self->{'config'}->{'PHP_FPM_MIN_SPARE_SERVERS'},
            PHP_FPM_MAX_SPARE_SERVERS           => $self->{'config'}->{'PHP_FPM_MAX_SPARE_SERVERS'},
            PHP_FPM_PROCESS_IDLE_TIMEOUT        => $self->{'config'}->{'PHP_FPM_PROCESS_IDLE_TIMEOUT'},
            PHP_FPM_MAX_REQUESTS                => $self->{'config'}->{'PHP_FPM_MAX_REQUESTS'},
            PHP_FPM_PROCESS_MANAGER_MODE        => $self->{'config'}->{'PHP_FPM_PROCESS_MANAGER_MODE'},
            CHKROOTKIT_LOG                      => $::imscpConfig{'CHKROOTKIT_LOG'},
            CONF_DIR                            => $::imscpConfig{'CONF_DIR'},
            DOMAIN                              => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
            DISTRO_OPENSSL_CNF                  => $::imscpConfig{'DISTRO_OPENSSL_CNF'},
            DISTRO_CA_BUNDLE                    => $::imscpConfig{'DISTRO_CA_BUNDLE'},
            HOME_DIR                            => $::imscpConfig{'FRONTEND_ROOT_DIR'},
            MTA_VIRTUAL_MAIL_DIR                => iMSCP::Servers::Mta->factory()->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
            OTHER_ROOTKIT_LOG                   => length $::imscpConfig{'OTHER_ROOTKIT_LOG'} ? ":$::imscpConfig{'OTHER_ROOTKIT_LOG'}" : '',
            RKHUNTER_LOG                        => $::imscpConfig{'RKHUNTER_LOG'},
            TIMEZONE                            => ::setupGetQuestion( 'TIMEZONE' ),
            WEB_DIR                             => $::imscpConfig{'FRONTEND_ROOT_DIR'}
        },
        {
            destination => "/usr/local/etc/imscp_panel/php-fpm.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0640
        }
    );
    $self->buildConfFile( "$self->{'cfgDir'}/php.ini",
        {
            PHP_OPCODE_CACHE_ENABLED    => $self->{'config'}->{'PHP_OPCODE_CACHE_ENABLED'},
            PHP_OPCODE_CACHE_MAX_MEMORY => $self->{'config'}->{'PHP_OPCODE_CACHE_MAX_MEMORY'},
            PHP_APCU_CACHE_ENABLED      => $self->{'config'}->{'PHP_APCU_CACHE_ENABLED'},
            PHP_APCU_CACHE_MAX_MEMORY   => $self->{'config'}->{'PHP_APCU_CACHE_MAX_MEMORY'},
            TIMEZONE                    => ::setupGetQuestion( 'TIMEZONE' )
        },
        {
            destination => "/usr/local/etc/imscp_panel/php.ini",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0640
        }
    );
}

=item _buildHttpdConfig( )

 Build httpd configuration

 Return void, die on failure

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    my $availableCPUcores = $self->_getNbCPUcores();
    my $nbCPUcores = $self->{'config'}->{'HTTPD_WORKER_PROCESSES'};
    $nbCPUcores = $availableCPUcores if $self->{'config'}->{'HTTPD_WORKER_PROCESSES'} eq 'auto' || $nbCPUcores > $availableCPUcores;
    $nbCPUcores = $self->{'config'}->{'HTTPD_WORKER_PROCESSES_LIMIT'} if $nbCPUcores > $self->{'config'}->{'HTTPD_WORKER_PROCESSES_LIMIT'};


    # Build main nginx configuration file
    $self->buildConfFile( "$self->{'cfgDir'}/nginx.nginx",
        {
            HTTPD_USER               => $self->{'config'}->{'HTTPD_USER'},
            HTTPD_WORKER_PROCESSES   => $nbCPUcores,
            HTTPD_WORKER_CONNECTIONS => $self->{'config'}->{'HTTPD_WORKER_CONNECTIONS'},
            HTTPD_RLIMIT_NOFILE      => $self->{'config'}->{'HTTPD_RLIMIT_NOFILE'},
            HTTPD_LOG_DIR            => $self->{'config'}->{'HTTPD_LOG_DIR'},
            HTTPD_PID_FILE           => $self->{'config'}->{'HTTPD_PID_FILE'},
            HTTPD_CONF_DIR           => $self->{'config'}->{'HTTPD_CONF_DIR'},
            HTTPD_SITES_ENABLED_DIR  => $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'}
        },
        {
            destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/nginx.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0644
        }
    );

    # Build FastCGI configuration file
    $self->buildConfFile( "$self->{'cfgDir'}/imscp_fastcgi.nginx", { APPLICATION_ENV => $self->{'config'}->{'APPLICATION_ENV'} }, {
        destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );

    # Build PHP backend configuration file
    $self->buildConfFile( "$self->{'cfgDir'}/imscp_php.nginx", {}, {
        destination => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildHttpdConfig' );
    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildHttpdVhosts' );

    # Build frontEnd site files
    my $baseServerIpVersion = iMSCP::Net->getInstance()->getAddrVersion( ::setupGetQuestion( 'BASE_SERVER_IP' ));
    my $httpsPort = ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTPS_PORT' );
    my $tplVars = {
        BASE_SERVER_VHOST            => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        BASE_SERVER_IP               => ( $baseServerIpVersion eq 'ipv4' )
            ? ::setupGetQuestion( 'BASE_SERVER_IP' ) =~ s/^\Q0.0.0.0\E$/*/r : '[' . ::setupGetQuestion( 'BASE_SERVER_IP' ) . ']',
        BASE_SERVER_VHOST_HTTP_PORT  => ::setupGetQuestion( 'BASE_SERVER_VHOST_HTTP_PORT' ),
        BASE_SERVER_VHOST_HTTPS_PORT => $httpsPort,
        WEB_DIR                      => $::imscpConfig{'FRONTEND_ROOT_DIR'},
        CONF_DIR                     => $::imscpConfig{'CONF_DIR'},
        HTTPD_LOG_DIR                => $self->{'config'}->{'HTTPD_LOG_DIR'}
    };

    $self->disableSites( 'default', '00_master.conf', '00_master_ssl.conf' );
    $self->{'eventManager'}->register(
        'beforeFrontEndBuildConf',
        sub {
            my ( $cfgTpl, $tplName ) = @_;

            return unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

            if ( $baseServerIpVersion eq 'ipv6' || ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'no' ) {
                processBlocByRef( $cfgTpl, '# SECTION IPv6 BEGIN.', '# SECTION IPv6 ENDING.' );
            }

            return unless $tplName eq '00_master.nginx';

            if ( ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) eq 'https://' ) {
                processBlocByRef( $cfgTpl, '# SECTION http BEGIN.', '# SECTION http ENDING.' );
                return;
            }

            processBlocByRef( $cfgTpl, '# SECTION https redirect BEGIN.', '# SECTION https redirect ENDING.' );
        }
    );
    $self->buildConfFile( '00_master.nginx', $tplVars, {
        destination => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf",
        user        => $::imscpConfig{'ROOT_USER'},
        group       => $::imscpConfig{'ROOT_GROUP'},
        mode        => 0644
    } );
    $self->enableSites( '00_master.conf' );

    if ( ::setupGetQuestion( 'PANEL_SSL_ENABLED' ) eq 'yes' ) {
        $self->buildConfFile( '00_master_ssl.nginx', $tplVars, {
            destination => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master_ssl.conf",
            user        => $::imscpConfig{'ROOT_USER'},
            group       => $::imscpConfig{'ROOT_GROUP'},
            mode        => 0644
        } );
        $self->enableSites( '00_master_ssl.conf' );
    } else {
        iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master_ssl.conf" )->remove();
    }

    if ( -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf" ) {
        # Nginx package as provided by Nginx Team
        iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf" )->move(
            "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled"
        );
    }
}

=item _addDnsZone( )

 Add DNS zone for the control panel

 Return void, die on failure

=cut

sub _addDnsZone
{
    my ( $self ) = @_;

    # Delete the previous DNS zone file if needed
    if ( length $::imscpOldConfig{'BASE_SERVER_VHOST'} && $::imscpOldConfig{'BASE_SERVER_VHOST'} ne ::setupGetQuestion( 'BASE_SERVER_VHOST' ) ) {
        iMSCP::Servers::Named->factory()->deleteDomain( {
            PARENT_DOMAIN_NAME => $::imscpOldConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $::imscpOldConfig{'BASE_SERVER_VHOST'},
            FORCE_DELETION     => TRUE
        } );
    }

    iMSCP::Servers::Named->factory()->addDomain( {
        BASE_SERVER_VHOST     => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        BASE_SERVER_IP        => ::setupGetQuestion( 'BASE_SERVER_IP' ),
        BASE_SERVER_PUBLIC_IP => ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' ),
        DOMAIN_TYPE           => 'dmn',
        PARENT_DOMAIN_NAME    => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        DOMAIN_NAME           => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        DOMAIN_IP             => ::setupGetQuestion( 'BASE_SERVER_IP' ),
        EXTERNAL_MAIL         => FALSE,
        STATUS                => 'toadd'
    } );
}

=item _addMailDomain( )

 Add mail domain for the control panel

 Return void, die on failure

=cut

sub _addMailDomain
{
    my ( $self ) = @_;

    return if length ::setupGetQuestion( 'BASE_SERVER_VHOST' ) eq ::setupGetQuestion( 'SERVER_HOSTNAME' );

    iMSCP::Servers::Mta->factory()->addDomain( {
        DOMAIN_NAME   => ::setupGetQuestion( 'BASE_SERVER_VHOST' ),
        EXTERNAL_MAIL => FALSE
    } );
}

=item _installSystemFiles()

 Install system files

 Return void, die on failure

=cut

sub _installSystemFiles
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    for my $dir ( 'cron.daily', 'logrotate.d' ) {
        my $fileContentRef = iMSCP::File->new( filename => "$self->{'cfgDir'}/$dir/imscp_frontend" )->getAsRef();
        processVarsByRef( $fileContentRef, {
            WEB_DIR     => $::imscpConfig{'FRONTEND_ROOT_DIR'},
            PANEL_USER  => $usergroup,
            PANEL_GROUP => $usergroup
        } );
        iMSCP::File->new( filename => "/etc/$dir/imscp_frontend" )->set( ${ $fileContentRef } )->save();
    }
}

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'cfgDir'}/frontend.old.data" )->remove();
}

=item _getFullPhpVersionFor( $binaryPath )

 Get full PHP version for the given PHP binary

 Param string $binaryPath Path to PHP binary
 Return int 0 on success, other on failure

=cut

sub _getFullPhpVersionFor
{
    my ( $self, $binaryPath ) = @_;

    my $rs = execute( [ $binaryPath, '-nv' ], \my $stdout, \my $stderr );
    $rs == 0 or die( $stderr || 'Unknown error' );
    return undef unless length $stdout;
    $stdout =~ /PHP\s+([^\s]+)/;
    $1;
}

=item _getNbCPUcores( )

 Get number of available CPU cores

 Return int Number of CPU cores

=cut

sub _getNbCPUcores
{
    execute( 'grep processor /proc/cpuinfo 2>/dev/null | wc -l', \my $stdout );
    $stdout =~ /^(\d+)/;
    $1 || 1;
}

=item _buildConf( \$cfgTpl, $filename [, \%tplVars ] )

 Build the given configuration template

 Param scalarref \$cfgTpl Reference to Temmplate's content
 Param string $filename Template filename
 Param hashref \%tplVars OPTIONAL Template variables
 Return void, die on failure

=cut

sub _buildConf
{
    my ( $self, $cfgTpl, $filename, $tplVars ) = @_;

    $tplVars ||= {};
    $self->{'eventManager'}->trigger( 'beforeFrontEndBuildConf', $cfgTpl, $filename, $tplVars );
    processVarsByRef( $cfgTpl, $tplVars );
    $self->{'eventManager'}->trigger( 'afterFrontEndBuildConf', $cfgTpl, $filename, $tplVars );
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

    for my $dir ( '/etc/default/imscp_panel', '/etc/tmpfiles.d/imscp_panel.conf', "$::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp_panel",
        '/usr/local/sbin/imscp_panel', '/var/log/imscp_panel.log'
    ) {
        iMSCP::File->new( filename => $dir )->remove();
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
    my ( $self ) = @_;

    $self->disableSites( '00_master.conf' );

    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" )->remove();
    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/imscp_fastcgi.conf" )->remove();
    iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/imscp_php.conf" )->remove();

    if ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/default" ) {
        # Nginx as provided by Debian
        $self->enableSites( 'default' );
        return;
    }

    if ( $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && -f "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d/default.conf.disabled" ) {
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
    iMSCP::SystemUser->new( force => 'yes' )->delSystemUser( $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} );
    iMSCP::SystemGroup->getInstance()->delSystemGroup( $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'} );
}

=item END

 Start, restart or reload frontEnd services: nginx or/and imscp_panel when required

 Return int Exit code

=cut

END
    {
        return if $? || iMSCP::Getopt->context() eq 'installer';

        my $instance = __PACKAGE__->hasInstance();

        return unless $instance && ( my $action = $instance->{'restart'}
            ? 'restart' : ( $instance->{'reload'} ? 'reload' : ( $instance->{'start'} ? ' start' : undef ) ) );

        my $nginxAction = "${action}Nginx";
        my $fpmAction = "${action}PhpFpm";

        iMSCP::Service->getInstance()->registerDelayedAction(
            "nginx", [ $action, sub { $instance->$nginxAction(); } ], __PACKAGE__->getPackagePriority()
        );
        iMSCP::Service->getInstance()->registerDelayedAction(
            "imscp_panel", [ $action, sub { $instance->$fpmAction(); } ], __PACKAGE__->getPackagePriority()
        );
    }

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
