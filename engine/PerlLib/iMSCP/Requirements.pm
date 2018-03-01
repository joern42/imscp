=head1 NAME

 iMSCP::Requirements - Check for i-MSCP requirements

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

package iMSCP::Requirements;

use strict;
use warnings;
use English;
use iMSCP::ProgramFinder;
use version;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Check for i-MSCP requirements.

=head1 PUBLIC METHODS

=over 4

=items getPhpModuleRequirements( [ $prerequiredOnly = FALSE ] )

 Return list of PHP module requirements
 
 Param bool $prerequiredOnly Flag indicating whether or not only list of pre-required modules must be returned
 Return arrayref List of required PHP modules
 
=cut

sub getPhpModuleRequirements
{
    my ( $self, $prerequiredOnly ) = @_;

    return $self->{'programs'}->{'php'}->{'modules'}->{'prerequired'} if $prerequiredOnly;

    [ @{ $self->{'programs'}->{'php'}->{'modules'}->{'prerequired'} }, @{ $self->{'programs'}->{'php'}->{'modules'}->{'required'} } ];
}

=items getPerlModuleRequirements ( [ $prerequiredOnly = FALSE ] )

 Return array List of Perl module requirements
 
 Param bool $prerequiredOnly Flag indicating whether or not only list of pre-required modules must be returned
 Return hashref List of required Perl modules where each key pairs is module name and version
 
=cut

sub getPerlModuleRequirements
{
    my ( $self, $prerequiredOnly ) = @_;

    return $self->{'programs'}->{'perl'}->{'modules'}->{'prerequired'} if $prerequiredOnly;
    return { %{ $self->{'programs'}->{'perl'}->{'modules'}->{'prerequired'} }, %{ $self->{'programs'}->{'perl'}->{'modules'}->{'required'} } };
}

=item all( )

 Process check for all requirements

 Return self, die if requirements are not meet

=cut

sub all
{
    my ( $self ) = @_;

    $self->user()->checkPrograms()->checkPhpModules()->checkPerlModules();
}

=item user( )

 Check user under which the script is running with privileges of super user

 Return self, die if EUID is not 0;

=cut

sub user
{
    my ( $self ) = @_;

    $EUID == 0 or die( 'This script must be run with the privileges of super user.' );
    $self;
}

=item checkPrograms( )

 Checks program requirements

 Return self, die if program requirements are not meet

=cut

sub checkPrograms
{
    my ( $self ) = @_;

    for my $program ( sort keys %{ $self->{'programs'} } ) {
        eval {
            if ( exists $self->{'programs'}->{$program}->{'version_routine'} ) {
                $self->checkVersion(
                    $self->{'programs'}->{$program}->{'version_routine'}->(),
                    $self->{'programs'}->{$program}->{'min_version'},
                    $self->{'programs'}->{$program}->{'max_version'}
                );
            } else {
                $self->{'programs'}->{$program}->{'command_path'} = iMSCP::ProgramFinder::find( $program ) or die(
                    sprintf( "Couldn't find %s executable in \$PATH", $program )
                );
                $self->_programVersions(
                    sprintf( $self->{'programs'}->{$program}->{'version_pattern'}, $self->{'programs'}->{$program}->{'command_path'} ),
                    $self->{'programs'}->{$program}->{'version_regexp'},
                    $self->{'programs'}->{$program}->{'min_version'},
                    $self->{'programs'}->{$program}->{'max_version'}
                ) if $self->{'programs'}->{$program}->{'version_pattern'};
            }
        };
        !$@ or die( sprintf( "%s %s\n", $program, $@ ));
    }

    $self;
}

=item checkPhpModules( [ \@modules = $self->{'programs'}->{'php7.1'}->{'modules'} ] )

 Checks that the given PHP modules are available

 Param array \@modules List of modules
 Return self, die if PHP module requirements are not meet

=cut

sub checkPhpModules
{
    my ( $self, $modules ) = @_;
    $modules //= $self->getPhpModuleRequirements();

    open my $fh, '-|', $self->{'programs'}->{'php'}->{'command_path'}, '-d', 'date.timezone=UTC', '-m' or die(
        sprintf( "Couldn't pipe to php command: %s", $! )
    );
    chomp( my @modules = <$fh> );

    my @missingModules = ();
    for my $module ( @{ $modules } ) {
        push @missingModules, $module unless grep (lc( $_ ) eq lc( $module ), @modules);
    }

    return $self unless @missingModules;

    @missingModules < 2 or die(
        sprintf( "\nThe following PHP (%s) modules are not installed or not enabled:\n\n %s\n", join ", ", sort @missingModules )
    );
    die( sprintf( "\nThe PHP module %s is not installed or not enabled.\n", pop @missingModules ));
}

