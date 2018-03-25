=head1 NAME

 iMSCP::Installer::Debian - i-MSCP Debian like distribution installer implementation

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

package iMSCP::Installer::Debian;

use strict;
use warnings;
use Array::Utils qw/ array_minus unique /;
use File::HomeDir;
use Fcntl qw/ :flock /;
use File::Temp;
use FindBin;
use iMSCP::Boolean;
use iMSCP::Cwd;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dialog;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList /;
use iMSCP::DistPackageManager;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Installer::Functions qw/ expandVars /;
use iMSCP::ProgramFinder;
use iMSCP::Stepper qw/ startDetail endDetail step /;
use iMSCP::TemplateParser qw/ processByRef /;
use iMSCP::Umask;
use XML::Simple;
use version;
use parent 'iMSCP::Installer::Abstract';

=head1 DESCRIPTION

 i-MSCP installer for Debian like distributions (Debian, Devuan, Ubuntu).

=head1 PUBLIC METHODS

=over 4

=item preBuild( \@steps )

 Process preBuild tasks

 Param array \@steps List of build steps
 Return void, die on failure

=cut

sub preBuild
{
    my ( $self, $steps ) = @_;

    return if iMSCP::Getopt->skippackages;

    unshift @{ $steps },
        (
            [ sub { $self->_processPackagesFile() }, 'Processing distribution packages file' ],
            [ sub { $self->_installAPTsourcesList(); }, 'Installing new APT sources.list(5) file' ],
            [ sub { $self->_addAPTrepositories() }, 'Adding APT repositories' ],
            [ sub { $self->_processAptPreferences() }, 'Setting APT preferences' ],
            [ sub { $self->_prefillDebconfDatabase() }, 'Setting Debconf database' ]
        );
}

=item installPackages( )

 Install Debian packages

 Return void, die on failure

=cut

sub installPackages
{
    my ( $self ) = @_;

    # See https://people.debian.org/~hmh/invokerc.d-policyrc.d-specification.txt
    my $policyrcd = File::Temp->new();

    # Prevents invoke-rc.d (which is invoked by package maintainer scripts) to start some services
    #
    # - Prevent "bind() to 0.0.0.0:80 failed (98: Address already in use" failure (Apache2, Nginx)
    # - Prevent start failure when IPv6 stack is not enabled (Dovecot, Nginx)
    # - Prevent failure when resolvconf is not configured yet (bind9)
    print $policyrcd <<'EOF';
#!/bin/sh

initscript=$1
action=$2

if [ "$action" = "start" ] || [ "$action" = "restart" ]; then
    for i in apache2 bind9 dovecot nginx; do
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

    $self->{'eventManager'}->trigger( 'beforeInstallPackages', $self->{'packagesToInstall'}, $self->{'packagesToInstallDelayed'} );

    {
        startDetail();
        local $CWD = "$FindBin::Bin/installer/scripts";

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
                    },
                    sprintf( 'Executing pre-install tasks for %s... Please be patient.', $subjectH ), $nTasks, $cTask++
                );
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
        local $CWD = "$FindBin::Bin/installer/scripts";

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
                    },
                    sprintf( 'Executing post-install tasks for %s... Please be patient.', $subjectH ), $nTasks, $cTask++
                );
            }

        }

        endDetail();
    }

    while ( my ( $package, $metadata ) = each( %{ $self->{'packagesToRebuild'} } ) ) {
        $self->_rebuildAndInstallPackage(
            $package, $metadata->{'pkg_src_name'}, $metadata->{'patches_directory'}, $metadata->{'discard_patches'},
            $metadata->{'patch_sys_type'}
        );
    }

    if ( @{ $self->{'packagesToUninstall'} } ) {
        # Filter packages that must be kept or that were already uninstalled
        my @packagesToKeep = (
            @{ $self->{'packagesToInstall'} }, @{ $self->{'packagesToInstallDelayed'} }, keys %{ $self->{'packagesToRebuild'} },
            @{ $self->{'packagesToPreUninstall'} }
        );
        @{ $self->{'packagesToUninstall'} } = array_minus( @{ $self->{'packagesToUninstall'} }, @packagesToKeep );
        undef @packagesToKeep;

        if ( @{ $self->{'packagesToUninstall'} } ) {
            $self->{'eventManager'}->trigger( 'beforeUninstallPackages', $self->{'packagesToUninstall'} );
            iMSCP::DistPackageManager->getInstance()->uninstallPackages( @{ $self->{'packagesToUninstall'} } );
            $self->{'eventManager'}->trigger( 'afterUninstallPackages', $self->{'packagesToUninstall'} );
        }
    }

    $self->{'eventManager'}->trigger( 'afterInstallPackages' );
}

=back

