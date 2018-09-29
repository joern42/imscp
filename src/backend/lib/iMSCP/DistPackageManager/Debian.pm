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
use Carp 'croak';
use File::Basename 'basename';
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Cwd '$CWD';
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::ProgramFinder;
use iMSCP::Stepper qw/ startDetail endDetail step /;
use POSIX ();
use parent qw/ iMSCP::Common::Object iMSCP::DistPackageManager::Interface /;

use constant ISATTY => POSIX::isatty \*STDOUT;

BEGIN {
    local $@;
    # Get File::Copy or fake 
    eval { require File::Copy } or require iMSCP::Faker;
    # Get iMSCP::Debug or fake it
    eval { require iMSCP::Debug } or require iMSCP::Faker;
}

my $APT_SOURCES_LIST_FILE_PATH = '/etc/apt/sources.list';
my $APT_PREFERENCES_FILE_PATH = '/etc/apt/preferences.d/imscp';
my $PBUILDER_DIR = '/var/cache/pbuilder';

=head1 DESCRIPTION

 Debian distribution package manager.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::addRepositories()
 
 See also SOURCES.LIST(5)
 
 Param arrayref \@repositories List of repositories, each represented as a hash with the following key/value pairs:
  repository         : APT repository in format '[options] uri suite [component1] [component2] [...]' excluding type (deb|deb-src) 
  repository_key_srv : APT repository key server such as keyserver.ubuntu.com  (not needed if repository_key_uri is provided)
  repository_key_id  : APT repository key identifier such as 5072E1F5 (not needed if repository_key_uri is provided)
  repository_key_uri : APT repository key URI such as https://packages.sury.org/php/apt.gpg (not needed if repository_key_id is provided)
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method

=cut

sub addRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or croak( 'Invalid $repositories parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'repositoriesToAdd'} }, @{ $repositories };
        return $self;
    }

    return $self unless @{ $repositories };

    open my $fh, '+<', $APT_SOURCES_LIST_FILE_PATH or die( $! );
    my $fileC = do { local $/, scalar readline $fh };

    # Add APT repositories
    for my $repository ( @{ $repositories } ) {
        # Make sure that $repository isn't added twice
        $fileC =~ s/^\n?(?:#\s*)?deb(?:-src)?\s+\Q$repository->{'repository'}\E.*?\n//gm;
        # Add ther repository
        $fileC .= <<"EOF";

deb $repository->{'repository'}
deb-src $repository->{'repository'}
EOF

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
                [ 'wget', '--prefer-family=IPv4', '--timeout=30', '-O', $keyFile, $repository->{'repository_key_uri'} ],
                \my $stdout,
                \my $stderr
            );
            debug( $stdout ) if length $stdout;
            $rs == 0 or die( $stderr || 'Unknown error' );

            $rs = execute( [ 'apt-key', 'add', $keyFile ], \$stdout, \$stderr );
            debug( $stdout ) if length $stdout;
            $rs == 0 or die( $stderr || 'Unknown error' );
        }
    }

    seek( $fh, 0, 0 ) or die( $! );
    print { $fh } $fileC;
    close( $fh ) or die( $! );
    $self;
}

=item removeRepositories( \@repositories [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::removeRepositories()
 
 Param arrayref \@repositories Array containing list of repositories in following format: 'uri suite [component1] [component2] [...]'
 Param boolean $delayed Flag allowing to delay processing till the next call of the processDelayedTasks() method 

=cut

sub removeRepositories
{
    my ( $self, $repositories, $delayed ) = @_;

    ref $repositories eq 'ARRAY' or croak( 'Invalid $repositories parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'repositoriesToRemove'} }, @{ $repositories };
        return $self;
    }

    return $self unless @{ $repositories } && -f $APT_SOURCES_LIST_FILE_PATH;

    open my $fh, '+<', $APT_SOURCES_LIST_FILE_PATH or die( $! );
    my $fileC = do { local $/, scalar readline $fh };
    $fileC =~ s/^\n?(?:#\s*)?deb(?:-src)?\s+\Q$_\E.*?\n//gm for @{ $repositories };
    seek( $fh, 0, 0 ) or die( $! );
    print { $fh } $fileC;
    close $fh or die( $! );
    $self;
}

=item installPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or croak( 'Invalid $packages parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToInstall'} }, @{ $packages };
        return $self;
    }

    return $self unless @{ $packages };

    my ( $stdout, $stderr );
    CORE::state $apt11 = !execute( 'dpkg --compare-versions $(dpkg-query --show --showformat \'${Version}\' apt) ge 1.1', \$stdout, \$stderr );

    execute(
        _getAptGetCommand(
            '--assume-yes', '--auto-remove', '--purge', '--no-install-recommends', '--option', 'Dpkg::Options::=--force-confnew',
            '--option', 'Dpkg::Options::=--force-confmiss', '--option', 'Dpkg::Options::=--force-overwrite',
            ( $apt11 ? '--allow-downgrades' : '--force-yes' ), 'install', @{ $packages }
        ),
        ( iMSCP::Getopt->noninteractive && !iMSCP::Getopt->verbose ? \$stdout : undef ),
        \$stderr
    ) == 0 or die( sprintf( "Couldn't install packages: %s", $stderr || 'Unknown error' ));

    $self;
}

