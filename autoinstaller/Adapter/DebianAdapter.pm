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
use autoinstaller::Functions qw/ evalConditionFromXmlFile /;
use autouse 'iMSCP::Stepper' => qw/ startDetail endDetail step /;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug error output getMessageByType /;
use iMSCP::Dialog;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringInList /;
use iMSCP::DistPackageManager;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::ProgramFinder;
use Storable qw/ dclone /;
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

    return 0 if $::skippackages;

    unshift @{ $steps }, (
        [ sub { $self->_processPackagesFile() }, 'Processing distribution packages file' ],
        [ sub { $self->_addAptRepositories() }, 'Adding APT repositories' ],
        [ sub { $self->_addAptPreferences() }, 'Adding APT preferences' ],
        [
            sub {
                eval { $self->_seedDebconfValues(); };
                if ( $@ ) {
                    error( $@ );
                    return 1;
                }
                0;
            },
            'Seeding debconf values'
        ]
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
        my @services = qw/ apache2 bind9 dovecot nginx proftpd /;

        # - MariaDB upgrade failure
        # TODO: To be documented
        if ( grep ( /mariadb-server/, @{ $self->{'packagesToInstall'} } ) && ( $self->_getSqldInfo )[0] ne 'none' ) {
            push @services, 'mysql', 'mariadb'
        }

        print $policyrcd <<"EOF";
#!/bin/sh

initscript=\$1
action=\$2

if [ "\$action" = "start" ] || [ "\$action" = "restart" ]; then
    for i in @{ [ sort @services ] }; do
        if [ "\$initscript" = "\$i" ]; then
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

    @{ $self }{qw/
        eventManager repositorySections preRequiredPackages aptRepositoriesToRemove aptRepositoriesToAdd aptPreferences packagesToInstall
        packagesToInstallDelayed packagesToPreUninstall packagesToUninstall packagesToRebuild packagesPreInstallTasks packagesPostInstallTasks
        need_pbuilder_update
    /} = (
        iMSCP::EventManager->getInstance(),
        [ 'main', 'contrib', 'non-free' ],
        [
            'apt-transport-https', 'binutils', 'ca-certificates', 'debconf-utils', 'dialog', 'dirmngr', 'dpkg-dev', 'libbit-vector-perl',
            'libclass-insideout-perl', 'libclone-perl', 'liblchown-perl', 'liblist-compare-perl', 'liblist-moreutils-perl', 'libscalar-defer-perl',
            'libsort-versions-perl', 'libxml-simple-perl', 'lsb-release', 'policyrcd-script-zg2', 'wget'
        ],
        [], [], [], [], [], [], [], {}, {}, {}, TRUE
    );

    delete $ENV{'DEBCONF_FORCE_DIALOG'};

    $ENV{'DEBIAN_FRONTEND'} = iMSCP::Getopt->noprompt ? 'noninteractive' : 'dialog';
    #$ENV{'DEBIAN_SCRIPT_DEBUG'} = TRUE if iMSCP::Getopt->debug;
    $ENV{'DEBFULLNAME'} = 'i-MSCP Installer';
    $ENV{'DEBEMAIL'} = 'l.declercq@nuxwin.com';

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
            error( sprintf( "Couldn't read the '%s' file ", $file->{'filename'} ));
            return 1;
        }

        return 0 if $fileContent =~ m%^precedence\s+::ffff:0:0/96\s+100\n%m;
    }

    # Prefer IPv4
    $fileContent .= "precedence ::ffff:0:0/96  100\n";

    $file->set( $fileContent );
    $file->save();
}

=item _parsePackageNode( \%node|$node, $section, \%container [, $target = 'packagesToInstall' ] )

 Parse a package or package_delayed node for installation or uninstallation
 
 The package is scheduled for installation unless there is a condition that
 evaluate to FALSE, in which case, the package is scheduled for uninstallation
 unless the 'skip_uninstall' attribute is set.

 param string|hashref $node Package node
 param string $section Section name
 pararm hashref \%container Data container
 param string $target Target (packagesToInstall|packagesToInstallDelayed)
 Return void, die on failure