=head1 PRIVATE METHODS/FUNCTIONS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Installer::Debian, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
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
    $ENV{'DEBIAN_FRONTEND'} = iMSCP::Getopt->noprompt ? 'noninteractive' : 'dialog';
    $ENV{'DEBFULLNAME'} = 'i-MSCP Installer';
    $ENV{'DEBEMAIL'} = 'team@i-mscp.net';

    $self->_setupGetAddrinfoPrecedence();
    $self;
}

=item _setupGetAddrinfoPrecedence( )

 Setup getaddrinfo(3) precedence (IPv4) for the setup time being

 Return void, die on failure

=cut

sub _setupGetAddrinfoPrecedence
{
    my $file = iMSCP::File->new( filename => '/etc/gai.conf' );

    if ( -f '/etc/gai.conf' ) {
        return if ${ $file->getAsRef() } =~ m%^precedence\s+::ffff:0:0/96\s+100\n%m;
    }

    # Prefer IPv4
    ${ $file->getAsRef() } .= "precedence ::ffff:0:0/96  100\n";
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

    # Package to rebuild
    if ( $node->{'rebuild_with_patches'} ) {
        $self->{'packagesToRebuild'}->{$node->{'content'}} = {
            pkg_src_name      => $node->{'pkg_src_name'} || $node->{'content'},
            patches_directory => $node->{'rebuild_with_patches'},
            discard_patches   => [ $node->{'discard_patches'} ? split ',', $node->{'discard_patches'} : () ],
            patch_sys_type    => $node->{'patch_sys_type'} || 'quilt'
        };
    } else {
        push @{ $target }, $node->{'content'};
    }

    # Pre-install tasks
    if ( defined $node->{'pre_install_task'} ) {
        push @{ $self->{'packagesPreInstallTasks'}->{$node->{'content'}} }, $_ for @{ $node->{'pre_install_task'} };
    }

    # Post-install tasks
    if ( defined $node->{'post_install_task'} ) {
        push @{ $self->{'packagesPostInstallTasks'}->{$node->{'content'}} }, $_ for @{ $node->{'post_install_task'} };
    }

    # APT repository
    if ( defined $node->{'repository'} ) {
        push @{ $self->{'aptRepositoriesToAdd'} },
            {
                repository         => $node->{'repository'},
                repository_key_uri => $node->{'repository_key_uri'} || undef,
                repository_key_id  => $node->{'repository_key_id'} || undef,
                repository_key_srv => $node->{'repository_key_srv'} || undef
            };
    }

    # APT preferences
    if ( defined $node->{'pinning_package'} ) {
        push @{ $self->{'aptPreferences'} },
            {
                pinning_package      => $node->{'pinning_package'},
                pinning_pin          => $node->{'pinning_pin'} || undef,
                pinning_pin_priority => $node->{'pinning_pin_priority'} || undef
            };
    }
}

=item _processPackagesFile( )

 Process distribution packages file

 Return void, die on failure

=cut