=item checkPerlModules( [ \%modules = $self->{'programs'}->{'perl'}->{'modules'} ])

 Checks that the given Perl modules are availables at the minimum specified version

 params hashref \%modules OPTIOANL Reference to a hash of module name and module minimum version pairs
 Return self, die if Perl module requirements are not meet

=cut

sub checkPerlModules
{
    my ( $self, $modules ) = @_;
    $modules //= $self->getPerlModuleRequirements();

    my @missingModules = ();

    if ( eval "require Module::Load::Conditional; 1;" ) {
        Module::Load::Conditional->import( 'check_install' );

        local $Module::Load::Conditional::DEPRECATED = 1;
        local $Module::Load::Conditional::FIND_VERSION = 1;
        local $Module::Load::Conditional::FORCE_SAFE_INC = 1;
        local $Module::Load::Conditional::VERBOSE = 0;

        while ( my ( $moduleName, $moduleVersion ) = each %{ $modules } ) {
            my $rv = check_install( module => $moduleName, version => $moduleVersion );
            unless ( $rv && $rv->{'uptodate'} ) {
                push @missingModules, <<"EOF"
$moduleName @{ [ $rv && $moduleVersion ? "\n - Expected version : >= $moduleVersion\n - Found version    :  = $rv->{'version'}" : '' ] }         
EOF
            }
        }

        return $self unless @missingModules;
    } else {
        push @missingModules, "Module::Load::Conditional module\n";
    }

    die(
        sprintf( "\nThe following Perl modules are not installed or don't meet version requirements:\n\n - %s\n", join ' - ', sort @missingModules )
    );
}

=item checkVersion( $version, $minVersion [, $maxVersion ] )

 Checks the given version

 Param string $version Version to check
 Param string $minVersion Min. version
 Param string $maxVersion OPTIONAL Max. version
 Return self, die if $version version doesn't meet $minVersion and $maxVersion requirements

=cut

