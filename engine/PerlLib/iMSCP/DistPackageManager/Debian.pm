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
use iMSCP::Cwd '$CWD';
use iMSCP::Debug qw/ debug getMessageByType /;
use iMSCP::Dialog;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::Stepper qw/ startDetail step endDetail /;
use version;
use parent qw/ Common::Object iMSCP::DistPackageManager::Interface /;

my $APT_SOURCES_LIST_FILE_PATH = '/etc/apt/sources.list';
my $APT_PREFERENCES_FILE_PATH = '/etc/apt/preferences.d/imscp';
my $PBUILDER_DIR = '/var/cache/pbuilder';

=head1 DESCRIPTION

 Debian distribution package manager.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::addRepositories()
 
 Param arrayref \@repositories List of repositories, each represented as a hash with the following key/value pairs:
  repository         : APT repository in format 'uri suite [component1] [component2] [...]' 
  repository_key_srv : APT repository key server such as keyserver.ubuntu.com  (not needed if repository_key_uri is provided)
  repository_key_id  : APT repository key identifier such as 5072E1F5 (not needed if repository_key_uri is provided)
  repository_key_uri : APT repository key URI such as https://packages.sury.org/php/apt.gpg (not needed if repository_key_id is provided)
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub addRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or die( 'Invalid $repositories parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'repositoriesToAdd'} }, @{ $repositories };
        return $self;
    }

    $self->{'eventManager'}->trigger( 'beforeAddDistributionRepositories', $repositories ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    return $self unless @{ $repositories };

    # Make sure that repositories are not added twice
    $self->removeRepositories( [ map { $_->{'repository'} } @{ $repositories } ] );

    my $file = iMSCP::File->new( filename => $APT_SOURCES_LIST_FILE_PATH );
    my $fileC = $file->getAsRef();

    # Add APT repositories
    for my $repository ( @{ $repositories } ) {
        ${ $fileC } .= <<"EOF";

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

    $self->{'eventManager'}->trigger( 'afterAddDistributionRepositories', $repositories ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::removeRepositories()
 
 Param arrayref \@repositories Array containing list of repositories in following format: 'uri suite [component1] [component2] [...]'
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method 

=cut

sub removeRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or die( 'Invalid $repositories parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'repositoriesToRemove'} }, @{ $repositories };
        return $self;
    }

    $self->{'eventManager'}->trigger( 'beforeRemoveDistributionRepositories', $repositories ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    return $self unless @{ $repositories };

    my $file = iMSCP::File->new( filename => $APT_SOURCES_LIST_FILE_PATH );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/^\n?(?:#\s*)?deb(?:-src)?\s+\Q$_\E.*?\n//gm for @{ $repositories };

    $file->save();

    $self->{'eventManager'}->trigger( 'afterRemoveDistributionRepositories', $repositories ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or die( 'Invalid $packages parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToInstall'} }, @{ $packages };
        return $self;
    }

    $self->{'eventManager'}->trigger( 'beforeInstallDistributionPackages', $packages ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    return $self unless @{ $packages };

    # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
    execute( [ 'apt-mark', 'unhold', @{ $packages } ], \my $stdout, \my $stderr );

    iMSCP::Dialog->getInstance()->endGauge();

    local $ENV{'UCF_FORCE_CONFFNEW'} = TRUE;
    local $ENV{'UCF_FORCE_CONFFMISS'} = TRUE;
    local $ENV{'LANG'} = 'C';

    my @cmd = (
        ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ), 'apt-get', '--assume-yes', '--auto-remove', '--purge',
        ( version->parse( `apt-get --version 2>/dev/null` =~ /^apt\s+(\d\.\d)/ ) < version->parse( '1.1' ) ? '--force-yes' : '--allow-downgrades' ),
        'install'
    );

    execute( [ @cmd, @{ $packages } ], ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ), \$stderr ) == 0 or die(
        sprintf( "Couldn't install packages: %s", $stderr || 'Unknown error' )
    );

    $self->{'eventManager'}->trigger( 'afterInstallDistributionPackages', $packages ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
    $self;
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or die( 'Invalid $packages parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToUninstall'} }, @{ $packages };
        return $self;
    }

    $self->{'eventManager'}->trigger( 'beforeUninstallDistributionPackages', $packages ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    return $self unless @{ $packages };

    local $ENV{'LANG'} = 'C';

    # Filter packages that are no longer available or not installed
    # Ignore exit code as dpkg-query exit with status 1 when a queried package is not found
    execute( [ 'dpkg-query', '-W', '-f=${Package}\n', @{ $packages } ], \my $stdout, \my $stderr );
    @{ $packages } = split /\n/, $stdout;

    return $self unless @{ $packages };

    iMSCP::Dialog->getInstance()->endGauge();

    # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
    execute( [ 'apt-mark', 'unhold', @{ $packages } ], \$stdout, \$stderr );
    execute(
        [
            ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
            'apt-get', '--assume-yes', '--auto-remove', 'purge', @{ $packages }
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

    $self->{'eventManager'}->trigger( 'afterUninstallDistributionPackages', $packages ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
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

=item addAPTPreferences( \@preferences [, $delayed = FALSE ] )

 Add the given APT preferences
 
 See APT_PREFERENCES(5) for further details.

 Param arrayref \@preferences Array containing a list of APT preferences each represented as a hash containing the following key/value pairs:
  pinning_package       : List of pinned packages 
  pinning_pin           : origin, version, release
  pinning_pin_priority  : Pin priority
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub addAptPreferences
{
    my ( $self, $preferences, $delayed ) = @_;

    ref $preferences eq 'ARRAY' or die( 'Invalid $preferences parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'aptPreferencesToAdd'} }, @{ $preferences };
        return $self;
    }

    $self->{'eventManager'}->trigger( 'beforeAddDistributionAptPreferences', $preferences ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    # Make sure that preferences are not added twice
    $self->removeAptPreferences( $preferences );

    my $file = iMSCP::File->new( filename => $APT_PREFERENCES_FILE_PATH );
    my $fileC = -f $file->{'filename'} ? $file->get() : <<'EOF';
# APT_PREFERENCES(5) configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
EOF

    for my $preference ( @{ $preferences } ) {
        $fileC .= <<"EOF";

Package: @{ [ $preference->{'pinning_package'} // '*' ] }
Pin: @{ [ $preference->{'pinning_pin'} ] // 'origin ""' }
Pin-Priority: @{ [ $preference->{'pinning_pin_priority'} // '1001' ] }
EOF
    }

    $file->set( $fileC );
    $file->save() == 0 or die( sprintf(
        "Couldn't add APT preferences: %s", getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    ));

    $self->{'eventManager'}->trigger( 'afterAddDistributionAptPreferences', $preferences ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
    $self;
}

=item removeAptPreferences( \@preferences [, $delayed = FALSE ] )

 Remove the given APT preferences
 
 See APT_PREFERENCES(5) for further details.

 Param arrayref \@preferences Array containing a list of APT preferences each represented as a hash with the following key/value pairs:
  pinning_package       : List of pinned packages 
  pinning_pin           : origin, version, release
  pinning_pin_priority  : Pin priority
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub removeAptPreferences
{
    my ( $self, $preferences, $delayed ) = @_;

    ref $preferences eq 'ARRAY' or die( 'Invalid $preferences parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'aptPreferencesToRemove'} }, @{ $preferences };
        return $self;
    }

    return unless -f $APT_PREFERENCES_FILE_PATH;

    $self->{'eventManager'}->trigger( 'beforeRemoveDistributionAptPreferences', $preferences ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    my $file = iMSCP::File->new( filename => $APT_PREFERENCES_FILE_PATH );
    my $fileC = $file->getAsRef();

    for my $preference ( @{ $preferences } ) {
        my $preferencesStanza .= <<"EOF";
Package:\\s+\Q@{ [ $preference->{'pinning_package'} // '*' ] }\E
Pin:\\s+\Q@{ [ $preference->{'pinning_pin'} ] // 'origin ""' }\E
Pin-Priority:\\s+\Q@{ [ $preference->{'pinning_pin_priority'} // 1001 ] }\E
EOF
        ${ $fileC } =~ s/\n*$preferencesStanza//gm;
    }

    $file->save() == 0 or die( sprintf(
        "Couldn't add APT preferences: %s", getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    ));

    $self->{'eventManager'}->trigger( 'afterRemoveDistributionAptPreferences', $preferences ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
    $self;
}

=item processDelayedTasks( )

 Process delayed tasks if any

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub processDelayedTasks
{
    my ( $self ) = @_;

    if ( @{ $self->{'repositoriesToRemove'} } || @{ $self->{'repositoriesToAdd'} } ) {
        $self
            ->removeRepositories( delete $self->{'repositoriesToRemove'} )
            ->addRepositories( delete $self->{'repositoriesToAdd'} )
            ->updateRepositoryIndexes()
    }

    $self
        ->removeAptPreferences( delete $self->{'aptPreferencesToAdd'} )
        ->addAptPreferences( delete $self->{'aptPreferencesToAdd'} )
        ->installPackages( delete $self->{'packagesToInstall'} )
        ->uninstallPackages( delete $self->{'packagesToUninstall'} )
        ->rebuildAndInstallPackages( delete $self->{'packagesToRebuildAndInstall'} );

    @{ $self }{qw/ repositoriesToAdd repositoriesToRemove packagesToInstall packagesToUninstall packagesToRebuildAndInstall /} = (
        [], [], [], [], []
    );

    $self;
}

=item addRepositorySections( sections )

 Add the given sections to all repositories that support them

 Param arrayref $sections Repository sections
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub addRepositorySections
{
    my ( $self, $sections ) = @_;

    local $ENV{'LANG'} = 'C';

    my $file = iMSCP::File->new( filename => $APT_SOURCES_LIST_FILE_PATH );
    defined( my $fileC = $file->get()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );

    for my $section ( @{ $sections } ) {
        my @seenRepositories = ();
        my $foundSection = FALSE;

        while ( $fileC =~ /^deb\s+(?<uri>(?:https?|ftp)[^\s]+)\s+(?<dist>[^\s]+)\s+(?<components>.+)$/gm ) {
            my $rf = $&;
            my %rc = %+;
            next if grep ($_ eq "$rc{'uri'} $rc{'dist'}", @seenRepositories);
            push @seenRepositories, "$rc{'uri'} $rc{'dist'}";

            if ( $fileC !~ /^deb\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {
                my $rs = execute(
                    [ 'wget', '--prefer-family=IPv4', '--timeout=30', '--spider', "$rc{'uri'}/dists/$rc{'dist'}/$section/" =~ s{([^:])//}{$1/}gr ],
                    \my $stdout,
                    \my $stderr
                );
                debug( $stdout ) if $stdout;
                debug( $stderr || 'Unknown error' ) if $rs && $rs != 8;
                next if $rs; # Don't check for source archive when binary archive has not been found
                $foundSection = TRUE;
                $fileC =~ s/^($rf)$/$1 $section/m;
                $rf .= " $section";
            } else {
                $foundSection = TRUE;
            }

            if ( $foundSection && $fileC !~ /^deb-src\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {
                my $rs = execute(
                    [ 'wget', '--prefer-family=IPv4', '--timeout=30', '--spider', "$rc{'uri'}/dists/$rc{'dist'}/$section/source/" =~ s{([^:])//}{$1/}gr ],
                    \my $stdout,
                    \my $stderr
                );
                debug( $stdout ) if $stdout;
                debug( $stderr || 'Unknown error' ) if $rs && $rs != 8;

                unless ( $rs ) {
                    if ( $fileC !~ /^deb-src\s+$rc{'uri'}\s+$rc{'dist'}\s.*/m ) {
                        $fileC =~ s/^($rf)/$1\ndeb-src $rc{'uri'} $rc{'dist'} $section/m;
                    } else {
                        $fileC =~ s/^($&)$/$1 $section/m;
                    }
                }
            }
        }

        $foundSection or die( sprintf( "Couldn't find any repository supporting the '%s' section", $section ));
    }

    $file->set( $fileC );
    $file->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error ' );
    $self;
}

=item rebuildAndInstallPackages( \@packages, $pbuilderConffile [, $delayed = FALSE ] ] )

 Rebuild and install the given packages
 
 Param hashref \@packages List of package to rebuild and install, each represented as a hash with the following key/value pairs:
  package         : Package name
  package_src     : Package source name
  patches_manager : Patches manager (either dpatch or quilt, default to quilt)
  patches_dir     : OPTIONAL Path to directory containing patches (relative to $CWD)
  discard_patches : OPTIONAL list of patches to discard
 Param string $pbuilderConffile Pbuilder configuration file path
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method
 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub rebuildAndInstallPackages
{
    my ( $self, $packages, $pbuilderConffile, $delayed ) = @_;

    ref $packages eq 'ARRAY' or die( 'Invalid $packages parameter. ARRAY expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToRebuildAndInstall'} }, @{ $packages };
        return $self;
    }

    local $ENV{'LANG'} = 'C';
    CORE::state $needPbuilderUpdate = TRUE;

    my $lsbRelease = iMSCP::LsbRelease->getInstance();
    my $distCodename = lc $lsbRelease->getCodename( TRUE );
    my $distID = lc $lsbRelease->getId( 1 );
    undef $lsbRelease;

    defined $pbuilderConffile && ref \$pbuilderConffile eq 'SCALAR' or die( 'Missing or invalid $pbuilderConffile parameter. SCALAR expected.' );

    # Avoid pbuilder warning due to missing /root/.pbuilderrc file
    iMSCP::File->new( filename => '/root/.pbuilderrc' )->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));

    my $pbuilderBuildResultDir = File::Temp->newdir( CLEANUP => TRUE );

    for my $package ( @{ $packages } ) {
        defined $package->{'package'} && ref \$package->{'package'} eq 'SCALAR' or die( "Missing or invalid 'package' key." );
        $package->{'package_src'} //= $package->{'package'};
        ref \$package->{'package_src'} eq 'SCALAR' or die( "Invalid 'package_src' key." );

        if ( defined $package->{'patches_dir'} ) {
            ref \$package->{'patches_dir'} eq 'SCALAR' && -d $package->{'patches_dir'} or die( "Invalid 'patches_dir' key." );
            $package->{'patches_dir'} = "$CWD/$package->{'patches_dir'}";

            $package->{'patches_manager'} //= 'quilt';
            ref \$package->{'patches_manager'} eq 'SCALAR' && grep ( $package->{'patches_manager'} eq $_, 'quilt', 'dpatch') or die(
                "Invalid 'patches_manager' key."
            );
            $package->{'discard_patches'} //= [];
            ref $package->{'discard_patches'} eq 'ARRAY' or die( "Invalid 'discard_patches' key." );
        }

        my $srcDownloadDir = File::Temp->newdir( CLEANUP => TRUE );

        if ( ( undef, undef, my $uid ) = getpwnam( '_apt' ) ) {
            # Fix 'W: Download is performed unsandboxed as root as file...' warning with newest APT versions
            chown $uid, -1, $srcDownloadDir or die( sprintf( "Couldn't change ownership for the %s directory: %s", $srcDownloadDir, $! ));
        }

        local $CWD = $srcDownloadDir;

        startDetail();

        my $rs = step(
            sub {
                return 0 unless $needPbuilderUpdate;
                $needPbuilderUpdate = FALSE;
                my $msgHeader = "Creating/Updating pbuilder environment\n\n - ";
                my $msgFooter = "\n\nPlease be patient. This may take few minutes...";
                my $stderr = '';
                my $cmd = [
                    'pbuilder', ( -f "$PBUILDER_DIR/base.tgz" ? ( '--update', '--autocleanaptcache' ) : '--create' ),
                    '--distribution', $distCodename, '--configfile', $pbuilderConffile, '--override-config'
                ];
                executeNoWait(
                    $cmd,
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 1 );
                    } ),
                    sub { $stderr .= shift; }
                ) == 0 or die( "Couldn't create/update pbuilder environment: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            'Creating/Updating pbuilder environment', 5, 1
        );
        $rs ||= step(
            sub {
                my $msgHeader = "Downloading $package->{'package_src'}, $distID source package\n\n - ";
                my $msgFooter = "\nDepending on your system this may take few seconds...";
                my $stderr = '';
                executeNoWait(
                    [ 'apt-get', '-y', 'source', $package->{'package_src'} ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                        step( undef, $msgHeader . ( ( shift ) =~ s/^\s*//r ) . $msgFooter, 5, 2 ); }
                    ),
                    sub { $stderr .= shift }
                ) == 0 or die( "Couldn't download packageSrc Debian source package: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            "Downloading $package->{'package_src'} $distID source package", 5, 2
        );

        local $CWD = ( glob( "$package->{'package_src'}-*" ) )[0];

        $rs ||= step(
            sub {

                if ( defined $package->{'patches_dir'} ) {
                    my $file = iMSCP::File->new( filename => "debian/patches/@{ [ $package->{'patches_manager'} eq 'quilt' ? 'series' : '00list' ] }" );
                    my $fileC = $file->getAsRef();
                    defined $fileC or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));

                    for my $patch ( sort { $a cmp $b } iMSCP::Dir->new( dirname => $package->{'patches_dir'} )->getFiles() ) {
                        next if grep ( $patch eq $_, @{ $package->{'discard_patches' } } );
                        ${ $fileC } .= "$patch\n";
                        iMSCP::File->new(
                            filename => "$package->{'patches_dir'}/$patch" )->copyFile( "debian/patches/$patch", { preserve => 'no' }
                        ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                    }

                    $file->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                }

                my $stderr;
                execute(
                    [ 'dch', '--local', '~i-mscp-', 'Rebuilt by i-MSCP internet Multi Server Control panel.' ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \my $stdout ),
                    \$stderr
                ) == 0 or die( sprintf( "Couldn't add 'imscp' local suffix: %s", $stderr || 'Unknown error' ));
                debug( $stdout ) if $stdout;
                0;
            },
            "Patching $package->{'package_src'} $distID source package...", 5, 3
        );
        $rs ||= step(
            sub {
                my $msgHeader = "Building new $package->{'package'} $distID package\n\n - ";
                my $msgFooter = "\n\nPlease be patient. This may take few seconds...";
                my $stderr;
                executeNoWait(
                    [ 'pdebuild', '--use-pdebuild-internal', '--buildresult', $pbuilderBuildResultDir, '--configfile', $pbuilderConffile ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 4 );
                    } ),
                    sub { $stderr .= shift }
                ) == 0 or die( "Couldn't build local $package->{'package'} $distID package: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            "Building local $package->{'package'} $distID package", 5, 4
        );

        unless ( $rs == 0 ) {
            endDetail();
            die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
        }
    }

    my @packages = map { $_->{'package'} } @{ $packages };

    my $rs = step(
        sub {
            local $CWD = $pbuilderBuildResultDir;


            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'unhold', @packages ], \my $stdout, \my $stderr );

            for my $package ( @packages ) {
                my $msgHeader = "Installing local $package $distID package\n\n";
                $stderr = '';
                executeNoWait(
                    "gdebi --non-interactive ${package}_*.deb",
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub { step( undef, $msgHeader . ( shift ), 5, 5 ) } ),
                    sub { $stderr .= shift }
                ) == 0 or die( "Couldn't install local $package $distID package: @{ [ $stderr || 'Unknown error' ] }" );
            }

            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'hold', @packages ], \$stdout, \$stderr );
            0;
        },
        "Installing local @packages $distID package(s)", 5, 5
    );
    unless ( $rs == 0 ) {
        endDetail();
        die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
    }

    endDetail();

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    delete $ENV{'DEBCONF_FORCE_DIALOG'};

    $ENV{'DEBIAN_FRONTEND'} = iMSCP::Getopt->noprompt ? 'noninteractive' : 'dialog';
    #$ENV{'DEBIAN_SCRIPT_DEBUG'} = TRUE if iMSCP::Getopt->debug;
    $ENV{'DEBFULLNAME'} = 'i-MSCP Installer';
    $ENV{'DEBEMAIL'} = 'dev@i-mscp.net';

    @{ $self }{qw/ repositoriesToAdd repositoriesToRemove packagesToInstall packagesToUninstall packagesToRebuildAndInstall /} = (
        [], [], [], [], []
    );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