sub _processPackagesFile
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBuildPackageList', \my $pkgFile );

    my $xml = XML::Simple->new( NoEscape => TRUE );
    my $pkgData = $xml->XMLin(
        $pkgFile || "$FindBin::Bin/installer/Packages/$::imscpConfig{'DISTRO_ID'}-$::imscpConfig{'DISTRO_CODENAME'}.xml",
        ForceArray     => [ 'package', 'package_delayed', 'package_conflict', 'pre_install_task', 'post_install_task' ],
        NormaliseSpace => 2
    );

    my $dialog = iMSCP::Dialog->getInstance();

    # Make sure that all mandatory sections are defined in the packages file
    for my $section ( qw/ cron server httpd php po mta ftpd sqld / ) {
        defined $pkgData->{$section} or die( sprintf( 'Missing %s section in the distribution packages file.', $section ));
    }

    while ( my ( $section, $data ) = each( %{ $pkgData } ) ) {
        # Packages to install
        if ( defined $data->{'package'} ) {
            for my $node ( @{ $data->{'package'} } ) {
                $self->_parsePackageNode( $node, $self->{'packagesToInstall'} );
            }
        }

        # Packages to install (delayed)
        if ( defined $data->{'package_delayed'} ) {
            for my $node ( @{ $data->{'package_delayed'} } ) {
                $self->_parsePackageNode( $node, $self->{'packagesToInstallDelayed'} );
            }
        }

        # Conflicting packages to pre-remove
        if ( defined $data->{'package_conflict'} ) {
            for my $node ( @{ $data->{'package_conflict'} } ) {
                push @{ $self->{'packagesToPreUninstall'} }, ref $node eq 'HASH' ? $node->{'content'} : $node;
            }
        }

        # APT repository
        if ( defined $data->{'repository'} ) {
            push @{ $self->{'aptRepositoriesToAdd'} },
                {
                    repository         => $data->{'repository'},
                    repository_key_uri => $data->{'repository_key_uri'} || undef,
                    repository_key_id  => $data->{'repository_key_id'} || undef,
                    repository_key_srv => $data->{'repository_key_srv'} || undef
                };
        }

        # APT preferences
        if ( defined $data->{'pinning_package'} ) {
            push @{ $self->{'aptPreferences'} },
                {
                    pinning_package      => $data->{'pinning_package'},
                    pinning_pin          => $data->{'pinning_pin'} || undef,
                    pinning_pin_priority => $data->{'pinning_pin_priority'} || undef,
                };
        }

        # Pre-install tasks
        if ( defined $data->{'pre_install_task'} ) {
            push @{ $self->{'packagesPreInstallTasks'}->{$section} }, $_ for @{ $data->{'pre_install_task'} };
        }

        # Post-install tasks
        if ( defined $data->{'post_install_task'} ) {
            push @{ $self->{'packagesPostInstallTasks'}->{$section} }, $_ for @{ $data->{'post_install_task'} };
        }

        # Delete items that were already processed
        delete @{ $data }{qw/ package package_delayed package_conflict pinning_package repository repository_key_uri repository_key_id
            repository_key_srv post_install_task post_install_task /};

        # Jump in next section, unless the section defines alternatives
        next unless %{ $data };

        # Dialog flag indicating whether or not user must be asked for alternative
        my $showDialog = FALSE;

        my $altDesc = delete $data->{'description'} || $section;
        my $sectionClass = delete $data->{'class'} or die(
            sprintf( "Undefined class for the %s section in the %s distribution package file", $section, $pkgFile )
        );

        # Retrieve current alternative
        my $sAlt = $::questions{ $sectionClass } || $::imscpConfig{ $sectionClass };

        # Builds list of supported alternatives for dialogs
        # Discard hidden alternatives that are hidden or for which  evaluation
        # of the 'condition' attribute expression (if any) is not TRUE
        my @supportedAlts = grep {
            !$data->{$_}->{'hidden'} && ( !defined $data->{$_}->{'condition'} || eval expandVars( $data->{$_}->{'condition'} ) )
        } keys %{ $data };

        if ( $section eq 'sqld' ) {
            # The sqld section need a specific treatment
            processSqldSection( $data, \$sAlt, \@supportedAlts, $dialog, \$showDialog );
        } else {
            if ( length $sAlt && !grep ($data->{$_}->{'class'} eq $sAlt, @supportedAlts) ) {
                # The selected alternative isn't longer available (or simply invalid). In such case, we reset it.
                # In preseed mode, we set the dialog flag to raise an error (preseed entry is not valid and user must be informed)
                $showDialog = TRUE if iMSCP::Getopt->preseed;
                $sAlt = '';
            }

            unless ( length $sAlt ) {
                # There is no alternative selected
                if ( @supportedAlts > 1 ) {
                    # There are many alternatives available, we select the default as defined in the packages file and we set the dialog flag to make
                    # user able to change it, unless we are in preseed mode, in which case the default alternative will be enforced.
                    $showDialog = TRUE unless iMSCP::Getopt->preseed;

                    for my $supportedAlt ( @supportedAlts ) {
                        next unless $data->{$supportedAlt}->{'default'};
                        $sAlt = $supportedAlt;
                        last;
                    }

                    # There are no default alternative defined in the packages file. We set it to the first entry.
                    $sAlt = $supportedAlts[0] unless length $sAlt;
                } else {
                    # There is only one alternative available. We set it wihtout setting the dialog flag
                    $sAlt = $supportedAlts[0] unless length $sAlt;
                }
            } else {
                # We make use of real alternative name for processing
                ( $sAlt ) = grep ($data->{$_}->{'class'} eq $sAlt, @supportedAlts)
            }
        }

        # Set the dialog flag in any case if there are many alternatives available and if user asked for alternative reconfiguration
        $showDialog ||= @supportedAlts > 1 && isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ $section, 'servers', 'all' ] );

        # Process alternative dialogs
        if ( $showDialog ) {
            local $dialog->{'opts'}->{'no-cancel'} = '';
            my %choices;
            @choices{ values @supportedAlts } = map { $data->{$_}->{'description'} // $_ } @supportedAlts;

            ( my $ret, $sAlt ) = $dialog->radiolist( <<"EOF", \%choices, $sAlt );
Please make your choice for the $altDesc:
\\Z \\Zn
EOF
            exit $ret if $ret; # Handle ESC case
        }

        # Process alternatives data
        while ( my ( $alt, $altData ) = each( %{ $data } ) ) {
            # Process data for the selected alternative or those which need to
            # be always installed
            if ( $alt eq $sAlt || $altData->{'install_always'} ) {
                # Packages to install
                if ( defined $altData->{'package'} ) {
                    for my $node ( @{ $altData->{'package'} } ) {
                        $self->_parsePackageNode( $node, $self->{'packagesToInstall'} );
                    }
                }

                # Package to install (delayed)
                if ( defined $altData->{'package_delayed'} ) {
                    for my $node ( @{ $altData->{'package_delayed'} } ) {
                        $self->_parsePackageNode( $node, $self->{'packagesToInstallDelayed'} );
                    }
                }

                # Conflicting packages to pre-remove
                if ( defined $altData->{'package_conflict'} ) {
                    for my $node ( @{ $altData->{'package_conflict'} } ) {
                        push @{ $self->{'packagesToPreUninstall'} }, ref $node eq 'HASH' ? $node->{'content'} : $node;
                    }
                }

                # APT repository
                if ( defined $altData->{'repository'} ) {
                    push @{ $self->{'aptRepositoriesToAdd'} },
                        {
                            repository         => $altData->{'repository'},
                            repository_key_uri => $altData->{'repository_key_uri'} || undef,
                            repository_key_id  => $altData->{'repository_key_id'} || undef,
                            repository_key_srv => $altData->{'repository_key_srv'} || undef
                        };
                }

                # APT preferences
                if ( defined $altData->{'pinning_package'} ) {
                    push @{ $self->{'aptPreferences'} },
                        {
                            pinning_package      => $altData->{'pinning_package'},
                            pinning_pin          => $altData->{'pinning_pin'} || undef,
                            pinning_pin_priority => $altData->{'pinning_pin_priority'} || undef,
                        }
                }

                # Pre-install tasks
                if ( defined $altData->{'pre_install_task'} ) {
                    for my $task ( @{ $altData->{'pre_install_task'} } ) {
                        push @{ $self->{'packagesPreInstallTasks'}->{$sAlt} }, $task;
                    }
                }

                # Post-install tasks
                if ( defined $altData->{'post_install_task'} ) {
                    for my $task ( @{ $altData->{'post_install_task'} } ) {
                        push @{ $self->{'packagesPostInstallTasks'}->{$sAlt} }, $task;
                    }
                }

                next;
            }

            # Process data for alternatives that don't need to be installed
            for ( qw/ package package_delayed / ) {
                next unless defined $altData->{$_};

                for ( @{ $altData->{$_} } ) {
                    my $package = ref $_ eq 'HASH' ? $_->{'content'} : $_;
                    #next if grep( $package eq $_, @{$self->{'packagesToPreUninstall'}} );
                    push @{ $self->{'packagesToUninstall'} }, $package;
                }
            }
        }

        # Set server/package class name for the selected alternative
        $::imscpConfig{$sectionClass} = $::questions{$sectionClass} = $data->{$sAlt}->{'class'} || 'iMSCP::Servers::NoServer';
        # Set alternative name for installer use
        $::questions{'_' . $section} = $sAlt;
    }

    @{ $self->{'packagesToPreUninstall'} } = sort ( unique( @{ $self->{'packagesToPreUninstall'} } ) );
    @{ $self->{'packagesToUninstall'} } = sort ( unique( @{ $self->{'packagesToUninstall'} } ) );
    @{ $self->{'packagesToInstall'} } = sort ( unique( @{ $self->{'packagesToInstall'} } ) );
    @{ $self->{'packagesToInstallDelayed'} } = sort ( unique( @{ $self->{'packagesToInstallDelayed'} } ) );
}

