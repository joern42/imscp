# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
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

package iMSCP::Requirements;

use strict;
use warnings;
use iMSCP::ProgramFinder;
use version;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Requirement library

=head1 PUBLIC METHODS

=over 4

=item all( )

 Process check for all requirements

 Return undef on success, die on failure

=cut

sub all
{
    my ($self) = @_;

    $self->user();
    $self->_checkPrograms();
    $self->_checkPhpModules();
    $self->_checkPerlModules();
    undef;
}

=item user( )

 Check user under which the script is running

 Return undef on success, die on failure

=cut

sub user
{
    $< == 0 or die( 'This script must be run as root user.' );
    undef;
}

=item checkVersion( $version, $minVersion [, $maxVersion ] )

 Checks for version

 Param string $version Version to match
 Param string $minVersion Min required version
 Param string $maxVersion Max required version
 Return undef on success, die on failure

=cut

sub checkVersion
{
    my (undef, $version, $minVersion, $maxVersion) = @_;

    if ( version->parse( $version ) < version->parse( $minVersion ) ) {
        die( sprintf( "version %s is too old. Minimum supported version is %s\n", $version, $minVersion ));
    }

    if ( $maxVersion && version->parse( $version ) > version->parse( $maxVersion ) ) {
        die( sprintf( "version %s is not supported. Supported versions are %s to %s\n", $version, $minVersion, $maxVersion ));
    }

    undef;
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
    my ($self) = @_;

    $self->{'programs'} = {
        # We only check the PHP version that is required for the i-MSCP frontEnd
        php  => {
            version_command => "%s -nv 2> /dev/null",
            version_regexp  => qr/PHP\s+([\d.]+)/,
            min_version     => '5.6.0',
            max_version     => '7.1.999', # Arbitrary minor version is intentional. We only want reject PHP > 7.1.x
            modules         => [
                # Only mandatories extensions must be listed below
                'ctype', 'curl', 'date', 'dom', 'fileinfo', 'filter', 'ftp', 'gd', 'gettext', 'gmp', 'hash', 'iconv', 'imap', 'intl', 'json',
                'libxml', 'mbstring', 'mcrypt', 'mysqlnd', 'mysqli', 'openssl', 'pcntl', 'pcre', 'PDO', 'pdo_mysql', 'Phar', 'posix', 'pspell',
                'Reflection', 'session', 'SimpleXML', 'sockets', 'SPL', 'xml', 'xmlreader', 'xmlwriter', 'zip', 'zlib', 'Zend OPcache'
            ]
        },
        perl => {
            version_command => "%s -V:version 2> /dev/null",
            version_regexp  => qr/version='([\d.]+)'/,
            min_version     => '5.18.2',
            max_version     => '5.999', # Arbitrary minor version is intentional. We only want reject Perl >= 6
            modules         => {
                'Array::Utils'               => 0.5,
                autouse                      => 1.07, # Core module
                'Bit::Vector'                => 7.3,
                'Capture::Tiny'              => 0.24,
                'Class::Autouse'             => 2.01,
                'Crypt::Blowfish'            => 2.14,
                'Crypt::CBC'                 => 2.33,
                'Crypt::Eksblowfish::Bcrypt' => 0.009,
                'Data::Clone'                => 0.004,
                'Data::Compare'              => 1.22,
                'Data::Dumper'               => 2.145, # Core module
                'Data::Validate::Domain'     => 0.10,
                'Data::Validate::IP'         => 0.22,
                'Date::Parse'                => 2.3000,
                DateTime                     => 1.06,
                DBI                          => 1.630,
                'DBD::mysql'                 => 4.025,
                'Digest::SHA'                => 5.84_01, # Core module
                'Digest::MD5'                => 2.52, # Core module
                'Email::Valid'               => 1.192,
                Encode                       => 2.49, # Core module
                Errno                        => 1.18, # Core module
                Fcntl                        => 1.11, # Core module
                'File::Basename'             => 2.84, # Core module
                'File::chmod'                => 0.40,
                'File::Copy'                 => 2.26, # Core module
                'File::Find'                 => 1.23, # Core module
                'File::HomeDir'              => 1.00,
                'File::Path'                 => 2.09, # Core module
                'File::Spec'                 => 3.40, # Core module
                'File::stat'                 => 1.07, # Core module
                'File::Temp'                 => 0.23, # Core module
                FindBin                      => 1.51, # Core module
                'Getopt::Long'               => 2.39, # Core module
                'Hash::Merge'                => 0.200,
                'IO::Select'                 => 1.21, # Core module
                'IPC::Open3'                 => 1.13, # Core module
                JSON                         => 2.61,
                'JSON::XS'                   => 2.340,
                Lchown                       => 1.01,
                'List::Util'                 => 1.27, # Core module
                'LWP::Simple'                => 6.00,
                'Mail::Address'              => 2.12,
                'MIME::Base64'               => 3.13, # Core module
                'MIME::Entity'               => 5.505,
                'MIME::Parser'               => 5.505,
                'Net::IP'                    => 1.26,
                'Net::LibIDN'                => 0.12,
                'Params::Check'              => 0.36, # Core module
                POSIX                        => 1.32, # Core module
                'Scalar::Util'               => 1.27, # Core module
                'Scalar::Defer'              => 0.23,
                'Sort::Naturally'            => 1.02,
                Symbol                       => 1.07, # Core module
                'Text::Wrap'                 => 2012.0818, # Core module
                'Text::Balanced'             => 2.02, # Core module
                'Tie::File'                  => 0.99, # Core module
                version                      => 0.9902, # Core module
                'XML::Simple'                => 2.20
            }
        }
    };
    $self;
}

