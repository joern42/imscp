=head1 NAME

 iMSCP::Installer  i-MSCP Installer

=cut

package iMSCP::Installer;

use strict;
use warnings;
use File::Basename qw/ basename dirname fileparse /;
use File::Find;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Compat::HashrefViaHash;
use iMSCP::Provider::Config::iMSCP;
use iMSCP::Provider::Config::JavaProperties;
use iMSCP::Cwd '$CWD';
use iMSCP::Debug qw/ debug error getMessageByType endDebug newDebug /;
use iMSCP::Dialog;
use iMSCP::InputValidation 'isStringInList';
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::Umask '$UMASK';
use iMSCP::Rights 'setRights';
use iMSCP::Service;
use iMSCP::Stepper 'step';
use iMSCP::TemplateParser 'processByRef';
use iMSCP::Umask '$UMASK';
use version;
use XML::Simple qw/ :strict XMLin /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Installer adapter for Debian distribution.

=head1 PUBLIC METHODS

=over 4

=item install( )

 Process installation tasks

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;

    if($ENV{IMSCP_DIST_INSTALLER}) {
        $self->_getDistInstallerAdapter()->install();
        $self->_buildDistributionFiles();
        $self->_checkRequirements();
        $self->_removeObsoleteFiles();
        $self->_savePersistentData();

        # Make $::DESTDIR free of any .gitkeep file
        {
            local $SIG{'__WARN__'} = sub { die @_ };
            find(
                {
                    wanted   => sub { unlink or die( sprintf( "Failed to remove the %s file: %s", $_, $! )) if /\.gitkeep$/; },
                    no_chdir => TRUE
                },
                $::{'DESTDIR'}
            );
        }
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See Common::Singleton::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    # Set execution context
    iMSCP::Getopt->context( 'installer' );

    if ( iMSCP::Getopt->preseed ) {
        # The preseed option supersede the reconfigure option
        iMSCP::Getopt->reconfigure( 'none' );
        iMSCP::Getopt->noninteractive( TRUE );
    }

    # Set default UMASK(2)
    $UMASK = 022;

    if ( $ENV{'IMSCP_DIST_INSTALLER'} ) {
        $self->{'DESTDIR'} = $ENV{'DESTDIR'} // File::Temp->newdir( CLEANUP => TRUE );
        $self->_processDistLayout();
        use Data::Dumper;
        print Dumper( $self );
        exit;
    }

    $self->_loadConfig( $self->{'DESTDIR'} );
    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
}

=item processDistLayout

 Process distribution layout.xml file

 Return void, die on failure

=cut

sub _processDistLayout
{
    my ( $self ) = @_;

    my $distLayout = "config/@{ [ iMSCP::LsbRelease->getInstance()->getId( TRUE ) ] }/layout.xml";
    $self->_processXmlFile( -f $distLayout ? $distLayout : 'config/Debian/layout.xml' );

    for my $variable ( qw/ EXEC_PREFIX BINDIR SBINDIR DATAROOTDIR DATADIR SYSCONFDIR LOCALSTATEDIR RUNSTATEDIR DOCDIR MANDIR CONFDIR / ) {
        defined $self->{$variable} or die(
            sprintf( "The '%s' distribution layout.xml file must export the non-empty '%s' directory variable.", $distLayout, $variable )
        );

        $self->{$variable} =~ s/\+$/\/imscp/;
        print "god\n";
    }

    use Data::Dumper;
    print Dumper( $self );
    exit;
}

=item _loadConfig( [ $destdir = '/' ])

 Load configuration

 Param string $destdir
 Return void, die on failure

=cut