=item _installAPTsourcesList( )

 Installs i-MSCP provided SOURCES.LIST(5) configuration file

 Return void, die on failure

=cut

sub _installAPTsourcesList
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/apt/sources.list" );
    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'apt', 'sources.list', $file->getAsRef( TRUE ));

    processByRef( { codename => $::imscpConfig{'DISTRO_CODENAME'} }, $file->getAsRef());

    $file->{'filename'} = '/etc/apt/sources.list';
    $file->save();
}

=item _addAPTrepositories( )

 Add required APT repositories

 Return void, die on failure

=cut

sub _addAPTrepositories
{
    my ( $self ) = @_;

    return unless @{ $self->{'aptRepositoriesToAdd'} };

    iMSCP::DistPackageManager->getInstance()->addRepositories( @{ $self->{'aptRepositoriesToAdd'} } );
}

=item _processAptPreferences( )

 Process apt preferences

 Return void, die on failure

=cut

sub _processAptPreferences
{
    my ( $self ) = @_;

    my $fileContent = '';

    for my $pref ( @{ $self->{'aptPreferences'} } ) {
        $pref->{'pinning_pin'} || $pref->{'pinning_pin_priority'} or die(
            'One of these attributes is missing: pinning_pin or pinning_pin_priority'
        );

        $fileContent .= <<"EOF";

Package: $pref->{'pinning_package'}
Pin: $pref->{'pinning_pin'}
Pin-Priority: $pref->{'pinning_pin_priority'}
EOF
    }

    my $file = iMSCP::File->new( filename => '/etc/apt/preferences.d/imscp' );

    if ( $fileContent ) {
        $fileContent =~ s/^\n//;
        $file->set( $fileContent )->save()->mode( 0644 );
        return;
    }

    $file->remove();
}

=item _prefillDebconfDatabase( )

 Pre-fill debconf database

 Return void, die on failure

