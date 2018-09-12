=head1 NAME

 Servers::named::bind - i-MSCP Bind9 Server implementation

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package Servers::named::bind;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => 'setRights';
use Class::Autouse qw/ :nostat Servers::named::bind::installer Servers::named::bind::uninstaller /;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Net;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use iMSCP::TemplateParser qw/ getBlocByRef process processByRef replaceBlocByRef /;
use iMSCP::Umask;
use POSIX 'strftime';
use parent 'Servers::abstract';

=head1 DESCRIPTION

 i-MSCP Bind9 Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    Servers::named::bind::installer->getInstance()->registerInstallerDialogs( $dialogs );
}

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPreInstall', 'bind' );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPreInstall', 'bind' );
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedInstall', 'bind' );
    $rs ||= Servers::named::bind::installer->getInstance()->install();
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedInstall', 'bind' );
}

=item postinstall( )

 See iMSCP::Installer::AbstractActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostInstall' );
    return $rs if $rs;
 
    iMSCP::Service->getInstance()->enable( $self->{'config'}->{'NAMED_SNAME'} );

    $rs ||= $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'Bind9' ];
            0;
        },
        100
    );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPostInstall' );
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedUninstall', 'bind' );
    $rs ||= Servers::named::bind::uninstaller->getInstance()->uninstall();
    return $rs if $rs;

    if ( iMSCP::ProgramFinder::find( $self->{'config'}->{'NAMED_BNAME'} ) ) {
        $rs = $self->restart();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterNamedUninstall', 'bind' );
}

=item setEnginePermissions( )

 See iMSCP::Installer::AbstractActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedSetEnginePermissions' );
    $rs ||= setRights( $self->{'config'}->{'BIND_CONF_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $self->{'config'}->{'BIND_GROUP'},
        dirmode   => '2750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= setRights( $self->{'config'}->{'BIND_DB_ROOT_DIR'}, {
        user      => $self->{'config'}->{'BIND_USER'},
        group     => $self->{'config'}->{'BIND_GROUP'},
        dirmode   => '2750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedSetEnginePermissions' );
}

=item addDmn( \%data )

 See iMSCP::Modules::AbstractActions::addDmn()

=cut

sub addDmn
{
    my ( $self, $data ) = @_;

    # Never process the same zone twice
    # Occurs only in few contexts (eg. when using BASE_SERVER_VHOST as customer domain)
    return 0 if $self->{'seen_zones'}->{$data->{'DOMAIN_NAME'}};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedAddDmn', $data );
    $rs ||= $self->_createZoneFile( $data ) if $self->{'config'}->{'BIND_TYPE'} eq 'master';
    $rs ||= $self->_addZone( $data );
    $self->{'seen_zones'}->{$data->{'DOMAIN_NAME'}} = TRUE;
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedAddDmn', $data );
}