sub _loadConfig
{
    my ( $self, $destdir ) = @_;
    $destdir //= '/';

    my $distID = iMSCP::LsbRelease->getInstance()->getId( TRUE );
    my $masterDistConffile = $ENV{'IMSCP_DIST_INSTALLER'}
        ? ( -f "config/$distID/imscp.conf.dist" ? "config/$distID/imscp.conf.dist" : "config/Debian/imscp.conf.dist" ) : undef;

    # Load distribution configuration (new config)

    my $provider = iMSCP::Provider::Config::iMSCP->new(
        DISTRIBUTION_FILE => $masterDistConffile,
        PRODUCTION_FILE   => "$self->{'CONFDIR'}/imscp.conf",
        DESTDIR           => "$destdir",
        EXCLUDE_REGEXP    => qr/^(?:BuildDate|Version|CodeName|PluginApi|
            THEME_ASSETS_VERSION|EXEC_PREFIX|BINDIR|SBINDIR|DATAROOTDIR|DATADIR|SYSCONFDIR|LOCALSTATEDIR|RUNSTATEDIR|DOCDIR|MANDIR|CONFDIR)$/x,
        VARIABLES         => $ENV{'IMSCP_DIST_INSTALLER'} ? { map { $_ => $self->{$_} } qw/
            EXEC_PREFIX BINDIR SBINDIR DATAROOTDIR DATADIR SYSCONFDIR LOCALSTATEDIR RUNSTATEDIR DOCDIR MANDIR CONFDIR
        / } : {}
    );
    $self->{'config'} = $provider->( $provider );

    # Set distribution variables
    $self->{'config'}->{'DIST_ID'} = $distID;
    $self->{'config'}->{'DIST_CODENAME'} = iMSCP::LsbRelease->getInstance()->getCodename( TRUE );
    $self->{'config'}->{'DIST_RELEASE'} = iMSCP::LsbRelease->getInstance()->getRelease( TRUE, TRUE );

    # Only for backward compatibility (transitional)
    tie %::imscpConfig, 'iMSCP::Compat::HashrefViaHash', HASHREF => $self->{'config'};

    use Data::Dumper;
    print Dumper( \%::imscpConfig );
    exit;

    # Load production configuration (old config)
    if ( -f "$self->{'CONFDIR'}/imscp.conf" ) {
        iMSCP::File->new( filename => "$self->{'CONFDIR'}/imscp.conf" )->copyFile(
            "$destdir$self->{'CONFDIR'}/imscpOld.conf"
        ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
    } else {
        iMSCP::File->new( filename => "$destdir$self->{'CONFDIR'}/imscp.conf" )->copyFile(
            "$destdir$self->{'CONFDIR'}/imscpOld.conf"
        ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
    }
    $provider = iMSCP::Provider::Config::iMSCP->new(
        DISTRIBUTION_FILE => $masterDistConffile,
        PRODUCTION_FILE   => "$destdir$self->{'CONFDIR'}/imscpOld.conf",
    );
    $self->{'old_config'} = $provider->( $provider );

    # Only for backward compatibility (transitional)  
    tie %::imscpOldConfig, 'iMSCP::Compat::HashrefViaHash', HASHREF => $self->{'old_config'};

    exit;

    return;
}

=item _buildDistributionFiles( )

 Build distribution files

 Return int 0 on success, other on failure

=cut

sub _buildDistributionFiles
{
    my ( $self ) = @_;

    for my $dir ( qw/ config contrib docs src / ) {
        local $CWD = $dir;
        $self->_processXmlFile( 'install.xml' );
    }
}

=item _processXmlFile( $file )

 Process the givem install.xml or layout.xml file

 Param string $file XML file
 Return void, die on failure

=cut

sub _processXmlFile
{
    my ( $self, $file ) = @_;

    my $nodes = XMLin( $file, ForceArray => TRUE, ForceContent => TRUE, NormaliseSpace => 2, KeyAttr => {}, VarAttr => 'export' );

    $self->_processFolderNode( $_ ) for @{ $nodes->{'folder'} };
    $self->_processCopyConfigNode( $_ ) for @{ $nodes->{'copy_config'} };
    $self->_processCopyNode( $_ ) for @{ $nodes->{'copy'} };

    for ( @{ $nodes->{'install'} } ) {
        local $CWD = $self->_expandVars( $_ > { 'content' } );
        $self->_processXmlFile( 'install.xml' );
    }

    $self->_processCommandNode( $_ ) for @{ $nodes->{'command'} };
}

=item _processFolderNode( \%node )

 Create a folder according the given node

 Process the xml folder node by creating the described directory.

 Param hashref \%node Node
  OPTIONAL node attributes:
   export     : Export the given variable, seeding it with node content. Variable are exported as attribute of this package.
   create_if  : Create the folder only if the condition is met
   umask      : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
   user       : Folder owner
   group      : Folder group
   mode       : Folder mode
 Return void, die on failure

=cut

sub _processFolderNode
{
    my ( $self, $node ) = @_;

    $node->{'content'} = $self->_expandVars( $node->{'content'} );
    $self->{$node->{'export'}} = $node->{'content'} if defined $node->{'export'};

    return unless length $node->{'content'} && ( !defined $node->{'create_if'} || eval expandVars( $node->{'create_if'} ) );

    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    $node->{'content'} = $self->{'DESTDIR'} . $node->{'content'};

    iMSCP::Dir
        ->new( dirname => $node->{'content'} )
        ->make( {
            user  => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
            group => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
            mode  => defined $node->{'mode'} ? oct( $node->{'mode'} ) : undef
        } );
}

=item _processCopyConfigNode( \%node )

 Copy a configuration directory or file according the given node

 Files that are being removed and which are located under one of /etc/init,
 /etc/init.d, /etc/systemd/system or /usr/local/lib/systemd/system directories
 are processed by the service provider. Specific treatment must be applied for
 these files. Removing them without further care could cause unexpected issues
 with the init system

 Param hashref \%node Node
  OPTIONAL node attributes:
   copy_if       : Copy the file or directory only if the condition is met, remove it otherwise, unless the keep_if expression evaluate to TRUE
   keep_if       : Don't delete the file or directory if it exists and if the keep_if expression evaluate to TRUE
   copy_cwd      : Copy the $CWD directory (excluding the install.xml), instead of a directory in $CWD (current configuration directory)
   copy_as       : Destination file or directory name
   subdir        : Sub-directory in which file must be searched, relative to $CWD (current configuration directory)
   umask         : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
   mode          : Destination file or directory mode
   dirmode       : Destination directory mode (can be set only if the mode attribute is not set)
   filemode      : Destination directory mode (can be set only if the mode attribute is not set)
   user          : Destination file or directory owner
   group         : Destination file or directory group
   recursive     : Whether or not ownership and permissions must be fixed recursively
   expand_vars   : Whether or not the copied file(s) must be processed for variables expansion
   srv_provider  : Whether or not the give node must be processed by the service provider on removal (case of SysVinit, Upstart and Systemd conffiles)
                   That attribute must be set with the service name for which the system provider must act. This attribute is evaluated only when
                   the node provide the copy_if attribute and only if the expression (value) of that attribute evaluate to FALSE.
 Return void, die on failure

=cut

sub _processCopyConfigNode
{
    my ( $self, $node ) = @_;

    $node->{'content'} = $self->_expandVars( $node->{'content'} );

    if ( defined $node->{'copy_if'} && !$self->evalConditionFromXmlFile( $node->{'copy_if'} ) ) {
        return if defined $node->{'keep_if'} && eval $self->_expandVars( $node->{'keep_if'} );

        my $syspath;
        if ( defined $node->{'copy_as'} ) {
            my ( undef, $dirs ) = fileparse( $node->{'content'} );
            $syspath = "$dirs/$node->{'copy_as'}";
        } else {
            $syspath = $node->{'content'};
        }

        return unless $syspath ne '/' && -e $syspath;

        if ( $node->{'srv_provider'} ) {
            iMSCP::Service->getInstance()->remove( $node->{'srv_provider'} );
            return;
        }

        if ( -d _ ) {
            iMSCP::Dir->new( dirname => $syspath )->remove();
        } else {
            iMSCP::File->new( filename => $syspath )->delFile() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        }

        return;
    }

    $node->{'content'} = $self->{'DESTDIR'} . '/' . $node->{'content'};

    local $CWD = dirname( $CWD ) if $node->{'copy_cwd'};
    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};
    my ( $name, $dirs ) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $dest = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    if ( !-e $source && $::imscpConfig{'DISTRO_FAMILY'} ne $::imscpConfig{'DISTRO_ID'} ) {
        # If name isn't in $CWD(/$node->{'subdir'})?, search for it in the <DISTRO_FAMILY>(/$node->{'subdir'})? directory,
        $source =~ s%^($FindBin::Bin/configs/)$::imscpConfig{'DISTRO_ID'}%${1}$::imscpConfig{'DISTRO_FAMILY'}%;
        # stat again as _ refers to the previous stat structure
        stat $source or die( sprintf( "Couldn't stat %s: %s", $source, $! ));
    }

    if ( -d _ ) {
        iMSCP::Dir->new( dirname => $source )->copy( $dest );

        if ( $node->{'expand_vars'} ) {
            while ( my $dentry = <$dest/*> ) {
                my $file = iMSCP::File->new( filename => $dentry );
                defined( my $fileC = $file->getAsRef()) or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
                processByRef( $self->{'config'}, $fileC );
                $file->save();
            }
        }

        if ( $node->{'copy_cwd'} ) {
            iMSCP::File->new( filename => $dest . '/install.xml' )->remove() == 0 or die(
                getMessageByType( 'error', { amount => 1, remove => TRUE } )
            );
        }
    } else {
        iMSCP::File->new( filename => $source )->copy( $dest ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
    }

    setRights( $dest, {
        mode      => $node->{'mode'},
        dirmode   => $node->{'dirmode'},
        filemode  => $node->{'filemode'},
        user      => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
        group     => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
        recursive => $node->{'recursive'}
    } ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));

    return;
}

=item _processCopyNode( \%node )

 Copy a directory or file according the given node

 Param hashref \%node Node
  OPTIONAL node attributes:
   copy_if      : Copy the file or directory only if the condition is met, remove it otherwise, unless the keep_if expression evaluate to TRUE
   keep_if      : Don't delete the file or directory if it exists and if the keep_if expression evaluate to TRUE
   copy_cwd     : Copy the $CWD directory (excluding the install.xml), instead of a directory in $CWD (current configuration directory)
   copy_as      : Destination file or directory name
   subdir       : Sub-directory in which file must be searched, relative to $CWD (current configuration directory)
   umask        : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
   mode         : Destination file or directory mode
   dirmode      : Destination directory mode (can be set only if the mode attribute is not set)
   filemode     : Destination directory mode (can be set only if the mode attribute is not set)
   user         : Destination file or directory owner
   group        : Destination file or directory group
   recursive    : Whether or not ownership and permissions must be fixed recursively
   expand_vars  : Whether or not the copied file(s) must be processed for variables expansion
 Return void, die on failure

=cut

sub _processCopyNode
{
    my ( $self, $node ) = @_;

    # Expand variable inside node content
    $_->{'content'} = $self->_expandVars( $_->{'content'} );

    if ( defined $node->{'copy_if'} && !eval expandVars( $node->{'copy_if'} ) ) {
        return if defined $node->{'keep_if'} && eval expandVars( $node->{'keep_if'} );

        return unless $node->{'content'} ne '/' && -e $node->{'content'};

        if ( -d _ ) {
            iMSCP::Dir->new( dirname => $node->{'content'} )->remove();
        } else {
            iMSCP::File->new( filename => $node->{'content'} )->delFile() == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
        }

        return;
    }

    $node->{'content'} = $self->{'DESTDIR'} . '/' . $node->{'content'};

    local $CWD = dirname( $CWD ) if $node->{'copy_cwd'};
    local $UMASK = oct( $node->{'umask'} ) if defined $node->{'umask'};

    my ( $name, $dirs ) = fileparse( $node->{'content'} );
    my $source = File::Spec->catfile( $CWD, $node->{'subdir'} // '', $name );
    my $dest = File::Spec->canonpath( $dirs . '/' . ( $node->{'copy_as'} // $name ));

    if ( -d $source ) {
        iMSCP::Dir->new( dirname => $source )->copy( $dest );
    } else {
        iMSCP::File->new( filename => $source )->copyFile( $dest ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
    }

    setRights( $dest, {
        mode      => $node->{'mode'},
        dirmode   => $node->{'dirmode'},
        filemode  => $node->{'filemode'},
        user      => defined $node->{'user'} ? expandVars( $node->{'user'} ) : undef,
        group     => defined $node->{'group'} ? expandVars( $node->{'group'} ) : undef,
        recursive => $node->{'recursive'}
    } ) == 0 or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));

    return;
}

=item expandVars( $string )

 Expand variables in the given string

 Param string $string string containing variables to expands
 Return string

=cut

sub _expandVars
{
    my ( $self, $string ) = @_;

    return '' unless length $string;

    while ( my ( $variable ) = $string =~ /\$\{([^\}]+)\}/g ) {
        if ( exists $self->{$variable} ) {
            # Expand variable using value from exported variable
            $string =~ s/\$\{$variable\}/$self->{$variable}/g;
        } elsif ( exists $self->{'config'}->{$variable} ) {
            # Expand variable using value from master configuration file
            $string =~ s/\$\{$variable\}/$self->{'config'}->{$variable}/g;
        } else {
            die( "Couldn't expand variable \${$variable}. Variable not found." );
        }
    }

    $string;
}

=item _getDistInstallerAdapter( $string )

 Get distribution installer adapter instance

 Return iMSCP::Installer::DistAdapter::Abstract

=cut

sub _getDistInstallerAdapter
{
    my ($self) = @_;

    CORE::state $distAdapter||= do {
        my $distAdapter = "iMSCP::Installer::DistAdapter::@{ [ iMSCP::LsbRelease->getInstance()->getId( TRUE ) ] }";
        eval "require $distAdapter;" or die( sprintf( "Couldn't load the '%s' distribution installer adapter: %s", $distAdapter, $@ ));
        $self->{'dist_adapter'} = $distAdapter->new(
            config       => $self->{'config'},
            old_config   => $self->{'old_config'},
            eventManager => $self->{'eventManager'}
        );
    };

    $distAdapter;
}

=back

=head1 Author

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