=item uninstallPackages( \@packages [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface::uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, $packages, $delayed ) = @_;

    ref $packages eq 'ARRAY' or croak( 'Invalid $packages parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToUninstall'} }, @{ $packages };
        return $self;
    }

    return $self unless @{ $packages };

    # Filter packages that are no longer available or not installed
    # Ignore exit code as dpkg-query exit with status 1 when a queried package is not found
    execute( [ 'dpkg-query', '-W', '-f=${Package}\n', @{ $packages } ], \my $stdout, \my $stderr );
    @{ $packages } = split /\n/, $stdout;

    return $self unless @{ $packages };

    execute(
        _getAptGetCommand( '--assume-yes', '--auto-remove', '--ignore-hold', 'purge', @{ $packages } ),
        iMSCP::Getopt->noninteractive && !iMSCP::Getopt->verbose ? \$stdout : undef,
        \$stderr
    ) == 0 or die( sprintf( "Couldn't uninstall packages: %s", $stderr || 'Unknown error' ));

    # Purge packages that were marked for removal but for which configuration
    # files are still present (RC)
    #execute(
    #    "@{ _getAptGetCommand( '--assume-yes', '--auto-remove', '--ignore-hold', 'purge' ) } \$(dpkg -l | grep ^rc | awk '{print \$2}')",
    #    ( iMSCP::Getopt->noninteractive && !iMSCP::Getopt->verbose ? \$stdout : undef ),
    #    \$stderr
    #) == 0 or die( sprintf( "Couldn't purge packages that are in RC state: %s", $stderr || 'Unknown error' ));

    $self;
}