=item postaddDmn( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostAddDmn', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'WEBSITE_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
        $rs = $self->addSub( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $data->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'},
            MAIL_ENABLED       => FALSE,
            DOMAIN_IP          => $::imscpConfig{'BASE_SERVER_PUBLIC_IP'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedPostAddDmn', $data );
}

=item disableDmn( \%data )

 See iMSCP::Modules::AbstractActions::disableDmn()

=cut

sub disableDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDisableDmn', $data );
    $rs ||= $self->addDmn( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedDisableDmn', $data );
}

=item postdisableDmn( \%data )

 See iMSCP::Modules::AbstractActions::postdisableDmn()

 See the disableDmn() method for explaination.

=cut

sub postdisableDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDisableDmn', $data );
    $rs ||= $self->postaddDmn( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPostDisableDmn', $data );
}

=item deleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::deleteDmn()

=cut

sub deleteDmn
{
    my ( $self, $data ) = @_;

    return 0 if $data->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$data->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelDmn', $data );
    $rs ||= $self->_deleteZone( $data );
    return $rs if $rs;

    if ( $self->{'config'}->{'BIND_TYPE'} eq 'master' ) {
        for ( "$self->{'wrkDir'}/$data->{'DOMAIN_NAME'}.db", "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$data->{'DOMAIN_NAME'}.db" ) {
            next unless -f;
            $rs = iMSCP::File->new( filename => $_ )->delFile();
            return $rs if $rs;
        }
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedDelDmn', $data );
}

=item postdeleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::postdeleteDmn()

=cut

sub postdeleteDmn
{
    my ( $self, $data ) = @_;

    return 0 if $data->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$data->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDelDmn', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'WEBSITE_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
        $rs = $self->deleteSub( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $data->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedPostDelDmn', $data );
}

=item addSub( \%data )

 See iMSCP::Modules::AbstractActions::addSub()

=cut

sub addSub
{
    my ( $self, $data ) = @_;

    return 0 unless $self->{'config'}->{'BIND_TYPE'} eq 'master';

    my $dbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'PARENT_DOMAIN_NAME'}.db" );
    my $dbFileC = $dbFile->getAsRef();
    return 1 unless defined $dbFileC;

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', 'db_sub.tpl', \my $dbSubTplC, $data );
    return $rs if $rs;

    unless ( defined $dbSubTplC ) {
        $dbSubTplC = iMSCP::File->new( filename => "$self->{'tplDir'}/db_sub.tpl" )->get();
        return 1 unless defined $dbSubTplC;
    }

    $rs = $self->_updateSerialNumber( $data->{'PARENT_DOMAIN_NAME'}, $dbFileC ) unless $self->{'serials'}->{$data->{'PARENT_DOMAIN_NAME'}};
    $rs ||= $self->{'eventManager'}->trigger( 'beforeNamedAddSub', $dbFileC, \$dbSubTplC, $data );
    return $rs if $rs;

    my $net = iMSCP::Net->getInstance();
    my $domainIP = $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} eq 'no' || $net->isRoutableAddr( $data->{'DOMAIN_IP'} )
        ? $data->{'DOMAIN_IP'} : $::imscpConfif{'BASE_SERVER_PUBLIC_IP'};

    replaceBlocByRef( "; mail rr begin.\n", "; mail rr ending.\n", '', \$dbSubTplC ) unless $data->{'MAIL_ENABLED'};
    processByRef(
        {
            DOMAIN_NAME    => $data->{'PARENT_DOMAIN_NAME'},
            SUBDOMAIN_NAME => $data->{'DOMAIN_NAME'},
            MX_HOST        => $::imscpConfig{'SERVER_HOSTNAME'} . $::imscpConfig{'SERVER_DOMAIN'} . '.',
            IP_TYPE        => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP      => $domainIP
        },
        \$dbSubTplC
    );
    replaceBlocByRef( "; sub [$data->{'DOMAIN_NAME'}] begin.\n", "; sub [$data->{'DOMAIN_NAME'}] ending.\n", '', $dbFileC );
    replaceBlocByRef( "; sub [{SUBDOMAIN_NAME}] begin.\n", "; sub [{SUBDOMAIN_NAME}] ending.\n", $dbSubTplC, $dbFileC, TRUE );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddSub', $dbFileC, $data );
    $rs ||= $dbFile->save();
    $rs ||= $self->_compileZone( $data->{'PARENT_DOMAIN_NAME'}, $dbFile );
    $self->{'reload'} = TRUE unless $rs;
    $rs;
}

=item disableSub( \%data )

 See iMSCP::Modules::AbstractActions::disableSub()

 When a subdomain is being disabled, we must ensure that the DNS data are still present for it (eg: when doing a full
 upgrade or reconfiguration). This explain here why we are executing the addSub( ) action.

=cut

sub disableSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDisableSub', $data );
    $rs ||= $self->addSub( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedDisableSub', $data );
}

=item postdisableSub( \%data )

 See iMSCP::Modules::AbstractActions::postdisableSub()

 See the disableSub( ) method for explaination.

=cut

sub postdisableSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDisableSub', $data );
    $rs ||= $self->postaddSub( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPostDisableSub', $data );
}

=item deleteSub( \%data )

 See iMSCP::Modules::AbstractActions::deleteSub()

=cut

sub deleteSub
{
    my ( $self, $data ) = @_;

    return 0 unless $self->{'config'}->{'BIND_TYPE'} eq 'master';

    my $dbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'PARENT_DOMAIN_NAME'}.db" );
    my $dbFileC = $dbFile->getAsRef();
    return 1 unless defined $dbFileC;

    unless ( $self->{'serials'}->{$data->{'PARENT_DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSerialNumber( $data->{'PARENT_DOMAIN_NAME'}, $dbFileC );
        return $rs if $rs;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelSub', $dbFileC, $data );
    return $rs if $rs;

    replaceBlocByRef( "; sub [$data->{'DOMAIN_NAME'}] begin.\n", "; sub [$data->{'DOMAIN_NAME'}] ending.\n", '', $dbFileC );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedDelSub', $dbFileC, $data );
    $rs ||= $dbFile->save();
    $rs ||= $self->_compileZone( $data->{'PARENT_DOMAIN_NAME'}, $dbFile );
    $self->{'reload'} = TRUE unless $rs;
    $rs;
}

=item addCustomDNS( \%data )

 See iMSCP::Modules::AbstractActions::addCustomDNS()

=cut

sub addCustomDNS
{
    my ( $self, $data ) = @_;

    return 0 unless $self->{'config'}->{'BIND_TYPE'} eq 'master';

    my $dbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'DOMAIN_NAME'}.db" );
    my $dbFileC = $dbFile->getAsRef();
    return 1 unless defined $dbFileC;

    unless ( $self->{'serials'}->{$data->{'DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSerialNumber( $data->{'DOMAIN_NAME'}, $dbFileC );
        return $rs if $rs;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedAddCustomDNS', $dbFileC, $data );
    return $rs if $rs;

    my @rr = ();
    push @rr, join "\t", @{ $_ } for @{ $data->{'DNS_RECORDS'} };

    my $fh;
    unless ( open( $fh, '<', $dbFileC ) ) {
        error( sprintf( "Couldn't open in-memory file handle: %s", $! ));
        return 1;
    }

    my ( $tmpFileC, $origin ) = ( '', '' );
    while ( my $line = <$fh> ) {
        my $isOrigin = $line =~ /^\$ORIGIN\s+([^\s;]+).*\n$/;
        $origin = $1 if $isOrigin; # Update $ORIGIN if needed

        unless ( $isOrigin || index( $line, '$' ) == 0 || index( $line, ';' ) == 0 ) {
            # Process $ORIGIN substitutions
            $line =~ s/\@/$origin/g;
            $line =~ s/^(\S+?[^\s.])\s+/$1.$origin\t/;
            # Skip the default SPF record if it is overridden with a custom DNS record
            next if $line =~ /^(\S+)\s+.*?\s+"v=\bspf1\b.*?"/ && grep /^\Q$1\E\s+.*?\s+"v=\bspf1\b.*?"/, @rr;
        }

        $tmpFileC .= $line;
    }
    close( $fh );

    ${ $dbFileC } = $tmpFileC;
    undef $tmpFileC;
    undef $origin;

    replaceBlocByRef( "; dns rr begin.\n", "; dns rr ending.\n", "; dns rr begin.\n" . join( "\n", @rr ) . "\n; dns rr ending.\n", $dbFileC );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddCustomDNS', $dbFileC, $data );
    $rs ||= $dbFile->save();
    $rs ||= $self->_compileZone( $data->{'DOMAIN_NAME'}, $dbFile );
    $self->{'reload'} = TRUE unless $rs;
    $rs;
}

=item restart( )

 Restart Bind9

 Return int 0 on success, other or die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedRestart' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->restart( $self->{'config'}->{'NAMED_SNAME'} );

    $self->{'eventManager'}->trigger( 'afterNamedRestart' );
}

=item reload( )

 Reload Bind9

 Return int 0 on success, other or die on failure

=cut

sub reload
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedReload' );
    return $rs if $rs;

    iMSCP::Service->getInstance()->reload( $self->{'config'}->{'NAMED_SNAME'} );

    $self->{'eventManager'}->trigger( 'afterNamedReload' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Servers::named::bind

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    @{ $self }{qw/ start restart /} = ( FALSE, FALSE );
    $self->{'serials'} = {};
    $self->{'seen_zones'} = {};
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/bind";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->{'tplDir'} = "$self->{'cfgDir'}/parts";

    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/bind.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/bind.data",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer';

    $self;
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/bind.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/bind.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/bind.data", readonly => TRUE;
        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.data.dist" )->moveFile( "$self->{'cfgDir'}/bind.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item _addZone( \%data )

 Add a zone in the Bind9 configuration file

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _addZone
{
    my ( $self, $data ) = @_;

    my ( $cfgFileName, $cfgFileDir ) = fileparse( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} || $self->{'config'}->{'BIND_CONF_FILE'} );
    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    my $tplFileName = "cfg_$self->{'config'}->{'BIND_TYPE'}.tpl";
    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', $tplFileName, \my $cfgTplC, $data );
    return $rs if $rs;

    unless ( defined $cfgTplC ) {
        $cfgTplC = iMSCP::File->new( filename => "$self->{'tplDir'}/$tplFileName" )->get();
        return 1 unless defined $cfgTplC;
    }

    $rs = $self->{'eventManager'}->trigger( 'beforeNamedAddDmnConfig', $fileC, \$cfgTplC, $data );
    return $rs if $rs;

    processByRef(
        {
            BIND_DB_FORMAT => $self->{'config'}->{'BIND_DB_FORMAT'} =~ s/=\d//r,
            ZONE_NAME      => $data->{'DOMAIN_NAME'},
            IP_ADDRESSES   => $self->{'config'}->{'BIND_TYPE'} eq 'master' ?
                (
                    $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} ne 'none'
                        # There are slave DNS servers: We allow AXFR queries from the slave DNS servers and localhost
                        ? join( '; ', split( /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} )) . '; localhost;'
                        # There are no slave DNS servers. We allow AXFR queries from localhost only
                        : 'localhost;'
                ) :
                # Authoritative DNS servers (masters statement)
                join( '; ', split( /[;, ]+/, $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} ))
        },
        \$cfgTplC
    );
    replaceBlocByRef( "// imscp [$data->{'DOMAIN_NAME'}] zone begin.\n", qr#\Q// imscp [$data->{'DOMAIN_NAME'}] zone ending.\E\n+#, '', $fileC );
    replaceBlocByRef( "// imscp [{ZONE_NAME}] zone begin.\n", "// imscp [{ZONE_NAME}] zone ending.\n", $cfgTplC, $fileC, TRUE );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddDmnConfig', $fileC, $data );
    $rs ||= $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _deleteZone( \%data )

 Delete a zone entry fro the Bind9 configuration file

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _deleteZone
{
    my ( $self, $data ) = @_;

    my ( $cfgFileName, $cfgFileDir ) = fileparse( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} || $self->{'config'}->{'BIND_CONF_FILE'} );
    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelDmnConfig', $fileC, $data );
    return $rs if $rs;

    replaceBlocByRef( "// imscp [$data->{'DOMAIN_NAME'}] zone begin.\n", "// imscp [$data->{'DOMAIN_NAME'}] zone ending.\n", '', $fileC );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedDelDmnConfig', $fileC, $data );
    $rs ||= $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _createZoneFile( \%data )

 Create (or update) a DNS zone file

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _createZoneFile
{
    my ( $self, $data ) = @_;

    my $wDbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'DOMAIN_NAME'}.db" );
    my $wDbFileC;

    return 1 if -f $wDbFile && !defined( $wDbFileC = $wDbFile->getAsRef());

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', 'db.tpl', \my $dbTplC, $data );
    return $rs if $rs;

    unless ( defined $dbTplC ) {
        $dbTplC = iMSCP::File->new( filename => "$self->{'tplDir'}/db.tpl" )->get();
        return 1 unless defined $dbTplC;
    }

    $rs = $self->_updateSerialNumber( $data->{'DOMAIN_NAME'}, \$dbTplC, $wDbFileC );
    $rs ||= $self->{'eventManager'}->trigger( 'beforeNamedAddDmnDb', \$dbTplC, $data );
    return $rs if $rs;

    my $nsRRB = getBlocByRef( "; ns rr begin.\n", "; ns rr ending.\n", \$dbTplC );
    my $glueRRB = getBlocByRef( "; glue rr begin.\n", "; glue rr ending.\n", \$dbTplC );
    my $net = iMSCP::Net->getInstance();
    my $domainIP = $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} eq 'no' || $net->isRoutableAddr( $data->{'DOMAIN_IP'} )
        ? $data->{'DOMAIN_IP'} : $::imscpConfig{'BASE_SERVER_PUBLIC_IP'};
    my @nsIPS = (
        # Master DNS IP addresses
        ( $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} eq 'none' ? $domainIP : split /[;, ]+/, $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} ),
        # Slave DNS IP addresses
        ( $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} eq 'none' ? () : split /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} )
    );
    my @nsNames = (
        # Master DNS names
        ( $self->{'config'}->{'BIND_MASTER_NAMES'} eq 'none' ? 'historical' : split /[;, ]+/, $self->{'config'}->{'BIND_MASTER_NAMES'} ),
        # Slave DNS names 
        ( $self->{'config'}->{'BIND_SLAVE_NAMES'} eq 'none' ? () : split /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_NAMES'} ),
    );

    my ( $nsRR, $glueRR ) = ( '', '' );

    for my $ipAddrType ( qw/ ipv4 ipv6 / ) {
        my $nsIdx = 1; # prefix counter for autogenerated names (historical behavior)

        for my $ipAddrIdx ( 0 .. $#nsIPS ) {
            next unless $net->getAddrVersion( $nsIPS[$ipAddrIdx] ) eq $ipAddrType;
            my $name = $nsNames[$ipAddrIdx] && $nsNames[$ipAddrIdx] ne 'historical' ? $nsNames[$ipAddrIdx] . '.' : "ns$nsIdx";

            # Insert NS record (only if NS records are not managed through listener file)
            $nsRR .= process( { NS_NAME => $name }, $nsRRB ) unless $nsRRB eq '';

            # Insert glue record (only if glue records are not managed through listener file)
            # Glue RR must be set only if not out-of-zone
            $glueRR .= process(
                {
                    ZONE_NAME  => $data->{'DOMAIN_NAME'},
                    NS_NAME    => $name,
                    NS_IP_TYPE => $ipAddrType eq 'ipv4' ? 'A' : 'AAAA',
                    NS_IP      => $nsIPS[$ipAddrIdx]
                },
                $glueRRB
            ) unless $glueRRB eq '' || ( $name ne "ns$nsIdx" && $name !~ /\Q$data->{'DOMAIN_NAME'}\E$/ );

            $nsIdx++;
        }
    }

    replaceBlocByRef( "; ns rr begin.\n", "; ns rr ending.\n", $nsRR, \$dbTplC ) unless $nsRRB eq '';
    replaceBlocByRef( "; glue rr begin.\n", "; glue rr ending.\n", $glueRR, \$dbTplC ) unless $glueRRB eq '';
    replaceBlocByRef( "; mail rr begin.\n", "; mail rr ending.\n", '', \$dbTplC ) unless $data->{'MAIL_ENABLED'};
    processByRef(
        {
            ZONE_NAME        => $data->{'DOMAIN_NAME'},
            HOSTMASTER_EMAIL => $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} ne 'none'
                ? $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} =~ s/\@/./r : 'hostmaster.{ZONE_NAME}',
            NS_NAME          => $nsNames[0] && $nsNames[0] ne 'historical' ? $nsNames[0] : 'ns1.{ZONE_NAME}',
            MX_HOST          => $::imscpConfig{'SERVER_HOSTNAME'} . $::imscpConfig{'SERVER_DOMAIN'} . '.',
            DOMAIN_NAME      => $data->{'DOMAIN_NAME'},
            IP_TYPE          => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP        => $domainIP
        },
        \$dbTplC
    );

    unless ( !defined $wDbFileC || iMSCP::Getopt->context() eq 'installer' ) {
        replaceBlocByRef(
            "; sub rr begin.\n",
            "; sub rr ending.\n",
            getBlocByRef( "; sub rr begin.\n", "; sub rr ending.\n", $wDbFileC, TRUE ),
            \$dbTplC
        );
        replaceBlocByRef(
            "; dns rr begin.\n",
            "; dns rr ending.\n",
            getBlocByRef( "; dns rr begin.\n", "; dns rr ending.\n", $wDbFileC, TRUE ),
            \$dbTplC
        );
    }

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddDmnDb', \$dbTplC, $data );
    $rs ||= $wDbFile->set( $dbTplC );
    $rs ||= $wDbFile->save();
    $rs ||= $self->_compileZone( $data->{'DOMAIN_NAME'}, $wDbFile );
}