=cut

sub _prefillDebconfDatabase
{
    my ( $self ) = @_;

    my $fileContent = '';

    if ( $::questions{'_mta'} eq 'postfix' ) {
        chomp( my $mailname = `hostname --fqdn 2>/dev/null` || 'localdomain' );
        my $hostname = ( $mailname ne 'localdomain' ) ? $mailname : 'localhost';
        chomp( my $domain = `hostname --domain 2>/dev/null` || 'localdomain' );

        # Mimic behavior from the postfix package postfix.config maintainer script
        my $destinations = ( $mailname eq $hostname )
            ? join ', ', ( $mailname, 'localhost.' . $domain, ', localhost' )
            : join ', ', ( $mailname, $hostname, 'localhost.' . $domain . ', localhost' );

        # Pre-fill debconf database for Postfix
        $fileContent .= <<"EOF";
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $mailname
postfix postfix/destinations string $destinations
EOF
    }

    if ( $::questions{'_ftpd'} eq 'proftpd' ) {
        # Pre-fill debconf database for Proftpd
        $fileContent .= "proftpd-basic shared/proftpd/inetd_or_standalone select standalone\n";
    }

    if ( $::questions{'_po'} eq 'courier' ) {
        # Pre-fill debconf database for Courier
        $fileContent .= <<'EOF';
courier-base courier-base/webadmin-configmode boolean false
courier-base courier-base/maildirpath note
courier-base courier-base/certnotice note
courier-base courier-base/courier-user note
courier-base courier-base/maildir string Maildir
EOF
        if ( grep ( $::imscpConfig{'DISTRO_CODENAME'} eq $_, 'jessie', 'trusty', 'xenial' ) ) {
            # Only for the old courier-ssl package. It is a transitional
            # package in latest Debian like distributons.
            $fileContent .= "courier-ssl courier-ssl/certnotice note\n";
        }
    }

    # Pre-fill debconf database for Dovecot
    if ( $::questions{'_po'} eq 'dovecot' ) {
        # Pre-fill debconf database for Dovecot
        $fileContent .= <<'EOF';
dovecot-core dovecot-core/ssl-cert-name string localhost
dovecot-core dovecot-core/create-ssl-cert boolean true
EOF
    }

    # Pre-fill question for sasl2-bin package if required
    if ( `echo GET cyrus-sasl2/purge-sasldb2 | debconf-communicate sasl2-bin 2>/dev/null` =~ /^0/ ) {
        $fileContent .= "sasl2-bin cyrus-sasl2/purge-sasldb2 boolean true\n";
    }

    if ( my ( $sqldVendor, $sqldVersion ) = $::questions{'_sqld'} =~ /^(mysql|mariadb|percona)_(\d+\.\d+)/ ) {
        my ( $package );
        if ( $sqldVendor eq 'mysql' ) {
            $package = grep ($_ eq 'mysql-community-server', @{ $self->{'packagesToInstall'} }) ? 'mysql-community-server' : "mysql-server-$sqldVersion";
        } else {
            $package = ( $sqldVendor eq 'mariadb' ? 'mariadb-server-' : 'percona-server-server-' ) . $sqldVersion;
        }

        # Only show critical questions if the SQL server has been already installed
        #$ENV{'DEBIAN_PRIORITY'} = 'critical' if -d '/var/lib/mysql';

        READ_DEBCONF_DB:

        my $isManualTplLoading = FALSE;
        open my $fh, '-|', "debconf-get-selections 2>/dev/null | grep $package" or die(
            sprintf( "Couldn't pipe to debconf database: %s", $! || 'Unknown error' )
        );

        if ( eof $fh ) {
            !$isManualTplLoading or die( "Couldn't pre-fill debconf database for the SQL server. Debconf template not found." );

            # The debconf template is not available (the package has not been installed yet or something went wrong with the debconf database)
            # In such case, we download the package into a temporary directory, we extract the debconf template manually and we load it into the
            # debconf database. Once done, we process as usually. This is lot of work but we have not choice as question names for different SQL
            # server vendors/versions are not consistent.
            close( $fh );

            my $tmpDir = File::Temp->newdir();

            if ( my $uid = ( getpwnam( '_apt' ) )[2] ) {
                # Prevent Fix `W: Download is performed unsandboxed as root as file...' warning with newest APT versions
                chown $uid, -1, $tmpDir or die(
                    sprintf( "Couldn't change ownership for the %s directory: %s", $tmpDir, $! || 'Unknown error' )
                );
            }

            local $CWD = $tmpDir;

            # Download the package into a temporary directory
            startDetail;
            my $rs = execute( [ 'apt-get', '--quiet=1', 'download', $package ], \my $stdout, \my $stderr );
            debug( $stdout ) if $stdout;

            # Extract the debconf template into the temporary directory
            $rs ||= execute( [ 'apt-extracttemplates', '-t', $tmpDir, <$tmpDir/*.deb> ], \$stdout, \$stderr );
            $rs || debug( $stdout ) if $stdout;

            # Load the template into the debconf database
            $rs ||= execute( [ 'debconf-loadtemplate', $package, <$tmpDir/$package.template.*> ], \$stdout, \$stderr );
            $rs || debug( $stdout ) if $stdout;

            !$rs or die( $stderr || 'Unknown errror' );
            endDetail;

            $isManualTplLoading = TRUE;
            goto READ_DEBCONF_DB;
        }

        # Pre-fill debconf database for the SQL server (mariadb, mysql or percona)
        while ( <$fh> ) {
            if ( my ( $qOwner, $qNamePrefix, $qName ) = m%(.*?)\s+(.*?)/([^\s]+)% ) {
                if ( grep ($qName eq $_, 'remove-data-dir', 'postrm_remove_databases') ) {
                    # We do not want ask user for databases removal (we want avoid mistakes as much as possible)
                    $fileContent .= "$qOwner $qNamePrefix/$qName boolean false\n";
                } elsif ( grep ($qName eq $_, 'root_password', 'root-pass', 'root_password_again', 're-root-pass')
                    && iMSCP::Getopt->preseed && length $::questions{'SQL_ROOT_PASSWORD'}
                ) {
                    # Preset root SQL password using value from preseed file if required
                    $fileContent .= "$qOwner $qNamePrefix/$qName password $::questions{'SQL_ROOT_PASSWORD'}\n";

                    # Register an event listener to empty the password field in the debconf database after package installation
                    #$self->{'eventManager'}->registerOne(
                    #    'afterInstallPackages',
                    #    sub {
                    #        my $rs = execute( "echo SET $qNamePrefix/$qName | debconf-communicate $qOwner", \ my $stdout, \ my $stderr );
                    #        debug( $stdout ) if $stdout;
                    #        !$rs or die( $stderr || 'Unknown error' ) if $rs;
                    #    }
                    #);
                }
            }
        }

        close( $fh );
    }

    return unless length $fileContent;

    my $debconfSelectionsFile = File::Temp->new();
    print $debconfSelectionsFile $fileContent;
    $debconfSelectionsFile->close();

    my $rs = execute( [ 'debconf-set-selections', $debconfSelectionsFile ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || "Couldn't pre-fill Debconf database" );
}

=item _rebuildAndInstallPackage( $pkg, $pkgSrc, $patchesDir [, $patchesToDiscard = [] [,  $patchFormat = 'quilt' ]] )

 Rebuild the given Debian package using patches from given directory and install the resulting local Debian package

 Note: It is assumed here that the Debian source package is dpatch or quilt ready.

 Param string $pkg Name of package to rebuild
 Param string $pkgSrc Name of source package
 Param string $patchDir Directory containing set of patches to apply on Debian package source
 param arrayref $patcheqToDiscad OPTIONAL List of patches to discard
 Param string $patchFormat OPTIONAL Patch format (quilt|dpatch) - Default quilt
 Return void, die on failure

=cut

sub _rebuildAndInstallPackage
{
    my ( $self, $pkg, $pkgSrc, $patchesDir, $patchesToDiscard, $patchFormat ) = @_;
    $patchesDir ||= "$pkg/patches";
    $patchesToDiscard ||= [];
    $patchFormat ||= 'quilt';

    defined $pkg or die( '$pkg parameter is not defined' );
    defined $pkgSrc or die( '$pkgSrc parameter is not defined' );
    $patchFormat =~ /^(?:quilt|dpatch)$/ or die( 'Unsupported patch format.' );

    $patchesDir = "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/$patchesDir";
    -d $patchesDir or die( sprintf( '%s is not a valid patches directory', $patchesDir ));

    my $srcDownloadDir = File::Temp->newdir( CLEANUP => TRUE );

    # Fix `W: Download is performed unsandboxed as root as file...' warning with newest APT versions
    if ( ( undef, undef, my $uid ) = getpwnam( '_apt' ) ) {
        chown $uid, -1, $srcDownloadDir or die( sprintf( "Couldn't change ownership for the %s directory: %s", $srcDownloadDir, $! ));
    }

    # chdir() into download directory
    local $CWD = $srcDownloadDir;

    # Avoid pbuilder warning due to missing $HOME/.pbuilderrc file
    iMSCP::File->new( filename => File::HomeDir->my_home . '/.pbuilderrc' )->save();

    startDetail();
    step(
        sub {
            if ( $self->{'need_pbuilder_update'} ) {
                $self->{'need_pbuilder_update'} = FALSE;

                my $msgHeader = "Creating/Updating pbuilder environment\n\n - ";
                my $msgFooter = "\n\nPlease be patient. This may take few minutes...";
                my $stderr = '';
                my $cmd = [
                    'pbuilder',
                    ( -f '/var/cache/pbuilder/base.tgz' ? ( '--update', '--autocleanaptcache' ) : '--create' ),
                    '--distribution', $::imscpConfig{'DISTRO_CODENAME'},
                    '--configfile', "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/pbuilder/pbuilderrc",
                    '--override-config'
                ];

                executeNoWait(
                    $cmd,
                    ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose
                        ? sub {}
                        : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 1 );
                    }
                    ),
                    sub { $stderr .= shift; }
                ) == 0 or die( sprintf( "Couldn't create/update pbuilder environment: %s", $stderr || 'Unknown error' ));
            }
        },
        'Creating/Updating pbuilder environment', 5, 1
    );
    step(
        sub {
            my $msgHeader = sprintf( "Downloading %s %s source package\n\n - ", $pkgSrc, $::imscpConfig{'DISTRO_ID'} );
            my $msgFooter = "\nDepending on your system this may take few seconds...";
            my $stderr = '';
            executeNoWait(
                [ 'apt-get', '-y', 'source', $pkgSrc ],
                ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose
                    ? sub {} : sub { step( undef, $msgHeader . ( ( shift ) =~ s/^\s*//r ) . $msgFooter, 5, 2 ); }
                ),
                sub { $stderr .= shift }
            ) == 0 or die( sprintf( "Couldn't download %s Debian source package: %s", $pkgSrc, $stderr || 'Unknown error' ));
        },
        sprintf( 'Downloading %s %s source package', $pkgSrc, $::imscpConfig{'DISTRO_ID'} ), 5, 2
    );

    {
        # chdir() into package source directory
        local $CWD = ( <$pkgSrc-*> )[0];

        step(
            sub {
                my $serieFile = iMSCP::File->new( filename => "debian/patches/" . ( $patchFormat eq 'quilt' ? 'series' : '00list' ));
                my $serieFileContent = $serieFile->getAsRef();

                for my $patch ( sort { $a cmp $b } iMSCP::Dir->new( dirname => $patchesDir )->getFiles() ) {
                    next if grep ( $_ eq $patch, @{ $patchesToDiscard } );
                    ${ $serieFileContent } .= "$patch\n";
                    iMSCP::File->new( filename => "$patchesDir/$patch" )->copy( "debian/patches/$patch" );
                }

                $serieFile->save();

                my $stderr;
                my $rs = execute(
                    [ 'dch', '--local', '~i-mscp-', 'Patched by i-MSCP installer for compatibility.' ],
                    ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \my $stdout ),
                    \$stderr
                );
                debug( $stdout ) if $stdout;
                !$rs or die( sprintf( "Couldn't add `imscp' local suffix: %s", $stderr || 'Unknown error' ));
            },
            sprintf( 'Patching %s %s source package...', $pkgSrc, $::imscpConfig{'DISTRO_ID'} ), 5, 3
        );
        step(
            sub {
                my $msgHeader = sprintf( "Building new %s %s package\n\n - ", $pkg, $::imscpConfig{'DISTRO_ID'} );
                my $msgFooter = "\n\nPlease be patient. This may take few seconds...";
                my $stderr;
                executeNoWait(
                    [
                        'pdebuild',
                        '--use-pdebuild-internal',
                        '--configfile', "$FindBin::Bin/configs/$::imscpConfig{'DISTRO_ID'}/pbuilder/pbuilderrc"
                    ],
                    ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose
                        ? sub {}
                        : sub {
                        return unless ( shift ) =~ /^i:\s*(.*)/i;
                        step( undef, $msgHeader . ucfirst( $1 ) . $msgFooter, 5, 4 );
                    }
                    ),
                    sub { $stderr .= shift }
                ) == 0 or die(
                    sprintf( "Couldn't build local %s %s package: %s", $pkg, $::imscpConfig{'DISTRO_ID'}, $stderr || 'Unknown error' )
                );
            },
            sprintf( 'Building local %s %s package', $pkg, $::imscpConfig{'DISTRO_ID'} ), 5, 4
        );
    }

    step(
        sub {
            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'unhold', $pkg ], \my $stdout, \my $stderr );
            debug( $stderr ) if $stderr;

            my $msgHeader = sprintf( "Installing local %s %s package\n\n", $pkg, $::imscpConfig{'DISTRO_ID'} );
            $stderr = '';

            executeNoWait(
                "dpkg --force-confnew -i /var/cache/pbuilder/result/${pkg}_*.deb",
                ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? sub {} : sub { step( undef, $msgHeader . ( shift ), 5, 5 ) } ),
                sub { $stderr .= shift }
            ) == 0 or die(
                sprintf( "Couldn't install local %s %s package: %s", $pkg, $::imscpConfig{'DISTRO_ID'}, $stderr || 'Unknown error' )
            );

            # Ignore exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
            execute( [ 'apt-mark', 'hold', $pkg ], \$stdout, \$stderr );
            debug( $stdout ) if $stdout;
            debug( $stderr ) if $stderr;
        },
        sprintf( 'Installing local %s %s package', $pkg, $::imscpConfig{'DISTRO_ID'} ), 5, 5
    );
    endDetail();
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
        if ( my ( $version, $vendor ) = $stdout =~ /Ver\s+(\d+.\d+).*?(mariadb|percona|mysql)/i ) {
            return( lc $vendor, $version );
        }
    }

    ( 'none', 'none' );
}