=item _checkPrograms( )

 Checks program requirements

 Return undef on success, die on failure

=cut

sub _checkPrograms
{
    my ($self) = @_;

    for ( keys %{$self->{'programs'}} ) {
        $self->{'programs'}->{$_}->{'command_path'} = iMSCP::ProgramFinder::find( $_ ) or die(
            sprintf( "Couldn't find %s executable in \$PATH", $_ )
        );

        next unless $self->{'programs'}->{$_}->{'version_command'};

        eval {
            $self->_programVersions(
                sprintf( $self->{'programs'}->{$_}->{'version_command'}, $self->{'programs'}->{$_}->{'command_path'} ),
                $self->{'programs'}->{$_}->{'version_regexp'},
                $self->{'programs'}->{$_}->{'min_version'},
                $self->{'programs'}->{$_}->{'max_version'}
            );
        };

        die( sprintf( "%s: %s\n", $_, $@ )) if $@;
    }

    undef;
}

=item _programVersions( $versionCommand, $versionRegexp, $minVersion [, $maxVersion ] )

 Check program version

 Param string $versionCommand Command to execute to find program version
 Param regexp $versionRegexp Regexp to find version in command version output string
 Param $minVersion Min required version
 Param $maxVersion Max required version
 Return undef on success, die on failure

=cut

sub _programVersions
{
    my ($self, $versionCommand, $versionRegexp, $minversion, $maxVersion) = @_;

    my $stdout = `$versionCommand 2>/dev/null`;

    $stdout or die( "Couldn't find version. No output\n" );

    if ( $versionRegexp ) {
        $stdout =~ /$versionRegexp/m or die( sprintf( "Couldn't find version. Output was: %s\n", $stdout ));
        $stdout = $1;
    }

    $self->checkVersion( $stdout, $minversion, $maxVersion );
}

=item _checkPhpModules( [ \@modules = $self->{'programs'}->{'php7.1'}->{'modules'} ] )

 Checks that the given PHP modules are available

 Param array \@modules List of modules
 Return undef on success, die on failure

=cut

sub _checkPhpModules
{
    my ($self, $modules) = @_;
    $modules //= $self->{'programs'}->{'php'}->{'modules'};

    open my $fh, '-|', $self->{'programs'}->{'php'}->{'command_path'}, '-d', 'date.timezone=UTC', '-m' or die(
        sprintf( "Couldn't pipe to php command: %s", $! )
    );
    chomp( my @modules = <$fh> );

    my @missingModules = ();
    for my $module( @{$modules} ) {
        push @missingModules, $module unless grep(lc( $_ ) eq lc( $module ), @modules);
    }

    return undef unless @missingModules;

    @missingModules < 2 or die( sprintf( "The following PHP modules are not installed or not enabled: %s\n", join ', ', @missingModules ));
    die( sprintf( "The PHP module %s is not installed or not enabled.\n", pop @missingModules ));
}

=item _checkPerlModules( [ \%modules = $self->{'programs'}->{'perl'}->{'modules'} ])

 Checks that the given Perl modules are availables at the minimum specified version

 params hashref \%modules OPTIOANL Reference to a hash of module name and module minimum version pairs
 Return undef on success, die on failure

=cut

sub _checkPerlModules
{
    my ($self, $modules) = @_;
    $modules //= $self->{'programs'}->{'perl'}->{'modules'};

    my @missingModules = ();

    if ( eval "require Module::Load::Conditional; 1;" ) {
        Module::Load::Conditional->import( 'check_install' );

        local $Module::Load::Conditional::DEPRECATED = 1;
        local $Module::Load::Conditional::FIND_VERSION = 1;
        local $Module::Load::Conditional::FORCE_SAFE_INC = 1;
        local $Module::Load::Conditional::VERBOSE = 0;

        while ( my ($moduleName, $moduleVersion) = each %{$modules} ) {
            my $rv = check_install( module => $moduleName, version => $moduleVersion );
            unless ( $rv && $rv->{'uptodate'} ) {
                push @missingModules, <<"EOF"
$moduleName module@{ [ $rv && $moduleVersion ? "\n - Expected version : >= $moduleVersion\n - Found version    : $rv->{'version'}" : '' ] }         
EOF
            }
        }

        return undef unless @missingModules;
    } else {
        push @missingModules, "Module::Load::Conditional module\n";
    }

    die( sprintf( "The following Perl modules are not installed or don't met version requirements:\n\n%s", join "\n", @missingModules ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
