=head1 NAME

 autoinstaller::Adapter::DebianAdapter - Debian autoinstaller adapter

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
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

package autoinstaller::Adapter::DebianAdapter;

use strict;
use warnings;
use autoinstaller::Functions qw/ expandVars /;
use autouse 'iMSCP::Stepper' => qw/ startDetail endDetail step /;
use Class::Autouse qw/ :nostat File::HomeDir /;
use Fcntl qw/ :flock /;
use File::Temp;
use FindBin;
use iMSCP::Boolean;
use iMSCP::DistPackageManager;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug error output getMessageByType /;
use iMSCP::Dialog;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::ProgramFinder;
use version;
use parent 'autoinstaller::Adapter::AbstractAdapter';

=head1 DESCRIPTION

 i-MSCP autoinstaller adapter implementation for Debian.

=head1 PUBLIC METHODS

=over 4

=item installPreRequiredPackages( )

 Install pre-required packages

 Return int 0 on success, other on failure

=cut

sub installPreRequiredPackages
{
    my ( $self ) = @_;

    print STDOUT output( 'Satisfying prerequisites... Please wait.', 'info' );

    eval {
        $self->_updateAptSourceList() == 0 or die(
            sprintf( "Couldn't update APT source list: %s", getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' )
        );

        iMSCP::DistPackageManager->getInstance()
            ->updateRepositoryIndexes()
            ->installPackages( @{ $self->{'preRequiredPackages'} } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item preBuild( \@steps )

 Process preBuild tasks

 Param array \@steps List of build steps
 Return int 0 on success, other on failure

=cut

sub preBuild
{
    my ( $self, $steps ) = @_;

    return 0 if $main::skippackages;

    unshift @{ $steps },
        (
            [ sub { $self->_processPackagesFile() }, 'Process distribution packages file' ],
            [ sub { $self->_prefillDebconfDatabase() }, 'Pre-fill Debconf database' ],
            [ sub { $self->_addAptRepositories() }, 'Processing APT repositories' ],
            [ sub { $self->_addAptPreferences() }, 'Processing APT preferences' ]
        );

    0
}

=item installPackages( )

 Install Debian packages

 Return int 0 on success, other on failure

=cut

sub installPackages
{
    my ( $self ) = @_;

    eval {
        # See https://people.debian.org/~hmh/invokerc.d-policyrc.d-specification.txt
        my $policyrcd = File::Temp->new( UNLINK => TRUE );

        # Prevents invoke-rc.d (which is invoked by package maintainer scripts) to start some services
        #
        # - Prevent "bind() to 0.0.0.0:80 failed (98: Address already in use" failure (Apache2, Nginx)
        # - Prevent start failure when IPv6 stack is not enabled (Dovecot, Nginx)
        # - Prevent failure when resolvconf is not configured yet (bind9)
        # - ProFTPD daemon making too much time to start with default configuration
        print $policyrcd <<'EOF';
#!/bin/sh

initscript=$1
action=$2

if [ "$action" = "start" ] || [ "$action" = "restart" ]; then
    for i in apache2 bind9 dovecot nginx proftpd; do
        if [ "$initscript" = "$i" ]; then
            exit 101;
        fi
    done
fi
EOF
        $policyrcd->close();
        chmod( 0750, $policyrcd->filename ) or die( sprintf( "Couldn't change permissions on %s: %s", $policyrcd->filename, $! ));

        # See ZG-POLICY-RC.D(8)
        local $ENV{'POLICYRCD'} = $policyrcd->filename();

        iMSCP::DistPackageManager->getInstance()->uninstallPackages( @{ $self->{'packagesToPreUninstall'} } );

        {
            startDetail();
            local $CWD = "$FindBin::Bin/autoinstaller/preinstall";

            for my $subject ( keys %{ $self->{'packagesPreInstallTasks'} } ) {
                my $subjectH = $subject =~ s/_/ /gr;
                my ( $cTask, $nTasks ) = ( 1, scalar @{ $self->{'packagesPreInstallTasks'}->{$subject} } );

                for my $task ( @{ $self->{'packagesPreInstallTasks'}->{$subject} } ) {
                    step(
                        sub {
                            my ( $stdout, $stderr );
                            execute( $task, ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \$stdout ), \$stderr ) == 0 or die(
                                sprintf( 'Error while executing pre-install tasks for %s: %s', $subjectH, $stderr || 'Unknown error' )
                            );
                            0;
                        },
                        sprintf( 'Executing pre-install tasks for %s... Please be patient.', $subjectH ), $nTasks, $cTask++
                    ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
                }
            }

            endDetail();
        }

        for my $packages ( $self->{'packagesToInstall'}, $self->{'packagesToInstallDelayed'} ) {
            next unless @{ $packages };
            iMSCP::DistPackageManager->getInstance()->installPackages( @{ $packages } );
        }

        {
            startDetail();
            local $CWD = "$FindBin::Bin/autoinstaller/postinstall";

            for my $subject ( keys %{ $self->{'packagesPostInstallTasks'} } ) {
                my $subjectH = $subject =~ s/_/ /gr;
                my ( $cTask, $nTasks ) = ( 1, scalar @{ $self->{'packagesPostInstallTasks'}->{$subject} } );

                for my $task ( @{ $self->{'packagesPostInstallTasks'}->{$subject} } ) {
                    step(
                        sub {
                            my ( $stdout, $stderr );
                            execute( $task, ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \$stdout ), \$stderr ) == 0 or die(
                                sprintf( 'Error while executing post-install tasks for %s: %s', $subjectH, $stderr || 'Unknown error' )
                            );
                            0;
                        },
                        sprintf( 'Executing post-install tasks for %s... Please be patient.', $subjectH ), $nTasks, $cTask++
                    ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error' );
                }
            }

            endDetail();
        }

        while ( my ( $package, $metadata ) = each( %{ $self->{'packagesToRebuild'} } ) ) {
            $self->_rebuildAndInstallPackage(
                $package, $metadata->{'pkg_src_name'}, $metadata->{'patches_directory'}, $metadata->{'discard_patches'}, $metadata->{'patch_sys_type'}
            ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        }

        if ( @{ $self->{'packagesToUninstall'} } ) {
            # Filter packages that must be kept or that were already uninstalled
            my %map = map { $_ => undef } @{ $self->{'packagesToInstall'} }, @{ $self->{'packagesToInstallDelayed'} },
                keys %{ $self->{'packagesToRebuild'} }, @{ $self->{'packagesToPreUninstall'} };
            @{ $self->{'packagesToUninstall'} } = grep (!exists $map{$_}, @{ $self->{'packagesToUninstall'} } );

            if ( @{ $self->{'packagesToUninstall'} } ) {
                iMSCP::DistPackageManager->getInstance()->uninstallPackages( @{ $self->{'packagesToUninstall'} } );
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS/FUNCTIONS

=over 4

=item _init( )

 Initialize instance

 Return autoinstaller::Adapter::DebianAdapter

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();

    $self->{'repositorySections'} = [ 'main', 'contrib', 'non-free' ];
    $self->{'preRequiredPackages'} = [
        'apt-transport-https', 'binutils', 'ca-certificates', 'debconf-utils', 'dialog', 'dirmngr', 'dpkg-dev', 'libbit-vector-perl',
        'libclass-insideout-perl', 'libclone-perl', 'liblchown-perl', 'liblist-compare-perl', 'liblist-moreutils-perl', 'libscalar-defer-perl',
        'libsort-versions-perl', 'libxml-simple-perl', 'lsb-release', 'policyrcd-script-zg2', 'wget',
    ];
    $self->{'aptRepositoriesToRemove'} = [];
    $self->{'aptRepositoriesToAdd'} = [];
    $self->{'aptPreferences'} = [];
    $self->{'packagesToInstall'} = [];
    $self->{'packagesToInstallDelayed'} = [];
    $self->{'packagesToPreUninstall'} = [];
    $self->{'packagesToUninstall'} = [];
    $self->{'packagesToRebuild'} = {};
    $self->{'packagesPreInstallTasks'} = {};
    $self->{'packagesPostInstallTasks'} = {};
    $self->{'need_pbuilder_update'} = TRUE;

    delete $ENV{'DEBCONF_FORCE_DIALOG'};

    $ENV{'DEBIAN_FRONTEND'} = 'noninteractive' if iMSCP::Getopt->noprompt;
    $ENV{'DEBFULLNAME'} = 'i-MSCP Installer';
    $ENV{'DEBEMAIL'} = 'team@i-mscp.net';

    $self->_setupGetAddrinfoPrecedence();
    $self;
}

=item _setupGetAddrinfoPrecedence( )

 Setup getaddrinfo(3) precedence (IPv4) for the setup time being

 Return int 0 on success, other on failure

=cut

sub _setupGetAddrinfoPrecedence
{
    my $file = iMSCP::File->new( filename => '/etc/gai.conf' );
    my $fileContent = '';

    if ( -f '/etc/gai.conf' ) {
        $fileContent = $file->get();
        unless ( defined $fileContent ) {
            error( sprintf( "Couldn't read %s file ", $file->{'filename'} ));
            return 1;
        }

        return 0 if $fileContent =~ m%^precedence\s+::ffff:0:0/96\s+100\n%m;
    }

    # Prefer IPv4
    $fileContent .= "precedence ::ffff:0:0/96  100\n";

    $file->set( $fileContent );
    $file->save();
}

=item _parsePackageNode( \%node|$node, \@target )

 Parse a package or package_delayed node

 param string|hashref $node Package node
 param arrayref \@target Target ($self->{'packagesToInstall'}|$self->{'packagesToInstallDelayed'})
 Return void

=cut

sub _parsePackageNode
{
    my ( $self, $node, $target ) = @_;

    unless ( ref $node eq 'HASH' ) {
        # Package without further treatment
        push @{ $target }, $node;
        return;
    }

    # Skip packages for which evaluation of the 'condition' attribute expression (if any) is not TRUE
    return if defined $node->{'condition'} && !eval expandVars( $node->{'condition'} );

    # Per package rebuild task to execute
    if ( $node->{'rebuild_with_patches'} ) {
        $self->{'packagesToRebuild'}->{$node->{'content'}} = {
            pkg_src_name      => $node->{'pkg_src_name'} || $node->{'content'},
            patches_directory => $node->{'rebuild_with_patches'},
            discard_patches   => [ defined $node->{'discard_patches'} ? split ',', $node->{'discard_patches'} : () ],
            patch_sys_type    => $node->{'patch_sys_type'} || 'quilt'
        };
    } else {
        push @{ $target }, $node->{'content'};
    }

    # Per package pre-installation task to execute
    if ( defined $node->{'pre_install_task'} ) {
        push @{ $self->{'packagesPreInstallTasks'}->{$node->{'content'}} }, $_ for @{ $node->{'pre_install_task'} };
    }

    # Per package post-installation task to execute
    if ( defined $node->{'post_install_task'} ) {
        push @{ $self->{'packagesPostInstallTasks'}->{$node->{'content'}} }, $_ for @{ $node->{'post_install_task'} };
    }

    # Per package APT repository to add
    if ( defined $node->{'repository'} ) {
        push @{ $self->{'aptRepositoriesToAdd'} }, {
            repository         => $node->{'repository'},
            repository_key_uri => $node->{'repository_key_uri'},
            repository_key_id  => $node->{'repository_key_id'},
            repository_key_srv => $node->{'repository_key_srv'}
        };
    }

    # Per package APT preferences (pinning) to add
    if ( defined $node->{'pinning_package'} ) {
        push @{ $self->{'aptPreferences'} },
            {
                pinning_package      => $node->{'pinning_package'},
                pinning_pin          => $node->{'pinning_pin'},
                pinning_pin_priority => $node->{'pinning_pin_priority'}
            };
    }
}

=item _processPackagesFile( )

 Process distribution packages file

 Return int 0 on success, other on failure

=cut

sub _processPackagesFile
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'onBuildPackageList', \my $pkgFile );
    return $rs if $rs;

    my $lsbRelease = iMSCP::LsbRelease->getInstance();
    my $distroID = lc $lsbRelease->getId( 'short' );
    my $distroCodename = lc $lsbRelease->getCodename( 'short' );

    require XML::Simple;
    my $xml = XML::Simple->new( NoEscape => TRUE );

    my $pkgData = $xml->XMLin(
        $pkgFile || "$FindBin::Bin/autoinstaller/Packages/$distroID-$distroCodename.xml",
        ForceArray     => [ 'package', 'package_delayed', 'package_conflict', 'pre_install_task', 'post_install_task' ],
        NormaliseSpace => 2
    );

    my $dialog = iMSCP::Dialog->getInstance();
    $dialog->set( 'no-cancel', '' );

    # Make sure that all mandatory sections are defined in the packages file
    for my $section ( qw/ panel_php panel_httpd httpd php po mta ftpd sqld named perl other / ) {
        defined $pkgData->{$section} or die( sprintf( 'Missing %s section in the distribution packages file.', $section ));
    }

    #
    ## Process sections
    #

    # Sort sections to make sure to show dialogs always in same order
    for my $section ( sort keys %{ $pkgData } ) {
        my $data = $pkgData->{$section};

        # Per section packages to install
        if ( defined $data->{'package'} ) {
            for my $node ( @{ delete $data->{'package'} } ) {
                $self->_parsePackageNode( $node, $self->{'packagesToInstall'} );
            }
        }

        # Per section packages to install (delayed)
        if ( defined $data->{'package_delayed'} ) {
            for my $node ( @{ delete $data->{'package_delayed'} } ) {
                $self->_parsePackageNode( $node, $self->{'packagesToInstallDelayed'} );
            }
        }

        # Per section conflicting packages to pre-remove
        if ( defined $data->{'package_conflict'} ) {
            for my $node ( @{ delete $data->{'package_conflict'} } ) {
                push @{ $self->{'packagesToPreUninstall'} }, ref $node eq 'HASH' ? $node->{'content'} : $node;
            }
        }

        # Per section APT repository to add
        if ( defined $data->{'repository'} ) {
            push @{ $self->{'aptRepositoriesToAdd'} }, {
                repository         => delete $data->{'repository'},
                repository_key_uri => delete $data->{'repository_key_uri'},
                repository_key_id  => delete $data->{'repository_key_id'},
                repository_key_srv => delete $data->{'repository_key_srv'}
            };
        }

        # Per section APT preferences (pinning) to add
        if ( defined $data->{'pinning_package'} ) {
            push @{ $self->{'aptPreferences'} }, {
                pinning_package      => delete $data->{'pinning_package'},
                pinning_pin          => delete $data->{'pinning_pin'},
                pinning_pin_priority => delete $data->{'pinning_pin_priority'},
            };
        }

        # Per section pre-installation tasks to execute
        if ( defined $data->{'pre_install_task'} ) {
            push @{ $self->{'packagesPreInstallTasks'}->{$section} }, $_ for @{ delete $data->{'pre_install_task'} };
        }

        # Per section post-installation tasks to execute
        if ( defined $data->{'post_install_task'} ) {
            push @{ $self->{'packagesPostInstallTasks'}->{$section} }, $_ for @{ delete $data->{'post_install_task'} };
        }

        # Jump in next section, unless the section defines alternatives
        next unless %{ $data };

        # Dialog flag indicating whether or not user must be asked for
        # alternative
        my $showDialog = FALSE;

        # Alternative section description
        my $altDesc = ( delete $data->{'description'} ) || $section;

        # Alternative section variable name
        my $varname = ( delete $data->{'varname'} ) || uc( $section ) . '_SERVER';

        # Whether or not full alternative section is hidden
        my $isAltSectionHidden = delete $data->{'hidden'};

        # Retrieve current selected alternative
        my $sAlt = $main::questions{ $varname } || $main::imscpConfig{ $varname } || '';

        # Builds list of selectable alternatives through dialog:
        # - Discard hidden alternatives, that is, those which don't involve any
        #   dialog
        # - Discard alternative for which evaluation of the 'condition'
        #   attribute expression (if any) is FALSE
        my @sAlts = $isAltSectionHidden ? keys %{ $data } : grep {
            !$data->{$_}->{'hidden'} && !defined $data->{$_}->{'condition'} || eval expandVars( $data->{$_}->{'condition'} )
        } keys %{ $data };

        # The sqld section needs a specific treatment
        _processSqldSection( \@sAlts, $dialog ) if $section eq 'sqld';

        # If there is a selected alternative which is unknown, we discard
        # it. In the preseed mode this will lead to a FATAL error (expected).
        $sAlt = '' if length $sAlt && !grep { $_ eq $sAlt } @sAlts;

        # If there is no alternative selected
        unless ( length $sAlt ) {
            # We select the default alternative as defined in the packages file
            # or the first entry if there are no default, and we set the dialog
            # flag to make the user able to change it unless there is only one
            # alternative available.
            ( $sAlt ) = grep { $data->{$_}->{'default'} } @sAlts;
            $sAlt ||= $sAlts[0];
            $showDialog = TRUE unless @sAlts < 2;
        }

        # Set the dialog flag in any case if there are many alternatives
        # available and if user asked for alternative reconfiguration
        $showDialog ||= @sAlts > 1 && grep( iMSCP::Getopt->reconfigure eq $_, $section, 'servers', 'all' );

        # Process alternative dialogs
        if ( $showDialog ) {
            local $dialog->{'_opts'}->{'no-cancel'} = '';
            my %choices;
            @choices{ values @sAlts } = map { $data->{$_}->{'description'} // $_ } @sAlts;

            ( my $ret, $sAlt ) = $dialog->radiolist( <<"EOF", \%choices, $sAlt );

Please select the $altDesc:
\\Z \\Zn
EOF
            exit $ret if $ret; # Handle ESC case
        }

        #
        ## Process alternatives data
        #

        while ( my ( $alt, $altData ) = each( %{ $data } ) ) {
            # Process data for the selected alternative or those which need to
            # be always installed
            if ( $alt eq $sAlt || $altData->{'install_always'} ) {
                # Per alternative packages to install
                if ( defined $altData->{'package'} ) {
                    for my $node ( @{ delete $altData->{'package'} } ) {
                        $self->_parsePackageNode( $node, $self->{'packagesToInstall'} );
                    }
                }

                # Per alternative packages to install (delayed)
                if ( defined $altData->{'package_delayed'} ) {
                    for my $node ( @{ delete $altData->{'package_delayed'} } ) {
                        $self->_parsePackageNode( $node, $self->{'packagesToInstallDelayed'} );
                    }
                }

                # Per alternative packages conflicting packages to pre-remove
                if ( defined $altData->{'package_conflict'} ) {
                    for my $node ( @{ delete $altData->{'package_conflict'} } ) {
                        push @{ $self->{'packagesToPreUninstall'} }, ref $node eq 'HASH' ? $node->{'content'} : $node;
                    }
                }

                # Per alternative APT repository to add
                if ( defined $altData->{'repository'} ) {
                    push @{ $self->{'aptRepositoriesToAdd'} }, {
                        repository         => delete $altData->{'repository'},
                        repository_key_uri => delete $altData->{'repository_key_uri'},
                        repository_key_id  => delete $altData->{'repository_key_id'},
                        repository_key_srv => delete $altData->{'repository_key_srv'}
                    };
                }

                # Per alternative APT preferences (pinning) to add
                if ( defined $altData->{'pinning_package'} ) {
                    push @{ $self->{'aptPreferences'} }, {
                        pinning_package      => delete $altData->{'pinning_package'},
                        pinning_pin          => delete $altData->{'pinning_pin'},
                        pinning_pin_priority => delete $altData->{'pinning_pin_priority'},
                    }
                }

                # Per alternative pre-installation tasks to execute
                if ( defined $altData->{'pre_install_task'} ) {
                    for my $task ( @{ delete $altData->{'pre_install_task'} } ) {
                        push @{ $self->{'packagesPreInstallTasks'}->{$sAlt} }, $task;
                    }
                }

                # Per alternative post-installation tasks to execute
                if ( defined $altData->{'post_install_task'} ) {
                    for my $task ( @{ delete $altData->{'post_install_task'} } ) {
                        push @{ $self->{'packagesPostInstallTasks'}->{$sAlt} }, $task;
                    }
                }

                # Per alternative conflicting APT repositories to remove
                if ( defined $data->{$sAlt}->{'repository_conflict'} ) {
                    push @{ $self->{'aptRepositoriesToRemove'} }, delete $data->{$sAlt}->{'repository_conflict'}
                }

                next;
            }

            # Per unselected alternative packages to uninstall
            for ( qw/ package package_delayed / ) {
                next unless defined $altData->{$_};
                for my $node ( @{ delete $altData->{$_} } ) {
                    push @{ $self->{'packagesToUninstall'} }, ref $node ? $node->{'content'} : $node;
                }
            }

            # Per unselected alternative APT repositories to remove
            for ( qw/ repository repository_conflict / ) {
                next unless defined $altData->{$_};
                push @{ $self->{'aptRepositoriesToRemove'} }, delete $altData->{$_};
            }
        }

        debug( sprintf( 'Alternative for %s set to: %s', $section, $sAlt ));

        # Set server name for the selected alternative if any
        $main::imscpConfig{$varname} = $sAlt if exists $main::imscpConfig{$varname};

        # Set package name for the selected aternative if any
        if ( exists $main::imscpConfig{uc( $section ) . '_PACKAGE'} ) {
            $main::imscpConfig{uc( $section ) . '_PACKAGE'} = $data->{$sAlt}->{'class'};
        }
    }

    require List::MoreUtils;
    List::MoreUtils->import( 'uniq' );

    @{ $self->{'packagesToPreUninstall'} } = sort (uniq( @{ $self->{'packagesToPreUninstall'} } ));
    @{ $self->{'packagesToUninstall'} } = sort (uniq( @{ $self->{'packagesToUninstall'} } ));
    @{ $self->{'packagesToInstall'} } = sort (uniq( @{ $self->{'packagesToInstall'} } ));
    @{ $self->{'packagesToInstallDelayed'} } = sort (uniq( @{ $self->{'packagesToInstallDelayed'} } ));

    0;
}

=item _updateAptSourceList( )

 Add required sections to repositories that support them

 Note: Also enable source repositories for the sections when available.
 TODO: Implement better check by parsing apt-cache policy output

 Return int 0 on success, other on failure

=cut

sub _updateAptSourceList
{
    my ( $self ) = @_;

    local $ENV{'LANG'} = 'C';

    my $file = iMSCP::File->new( filename => '/etc/apt/sources.list' );
    my $fileContent = $file->get();

    for my $section ( @{ $self->{'repositorySections'} } ) {
        my @seenRepositories = ();
        my $foundSection = FALSE;

        while ( $fileContent =~ /^deb\s+(?<uri>(?:https?|ftp)[^\s]+)\s+(?<dist>[^\s]+)\s+(?<components>.+)$/gm ) {
            my $rf = $&;
            my %rc = %+;
            next if grep ($_ eq "$rc{'uri'} $rc{'dist'}", @seenRepositories);
            push @seenRepositories, "$rc{'uri'} $rc{'dist'}";

            if ( $fileContent !~ /^deb\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {
                my $rs = execute(
                    [ 'wget', '--prefer-family=IPv4', '--timeout=30', '--spider', "$rc{'uri'}/dists/$rc{'dist'}/$section/" =~ s{([^:])//}{$1/}gr ],
                    \my $stdout,
                    \my $stderr
                );
                debug( $stdout ) if $stdout;
                debug( $stderr || 'Unknown error' ) if $rs && $rs != 8;
                next if $rs; # Don't check for source archive when binary archive has not been found
                $foundSection = TRUE;
                $fileContent =~ s/^($rf)$/$1 $section/m;
                $rf .= " $section";
            } else {
                $foundSection = TRUE;
            }

            if ( $foundSection && $fileContent !~ /^deb-src\s+$rc{'uri'}\s+$rc{'dist'}\s+.*\b$section\b/m ) {
                my $rs = execute(
                    [ 'wget', '--prefer-family=IPv4', '--timeout=30', '--spider', "$rc{'uri'}/dists/$rc{'dist'}/$section/source/" =~ s{([^:])//}{$1/}gr ],
                    \my $stdout,
                    \my $stderr
                );
                debug( $stdout ) if $stdout;
                debug( $stderr || 'Unknown error' ) if $rs && $rs != 8;

                unless ( $rs ) {
                    if ( $fileContent !~ /^deb-src\s+$rc{'uri'}\s+$rc{'dist'}\s.*/m ) {
                        $fileContent =~ s/^($rf)/$1\ndeb-src $rc{'uri'} $rc{'dist'} $section/m;
                    } else {
                        $fileContent =~ s/^($&)$/$1 $section/m;
                    }
                }
            }
        }

        unless ( $foundSection ) {
            error( sprintf( "Couldn't find any repository supporting %s section", $section ));
            return 1;
        }
    }

    $file->set( $fileContent );
    $file->save();
}

=item _addAptRepositories( )

 Add APT repositories

 Return int 0 on success, other on failure

=cut

sub _addAptRepositories
{
    my ( $self ) = @_;

    return 0 unless @{ $self->{'aptRepositoriesToRemove'} } || @{ $self->{'aptRepositoriesToAdd'} };
    
    eval {
        iMSCP::DistPackageManager->getInstance()
            ->removeRepositories( @{ $self->{'aptRepositoriesToRemove'} } )
            ->addRepositories( @{ $self->{'aptRepositoriesToAdd'} } )
            ->updateRepositoryIndexes();
    };
    if( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _addAptPreferences( )

 Add APT preferences

 Return 0 on success, other on failure

=cut

sub _addAptPreferences
{
    my ( $self ) = @_;

    if ( -f '/etc/apt/preferences.d/imscp' ) {
        my $rs = iMSCP::File->new( filename => '/etc/apt/preferences.d/imscp' )->delFile();
        return $rs if $rs;
    }

    eval { iMSCP::DistPackageManager->getInstance()->addAptPreferences( @{ $self->{'aptPreferences'} } ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _prefillDebconfDatabase( )

 Pre-fill debconf database

 Return int 0 on success, other on failure

=cut

sub _prefillDebconfDatabase
{
    my ( $self ) = @_;

    my $fileContent = '';

    # Pre-fill questions for Postfix SMTP server if required
    if ( $main::imscpConfig{'MTA_PACKAGE'} eq 'Servers::mta::postfix' ) {
        chomp( my $mailname = `hostname --fqdn 2>/dev/null` || 'localdomain' );
        my $hostname = ( $mailname ne 'localdomain' ) ? $mailname : 'localhost';
        chomp( my $domain = `hostname --domain 2>/dev/null` || 'localdomain' );

        # From postfix package postfix.config script
        my $destinations = ( $mailname eq $hostname )
            ? join ', ', ( $mailname, 'localhost.' . $domain, ', localhost' )
            : join ', ', ( $mailname, $hostname, 'localhost.' . $domain . ', localhost' );

        $fileContent .= <<"EOF";
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $mailname
postfix postfix/destinations string $destinations
EOF
    }

    # Pre-fill question for Proftpd FTP server if required
    if ( $main::imscpConfig{'FTPD_PACKAGE'} eq 'Servers::ftpd::proftpd' ) {
        $fileContent .= <<'EOF';
proftpd-basic shared/proftpd/inetd_or_standalone select standalone
EOF
    }

    # Pre-fill questions for Courier IMAP/POP server if required
    if ( $main::imscpConfig{'PO_PACKAGE'} eq 'Servers::po::courier' ) {
        $fileContent .= <<'EOF';
courier-base courier-base/courier-user note
courier-base courier-base/webadmin-configmode boolean false
courier-ssl courier-ssl/certnotice note
EOF
    }

    # Pre-fill questions for Dovecot IMAP/POP server if required
    if ( $main::imscpConfig{'PO_PACKAGE'} eq 'Servers::po::dovecot' ) {
        $fileContent .= <<'EOF';
dovecot-core dovecot-core/create-ssl-cert boolean true
dovecot-core dovecot-core/ssl-cert-name string localhost
EOF
    }

    # Pre-fill question for sasl2-bin package if required
    if ( `echo GET cyrus-sasl2/purge-sasldb2 | debconf-communicate sasl2-bin 2>/dev/null` =~ /^0/ ) {
        $fileContent .= <<'EOF'
sasl2-bin cyrus-sasl2/purge-sasldb2 boolean true
EOF
    }

    # Pre-fill questions for SQL server (MySQL, MariaDB or Percona) if required
    if ( my ( $sqlServerVendor, $sqlServerVersion ) = $main::imscpConfig{'SQLD_SERVER'} =~ /^(mysql|mariadb|percona)_(\d+\.\d+)/ ) {
        if ( $main::imscpConfig{'DATABASE_PASSWORD'} ne '' && -d $main::imscpConfig{'DATABASE_DIR'} ) {
            # Only show critical questions
            $ENV{'DEBIAN_PRIORITY'} = 'critical';

            # Allow switching to other vendor (e.g: MariaDB 10.0 to MySQL >= 5.6)
            # unlink glob "$main::imscpConfig{'DATABASE_DIR'}/debian-*.flag";

            # Don't show SQL root password dialog from package maintainer script
            # when switching to another vendor or a newest version
            # <DATABASE_DIR>/debian-5.0.flag is the file checked by maintainer script
            my $rs = iMSCP::File->new( filename => "$main::imscpConfig{'DATABASE_DIR'}/debian-5.0.flag" )->save();
            return $rs if $rs;
        }

        my ( $qOwner, $qNamePrefix );
        if ( $sqlServerVendor eq 'mysql' ) {
            if ( grep ($_ eq 'mysql-community-server', @{ $self->{'packagesToInstall'} }) ) {
                $qOwner = 'mysql-community-server';
                $qNamePrefix = 'mysql-community-server';
            } else {
                $qOwner = 'mysql-server-' . $sqlServerVersion;
                $qNamePrefix = 'mysql-server';
            }
        } elsif ( $sqlServerVendor eq 'mariadb' ) {
            $qOwner = 'mariadb-server-' . $sqlServerVersion;
            $qNamePrefix = 'mysql-server';
        } else {
            $qOwner = 'percona-server-server-' . $sqlServerVersion;
            $qNamePrefix = 'percona-server-server';
        }

        # We do not want ask user for <DATABASE_DIR> removal (we want avoid mistakes as much as possible)
        $fileContent .= <<"EOF";
$qOwner $qNamePrefix/remove-data-dir boolean false
$qOwner $qNamePrefix/postrm_remove_databases boolean false
EOF
        # Preset root SQL password using value from preseed file if required
        if ( iMSCP::Getopt->preseed ) {
            exit 5 unless exists $main::questions{'SQL_ROOT_PASSWORD'} & $main::questions{'SQL_ROOT_PASSWORD'} ne '';

            $fileContent .= <<"EOF";
$qOwner $qNamePrefix/root_password password $main::questions{'SQL_ROOT_PASSWORD'}
$qOwner $qNamePrefix/root-pass password $main::questions{'SQL_ROOT_PASSWORD'}
$qOwner $qNamePrefix/root_password_again password $main::questions{'SQL_ROOT_PASSWORD'}
$qOwner $qNamePrefix/re-root-pass password $main::questions{'SQL_ROOT_PASSWORD'}
EOF
            # Register an event listener to empty the password fields in Debconf database after package installation
            $self->{'eventManager'}->register(
                'postBuild',
                sub {
                    for ( 'root_password', 'root-pass', 'root_password_again', 're-root-pass' ) {
                        my $rs = execute( "echo SET $qNamePrefix/$_ | debconf-communicate $qOwner", \my $stdout, \my $stderr );
                        debug( $stdout ) if $stdout;
                        error( $stderr || 'Unknown error' ) if $rs;
                        return $rs if $rs;
                    }

                    0;
                }
            );
        }
    }

    return 0 if $fileContent eq '';

    my $debconfSelectionsFile = File::Temp->new();
    print $debconfSelectionsFile $fileContent;
    $debconfSelectionsFile->flush();
    $debconfSelectionsFile->close();

    my $rs = execute( [ 'debconf-set-selections', $debconfSelectionsFile->filename ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || "Couldn't pre-fill Debconf database" ) if $rs;
    $rs;
}

=item _rebuildAndInstallPackage( $pkg, $pkgSrc, $patchesDir [, $patchesToDiscard = [] [,  $patchFormat = 'quilt' ]] )

 Rebuild the given Debian package using patches from given directory and install the resulting local Debian package

 Note: It is assumed here that the Debian source package is dpatch or quilt ready.

 Param string $pkg Name of package to rebuild
 Param string $pkgSrc Name of source package
 Param string $patchDir Directory containing set of patches to apply on Debian package source
 param arrayref $patcheqToDiscad OPTIONAL List of patches to discard
 Param string $patchFormat OPTIONAL Patch format (quilt|dpatch) - Default quilt
 Return 0 on success, other on failure

=cut

sub _rebuildAndInstallPackage
{
    my ( $self, $pkg, $pkgSrc, $patchesDir, $patchesToDiscard, $patchFormat ) = @_;
    $patchesDir ||= "$pkg/patches";
    $patchesToDiscard ||= [];
    $patchFormat ||= 'quilt';

    unless ( defined $pkg ) {
        error( '$pkg parameter is not defined' );
        return 1;
    }
    unless ( defined $pkgSrc ) {
        error( '$pkgSrc parameter is not defined' );
        return 1;
    }
    unless ( $patchFormat =~ /^(?:quilt|dpatch)$/ ) {
        error( 'Unsupported patch format.' );
        return 1;
    }

    local $ENV{'LANG'} = 'C';

    my $lsbRelease = iMSCP::LsbRelease->getInstance();
    $patchesDir = "$FindBin::Bin/configs/" . lc( $lsbRelease->getId( 1 )) . "/$patchesDir";
    unless ( -d $patchesDir ) {
        error( sprintf( '%s is not a valid patches directory', $patchesDir ));
        return 1;
    }

    my $srcDownloadDir = File::Temp->newdir( CLEANUP => 1 );

    # Fix `W: Download is performed unsandboxed as root as file...' warning with newest APT versions
    if ( ( undef, undef, my $uid ) = getpwnam( '_apt' ) ) {
        unless ( chown $uid, -1, $srcDownloadDir ) {
            error( sprintf( "Couldn't change ownership for the %s directory: %s", $srcDownloadDir, $! ));
            return 1;
        }
    }

    # chdir() into download directory
    local $CWD = $srcDownloadDir;

    # Avoid pbuilder warning due to missing $HOME/.pbuilderrc file
    my $rs = iMSCP::File->new( filename => File::HomeDir->my_home . '/.pbuilderrc' )->save();
    return $rs if $rs;

    startDetail();

    $rs = step(
        sub {
            if ( $self->{'need_pbuilder_update'} ) {
                $self->{'need_pbuilder_update'} = FALSE;

                my $msgHeader = "Creating/Updating pbuilder environment\n\n - ";
                my $msgFooter = "\n\nPlease be patient. This may take few minutes...";

                my $stderr = '';
                my $cmd = [
                    'pbuilder',
                    ( -f '/var/cache/pbuilder/base.tgz' ? ( '--update', '--autocleanaptcache' ) : '--create' ),
                    '--distribution', lc( $lsbRelease->getCodename( 1 )),
                    '--configfile', "$FindBin::Bin/configs/" . lc( $lsbRelease->getId( 1 )) . '/pbuilder/pbuilderrc',
                    '--override-config'
                ];
                $rs = executeNoWait(
                    $cmd,
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 1 );
                    } ),
                    sub { $stderr .= shift; }
                );
                error( sprintf( "Couldn't create/update pbuilder environment: %s", $stderr || 'Unknown error' )) if $rs;
                return $rs if $rs;
            }
            0;
        },
        'Creating/Updating pbuilder environment', 5, 1
    );
    $rs ||= step(
        sub {
            my $msgHeader = sprintf( "Downloading %s %s source package\n\n - ", $pkgSrc, $lsbRelease->getId( 1 ));
            my $msgFooter = "\nDepending on your system this may take few seconds...";

            my $stderr = '';
            $rs = executeNoWait(
                [ 'apt-get', '-y', 'source', $pkgSrc ],
                ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                    step( undef, $msgHeader . ( ( shift ) =~ s/^\s*//r ) . $msgFooter, 5, 2 ); }
                ),
                sub { $stderr .= shift }
            );
            error( sprintf( "Couldn't download %s Debian source package: %s", $pkgSrc,
                $stderr || 'Unknown error' )) if $rs;
            $rs;
        },
        sprintf( 'Downloading %s %s source package', $pkgSrc, $lsbRelease->getId( 1 )), 5, 2
    );

    {
        # chdir() into package source directory
        local $CWD = ( <$pkgSrc-*> )[0];

        $rs ||= step(
            sub {
                my $serieFile = iMSCP::File->new( filename => "debian/patches/" . ( $patchFormat eq 'quilt' ? 'series' : '00list' ));
                my $serieFileContent = $serieFile->get();
                unless ( defined $serieFileContent ) {
                    error( sprintf( "Couldn't read %s", $serieFile->{'filename'} ));
                    return 1;
                }

                for my $patch ( sort { $a cmp $b } iMSCP::Dir->new( dirname => $patchesDir )->getFiles() ) {
                    next if grep ($_ eq $patch, @{ $patchesToDiscard });
                    $serieFileContent .= "$patch\n";
                    $rs = iMSCP::File->new( filename => "$patchesDir/$patch" )->copyFile( "debian/patches/$patch", { preserve => 'no' } );
                    return $rs if $rs;
                }

                $rs = $serieFile->set( $serieFileContent );
                $rs ||= $serieFile->save();
                return $rs if $rs;

                my $stderr;
                $rs = execute(
                    [ 'dch', '--local', '~i-mscp-', 'Patched by i-MSCP installer for compatibility.' ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \my $stdout ),
                    \$stderr
                );
                debug( $stdout ) if $stdout;
                error( sprintf( "Couldn't add `imscp' local suffix: %s", $stderr || 'Unknown error' )) if $rs;
                return $rs if $rs;
            },
            sprintf( 'Patching %s %s source package...', $pkgSrc, $lsbRelease->getId( 1 )), 5, 3
        );
        $rs ||= step(
            sub {
                my $msgHeader = sprintf( "Building new %s %s package\n\n - ", $pkg, $lsbRelease->getId( 1 ));
                my $msgFooter = "\n\nPlease be patient. This may take few seconds...";
                my $stderr;

                $rs = executeNoWait(
                    [
                        'pdebuild',
                        '--use-pdebuild-internal',
                        '--configfile', "$FindBin::Bin/configs/" . lc( $lsbRelease->getId( 1 )) . '/pbuilder/pbuilderrc'
                    ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 4 );
                    } ),
                    sub { $stderr .= shift }
                );
                error( sprintf( "Couldn't build local %s %s package: %s", $pkg, $lsbRelease->getId( 1 ), $stderr || 'Unknown error' )) if $rs;
                $rs;
            },
            sprintf( 'Building local %s %s package', $pkg, $lsbRelease->getId( 1 )), 5, 4
        );
    }

    $rs ||= step(
        sub {
            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'unhold', $pkg ], \my $stdout, \my $stderr );
            debug( $stderr ) if $stderr;

            my $msgHeader = sprintf( "Installing local %s %s package\n\n", $pkg, $lsbRelease->getId( 1 ));
            $stderr = '';

            $rs = executeNoWait(
                "dpkg --force-confnew -i /var/cache/pbuilder/result/${pkg}_*.deb",
                ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : sub { step( undef, $msgHeader . ( shift ), 5, 5 ) } ),
                sub { $stderr .= shift }
            );
            error( sprintf( "Couldn't install local %s %s package: %s", $pkg, $lsbRelease->getId( 1 ),
                $stderr || 'Unknown error' )) if $rs;
            return $rs if $rs;

            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'hold', $pkg ], \$stdout, \$stderr );
            debug( $stdout ) if $stdout;
            debug( $stderr ) if $stderr;
            0;
        },
        sprintf( 'Installing local %s %s package', $pkg, $lsbRelease->getId( 1 )), 5, 5
    );
    endDetail();

    $rs;
}

=item _getSqldInfo

 Get SQL server info (vendor and version)

 Return list List containing SQL server vendor (lowercase) and version, die on failure

=cut

sub _getSqldInfo
{
    if ( my $mysqld = iMSCP::ProgramFinder::find( 'mysqld' ) ) {
        my ( $stdout, $stderr );
        execute( [ $mysqld, '--version' ], \$stdout, \$stderr ) == 0 or die(
            sprintf( "Couldn't guess SQL server info: %s", $stderr || 'Unknown error' )
        );

        # mysqld  Ver 10.1.26-MariaDB-0+deb9u1 for debian-linux-gnu on x86_64 (Debian 9.1)
        # mysqld  Ver 5.5.60-0ubuntu0.14.04.1 for debian-linux-gnu on x86_64 ((Ubuntu))
        # mysqld  Ver 5.7.22 for Linux on x86_64 (MySQL Community Server (GPL))
        # ...
        if ( my ( $version, $vendor ) = $stdout =~ /Ver\s+(\d+.\d+).*?(\b(?:mariadb|percona|mysql|ubuntu)\b)/i ) {
            $vendor = 'mysql' if lc $vendor eq 'ubuntu';
            return( lc $vendor, $version );
        }
    }

    ( 'none', 'none' );
}

=item _processSqldSection( \@sAlts, \%dialog )

 Process sqld section from the distribution packages file

 Param arrayref \@sAlts List of supported alternatives
 Param iMSCP::Dialog \%dialog Dialog instance
 Return void, die on failure

=cut

sub _processSqldSection
{
    my ( $sAlts, $dialog ) = @_;

    my ( $vendor, $version ) = _getSqldInfo();

    return if $vendor eq 'none';

    # Discard any SQL server vendor other than current installed, except remote
    # Discard any SQL server version (MAJOR.MINOR) older than current installed
    $version = version->parse( $version );
    my @sAltsTmp = grep { $_ eq 'remote_server' || ( index( $_, $vendor ) == 0 && version->parse( $_ =~ s/^.*_//r ) >= $version ) } @{ $sAlts };
    if ( @sAltsTmp ) {
        @{ $sAlts } = @sAltsTmp;
        return;
    }

    # Ask for confirmation if current SQL server vendor is no longer
    # supported (safety measure)
    $dialog->endGauge();
    local $dialog->{'_opts'}->{'no-cancel'} = undef;
    exit 50 if $dialog->yesno( <<"EOF", TRUE );

\\Zb\\Z1WARNING \\Z0CURRENT SQL SERVER VENDOR IS NOT SUPPORTED \\Z1WARNING\\Zn

The installer detected that your current SQL server ($vendor $version) is not supported and that there is no alternative version for that vendor.
If you continue, you'll be asked for another SQL server vendor but bear in mind that the upgrade could fail. You should really considere backuping all your SQL data before continue.
                
Are you sure you want to continue?
EOF
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
