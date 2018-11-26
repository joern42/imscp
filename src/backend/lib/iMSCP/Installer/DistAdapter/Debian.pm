=head1 NAME

 iMSCP::Installer::DistAdapter::Debian Installer adapter for Debian distribution

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright 2010-2018 by internet Multi Server Control Panel
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

package iMSCP::Installer::DistAdapter::Debian;

use strict;
use warnings;
use Data::Clone 'clone';
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Cwd '$CWD';
use iMSCP::Debug qw/ debug getMessageByType output /;
use iMSCP::InputValidation qw/ isOneOfStringsInList isStringInList /;
use iMSCP::DistPackageManager;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::ProgramFinder;
use iMSCP::Stepper qw/ startDetail endDetail step /;
use XML::Simple qw/ :strict XMLin /;
use version;
use parent 'iMSCP::Installer::DistAdapter::Abstract';

=head1 DESCRIPTION

 Installer adapter for Debian distribution.

=head1 PRIVATE METHODS

=over 4

=item install( )

 See iMSCP::Installer::DistAdapter::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_processDistPackageFile();
    $self->_setupGetAddrinfo();

    if ( -f '/etc/apt/preferences.d/imscp' ) {
        iMSCP::File->new( filename => '/etc/apt/preferences.d/imscp' )->delFile() == 0 or die(
            getMessageByType('error', { amount => 1, remove => TRUE })
        );
    }

    iMSCP::DistPackageManager
        ->getInstance()
        ->addRepositorySections( $self->{'repositorySections'} )
        ->removeRepositories( $self->{'repositoriesToRemove'} )
        ->addRepositories( $self->{'repositoriesToAdd'} )
        ->addAptPreferences( $self->{'preferences'} )
        ->updateRepositoryIndexes();

    $self->_seedDebconfValues();
    $self->_installDistributionPackages();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See Common::Object::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    @{ $self }{qw/
        repositorySections repositoriesToRemove repositoriesToAdd APTpreferences packagesToInstall packagesToInstallDelayed
        packagesToPreUninstall packagesToUninstall packagesToRebuildAndInstall packagesPreInstallTasks packagesPostInstallTasks
    /} = (
        [ 'contrib', 'non-free' ], [], [], [], [], [], [], [], [], {}, {}
    );

    $self;
}

=item _setupGetAddrinfo( )

 Setup getaddrinfo(3) precedence (IPv4) for the setup time being

 Return void, die on failure

=cut

sub _setupGetAddrinfo
{
    my $file = iMSCP::File->new( filename => '/etc/gai.conf' );
    my $fileC = '';

    if ( -f '/etc/gai.conf' ) {
        $fileC = $file->get();
        defined $fileC or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        return if $fileC =~ m%^precedence\s+::ffff:0:0/96\s+100\n%m;
    }

    # Prefer IPv4
    $fileC .= "precedence ::ffff:0:0/96  100\n";
    $file->set( $fileC );
    $file->save() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
}

=item _processDistPackageFile( )

 Process distribution package file
 
 Return void, die on failure

=cut