sub checkVersion
{
    my ( $self, $version, $minVersion, $maxVersion ) = @_;

    $version = version->parse( $version );
    $minVersion = version->parse( $minVersion );
    $version >= $minVersion or die( sprintf( "version %s is too old. Minimum supported version is %s\n", $version->normal(), $minVersion->normal()));

    return unless defined $maxVersion;

    $maxVersion = version->parse( $maxVersion );
    $version <= $maxVersion or die( sprintf(
        "version %s is not supported. Supported versions are %s to %s\n", $version->normal(), $minVersion->normal(), $maxVersion->normal()
    ));
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Requirements

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'programs'} = {
        facter => {
            version_pattern => '%s --version 2>/dev/null',
            version_regexp  => qr/([\d.]+)/,
            min_version     => '2.5.1',
            max_version     => '2.5.999' # Arbitrary minor version is intentional. We only want reject Facter > 2.5.x
        },
        # We only check the PHP version that is required for the i-MSCP frontEnd
        php    => {
            version_pattern => '%s -nv 2> /dev/null',
            version_regexp  => qr/PHP\s+([\d.]+)/,
            min_version     => '5.6.0',
            max_version     => '7.1.999', # Arbitrary minor version is intentional. We only want reject PHP > 7.1.x
            modules         => {
                prerequired => [],
                required    => [
                    # Only mandatories extensions must be listed below
                    'ctype', 'curl', 'date', 'dom', 'fileinfo', 'filter', 'ftp', 'gd', 'gettext', 'gmp', 'hash', 'iconv', 'imap', 'intl', 'json',
                    'libxml', 'mbstring', 'mcrypt', 'mysqlnd', 'mysqli', 'openssl', 'pcntl', 'pcre', 'PDO', 'pdo_mysql', 'Phar', 'posix', 'pspell',
                    'Reflection', 'session', 'SimpleXML', 'sockets', 'SPL', 'xml', 'xmlreader', 'xmlwriter', 'zip', 'zlib', 'Zend OPcache'
                ]
            }
        },
        perl   => {
            version_routine => sub { $]; },
            #version_pattern => '%s -V:version 2> /dev/null',
            #version_regexp  => qr/version='([\d.]+)'/,
            min_version     => '5.18.2',
            max_version     => '5.999', # Arbitrary minor version is intentional. We only want reject Perl >= 6
            modules         => {
                # Pre-required Perl modules, that is, those used by i-MSCP installer
                # Perl modules which need be installer from CPAN must also be listed
                # in the prerequired section as cpanm is invoked only via distribution
                # installer bootstrap
                prerequired => {
                    # Core modules (always listed in prerequired section)

                    autouse                  => '1.07',
                    'Data::Dumper'           => '2.145',
                    'Digest::SHA'            => '5.84_01',
                    'Digest::MD5'            => '2.52',
                    Encode                   => '2.49',
                    Errno                    => '1.18',
                    Fcntl                    => '1.11',
                    'File::Basename'         => '2.84',
                    'File::Copy'             => '2.26',
                    'File::Find'             => '1.23',
                    'File::Path'             => '2.09',
                    'File::Spec'             => '3.40',
                    'File::Temp'             => '0.23',
                    FindBin                  => '1.51',
                    'Getopt::Long'           => '2.39',
                    'IO::Select'             => '1.21',
                    'IPC::Open3'             => '1.13',
                    'List::Util'             => '1.27',
                    'MIME::Base64'           => '3.13',
                    'Params::Check'          => '0.36',
                    POSIX                    => '1.32',
                    'Scalar::Util'           => '1.27',
                    Symbol                   => '1.07',
                    'Text::Wrap'             => '2012.0818',
                    'Text::Balanced'         => '2.02',
                    'Tie::File'              => '0.99',
                    version                  => '0.9902',

                    # Non-core modules

                    # Need to be installed from CPAN
                    'Array::Utils'           => '0.5',

                    'Capture::Tiny'          => '0.24',
                    'Class::Autouse'         => '2.01',
                    'Data::Compare'          => '1.22',
                    'Data::Validate::Domain' => '0.10',
                    'Data::Validate::IP'     => '0.22',
                    'DateTime::TimeZone'     => '1.63',
                    'File::HomeDir'          => '1.00',
                    'Email::Valid'           => '1.192',
                    JSON                     => '2.61',
                    'JSON::XS'               => '2.340',
                    'List::Compare'          => '0.37',
                    'Net::IP'                => '1.26',

                    # Module used by the Data::Validate::Domain for TLDs validation.
                    # We need always request last available version from CPAN as the
                    # TLDs database is growing days to days.
                    'Net::Domain::TLD'       => '1.75',

                    'Net::LibIDN'            => '0.12',
                    'Scalar::Defer'          => '0.23',
                    'XML::Simple'            => '2.20'
                },
                required    => {
                    # Non-core modules

                    'Crypt::Blowfish'            => '2.14',
                    'Crypt::CBC'                 => '2.33',
                    'Crypt::Eksblowfish::Bcrypt' => '0.009',
                    'Crypt::Rijndael'            => '1.12',
                    'Data::Clone'                => '0.003',
                    'Date::Parse'                => '2.3000',
                    DBI                          => '1.630',
                    'DBD::mysql'                 => '4.025',
                    'Hash::Merge'                => '0.200',
                    'LWP::Simple'                => '6.05',
                    'Mail::Address'              => '2.12',
                    'MIME::Entity'               => '5.505',
                    'MIME::Parser'               => '5.505',
                    'Sort::Naturally'            => '1.02'
                }
            }
        }
    };
    $self;
}

=item _programVersions( $versionCommand, $versionRegexp, $minVersion [, $maxVersion ] )

 Check program version

 Param string $versionCommand Command to execute to find program version
 Param regexp $versionRegexp Regexp to find version in command version output string
 Param $minVersion Min required version
 Param $maxVersion Max required version
 Return void, die if program versionr requirements are not meet

=cut

sub _programVersions
{
    my ( $self, $versionCommand, $versionRegexp, $minversion, $maxVersion ) = @_;

    ( my $stdout = `$versionCommand` ) or die( "Couldn't find version. No output\n" );

    if ( $versionRegexp ) {
        $stdout =~ /$versionRegexp/m or die( sprintf( "Couldn't find version. Output was: %s\n", $stdout ));
        $stdout = $1;
    }

    $self->checkVersion( $stdout, $minversion, $maxVersion );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