=item processSqldSection( \%data, \$sAlt, \@supportedAlts, \%dialog, \$showDialog )

 Process sqld section from the distribution packages file

 Param hashref \%data Hash containing sqld section data
 Param scalarref \$sAlt Selected sqld alternative
 Param arrayref \@supportedAlts Array containing list of supported alternatives
 Param iMSCP::Dialog \%dialog Dialog instance
 Param scalarref \$showDialog Boolean indicating whether or not dialog must be shown for sqld section
 Return void, die on failure

=cut

sub processSqldSection
{
    my ( $data, $sAlt, $supportedAlts, $dialog, $showDialog ) = @_;

    my ( $sqldVendor, $sqldVersion ) = _getSqldInfo();

    $dialog->endGauge;

    if ( $sqldVendor ne 'none' ) {
        # There is an SQL server installed.

        # Discard any SQL server vendor other than current installed, excepted remote
        # Discard any SQL server version older than current installed, excepted remote
        $sqldVersion = version->parse( $sqldVersion );
        my @sqlSupportedAlts = grep {
            $_ eq 'remote_server' || ( index( $_, $sqldVendor ) == 0 && version->parse( $_ =~ s/^.*_//r ) >= $sqldVersion )
        } @{ $supportedAlts };

        # Ask for confirmation if current SQL server vendor is no longer supported (safety measure)
        unless ( @sqlSupportedAlts ) {
            $dialog->endGauge();
            local $dialog->{'opts'}->{'no-cancel'} = undef;
            exit 50 if $dialog->yesno( <<"EOF", TRUE );
\\Zb\\Z1WARNING \\Z0CURRENT SQL SERVER VENDOR IS NOT SUPPORTED \\Z1WARNING\\Zn

The installer detected that your current SQL server ($sqldVendor $sqldVersion) is not supported and that there is no alternative version for that vendor.
If you continue, you'll be asked for another SQL server vendor but bear in mind that the upgrade could fail. You should really considere backuping all your SQL databases before continue.
                
Are you sure you want to continue?
EOF
            # No alternative matches with the installed SQL server. User has been warned and want continue upgrade. We show it dialog with all
            # available alternatives, selecting the default as defined in the packages file, or the first alternative if there is not default.
            for ( @{ $supportedAlts } ) {
                next unless $data->{$_}->{'default'};
                ${ $sAlt } = $_;
                last;
            }
        } else {
            ${ $sAlt } = lc( $sqldVendor ) . '_' . $sqldVersion;
            @{ $supportedAlts } = @sqlSupportedAlts;

            # Resets alternative if the selected alternative is no longer available
            if ( !grep ($_ eq ${ $sAlt }, @{ $supportedAlts }) ) {
                ${ $showDialog } = 1;
                for ( @{ $supportedAlts } ) {
                    next unless $data->{$_}->{'default'};
                    ${ $sAlt } = $_;
                    last;
                }
            }
        }

        ${ $sAlt } = $supportedAlts->[0] unless length ${ $sAlt };
    } else {
        # There is no SQL server installed.

        if ( length ${ $sAlt } && !grep ($data->{$_}->{'class'} eq ${ $sAlt }, @{ $supportedAlts }) ) {
            # The selected alternative isn't longer available (or simply invalid). In such case, we reset it.
            # In preseed mode, we set the dialog flag to raise an error (preseed entry is wrong and user must be informed)
            ${ $showDialog } = 1 if iMSCP::Getopt->preseed; # We want raise an error in preseed mode
            ${ $sAlt } = '';
        }

        unless ( length ${ $sAlt } ) {
            # There is no alternative selected
            if ( @{ $supportedAlts } > 2 ) {
                # If there are many available, we select the default as defined in the packages file and we force dialog to make user able to
                # change it, unless we are in preseed or noninteractive mode, in which case the default alternative will be enforced.
                ${ $showDialog } = 1 unless iMSCP::Getopt->preseed;

                for ( @{ $supportedAlts } ) {
                    next unless $data->{$_}->{'default'};
                    ${ $sAlt } = $_;
                    last;
                }

                ${ $sAlt } = $supportedAlts->[0] unless length ${ $sAlt };
            } else {
                # There is only one alternative available. We select it wihtout showing dialog
                ${ $sAlt } = $supportedAlts->[0] unless length ${ $sAlt };
            }
        } else {
            # We make use of alternative name for processing
            ( ${ $sAlt } ) = grep ($data->{$_}->{'class'} eq ${ $sAlt }, @{ $supportedAlts })
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