sub _processDistPackageFile
{
    my ( $self ) = @_;

    my $lsb = iMSCP::LsbRelease->getInstance()->getCodename( TRUE );
    my $pkgData = XMLin(
        iMSCP::Getopt->distPackageFile || "config/@{ [ $lsb->getId( TRUE ) ] }/packages/@{ [ lc $lsb->getCodename( TRUE ) ] }.xml",
        ForceArray     => [ 'package', 'package_delayed', 'package_conflict', 'pre_install_task', 'post_install_task' ],
        ForceContent   => TRUE,
        KeyAttr        => {},
        #NoEscape       => TRUE,
        NormalizeSpace => 2
    );

    # List of required sections in package file
    my @requiredSections = qw/ sqld named panel_httpd panel_php httpd php ftpd mta po perl other /;

    # Make sure that all mandatory sections are defined in the package file
    for my $section ( @requiredSections ) {
        defined $pkgData->{$section} or die( sprintf( 'Missing %s section in the distribution package file.', $section ));
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
            repositoriesToRemove repositoriesToAdd APTpreferences packagesToInstall packagesToInstallDelayed packagesToPreUninstall
            packagesToUninstall packagesToRebuildAndInstall packagesPreInstallTasks packagesPostInstallTasks
        /} = ( [], [], [], [], [], [], [], [], {}, {} );

        # We don't operate on original data (backup capability)
        my $data = clone $pkgData->{$section};

        delete $data->{'dialog_priority'};

        # Per section packages to install
        if ( defined $data->{'package'} ) {
            for my $node ( @{ delete $data->{'package'} } ) {
                $self->_parsePackageNode( $node, $section, $container{$section} );
            }
        }

        # Per section packages to install (delayed)
        if ( defined $data->{'package_delayed'} ) {
            for my $node ( @{ delete $data->{'package_delayed'} } ) {
                $self->_parsePackageNode( $node, $section, $container{$section}, 'packagesToInstallDelayed' );
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
            push @{ $container{$section}->{'repositoriesToAdd'} }, {
                repository         => delete( $data->{'repository'} ),
                repository_key_uri => delete( $data->{'repository_key_uri'} ),
                repository_key_id  => delete( $data->{'repository_key_id'} ),
                repository_key_srv => delete( $data->{'repository_key_srv'} )
            };
        }

        # Per section APT preferences (pinning) to add
        if ( defined $data->{'pinning_package'} ) {
            push @{ $container{$section}->{'APTpreferences'} }, {
                pinning_package      => delete( $data->{'pinning_package'} ),
                pinning_pin          => delete( $data->{'pinning_pin'} ),
                pinning_pin_priority => delete( $data->{'pinning_pin_priority'} ),
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
        my $sAlt = exists $::questions{ $varname }
            ? $::questions{ $varname } : ( exists $self->{'config'}->{ $varname } ? $self->{'config'}->{ $varname } : '' );

        # Builds list of selectable alternatives through dialog:
        # - Discard hidden alternatives, that is, those which don't involve any
        #   dialog
        # - Discard alternative for which evaluation of the 'condition'
        #   attribute expression (if any) is FALSE
        my @sAlts = $isAltSectionHidden ? keys %{ $data } : grep {
            !$data->{$_}->{'hidden'} && !defined $data->{$_}->{'condition'} || $self->_evalConditionFromXmlFile( $data->{$_}->{'condition'} )
        } keys %{ $data };

        # The sqld section needs a specific treatment
        if ( $section eq 'sqld' ) {
            $self->_processSqldSection( \@sAlts, $dialog );
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
            # We select the default alternative as defined in the package file
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
            local $dialog->{'_opts'}->{'nocancel'} = $state ? undef : '';
            my %choices;
            @choices{ values @sAlts } = map { $data->{$_}->{'description'} // $_ } @sAlts;
            ( my $ret, $sAlt ) = $dialog->select( <<"EOF", \%choices, $sAlt );

Please select the $altDesc that you want to use:

@{ [ ( $altFullDesc // '' )] }
EOF
            exit $ret if $ret == 50; # ESC

            # backup capability
            if ( $ret == 30 ) {
                do {
                    $state--;
                    iMSCP::Getopt->reconfigure( $sections[$state], FALSE, TRUE );
                    $data = clone $pkgData->{$sections[$state]};
                    delete @{ $data }{qw/
                        description varname dialog_priority package package_delayed package_conflict repository repository_key_uri
                        repository_key_id repository_key_srv pinning_package pinning_pin pinning_pin_priority pre_install_task post_install_task
                        full_description
                    /};
                    @sAlts = delete $data->{'hidden'} ? keys %{ $data } : grep {
                        !$data->{$_}->{'hidden'} && !defined $data->{$_}->{'condition'} || $self->_evalConditionFromXmlFile( $data->{$_}->{'condition'} )
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
                        $self->_parsePackageNode( $node, $section, $container{$section} );
                    }
                }

                # Per alternative packages to install (delayed)
                if ( defined $altData->{'package_delayed'} ) {
                    for my $node ( @{ delete $altData->{'package_delayed'} } ) {
                        $self->_parsePackageNode( $node, $section, $container{$section}, 'packagesToInstallDelayed' );
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
                    push @{ $container{$section}->{'repositoriesToAdd'} }, {
                        repository         => delete( $altData->{'repository'} ),
                        repository_key_uri => delete( $altData->{'repository_key_uri'} ),
                        repository_key_id  => delete( $altData->{'repository_key_id'} ),
                        repository_key_srv => delete( $altData->{'repository_key_srv'} )
                    };
                }

                # Per alternative APT preferences (pinning) to add
                if ( defined $altData->{'pinning_package'} ) {
                    push @{ $container{$section}->{'APTpreferences'} }, {
                        pinning_package      => delete( $altData->{'pinning_package'} ),
                        pinning_pin          => delete( $altData->{'pinning_pin'} ),
                        pinning_pin_priority => delete( $altData->{'pinning_pin_priority'} ),
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
                    push @{ $container{$section}->{'repositoriesToRemove'} }, delete $data->{$sAlt}->{'repository_conflict'}
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
                push @{ $container{$section}->{'repositoriesToRemove'} }, delete $altData->{$_};
            }
        }

        # Set configuration variables for alternatives
        $self->{'config'}->{$varname} = $::questions{$varname} = $sAlt;
        $self->{'config'}->{uc( $section ) . '_PACKAGE'} = $data->{$sAlt}->{'class'} || 'none';
        $state++;
    }

    # In reconfiguration mode, we need redo the job silently to make sure that
    # all sections are processed.
    unless ( $secPass ) {
        $secPass = TRUE;
        goto sections_processing;
    }

    require List::MoreUtils;
    List::MoreUtils->import( 'uniq' );

    for my $section ( @sections ) {
        while ( my ( $target, $data ) = each( %{ $container{$section} } ) ) {
            if ( ref $data eq 'ARRAY' ) {
                push @{ $self->{ $target } }, @{ $data };
                @{ $self->{ $target } } = sort ( uniq( @{ $self->{ $target } } ) );
                next;
            }

            next unless exists $data->{$section};
            push @{ $self->{ $target }->{ $section } }, @{ $data->{$section} };
            @{ $self->{ $target }->{ $section } } = uniq( @{ $self->{ $target }->{ $section } } );
        }
    }
}

=item _seedDebconfValues( )

 Seed debconf values

 See DEBCONF(1) , DEBCONF-SET-SELECTIONS(1)

 Return void, die on failure

=cut

sub _seedDebconfValues
{
    my ( $self ) = @_;

    my $fileC = '';

    # Postfix MTA
    if ( $self->{'config'}->{'MTA_PACKAGE'} eq 'iMSCP::Server::mta::postfix' ) {
        chomp( my $mailname = `hostname --fqdn 2>/dev/null` || 'localdomain' );
        my $hostname = ( $mailname ne 'localdomain' ) ? $mailname : 'localhost';
        chomp( my $domain = `hostname --domain 2>/dev/null` || 'localdomain' );

        # Mimic behavior from the postfix package postfix.config maintainer script
        my $destinations = ( $mailname eq $hostname )
            ? join ', ', ( $mailname, 'localhost.' . $domain, ', localhost' )
            : join ', ', ( $mailname, $hostname, 'localhost.' . $domain . ', localhost' );
        $fileC .= <<"EOF";
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $mailname
postfix postfix/destinations string $destinations
EOF
    }

    # ProFTPD
    if ( $self->{'config'}->{'FTPD_PACKAGE'} eq 'iMSCP::Server::ftpd::proftpd' ) {
        $fileC .= <<'EOF';
proftpd-basic shared/proftpd/inetd_or_standalone select standalone
EOF
    }

    # Courier IMAP/POP
    if ( $self->{'config'}->{'PO_PACKAGE'} eq 'iMSCP::Server::po::courier' ) {
        # Pre-fill debconf database for Courier
        $fileC .= <<'EOF';
courier-base courier-base/webadmin-configmode boolean false
courier-base courier-base/maildirpath note
courier-base courier-base/certnotice note
courier-base courier-base/courier-user note
courier-base courier-base/maildir string Maildir
EOF
    }

    # Dovecot IMAP/POP
    elsif ( $self->{'config'}->{'PO_PACKAGE'} eq 'iMSCP::Server::po::dovecot' ) {
        $fileC .= <<'EOF';
dovecot-core dovecot-core/ssl-cert-name string localhost
dovecot-core dovecot-core/create-ssl-cert boolean true
EOF
    }

    # sasl2-bin package
    if ( `echo GET cyrus-sasl2/purge-sasldb2 | debconf-communicate sasl2-bin 2>/dev/null` =~ /^0/ ) {
        $fileC .= "sasl2-bin cyrus-sasl2/purge-sasldb2 boolean true\n";
    }

    # SQL server (MariaDB, MySQL, Percona
    if ( my ( $sqldVendor, $sqldVersion ) = $self->{'config'}->{'SQLD_SERVER'} =~ /^(mysql|mariadb|percona)_(\d+\.\d+)/ ) {
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
                    $fileC .= "$qOwner $qNamePrefix/$qName boolean false\n";
                } elsif ( grep ($qName eq $_, 'root_password', 'root-pass', 'root_password_again', 're-root-pass')
                    && iMSCP::Getopt->preseed && length $::questions{'SQL_ROOT_PASSWORD'}
                ) {
                    # Preset the root user SQL password using value from preseed file if available
                    # Password can be empty when 
                    $fileC .= "$qOwner $qNamePrefix/$qName password $::questions{'SQL_ROOT_PASSWORD'}\n";
                }
            }
        }

        close( $fh );
    }

    return unless length $fileC;

    my $debconfSelectionsFile = File::Temp->new();
    print $debconfSelectionsFile $fileC;
    $debconfSelectionsFile->close();

    my $rs = execute( [ 'debconf-set-selections', $debconfSelectionsFile->filename() ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    $rs == 0 or die( sprintf( "Couldn't seed debconf values: %s", $stderr || 'Unknown error' ));
}

=item _installDistributionPackages( )

 Install distribution packages

 Return void, die on failure

=cut

sub _installDistributionPackages
{
    my ( $self ) = @_;

    # See https://people.debian.org/~hmh/invokerc.d-policyrc.d-specification.txt
    my $policyrcd = File::Temp->new( UNLINK => TRUE );

    # Prevents invoke-rc.d (which is invoked by package maintainer scripts) to start some services
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

    iMSCP::DistPackageManager->getInstance()->uninstallPackages( $self->{'packagesToPreUninstall'} );

    {
        startDetail();
        local $CWD = "iMSCP/Installer/preinstall";

        for my $subject ( keys %{ $self->{'packagesPreInstallTasks'} } ) {
            my $subjectH = $subject =~ s/_/ /gr;
            my ( $cTask, $nTasks ) = ( 1, scalar @{ $self->{'packagesPreInstallTasks'}->{$subject} } );

            for my $task ( @{ $self->{'packagesPreInstallTasks'}->{$subject} } ) {
                step(
                    sub {
                        my ( $stdout, $stderr );
                        execute( $task, ( iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : \$stdout ), \$stderr ) == 0 or die(
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
        iMSCP::DistPackageManager->getInstance()->installPackages( $packages );
    }

    {
        startDetail();
        local $CWD = "iMSCP/Installer/postinstall";

        for my $subject ( keys %{ $self->{'packagesPostInstallTasks'} } ) {
            my $subjectH = $subject =~ s/_/ /gr;
            my ( $cTask, $nTasks ) = ( 1, scalar @{ $self->{'packagesPostInstallTasks'}->{$subject} } );

            for my $task ( @{ $self->{'packagesPostInstallTasks'}->{$subject} } ) {
                step(
                    sub {
                        my ( $stdout, $stderr );
                        execute( $task, ( iMSCP::Getopt->noninteractive && iMSCP::Getopt->verbose ? undef : \$stdout ), \$stderr ) == 0 or die(
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

    if ( @{ $self->{'packagesToRebuildAndInstall'} } ) {
        iMSCP::DistPackageManager->getInstance()->rebuildAndInstallPackages(
            $self->{'packagesToRebuildAndInstall'}, "$CWD/config/$self->{'config'}->{'DIST_ID'}/pbuilder/pbuilderrc"
        );
    }

    if ( @{ $self->{'packagesToUninstall'} } ) {
        # Filter packages that must be kept or that were already uninstalled
        my %map = map { $_ => TRUE }
            @{ $self->{'packagesToInstall'} },
            @{ $self->{'packagesToInstallDelayed'} },
            ( map { $_->{'package'} } @{ $self->{'packagesToRebuildAndInstall'} } ),
            @{ $self->{'packagesToPreUninstall'} };

        @{ $self->{'packagesToUninstall'} } = grep (!exists $map{$_}, @{ $self->{'packagesToUninstall'} } );

        if ( @{ $self->{'packagesToUninstall'} } ) {
            iMSCP::DistPackageManager->getInstance()->uninstallPackages( $self->{'packagesToUninstall'} );
        }
    }
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
    my ( $self, $node, $section, $container, $target ) = @_;
    $target //= 'packagesToInstall';

    unless ( ref $node ) {
        # Package without further treatment
        push @{ $container->{ $target } }, $node;
        return;
    }

    if ( defined $node->{'condition'} && !$self->_evalConditionFromXmlFile( $node->{'condition'} ) ) {
        push @{ $container->{'packagesToUninstall'} }, $node->{'content'} unless $node->{'skip_uninstall'};
        return;
    }

    # Per package rebuild task to execute
    if ( $node->{'rebuild'} ) {
        push @{ $container->{'packagesToRebuildAndInstall'} }, {
            package         => $node->{'content'},
            package_src     => $node->{'package_src'} || $node->{'content'},
            patches_dir     => $node->{'patches_dir'},
            discard_patches => [ defined $node->{'discard_patches'} ? split ',', $node->{'discard_patches'} : () ],
            patches_manager => $node->{'patches_manager'}
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
        push @{ $container->{'repositoriesToAdd'} }, {
            repository         => $node->{'repository'},
            repository_key_uri => $node->{'repository_key_uri'},
            repository_key_id  => $node->{'repository_key_id'},
            repository_key_srv => $node->{'repository_key_srv'}
        };
    }

    # Per package APT preferences (pinning) to add
    if ( defined $node->{'pinning_package'} ) {
        push @{ $container->{'APTpreferences'} }, {
            pinning_package      => $node->{'pinning_package'},
            pinning_pin          => $node->{'pinning_pin'},
            pinning_pin_priority => $node->{'pinning_pin_priority'}
        };
    }
}

=item _evalConditionFromXmlFile

 Evaluate a condition from an xml file
 
 Return boolean Condition evaluation result on success, die on failure

=cut

sub _evalConditionFromXmlFile
{
    my ( $self, $condition ) = @_;

    my $ret = eval expandVars( $condition );
    !$@ or die;
    !!$ret;
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

 Process sqld section from the distribution package file

 Param arrayref \@sAlts List of supported alternatives
 Param iMSCP::Dialog $dialog Dialog instance
 Return void, die on failure

=cut

sub _processSqldSection
{
    my ( $self, $sAlts, $dialog ) = @_;

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

    local $self->{'dialog'}->{'_opts'}->{'yes-button'} = 'Continue';
    local $self->{'dialog'}->{'_opts'}->{'no-button'} = 'Abort';
    exit 50 if $dialog->boolean( <<"EOF", TRUE );

\\Zb\\Z1WARNING \\Z0CURRENT SQL SERVER VENDOR IS NOT SUPPORTED \\Z1WARNING\\Zn

The installer detected that your current SQL server ($vendor $version) is not supported and that there is no alternative version for that vendor.
If you continue, you'll be asked for another SQL server vendor but bear in mind that the upgrade could fail. You should really considere backuping all your SQL data before continue.
                
Are you sure you want to continue?
EOF
}

=back

=head1 Author

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