=cut

sub _parsePackageNode
{
    my ( $node, $section, $container, $target ) = @_;
    $target //= 'packagesToInstall';

    unless ( ref $node ) {
        # Package without further treatment
        push @{ $container->{ $target } }, $node;
        return;
    }

    if ( defined $node->{'condition'} && !evalConditionFromXmlFile( $node->{'condition'} ) ) {
        push @{ $container->{'packagesToUninstall'} }, $node->{'content'} unless $node->{'skip_uninstall'};
        return;
    }

    # Per package rebuild task to execute
    if ( $node->{'rebuild_with_patches'} ) {
        $container->{'packagesToRebuild'}->{$node->{'content'}} = {
            pkg_src_name      => $node->{'pkg_src_name'} || $node->{'content'},
            patches_directory => $node->{'rebuild_with_patches'},
            discard_patches   => [ defined $node->{'discard_patches'} ? split ',', $node->{'discard_patches'} : () ],
            patch_sys_type    => $node->{'patch_sys_type'} || 'quilt'
        };
    } else {
        push @{ $container->{ $target } }, $node->{'content'};
    }

    # Per package pre-installation task to execute
    if ( defined $node->{'pre_install_task'} ) {
        push @{ $container->{'packagesPreInstallTasks'}->{$section} }, $_ for @{ $node->{'pre_install_task'} };
    }

    # Per package post-installation task to execute
    if ( defined $node->{'post_install_task'} ) {
        push @{ $container->{'packagesPostInstallTasks'}->{$section} }, $_ for @{ $node->{'post_install_task'} };
    }

    # Per package APT repository to add
    if ( defined $node->{'repository'} ) {
        push @{ $container->{'aptRepositoriesToAdd'} }, {
            repository         => $node->{'repository'},
            repository_key_uri => $node->{'repository_key_uri'},
            repository_key_id  => $node->{'repository_key_id'},
            repository_key_srv => $node->{'repository_key_srv'}
        };
    }

    # Per package APT preferences (pinning) to add
    if ( defined $node->{'pinning_package'} ) {
        push @{ $container->{'aptPreferences'} }, {
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
        NormalizeSpace => 2
    );

    # List of required sections in packages file
    my @requiredSections = qw/ sqld named panel_httpd panel_php httpd php ftpd mta postfix_srs po antispam antivirus perl other /;

    # Make sure that all mandatory sections are defined in the packages file
    for my $section ( @requiredSections ) {
        defined $pkgData->{$section} or die( sprintf( 'Missing %s section in the distribution packages file.', $section ));
    }

    # Flag indicating whether or not we are in second pass
    my $secPass = FALSE;

    sections_processing:

    # Sort sections to make sure to process them in expected order
    my @sections = sort { ( $pkgData->{$b}->{'dialog_priority'} || 0 ) <=> ( $pkgData->{$a}->{'dialog_priority'} || 0 ) } keys %{ $pkgData };

    # In reconfiguration mode, we do a first pass with selected section to
    # reconfigure only, unless all sections must be reconfigured
    if ( !$secPass && isOneOfStringsInList( iMSCP::Getopt->reconfigure, \@requiredSections ) ) {
        @sections = grep ( isStringInList( $_, @{ iMSCP::Getopt->reconfigure } ), @sections )
    }

    # Implements a simple state machine (backup capability)
    my ( $state, $countSections, $dialog, %container ) = ( 0, scalar @sections, iMSCP::Dialog->getInstance() );
    while ( $state < $countSections ) {
        my $section = $sections[$state];

        # Init/Reset container for the current section (backup capability)
        @{ $container{$section} }{qw/
            aptRepositoriesToRemove aptRepositoriesToAdd aptPreferences packagesToInstall packagesToInstallDelayed packagesToPreUninstall
            packagesToUninstall packagesToRebuild packagesPreInstallTasks packagesPostInstallTasks
        /} = ( [], [], [], [], [], [], [], {}, {}, {} );

        # We don't operate on original data (backup capability)
        my $data = dclone $pkgData->{$section};

        delete $data->{'dialog_priority'};

        # Per section packages to install
        if ( defined $data->{'package'} ) {
            for my $node ( @{ delete $data->{'package'} } ) {
                _parsePackageNode( $node, $section, $container{$section} );
            }
        }

        # Per section packages to install (delayed)
        if ( defined $data->{'package_delayed'} ) {
            for my $node ( @{ delete $data->{'package_delayed'} } ) {
                _parsePackageNode( $node, $section, $container{$section}, 'packagesToInstallDelayed' );
            }
        }

        # Per section conflicting packages to pre-remove
        if ( defined $data->{'package_conflict'} ) {
            for my $node ( @{ delete $data->{'package_conflict'} } ) {
                push @{ $container{$section}->{'packagesToPreUninstall'} }, ref $node eq 'HASH' ? $node->{'content'} : $node;
            }
        }

        # Per section APT repository to add
        if ( defined $data->{'repository'} ) {
            push @{ $container{$section}->{'aptRepositoriesToAdd'} }, {
                repository         => delete $data->{'repository'},
                repository_key_uri => delete $data->{'repository_key_uri'},
                repository_key_id  => delete $data->{'repository_key_id'},
                repository_key_srv => delete $data->{'repository_key_srv'}
            };
        }

        # Per section APT preferences (pinning) to add
        if ( defined $data->{'pinning_package'} ) {
            push @{ $container{$section}->{'aptPreferences'} }, {
                pinning_package      => delete $data->{'pinning_package'},
                pinning_pin          => delete $data->{'pinning_pin'},
                pinning_pin_priority => delete $data->{'pinning_pin_priority'},
            };
        }

        # Per section pre-installation tasks to execute
        if ( defined $data->{'pre_install_task'} ) {
            push @{ $container{$section}->{'packagesPreInstallTasks'}->{$section} }, $_ for @{ delete $data->{'pre_install_task'} };
        }

        # Per section post-installation tasks to execute
        if ( defined $data->{'post_install_task'} ) {
            push @{ $container{$section}->{'packagesPostInstallTasks'}->{$section} }, $_ for @{ delete $data->{'post_install_task'} };
        }

        # Jump in next section, unless the section defines alternatives
        unless ( %{ $data } ) {
            $state++;
            next;
        };

        # Dialog flag indicating whether or not user must be asked for
        # alternative
        my $showDialog = FALSE;
        # Alternative section description
        my $altDesc = ( delete $data->{'description'} ) || $section;
        my $altFullDesc = delete $data->{'full_description'};
        # Alternative section variable name
        my $varname = ( delete $data->{'varname'} ) || uc( $section ) . '_SERVER';
        # Whether or not full alternative section is hidden
        my $isAltSectionHidden = delete $data->{'hidden'};
        # Retrieve current selected alternative
        my $sAlt = exists $::questions{ $varname } ? $::questions{ $varname } : ( exists $::imscpConfig{ $varname } ? $::imscpConfig{ $varname } : '' );

        # Builds list of selectable alternatives through dialog:
        # - Discard hidden alternatives, that is, those which don't involve any
        #   dialog
        # - Discard alternative for which evaluation of the 'condition'
        #   attribute expression (if any) is FALSE
        my @sAlts = $isAltSectionHidden ? keys %{ $data } : grep {
            !$data->{$_}->{'hidden'} && !defined $data->{$_}->{'condition'} || evalConditionFromXmlFile( $data->{$_}->{'condition'} )
        } keys %{ $data };

        # The sqld section needs a specific treatment
        if ( $section eq 'sqld' ) {
            _processSqldSection( \@sAlts, $dialog );
            unless ( length $sAlt || !iMSCP::Getopt->preseed ) {
                ( $sAlt ) = grep { $data->{$_}->{'default'} } @sAlts;
                $sAlt ||= $sAlts[0];
            }
        }

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
        $showDialog ||= !$secPass && @sAlts > 1 && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ $section, 'servers', 'all' ] );

        # Process alternative dialogs
        if ( $showDialog ) {
            local $dialog->{'_opts'}->{'no-cancel'} = $state ? undef : '';
            my %choices;
            @choices{ values @sAlts } = map { $data->{$_}->{'description'} // $_ } @sAlts;
            ( my $ret, $sAlt ) = $dialog->radiolist( <<"EOF", \%choices, $sAlt );

Please select the $altDesc that you want to use:

@{ [ ( $altFullDesc // '' )] }
EOF
            exit $ret if $ret == 50; # ESC

            # backup capability
            if ( $ret == 30 ) {
                do {
                    $state--;
                    $data = dclone $pkgData->{$sections[$state]};
                    delete @{ $data }{qw/
                        description varname dialog_priority package package_delayed package_conflict repository repository_key_uri
                        repository_key_id repository_key_srv pinning_package pinning_pin pinning_pin_priority pre_install_task post_install_task
                        full_description
                    /};
                    @sAlts = delete $data->{'hidden'} ? keys %{ $data } : grep {
                        !$data->{$_}->{'hidden'} && !defined $data->{$_}->{'condition'} || evalConditionFromXmlFile( $data->{$_}->{'condition'} )
                    } keys %{ $data };
                } while @sAlts < 2;
                next;
            }
        }

        # Process alternatives
        while ( my ( $alt, $altData ) = each( %{ $data } ) ) {
            # Process data for the selected alternative or those which need to
            # be always installed
            if ( $alt eq $sAlt || $altData->{'install_always'} ) {
                # Per alternative packages to install
                if ( defined $altData->{'package'} ) {
                    for my $node ( @{ delete $altData->{'package'} } ) {
                        _parsePackageNode( $node, $section, $container{$section} );
                    }
                }

                # Per alternative packages to install (delayed)
                if ( defined $altData->{'package_delayed'} ) {
                    for my $node ( @{ delete $altData->{'package_delayed'} } ) {
                        _parsePackageNode( $node, $section, $container{$section}, 'packagesToInstallDelayed' );
                    }
                }

                # Per alternative packages conflicting packages to pre-remove
                if ( defined $altData->{'package_conflict'} ) {
                    for my $node ( @{ delete $altData->{'package_conflict'} } ) {
                        push @{ $container{$section}->{'packagesToPreUninstall'} }, ref $node ? $node->{'content'} : $node;
                    }
                }

                # Per alternative APT repository to add
                if ( defined $altData->{'repository'} ) {
                    push @{ $container{$section}->{'aptRepositoriesToAdd'} }, {
                        repository         => delete $altData->{'repository'},
                        repository_key_uri => delete $altData->{'repository_key_uri'},
                        repository_key_id  => delete $altData->{'repository_key_id'},
                        repository_key_srv => delete $altData->{'repository_key_srv'}
                    };
                }

                # Per alternative APT preferences (pinning) to add
                if ( defined $altData->{'pinning_package'} ) {
                    push @{ $container{$section}->{'aptPreferences'} }, {
                        pinning_package      => delete $altData->{'pinning_package'},
                        pinning_pin          => delete $altData->{'pinning_pin'},
                        pinning_pin_priority => delete $altData->{'pinning_pin_priority'},
                    }
                }

                # Per alternative pre-installation tasks to execute
                if ( defined $altData->{'pre_install_task'} ) {
                    for my $task ( @{ delete $altData->{'pre_install_task'} } ) {
                        push @{ $container{$section}->{'packagesPreInstallTasks'}->{$section} }, $task;
                    }
                }

                # Per alternative post-installation tasks to execute
                if ( defined $altData->{'post_install_task'} ) {
                    for my $task ( @{ delete $altData->{'post_install_task'} } ) {
                        push @{ $container{$section}->{'packagesPostInstallTasks'}->{$section} }, $task;
                    }
                }

                # Per alternative conflicting APT repositories to remove
                if ( defined $data->{$sAlt}->{'repository_conflict'} ) {
                    push @{ $container{$section}->{'aptRepositoriesToRemove'} }, delete $data->{$sAlt}->{'repository_conflict'}
                }

                next;
            }

            # Per unselected alternative packages to uninstall
            for ( qw/ package package_delayed / ) {
                next unless defined $altData->{$_} && !$altData->{'skip_uninstall'};
                for my $node ( @{ delete $altData->{$_} } ) {
                    push @{ $container{$section}->{'packagesToUninstall'} }, ref $node ? $node->{'content'} : $node;
                }
            }

            # Per unselected alternative APT repositories to remove
            for ( qw/ repository repository_conflict / ) {
                next unless defined $altData->{$_};
                push @{ $container{$section}->{'aptRepositoriesToRemove'} }, delete $altData->{$_};
            }
        }

        # Set configuration variables for alternatives
        $::imscpConfig{$varname} = $::questions{$varname} = $sAlt;
        $::imscpConfig{uc( $section ) . '_PACKAGE'} = $data->{$sAlt}->{'class'} || 'none';
        $state++;
    }

    # In reconfiguration mode, we need redo the job silently to make sure that
    # all sections are processed.
    unless ( $secPass ) {
        $secPass = TRUE;
        goto sections_processing;
    }

    require List::MoreUtils;
    List::MoreUtils->import( qw/ uniq / );

    for my $section ( @sections ) {
        while ( my ( $target, $data ) = each( %{ $container{$section} } ) ) {
            if ( ref $data eq 'ARRAY' ) {
                push @{ $self->{ $target } }, @{ $data };
                @{ $self->{ $target } } = sort( uniq( @{ $self->{ $target } } ) );
                next;
            }

            next unless exists $data->{$section};
            push @{ $self->{ $target }->{ $section } }, @{ $data->{$section} };
            @{ $self->{ $target }->{ $section } } = uniq( @{ $self->{ $target }->{ $section } } );
        }
    }

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
    if ( $@ ) {
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

=item _seedDebconfValues( )

 Seed debconf values

 See DEBCONF(1) , DEBCONF-SET-SELECTIONS(1)

 Return void, die on failure

=cut

sub _seedDebconfValues
{
    my ( $self ) = @_;

    my $fileContent = '';

    # Postfix MTA
    if ( $::imscpConfig{'MTA_PACKAGE'} eq 'Servers::mta::postfix' ) {
        chomp( my $mailname = `hostname --fqdn 2>/dev/null` || 'localdomain' );
        my $hostname = ( $mailname ne 'localdomain' ) ? $mailname : 'localhost';
        chomp( my $domain = `hostname --domain 2>/dev/null` || 'localdomain' );

        # Mimic behavior from the postfix package postfix.config maintainer script
        my $destinations = ( $mailname eq $hostname )
            ? join ', ', ( $mailname, 'localhost.' . $domain, ', localhost' )
            : join ', ', ( $mailname, $hostname, 'localhost.' . $domain . ', localhost' );
        $fileContent .= <<"EOF";
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $mailname
postfix postfix/destinations string $destinations
EOF
    }

    # ProFTPD
    if ( $::imscpConfig{'FTPD_PACKAGE'} eq 'Servers::ftpd::proftpd' ) {
        $fileContent .= <<'EOF';
proftpd-basic shared/proftpd/inetd_or_standalone select standalone
EOF
    }

    # Courier IMAP/POP
    if ( $::imscpConfig{'PO_PACKAGE'} eq 'Servers::po::courier' ) {
        # Pre-fill debconf database for Courier
        $fileContent .= <<'EOF';
courier-base courier-base/webadmin-configmode boolean false
courier-base courier-base/maildirpath note
courier-base courier-base/certnotice note
courier-base courier-base/courier-user note
courier-base courier-base/maildir string Maildir
EOF
    }

    # Dovecot IMAP/POP
    elsif ( $::imscpConfig{'PO_PACKAGE'} eq 'Servers::po::dovecot' ) {
        $fileContent .= <<'EOF';
dovecot-core dovecot-core/ssl-cert-name string localhost
dovecot-core dovecot-core/create-ssl-cert boolean true
EOF
    }

    # sasl2-bin package
    if ( `echo GET cyrus-sasl2/purge-sasldb2 | debconf-communicate sasl2-bin 2>/dev/null` =~ /^0/ ) {
        $fileContent .= "sasl2-bin cyrus-sasl2/purge-sasldb2 boolean true\n";
    }

    # SQL server (MariaDB, MySQL, Percona
    if ( my ( $sqldVendor, $sqldVersion ) = $::imscpConfig{'SQLD_SERVER'} =~ /^(mysql|mariadb|percona)_(\d+\.\d+)/ ) {
        my $package;
        if ( $sqldVendor eq 'mysql' ) {
            $package = grep ($_ eq 'mysql-community-server', @{ $self->{'packagesToInstall'} })
                ? 'mysql-community-server' : "mysql-server-$sqldVersion";
        } else {
            $package = ( $sqldVendor eq 'mariadb' ? 'mariadb-server-' : 'percona-server-server-' ) . $sqldVersion;
        }

        # Only show critical questions if the SQL server has been already installed
        #$ENV{'DEBIAN_PRIORITY'} = 'critical' if -d '/var/lib/mysql';

        READ_DEBCONF_DB:

        my $isManualTplLoading = FALSE;
        open my $fh, '-|', "debconf-get-selections 2>/dev/null | grep $package" or die(
            sprintf( "Couldn't pipe to the debconf-get-selections(1) command: %s", $! || 'Unknown error' )
        );

        if ( eof $fh ) {
            !$isManualTplLoading or die( "Couldn't seed debconf values for the SQL server. The debconf template couldn't be found." );

            # The debconf template is not available -- the package has not been
            # installed yet or something went wrong with the debconf database.
            # In such case, we download the package into a temporary directory,
            # we extract the debconf template manually and we load it into the
            # debconf database. Once done, we process as usually. This is lot
            # of work but we have not choice as question names for different
            # SQL server vendors/versions are not consistent.
            close( $fh );

            my $tmpDir = File::Temp->newdir();

            if ( my $uid = ( getpwnam( '_apt' ) )[2] ) {
                # Prevent Fix 'W: Download is performed unsandboxed as root as file...' warning with newest APT versions
                chown $uid, -1, $tmpDir or die( sprintf( "Couldn't change ownership for the '%s' directory: %s", $tmpDir, $! || 'Unknown error' ));
            }

            local $CWD = $tmpDir;

            # Download the package into a temporary directory
            startDetail;
            my $rs = execute( [ 'apt-get', '--quiet=1', 'download', $package ], \my $stdout, \my $stderr );
            debug( $stdout ) if length $stdout;

            # Extract the debconf template into the temporary directory
            $rs ||= execute( [ 'apt-extracttemplates', '-t', $tmpDir, <$tmpDir/*.deb> ], \$stdout, \$stderr );
            $rs || debug( $stdout ) if length $stdout;

            # Load the template into the debconf database
            $rs ||= execute( [ 'debconf-loadtemplate', $package, <$tmpDir/$package.template.*> ], \$stdout, \$stderr );
            $rs || debug( $stdout ) if length $stdout;

            endDetail;

            $rs == 0 or die( $stderr || 'Unknown errror' );

            $isManualTplLoading = TRUE;
            goto READ_DEBCONF_DB;
        }

        while ( my $line = <$fh> ) {
            if ( my ( $qOwner, $qNamePrefix, $qName ) = $line =~ m%(.*?)\s+(.*?)/([^\s]+)% ) {
                if ( grep ($qName eq $_, 'remove-data-dir', 'postrm_remove_databases') ) {
                    # We do not want ask user for databases removal (we want avoid mistakes as much as possible)
                    $fileContent .= "$qOwner $qNamePrefix/$qName boolean false\n";
                } elsif ( grep ($qName eq $_, 'root_password', 'root-pass', 'root_password_again', 're-root-pass')
                    && iMSCP::Getopt->preseed && length $::questions{'SQL_ROOT_PASSWORD'}
                ) {
                    # Preset the root user SQL password using value from preseed file if available
                    # Password can be empty when 
                    $fileContent .= "$qOwner $qNamePrefix/$qName password $::questions{'SQL_ROOT_PASSWORD'}\n";
                }
            }
        }

        close( $fh );
    }

    return unless length $fileContent;

    my $debconfSelectionsFile = File::Temp->new();
    print $debconfSelectionsFile $fileContent;
    $debconfSelectionsFile->close();

    my $rs = execute( [ 'debconf-set-selections', $debconfSelectionsFile->filename() ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    $rs == 0 or die( sprintf( "Couldn't seed debconf values: %s", $stderr || 'Unknown error' ));
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

    # Fix 'W: Download is performed unsandboxed as root as file...' warning with newest APT versions
    if ( ( undef, undef, my $uid ) = getpwnam( '_apt' ) ) {
        unless ( chown $uid, -1, $srcDownloadDir ) {
            error( sprintf( "Couldn't change ownership for the %s directory: %s", $srcDownloadDir, $! ));
            return 1;
        }
    }

    # chdir() into download directory
    local $CWD = $srcDownloadDir;

    # Avoid pbuilder warning due to missing /root/.pbuilderrc file
    my $rs = iMSCP::File->new( filename => '/root/.pbuilderrc' )->save();
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
                error( sprintf( "Couldn't add 'imscp' local suffix: %s", $stderr || 'Unknown error' )) if $rs;
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
            error( sprintf( "Couldn't install local %s %s package: %s", $pkg, $lsbRelease->getId( 1 ), $stderr || 'Unknown error' )) if $rs;
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
    CORE::state @info;

    return @info if scalar @info;

    if ( my $mysqld = iMSCP::ProgramFinder::find( 'mysqld' ) ) {
        my ( $stdout, $stderr );
        execute( [ $mysqld, '--version' ], \$stdout, \$stderr ) == 0 or die(
            sprintf( "Couldn't guess SQL server info: %s", $stderr || 'Unknown error' )
        );

        # mysqld  Ver 10.1.26-MariaDB-0+deb9u1 for debian-linux-gnu on x86_64 (Debian 9.1)
        # mysqld  Ver 5.5.60-0ubuntu0.14.04.1 for debian-linux-gnu on x86_64 ((Ubuntu))
        # mysqld  Ver 5.7.22 for Linux on x86_64 (MySQL Community Server (GPL))
        # ...
        if ( my ( $version, $vendor ) = $stdout =~ /Ver\s+(\d+.\d+).*?\b(debian|mariadb|mysql|percona|ubuntu)\b/i ) {
            $vendor = lc $vendor;
            $vendor = 'mysql' if grep ( $_ eq $vendor, 'debian', 'ubuntu' );
            return @info = ( $vendor, $version );
        }
    }

    @info = ( 'none', 'none' );
}

=item _processSqldSection( \@sAlts, $dialog )

 Process sqld section from the distribution packages file

 Param arrayref \@sAlts List of supported alternatives
 Param iMSCP::Dialog $dialog Dialog instance
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