=item _updateSerialNumber( $zoneName, \$dbFileC [, \$wrkDbFileC ] )

 Update SOA serial for the given zone
 
 See RFC 1912 section 2.2 recommendations

 Param string $zoneName Zone name
 Param scalarref \$dbFileC New zone file content
 Param scalarref \$wrkDbFileC OPTIONAL Working zone file content (for serial update)
 Return int 0 on success, other or die on failure

=cut

sub _updateSerialNumber
{
    my ( $self, $zoneName, $dbFileC, $wrkDbFileC ) = @_;

    my $newdate = strftime( '%Y%m%d', localtime ( time( ) ) );

    unless ( $wrkDbFileC ) {
        $self->{'serials'}->{$zoneName} = $newdate . '00';
        processByRef( { TIMESTAMP => $self->{'serials'}->{$zoneName} }, $dbFileC );
        return 0;
    }

    my ( $date, $nn ) = ${ $wrkDbFileC } =~ /^.*?\s+IN\s+SOA\s+.*\(\s+(\d{8})(\d{2})\s*;.*\)/s;
    unless ( $date ) {
        error( sprintf( "SOA serial number not found in the '%s' DNS zone file.", $zoneName ));
        return 1;
    }

    $nn++;
    $self->{'serials'}->{$zoneName} = $newdate > $date || $nn > 99 ? $newdate . '00' : $date . $nn;
    ${ $dbFileC } =~ s/^(.*?\s+IN\s+SOA\s+.*\(\s+)\d{10}\s*(;.*\))/$1$self->{'serials'}->{$zoneName}$2/s;
    0;
}

