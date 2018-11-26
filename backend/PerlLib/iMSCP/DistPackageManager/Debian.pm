=head1 NAME

 iMSCP::DistPackageManager::Debian - Debian distribution package manager

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

package iMSCP::DistPackageManager::Debian;

use strict;
use warnings;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dialog;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use version;
use parent qw/ iMSCP::Common::Object iMSCP::DistPackageManager::Interface /;

my $APT_SOURCES_LIST_FILE_PATH = '/etc/apt/sources.list';
my $APT_PREFERENCES_FILE_PATH = '/etc/apt/preferences.d/imscp';

=head1 DESCRIPTION

 Debian distribution package manager.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::addRepositories()
 
 Param list @repositories List of repositories, each represented as a hash with the following key/value pairs:
  repository         : APT repository in format 'uri suite [component1] [component2] [...]' 
  repository_key_srv : APT repository key server such as keyserver.ubuntu.com  (not needed if repository_key_uri is provided)
  repository_key_id  : APT repository key identifier such as 5072E1F5 (not needed if repository_key_uri is provided)
  repository_key_uri : APT repository key URI such as https://packages.sury.org/php/apt.gpg (not needed if repository_key_id is provided)

=cut

sub addRepositories
{
    my ( $self, @repositories ) = @_;

    $self->{'eventManager'}->trigger( 'beforeAddDistributionRepositories', \@repositories );

    # Make sure that repositories are not added twice
    $self->removeRepositories( map { $_->{'repository'} } @repositories );

    my $file = iMSCP::File->new( filename => $APT_SOURCES_LIST_FILE_PATH );
    my $fileContent = $file->getAsRef();

    local $ENV{'LANG'} = 'C';

    # Add APT repositories
    for my $repository ( @repositories ) {
        next if ${ $fileContent } =~ /^deb\s+$repository->{'repository'}/m;

        ${ $fileContent } .= <<"EOF";

deb $repository->{'repository'}
deb-src $repository->{'repository'}
EOF
        # Hide "apt-key output should not be parsed (stdout is not a terminal)" warning that
        # is raised in newest apt-key versions. Our usage of apt-key is not dangerous (not parsing)
        local $ENV{'APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE'} = TRUE;

        if ( $repository->{'repository_key_srv'} && $repository->{'repository_key_id'} ) {
            # Add the repository key from the given key server
            my $rs = execute(
                [ 'apt-key', 'adv', '--recv-keys', '--keyserver', $repository->{'repository_key_srv'}, $repository->{'repository_key_id'} ],
                \my $stdout,
                \my $stderr
            );
            debug( $stdout ) if length $stdout;
            $rs == 0 or die( $stderr || 'Unknown error' );

            # Workaround https://bugs.launchpad.net/ubuntu/+source/gnupg2/+bug/1633754
            execute( [ 'pkill', '-TERM', 'dirmngr' ], \$stdout, \$stderr );
        } elsif ( $repository->{'repository_key_uri'} ) {
            # Add the repository key by fetching it first from the given URI
            my $keyFile = File::Temp->new();
            $keyFile->close();
            my $rs = execute(
                [ 'wget', '--prefer-family=IPv4', '--timeout=30', '-O', $keyFile, $repository->{'repository_key_uri'} ], \my $stdout, \my $stderr
            );
            debug( $stdout ) if length $stdout;
            $rs == 0 or die( $stderr || 'Unknown error' );

            $rs = execute( [ 'apt-key', 'add', $keyFile ], \$stdout, \$stderr );
            debug( $stdout ) if length $stdout;
            $rs == 0 or die( $stderr || 'Unknown error' );
        }
    }

    $file->save();

    $self->{'eventManager'}->trigger( 'afterAddDistributionRepositories', \@repositories );
    
    $self->updateRepositoryIndexes();
}

=item removeRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::removeRepositories()
 
 @repositories must contain a list of repository in following format: 'uri suite [component1] [component2] [...]' 

=cut

sub removeRepositories
{
    my ( $self, @repositories ) = @_;

    $self->{'eventManager'}->trigger( 'beforeRemoveDistributionRepositories', \@repositories );
    
    my $file = iMSCP::File->new( filename => $APT_SOURCES_LIST_FILE_PATH );
    my $fileContent = $file->getAsRef();
    ${ $fileContent } =~ s/^\n?(?:#\s*)?deb(?:-src)?\s+\Q$_\E.*?\n//gm for @repositories;
    $file->save();

    $self->{'eventManager'}->trigger( 'afterRemoveDistributionRepositories', \@repositories );

    $self->updateRepositoryIndexes();
}

=item installPackages( @packages )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, @packages ) = @_;

    $self->{'eventManager'}->trigger( 'beforeInstallDistributionPackages', \@packages );
    
    # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
    execute( [ 'apt-mark', 'unhold', @packages ], \my $stdout, \my $stderr );

    iMSCP::Dialog->getInstance()->endGauge() if iMSCP::Getopt->context() eq 'installer';

    local $ENV{'UCF_FORCE_CONFFNEW'} = TRUE;
    local $ENV{'UCF_FORCE_CONFFMISS'} = TRUE;
    local $ENV{'LANG'} = 'C';

    my @cmd = (
        ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
        'apt-get', '--assume-yes', '--option', 'DPkg::Options::=--force-confnew', '--option',
        'DPkg::Options::=--force-confmiss', '--option', 'Dpkg::Options::=--force-overwrite',
        '--auto-remove', '--purge', '--no-install-recommends',
        ( version->parse( `apt-get --version 2>/dev/null` =~ /^apt\s+(\d\.\d)/ ) < version->parse( '1.1' ) ? '--force-yes' : '--allow-downgrades' ),
        'install'
    );

    execute( [ @cmd, @packages ], ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ), \$stderr ) == 0 or die(
        sprintf( "Couldn't install packages: %s", $stderr || 'Unknown error' )
    );

    $self->{'eventManager'}->trigger( 'afterInstallDistributionPackages', \@packages );

    $self;
}