=item installPerlModules( \@modules [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:installPerlModules()

=cut

sub installPerlModules
{
    my ( $self, $modules, $delayed ) = @_;

    ref $modules eq 'ARRAY' or croak( 'Invalid $modules parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'perlModulesToInstall'} }, @{ $modules };
        return $self;
    }

    return $self unless @{ $modules };

    iMSCP::Stepper::startDetail();

    my ( $countPackages, $step, $stderr ) = ( scalar @{ $modules }+1, 1 );
    my $msgHeader = "Installing/Updating Perl modules from CPAN:\n\n - ";
    my $msgFooter = "\nPlease be patient. This may take few seconds...";
    my $rs = step(
        sub {
            executeNoWait(
                [ 'cpanm', '--notest', '--quiet', '--no-lwp', @{ $modules } ],
                iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                    return if $_[0] =~ /distributions? installed/i;
                    step( undef, $msgHeader . $_[0] =~ s/successfully installed/Installed/ir . $msgFooter, $countPackages, $step++ );
                },
                sub { $stderr .= $_[0]; }
            ) == 0 or die( sprintf( "Couldn't install Perl modules: %s", $stderr || 'Unknown error' ));
            0;
        },
        $msgHeader . "Initialization...\n" . $msgFooter,
        $countPackages,
        $step++
    );
    unless ( $rs == 0 ) {
        iMSCP::Stepper::endDetail();
        die( iMSCP::Debug::getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
    }

    iMSCP::Stepper::endDetail();

    $self;
}

=item uninstallPerlModule( \@modules [, $delayed = FALSE ] )

 See iMSCP::DistPackageManager::Interface:uninstallPerlModules()

=cut

sub uninstallPerlModules
{
    my ( $self, $modules, $delayed ) = @_;

    ref $modules eq 'ARRAY' or croak( 'Invalid $modules parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'perlModulesToUninstall'} }, @{ $modules };
        return $self;
    }

    return $self unless @{ $modules };

    iMSCP::Stepper::startDetail();

    my ( $countPackages, $step, $stderr ) = ( scalar @{ $modules }+1, 1 );
    my $msgHeader = "Uninstalling Perl modules from CPAN:\n\n - ";
    my $msgFooter = "\nPlease be patient. This may take few seconds...";
    my $rs = step(
        sub {
            executeNoWait(
                [ 'cpanm', '--uninstall', '--quiet', @{ $modules } ],
                iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                    step( undef, $msgHeader . $_[0] =~ s/successfully uninstalled/Uninstalled/ir . $msgFooter, $countPackages, $step++ );
                },
                sub { $stderr .= $_[0]; }
            ) == 0 or die( sprintf( "Couldn't install Perl modules: %s", $stderr || 'Unknown error' ));
            0;
        },
        $msgHeader . "Initialization...\n" . $msgFooter,
        $countPackages,
        $step++
    );
    unless ( $rs == 0 ) {
        iMSCP::Stepper::endDetail();
        die( iMSCP::Debug::getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
    }

    iMSCP::Stepper::endDetail();

    $self;
}

=item updateRepositoryIndexes( )

 See iMSCP::DistPackageManager::Interface::updateRepositoryIndexes()

=cut

sub updateRepositoryIndexes
{
    my ( $self ) = @_;

    iMSCP::Dialog->getInstance()->endGauge();

    my ( $stdout, $stderr );
    execute( _getAptGetCommand( 'update' ), iMSCP::Getopt->noninteractive && !iMSCP::Getopt->verbose ? \$stdout : undef, \$stderr ) == 0 or die(
        sprintf( "Couldn't update APT repository indexes: %s", $stderr || 'Unknown error' )
    );
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

    ref $preferences eq 'ARRAY' or croak( 'Invalid $preferences parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'aptPreferencesToAdd'} }, @{ $preferences };
        return $self;
    }

    return $self unless @{ $preferences };

    # Make sure that preferences are not added twice
    $self->removeAptPreferences( $preferences );

    open my $fh, '+<', $APT_SOURCES_LIST_FILE_PATH or die( $! );
    my $fileC = do { local $/, scalar readline $fh } || <<'EOF';
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

    seek( $fh, 0, 0 ) or die( $! );
    print { $fh } $fileC;
    close( $fh ) or die( $! );

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

    ref $preferences eq 'ARRAY' or croak( 'Invalid $preferences parameter. Array expected' );

    if ( $delayed ) {
        push @{ $self->{'aptPreferencesToRemove'} }, @{ $preferences };
        return $self;
    }

    return $self unless @{ $preferences } && -f $APT_PREFERENCES_FILE_PATH;

    open my $fh, '+<', $APT_SOURCES_LIST_FILE_PATH or die( $! );
    my $fileC = do { local $/, scalar readline $fh };

    for my $preference ( @{ $preferences } ) {
        my $preferencesStanza .= <<"EOF";
Package:\\s+\Q@{ [ $preference->{'pinning_package'} // '*' ] }\E
Pin:\\s+\Q@{ [ $preference->{'pinning_pin'} ] // 'origin ""' }\E
Pin-Priority:\\s+\Q@{ [ $preference->{'pinning_pin_priority'} // 1001 ] }\E
EOF
        $fileC =~ s/\n*$preferencesStanza//gm;
    }

    seek( $fh, 0, 0 ) or die( $! );
    print { $fh } $fileC;
    close( $fh ) or die( $! );

    $self;
}

=item processDelayedTasks( )

 Process delayed tasks if any

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub processDelayedTasks
{
    my ( $self ) = @_;

    iMSCP::Debug::debug( 'Processing delayed tasks...' );

    if ( @{ $self->{'repositoriesToRemove'} } || @{ $self->{'repositoriesToAdd'} } ) {
        $self
            ->removeRepositories( delete $self->{'repositoriesToRemove'} )
            ->addRepositories( delete $self->{'repositoriesToAdd'} )
    }

    $self
        ->updateRepositoryIndexes()
        ->addAptPreferences( delete $self->{'aptPreferencesToAdd'} )
        ->installPackages( delete $self->{'packagesToInstall'} )
        ->uninstallPackages( delete $self->{'packagesToUninstall'} )
        ->rebuildAndInstallPackages( delete $self->{'packagesToRebuildAndInstall'} )
        ->installPerlModules( delete $self->{'perlModulesToInstall'} )
        ->uninstallPerlModules( delete $self->{'perlModulesToUninstall'} );

    @{ $self }{
        qw/
            repositoriesToAdd repositoriesToRemove aptPreferencesToAdd packagesToInstall packagesToUninstall packagesToRebuildAndInstall
            perlModulesToInstall perlModulesToUninstall
        /
    } = ( [], [], [], [], [], [], [], [] );

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

    ref $sections eq 'ARRAY' or croak( 'Invalid $sections parameter. ARRAY expected' );

    return $self unless @{ $sections };

    open my $fh, '+<', $APT_SOURCES_LIST_FILE_PATH or die $!;
    my $fileC = do { local $/, scalar readline $fh };

    for my $section ( @{ $sections } ) {
        my @seenRepositories = ();
        my $foundSection = FALSE;

        while ( $fileC =~ /^deb\s+((?:https?|ftp)[^\s]+)\s+([^\s]+)\s+(.+)$/gm ) {
            my $rf = $&;
            my %rc = ( 'uri', $1, 'dist', $2, 'components', $3 );
            next if grep ("$rc{'uri'} $rc{'dist'}" eq $_, @seenRepositories);
            push @seenRepositories, "$rc{'uri'} $rc{'dist'}";

            if ( $fileC !~ /^deb\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {

                my $rs = execute(
                    [
                        'wget', '--quiet', '--prefer-family=IPv4', '--timeout=30', '--spider',
                        "$rc{'uri'}/dists/$rc{'dist'}/$section/" =~ s{([^:])//}{$1/}gr
                    ],
                    undef,
                    \my $stderr
                );
                iMSCP::Debug::debug( $stderr || 'Unknown error' ) if $rs && $rs != 8;
                next if $rs; # Don't check for source archive when binary archive has not been found
                $foundSection = TRUE;
                $fileC =~ s/^($rf)$/$1 $section/m;
                $rf .= " $section";
            } else {
                $foundSection = TRUE;
            }

            exit;
            if ( $foundSection && $fileC !~ /^deb-src\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {
                my $rs = execute(
                    [
                        'wget', '--prefer-family=IPv4', '--timeout=30', '--spider',
                        "$rc{'uri'}/dists/$rc{'dist'}/$section/source/" =~ s{([^:])//}{$1/}gr
                    ],
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

    seek( $fh, 0, 0 ) or die( $! );
    print { $fh } $fileC;
    close( $fh ) or die( $! );
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

    ref $packages eq 'ARRAY' or croak( 'Invalid $packages parameter. ARRAY expected' );

    if ( $delayed ) {
        push @{ $self->{'packagesToRebuildAndInstall'} }, @{ $packages };
        return $self;
    }

    return $self unless @{ $packages };

    CORE::state $needPbuilderUpdate = TRUE;

    my $lsbRelease = iMSCP::LsbRelease->getInstance();
    my $distCodename = lc $lsbRelease->getCodename( TRUE );
    my $distID = lc $lsbRelease->getId( 1 );
    undef $lsbRelease;

    defined $pbuilderConffile && ref \$pbuilderConffile eq 'SCALAR' or die( 'Missing or invalid $pbuilderConffile parameter. SCALAR expected.' );

    # Avoid pbuilder warning due to missing /root/.pbuilderrc file
    open my $fh, '>', '/root/.pbuilderrc' or die( $! );
    close( $fh );

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

        iMSCP::Stepper::startDetail();

        my $rs = iMSCP::Stepper::step(
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
                    iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                        return unless $_[0] =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 1 );
                    },
                    sub { $stderr .= $_[0]; }
                ) == 0 or die( "Couldn't create/update pbuilder environment: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            'Creating/Updating pbuilder environment', 5, 1
        );
        $rs ||= iMSCP::Stepper::step(
            sub {
                my $msgHeader = "Downloading $package->{'package_src'}, $distID source package\n\n - ";
                my $msgFooter = "\nDepending on your system this may take few seconds...";
                my $stderr = '';
                executeNoWait(
                    [ 'apt-get', '--assume-yes', 'source', $package->{'package_src'} ],
                    iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                        step( undef, $msgHeader . ( $_[0] =~ s/^\s*//r ) . $msgFooter, 5, 2 );
                    },
                    sub { $stderr .= $_[0] }
                ) == 0 or die( "Couldn't download packageSrc Debian source package: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            "Downloading $package->{'package_src'} $distID source package", 5, 2
        );

        local $CWD = ( glob( "$package->{'package_src'}-*" ) )[0];

        $rs ||= iMSCP::Stepper::step(
            sub {

                if ( defined $package->{'patches_dir'} ) {
                    open $fh, '+<', "debian/patches/@{ [ $package->{'patches_manager'} eq 'quilt' ? 'series' : '00list' ] }" or die( $! );
                    my $fileC = do { local $/, scalar readline $fh };
                    for my $patch ( map { basename } sort { $a cmp $b } glob( "$package->{'patches_dir'}/*" ) ) {
                        next if grep ( $patch eq $_, @{ $package->{'discard_patches' } } );
                        $fileC .= "$patch\n";
                        File::Copy::copy( "$package->{'patches_dir'}/$patch", "debian/patches/$patch" ) or die( $! );
                    }
                    seek( $fh, 0, 0 ) or die( $! );
                    print $fh, $fileC;
                    close( $fh ) or die( $! );
                }

                my $stderr;
                execute(
                    [ 'dch', '--local', '~i-mscp-', 'Rebuilt by i-MSCP internet Multi Server Control panel.' ],
                    iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : \my $stdout,
                    \$stderr
                ) == 0 or die( sprintf( "Couldn't add 'imscp' local suffix: %s", $stderr || 'Unknown error' ));
                debug( $stdout ) if $stdout;
                0;
            },
            "Patching $package->{'package_src'} $distID source package...", 5, 3
        );
        $rs ||= iMSCP::Stepper::step(
            sub {
                my $msgHeader = "Building new $package->{'package'} $distID package\n\n - ";
                my $msgFooter = "\n\nPlease be patient. This may take few seconds...";
                my $stderr;
                executeNoWait(
                    [ 'pdebuild', '--use-pdebuild-internal', '--buildresult', $pbuilderBuildResultDir, '--configfile', $pbuilderConffile ],
                    iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                        return unless $_[0] =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 4 );
                    },
                    sub { $stderr .= $_[0] }
                ) == 0 or die( "Couldn't build local $package->{'package'} $distID package: @{ [ $stderr || 'Unknown error' ] }" );
                0;
            },
            "Building local $package->{'package'} $distID package", 5, 4
        );

        unless ( $rs == 0 ) {
            iMSCP::Stepper::endDetail();
            die( iMSCP::Debug::getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
        }
    }

    my @packages = map { $_->{'package'} } @{ $packages };

    my $rs = iMSCP::Stepper::step(
        sub {
            local $CWD = $pbuilderBuildResultDir;
            my ( $stdout, $stderr );
            for my $package ( @packages ) {
                my $msgHeader = "Installing local $package $distID package\n\n";
                executeNoWait(
                    "gdebi --non-interactive --options='--ignore-hold' ${package}_*.deb",
                    iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : sub {
                        step( undef, $msgHeader . $_[0], 5, 5 )
                    },
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
        iMSCP::Stepper::endDetail();
        die( iMSCP::Debug::getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
    }

    iMSCP::Stepper::endDetail();
    $self;
}

=back

=head1 PRIVATE METHODS/FUNCTIONS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    # Delete unwanted environment variables that could have been set elsewhere
    delete @{ENV}{qw/ DEBCONF_FORCE_DIALOG PERL5LIB PERL_CPANM_HOME PERL_CPANM_OPT /};

    # Define required environment variables
    @{ENV}{qw/
        APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE DEBIAN_FRONTEND DEBIAN_SCRIPT_DEBUG DEBFULLNAME DEBEMAIL UCF_FORCE_CONFFNEW UCF_FORCE_CONFFMISS
    /} = (
        TRUE, iMSCP::Getopt->noninteractive ? 'noninteractive' : 'dialog', $ENV{'iMSCP_DEVELOP'}, 'i-MSCP Dev Team', 'dev@i-mscp.net', TRUE, TRUE
    );

    @{ $self }{
        qw/
            repositoriesToAdd repositoriesToRemove aptPreferencesToAdd packagesToInstall packagesToUninstall packagesToRebuildAndInstall
            perlModulesToInstall perlModulesToUninstall
        /
    } = ( [], [], [], [], [], [], [], [] );
    $self;
}

=item _getAptGetCommand( @argv )

 Get APT-GET(8) command

 Param list @argv APT-GET(8) command arguments
 Return array APT-GET(8) command, die on failure
=cut

sub _getAptGetCommand
{
    CORE::state $bin = iMSCP::ProgramFinder::find( 'apt-get' ) or die "Couldn't find APT-GET(8) binary.";

    [
        !iMSCP::Getopt->noninteractive && ISATTY && iMSCP::ProgramFinder::find( 'whiptail' )
            && iMSCP::ProgramFinder::find( 'debconf-apt-progress' ) ? ( 'debconf-apt-progress', '--logstderr', '--' ) : (),
        $bin, @_
    ];
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