=item _compileZone( $zonename, $filename )

 Compiles the given zone
 
 Param string $zonename Zone name
 Param string $filename Path to zone filename (zone in text format)
 Return int 0 on success, other on error
 
=cut

sub _compileZone
{
    my ( $self, $zonename, $filename ) = @_;

    # Zone file must not be created world-readable
    local $UMASK = 027;
    my $rs = execute(
        [
            'named-compilezone',
            # Perform post-load zone integrity checks:
            # - MX records must refer to A or AAAA record (both in-zone and out-of-zone hostnames)
            # - SRV records must refer to A or AAAA record (both in-zone and out-of-zone hostnames).
            # - delegation NS records must refer to A or AAAA record (both in-zone and out-of-zone hostnames).
            '-i', 'full',
            '-T', 'ignore',                                                 # Ignore missing deprectated SPF records as we have only TXT records.
            '-k', 'fail',                                                   # Perform "check-names" checks with 'fail' as failure mode
            '-m', 'ignore',                                                 # Fail if MX records are not addresses
            '-M', 'fail',                                                   # Fail if MX records refers to a CNAME
            '-n', 'fail',                                                   # Fail if NS records are no addresses
            '-f', 'text',                                                   # Input fail format
            '-F', $self->{'config'}->{'BIND_DB_FORMAT'},                    # Dumped zone file format
            '-s', 'relative',                                               # Dumped zone file style (only relevant with raw format)
            '-o', "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$zonename.db", # Set zone name
            $zonename,                                                      # Zone name
            $filename                                                       # Input file path
        ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if $rs == 0 && $stdout;

    # Errors for invalid command usage are print to STDERR
    # Errors resulting of DNS record checks are print to STDOUT
    error( sprintf( "Couldn't compile the '%s' DNS zone: %s", $zonename, $stderr || $stdout || 'Unknown error' )) if $rs;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