=item uninstallPackages( @packages )

 See iMSCP::DistPackageManager::Interface::uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, @packages ) = @_;

    $self->{'eventManager'}->trigger( 'beforeUninstallDistributionPackages', \@packages );

    local $ENV{'LANG'} = 'C';

    # Filter packages that are no longer available or not installed
    # Ignore exit code as dpkg-query exit with status 1 when a queried package is not found
    execute( [ 'dpkg-query', '-W', '-f=${Package}\n', @packages ], \my $stdout, \my $stderr );
    @packages = split /\n/, $stdout;

    return $self unless @packages;

    iMSCP::Dialog->getInstance()->endGauge() if iMSCP::Getopt->context() eq 'installer';

    # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
    execute( [ 'apt-mark', 'unhold', @packages ], \$stdout, \$stderr );
    execute(
        [
            ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
            'apt-get', '--assume-yes', '--auto-remove', 'purge', @packages
        ],
        ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ),
        \$stderr
    ) == 0 or die( sprintf( "Couldn't uninstall packages: %s", $stderr || 'Unknown error' ));

    # Purge packages that were indirectly removed
    execute(
        "apt-get -y purge \$(dpkg -l | grep ^rc | awk '{print \$2}')",
        ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \$stdout ),
        \$stderr
    ) == 0 or die( sprintf( "Couldn't purge packages that are in RC state: %s", $stderr || 'Unknown error' ));

    $self->{'eventManager'}->trigger( 'afterUninstallDistributionPackages', \@packages );

    $self;
}

=item updateRepositoryIndexes( )

 See iMSCP::DistPackageManager::Interface::updateRepositoryIndexes()

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = @_;

    iMSCP::Dialog->getInstance()->endGauge();

    local $ENV{'LANG'} = 'C';

    my $stdout;
    my $rs = execute(
        [ ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ), 'apt-get', 'update' ],
        ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ), \my $stderr
    );
    $rs == 0 or die( sprintf( "Couldn't update APT repository indexes: %s", $stderr || 'Unknown error' ));
    debug( $stderr );
    $self;
}

=item addAptPreferences( @preferences )

 Add the given APT preferences
 
 See APT_PREFERENCES(5) for further details.

 Param list @preferences List of APT preferences each represented as a hash containing the following key/value pairs:
  pinning_package       : List of pinned packages 
  pinning_pin           : origin, version, release
  pinning_pin_priority  : Pin priority
 Return void, die on failure

=cut

sub addAptPreferences
{
    my ( $self, @preferences ) = @_;

    $self->{'eventManager'}->trigger( 'beforeAddDistributionAptPreferences', \@preferences );

    # Make sure that preferences are not added twice
    $self->removeAptPreferences( @preferences );

    my $file = iMSCP::File->new( filename => $APT_PREFERENCES_FILE_PATH );
    my $fileContent = $file->getAsRef( !-f $file->{'filename'} );

    $$fileContent ||= <<'EOF';
# APT_PREFERENCES(5) configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
EOF
    
    for my $preferences ( @preferences ) {
        ${ $fileContent } .= <<"EOF";

Package: @{ [ $preferences->{'pinning_package'} // '*' ] }
Pin: @{ [ $preferences->{'pinning_pin'} ] // 'origin ""' }
Pin-Priority: @{ [ $preferences->{'pinning_pin_priority'} // 1001 ] }
EOF
    }

    # Remove unwanted leading newline
    ${ $fileContent } =~ s/^\n//;

    $file->save();

    $self->{'eventManager'}->trigger( 'afterAddDistributionAptPreferences', \@preferences );
}

=item removeAptPreferences( @preferences )

 Remove the given APT preferences
 
 See APT_PREFERENCES(5) for further details.

 Param list @preferences List of APT preferences each represented as a hash with the following key/value pairs:
  pinning_package       : List of pinned packages 
  pinning_pin           : origin, version, release
  pinning_pin_priority  : Pin priority
 Return void, die on failure

=cut

sub removeAptPreferences
{
    my ( $self, @preferences ) = @_;

    return unless -f $APT_PREFERENCES_FILE_PATH;

    $self->{'eventManager'}->trigger( 'beforeRemoveDistributionAptPreferences', \@preferences );

    my $file = iMSCP::File->new( filename => $APT_PREFERENCES_FILE_PATH );
    my $fileContent = $file->getAsRef();

    for my $preferences ( @preferences ) {
        my $preferencesStanza .= <<"EOF";
Package:\\s+\Q@{ [ $preferences->{'pinning_package'} // '*' ] }\E
Pin:\\s+\Q@{ [ $preferences->{'pinning_pin'} ] // 'origin ""' }\E
Pin-Priority:\\s+\Q@{ [ $preferences->{'pinning_pin_priority'} // 1001 ] }\E
EOF
        ${ $fileContent } =~ s/\n*$preferencesStanza//gm;
    }

    $file->save();

    $self->{'eventManager'}->trigger( 'afterRemoveDistributionAptPreferences', \@preferences );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
