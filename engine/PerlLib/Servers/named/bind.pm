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
use Class::Autouse qw/ :nostat Servers::named::bind::installer Servers::named::bind::uninstaller /;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug;
use iMSCP::EventManager;
use iMSCP::Execute;
use iMSCP::File;
use iMSCP::Net;
use iMSCP::ProgramFinder;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Service;
use iMSCP::TemplateParser qw/ getBlocByRef process processByRef replaceBlocByRef /;
use iMSCP::Umask;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP Bind9 Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( undef, $eventManager ) = @_;

    Servers::named::bind::installer->getInstance()->registerSetupListeners( $eventManager );
}

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPreInstall', 'bind' );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPreInstall', 'bind' );
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedInstall', 'bind' );
    $rs ||= Servers::named::bind::installer->getInstance()->install();
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedInstall', 'bind' );
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostInstall' );
    return $rs if $rs;

    local $@;
    eval { iMSCP::Service->getInstance()->enable( $self->{'config'}->{'NAMED_SNAME'} ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

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

 Process uninstall tasks

 Return int 0 on success, other on failure

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

 Set engine permissions

 Return int 0 on success, other on failure

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

 Process addDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub addDmn
{
    my ( $self, $data ) = @_;

    # Never process the same zone twice
    # Occurs only in few contexts (eg. when using BASE_SERVER_VHOST as customer domain)
    return 0 if $self->{'seen_zones'}->{$data->{'DOMAIN_NAME'}};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedAddDmn', $data );
    $rs ||= $self->_addDmnConfig( $data );
    $rs ||= $self->_addDmnDb( $data ) if $self->{'config'}->{'BIND_TYPE'} eq 'master';

    $self->{'seen_zones'}->{$data->{'DOMAIN_NAME'}} = TRUE;

    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedAddDmn', $data );
}

=item postaddDmn( \%data )

 Process postaddDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostAddDmn', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
        $rs = $self->addSub( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $data->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'},
            MAIL_ENABLED       => FALSE,
            DOMAIN_IP          => $data->{'BASE_SERVER_PUBLIC_IP'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedPostAddDmn', $data );
}

=item disableDmn( \%data )

 Process disableDmn tasks

 When a domain is being disabled, we must ensure that the DNS data are still
 present for it (eg: when doing a full upgrade or reconfiguration). This
 explain here why we are executing the addDmn( ) action.

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub disableDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDisableDmn', $data );
    $rs ||= $self->addDmn( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedDisableDmn', $data );
}

=item postdisableDmn( \%data )

 Process postdisableDmn tasks

 See the disableDmn( ) method for explaination.

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postdisableDmn
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDisableDmn', $data );
    $rs ||= $self->postaddDmn( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPostDisableDmn', $data );
}

=item deleteDmn( \%data )

 Process deleteDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub deleteDmn
{
    my ( $self, $data ) = @_;

    return 0 if $data->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$data->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelDmn', $data );
    $rs ||= $self->_deleteDmnConfig( $data );
    return $rs if $rs;

    if ( $self->{'config'}->{'BIND_TYPE'} eq 'master' ) {
        for ( "$self->{'wrkDir'}/$data->{'DOMAIN_NAME'}.db", "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$data->{'DOMAIN_NAME'}.db" ) {
            next unless -f;
            $rs = iMSCP::File->new( filename => $_ )->delFile();
            return $rs if $rs;
        }
    }

    $self->{'eventManager'}->trigger( 'afterNamedDelDmn', $data );
}

=item postdeleteDmn( \%data )

 Process postdeleteDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postdeleteDmn
{
    my ( $self, $data ) = @_;

    return 0 if $data->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$data->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDelDmn', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
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

 Process addSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

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

    $rs = $self->_updateSOAserialNumber( $data->{'PARENT_DOMAIN_NAME'}, $dbFileC, $dbFileC ) unless $self->{'serials'}->{$data->{'PARENT_DOMAIN_NAME'}};
    $rs ||= $self->{'eventManager'}->trigger( 'beforeNamedAddSub', $dbFileC, \$dbSubTplC, $data );
    return $rs if $rs;

    my $net = iMSCP::Net->getInstance();
    my $domainIP = $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} eq 'no' || $net->isRoutableAddr( $data->{'DOMAIN_IP'} )
        ? $data->{'DOMAIN_IP'} : $data->{'BASE_SERVER_PUBLIC_IP'};

    replaceBlocByRef( "; mail rr begin.\n", "; mail rr ending.\n", '', \$dbSubTplC ) unless $data->{'MAIL_ENABLED'};
    processByRef(
        {
            SUBDOMAIN_NAME => $data->{'DOMAIN_NAME'},
            MX_HOST        => $::imscpConfig{'SERVER_HOSTNAME'},
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
}

=item postaddSub( \%data )

 Process postaddSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub postaddSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostAddSub', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
        $rs = $self->addSub( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $data->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'},
            MAIL_ENABLED       => FALSE,
            DOMAIN_IP          => $data->{'BASE_SERVER_PUBLIC_IP'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedPostAddSub', $data );
}

=item disableSub( \%data )

 Process disableSub tasks

 When a subdomain is being disabled, we must ensure that the DNS data are still present for it (eg: when doing a full
 upgrade or reconfiguration). This explain here why we are executing the addSub( ) action.

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub disableSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDisableSub', $data );
    $rs ||= $self->addSub( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedDisableSub', $data );
}

=item postdisableSub( \%data )

 Process postdisableSub tasks

 See the disableSub( ) method for explaination.

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postdisableSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDisableSub', $data );
    $rs ||= $self->postaddSub( $data );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNamedPostDisableSub', $data );
}

=item deleteSub( \%data )

 Process deleteSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub deleteSub
{
    my ( $self, $data ) = @_;

    return 0 unless $self->{'config'}->{'BIND_TYPE'} eq 'master';

    my $dbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'PARENT_DOMAIN_NAME'}.db" );
    my $dbFileC = $dbFile->getAsRef();
    return 1 unless defined $dbFileC;

    unless ( $self->{'serials'}->{$data->{'PARENT_DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSOAserialNumber( $data->{'PARENT_DOMAIN_NAME'}, $dbFileC, $dbFileC );
        return $rs if $rs;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelSub', $dbFileC, $data );
    return $rs if $rs;

    replaceBlocByRef( "; sub [$data->{'DOMAIN_NAME'}] begin.\n", "; sub [$data->{'DOMAIN_NAME'}] ending.\n", '', $dbFileC );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedDelSub', $dbFileC, $data );
    $rs ||= $dbFile->save();
    $rs ||= $self->_compileZone( $data->{'PARENT_DOMAIN_NAME'}, $dbFile );
}

=item postdeleteSub( \%data )

 Process postdeleteSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub postdeleteSub
{
    my ( $self, $data ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedPostDelSub', $data );
    return $rs if $rs;

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_TYPE'} eq 'master' && defined $data->{'ALIAS'} ) {
        $rs = $self->deleteSub( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $data->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} = TRUE;
    $self->{'eventManager'}->trigger( 'afterNamedPostDelSub', $data );
}

=item addCustomDNS( \%data )

 Process addCustomDNS tasks

 Param hash \%data Custom DNS data
 Return int 0 on success, other on failure

=cut

sub addCustomDNS
{
    my ( $self, $data ) = @_;

    return 0 unless $self->{'config'}->{'BIND_TYPE'} eq 'master';

    my $dbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$data->{'DOMAIN_NAME'}.db" );
    my $dbFileC = $dbFile->getAsRef();
    return 1 unless defined $dbFileC;

    unless ( $self->{'serials'}->{$data->{'DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSOAserialNumber( $data->{'DOMAIN_NAME'}, $dbFileC, $dbFileC );
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

 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedRestart' );
    return $rs if $rs;

    local $@;
    eval { iMSCP::Service->getInstance()->restart( $self->{'config'}->{'NAMED_SNAME'} ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterNamedRestart' );
}

=item reload( )

 Reload Bind9

 Return int 0 on success, other on failure

=cut

sub reload
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedReload' );
    return $rs if $rs;

    local $@;
    eval { iMSCP::Service->getInstance()->reload( $self->{'config'}->{'NAMED_SNAME'} ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

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

    $self->{'restart'} = FALSE;
    $self->{'reload'} = FALSE;
    $self->{'serials'} = {};
    $self->{'seen_zones'} = {};
    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/bind";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->{'tplDir'} = "$self->{'cfgDir'}/parts";
    $self->_mergeConfig() if -f "$self->{'cfgDir'}/bind.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/bind.data",
        readonly    => !( defined $::execmode && $::execmode eq 'setup' ),
        nodeferring => ( defined $::execmode && $::execmode eq 'setup' );
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

=item _addDmnConfig( \%data )

 Add domain DNS configuration

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _addDmnConfig
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
            IP_ADDRESSES   => $self->{'config'}->{'BIND_TYPE'} eq 'master' ? ( $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} ne 'none'
                ? join( '; ', split( /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} )) . '; localhost;' : 'localhost;'
            ) : join( '; ', split( /[;, ]+/, $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} )) . ';'
        },
        \$cfgTplC
    );
    replaceBlocByRef( "// imscp [$data->{'DOMAIN_NAME'}] begin.\n", "// imscp [$data->{'DOMAIN_NAME'}] ending.\n", '', $fileC );
    replaceBlocByRef( "// imscp [{ZONE_NAME}] entry begin.\n", "// imscp [{ZONE_NAME}] entry ending.\n", $cfgTplC, $fileC, TRUE );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddDmnConfig', $fileC, $data );
    $rs ||= $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _deleteDmnConfig( \%data )

 Delete domain DNS configuration

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _deleteDmnConfig
{
    my ( $self, $data ) = @_;

    my ( $cfgFileName, $cfgFileDir ) = fileparse( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} || $self->{'config'}->{'BIND_CONF_FILE'} );
    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedDelDmnConfig', $fileC, $data );
    return $rs if $rs;

    replaceBlocByRef( "// imscp [$data->{'ZONE_NAME'}] begin.\n", "// imscp [$data->{'ZONE_NAME'}] ending.\n", '', $fileC );

    $rs = $self->{'eventManager'}->trigger( 'afterNamedDelDmnConfig', $fileC, $data );
    $rs ||= $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _addDmnDb( \%data )

 Add domain DNS zone file

 Param hash \%data Data as provided by the Domain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _addDmnDb
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

    $rs = $self->_updateSOAserialNumber( $data->{'DOMAIN_NAME'}, \$dbTplC, $wDbFileC );
    $rs ||= $self->{'eventManager'}->trigger( 'beforeNamedAddDmnDb', \$dbTplC, $data );
    return $rs if $rs;

    my $nsRRB = getBlocByRef( "; ns rr begin.\n", "; ns rr ending.\n", \$dbTplC );
    my $glueRRB = getBlocByRef( "; glue rr begin.\n", "; glue rr ending.\n", \$dbTplC );
    my $net = iMSCP::Net->getInstance();
    my $domainIP = $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} eq 'no' || $net->isRoutableAddr( $data->{'DOMAIN_IP'} )
        ? $data->{'DOMAIN_IP'} : $data->{'BASE_SERVER_PUBLIC_IP'};
    my @nsIPS = (
        # Master DNS IP addresses
        ( $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} eq 'none' ? $domainIP : split /[;, ]+/, $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} ),
        # Slave DNS IP addresses
        ( $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} eq 'none' ? () : split /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} )
    );
    my @nsNames = (
        # Master DNS names
        ( $self->{'config'}->{'BIND_MASTER_NAMES'} eq 'none' ? () : split /[;, ]+/, $self->{'config'}->{'BIND_MASTER_NAMES'} ),
        # Slave DNS names 
        ( $self->{'config'}->{'BIND_SLAVE_NAMES'} eq 'none' ? () : split /[;, ]+/, $self->{'config'}->{'BIND_SLAVE_NAMES'} ),
    );

    my ( $nsRR, $glueRR ) = ( '', '' );

    for my $ipAddrType ( qw/ ipv4 ipv6 / ) {
        my $nsIdx = 1; # prefix counter for autogenerated names (historical behavior)

        for my $ipAddrIdx ( 0 .. $#nsIPS ) {
            next unless $net->getAddrVersion( $nsIPS[$ipAddrIdx] ) eq $ipAddrType;
            my $name = $nsNames[$ipAddrIdx] ? $nsNames[$ipAddrIdx] . '.' : "ns$nsIdx";

            # Insert NS record (only if NS records are not managed through listener file)
            $nsRR .= process( { NS_NAME => $name }, $nsRRB ) unless $nsRRB eq '';

            # Insert glue record (only if glue records are not managed through listener file)
            # Glue RR must be set only if not out-of-zone
            $glueRR .= process(
                {
                    NS_NAME    => $name,
                    NS_IP_TYPE => $ipAddrType eq 'ipv4' ? 'A' : 'AAAA',
                    NS_IP      => $nsIPS[$ipAddrIdx]
                },
                $glueRRB
            ) unless $glueRRB eq '' || ( $name ne "ns$nsIdx" && $name !~ /\Q$data->{'DOMAIN_NAME'}\E$/ );

            $nsIdx++;
        }
    }

    replaceBlocByRef( "; ns rr begin.\n", "; ns rr ending.\n", $nsRR, \$dbTplC ) if $nsRR ne '';
    replaceBlocByRef( "; glue rr begin.\n", "; glue rr ending.\n", $glueRR, \$dbTplC ) if $glueRR ne '';
    replaceBlocByRef( "; mail rr begin.\n", "; mail rr ending.\n", '', \$dbTplC ) unless $data->{'MAIL_ENABLED'};
    processByRef(
        {
            HOSTMASTER_EMAIL => $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} ne 'none'
                ? $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} =~ s/\@/./r : 'hostmaster.{DOMAIN_NAME}',
            NS_NAME          => $nsNames[0] || 'ns1.{DOMAIN_NAME}',
            MX_HOST          => $::imscpConfig{'SERVER_HOSTNAME'},
            DOMAIN_NAME      => $data->{'DOMAIN_NAME'},
            IP_TYPE          => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP        => $domainIP
        },
        \$dbTplC
    );

    unless ( !defined $wDbFileC || defined $::execmode && $::execmode eq 'setup' ) {
        replaceBlocByRef( "; sub rr begin.\n", "; sub rr ending.\n", getBlocByRef( "; sub rr begin.\n", "; sub rr ending.\n", $wDbFileC, TRUE ), \$dbTplC );
        replaceBlocByRef( "; dns rr begin.\n", "; dns rr ending.\n", getBlocByRef( "; dns rr begin.\n", "; dns rr ending.\n", $wDbFileC, TRUE ), \$dbTplC );
    }

    $rs = $self->{'eventManager'}->trigger( 'afterNamedAddDmnDb', \$dbTplC, $data );
    $rs ||= $wDbFile->set( $dbTplC );
    $rs ||= $wDbFile->save();
    $rs ||= $self->_compileZone( $data->{'DOMAIN_NAME'}, $wDbFile );
}

=item _updateSOAserialNumber( $zone, \$dbFileC, \$wrkDbFileC )

 Update SOA serial for the given zone according RFC 1912 section 2.2 recommendations

 Param string zone Zone name
 Param scalarref \$dbFileC Zone file content
 Param scalarref \$wrkDbFileC Working zone file content
 Return int 0 on success, other on failure

=cut

sub _updateSOAserialNumber
{
    my ( $self, $zone, $dbFileC, $wrkDbFileC ) = @_;

    $wrkDbFileC = $dbFileC unless defined ${ $wrkDbFileC };

    if ( ${ $wrkDbFileC } !~ /^\s+(?:(?<date>\d{8})(?<nn>\d{2})|(?<placeholder>\{TIMESTAMP\}))\s*;[^\n]*\n/m ) {
        error( sprintf( "Couldn't update SOA serial number for the %s DNS zone: SOA serial number or placeholder not found in input files.", $zone ));
        return 1;
    }

    my %rc = %+;
    my ( $d, $m, $y ) = ( gmtime() )[3 .. 5];
    my $nowDate = sprintf( '%d%02d%02d', $y+1900, $m+1, $d );

    if ( exists $+{'placeholder'} ) {
        $self->{'serials'}->{$zone} = $nowDate . '00';
        ${ $dbFileC } = process( { TIMESTAMP => $self->{'serials'}->{$zone} }, ${ $dbFileC } );
        return 0;
    }

    if ( $rc{'date'} >= $nowDate ) {
        $rc{'nn'}++;
        if ( $rc{'nn'} >= 99 ) {
            $rc{'date'}++;
            $rc{'nn'} = '00';
        }
    } else {
        $rc{'date'} = $nowDate;
        $rc{'nn'} = '00';
    }

    $self->{'serials'}->{$zone} = $rc{'date'} . $rc{'nn'};
    ${ $dbFileC } =~ s/^(\s+)(?:\d{10}|\{TIMESTAMP\})(\s*;[^\n]*\n)/$1$self->{'serials'}->{$zone}$2/m;
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

    local $UMASK = 027;
    my $rs = execute(
        [
            'named-compilezone', '-i', 'full', '-f', 'text', '-F', $self->{'config'}->{'BIND_DB_FORMAT'}, '-s', 'relative',
            '-o', "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$zonename.db", $zonename, $filename
        ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if $stdout;
    error( sprintf( "Couldn't compile the '%s' DNS zone: %s", $zonename, $stderr || 'Unknown error' )) if $rs;
    $rs;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
