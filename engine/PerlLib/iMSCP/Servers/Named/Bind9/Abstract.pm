=head1 NAME

 iMSCP::Servers::Named::Bind9::Abstract - i-MSCP Bind9 Server abstract implementation

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

package iMSCP::Servers::Named::Bind9::Abstract;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use File::Basename;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Net;
use iMSCP::TemplateParser qw/ getBlocByRef process processByRef replaceBlocByRef /;
use iMSCP::Service;
use iMSCP::Umask;
use version;
use parent 'iMSCP::Servers::Named';

=head1 DESCRIPTION

 i-MSCP Bind9 Server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    for my $conffile( 'BIND_CONF_DEFAULT_FILE', 'BIND_CONF_FILE', 'BIND_LOCAL_CONF_FILE', 'BIND_OPTIONS_CONF_FILE' ) {
        next if $self->{'config'}->{$conffile} eq '';

        my $rs = $self->_bkpConfFile( $self->{'config'}->{$conffile} );
        return $rs if $rs;
    }

    my $rs = $self->_setVersion();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_buildConf();
}

=item setEnginePermissions( )

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    my $rs = setRights( $self->{'config'}->{'BIND_CONF_DIR'},
        {
            user      => $main::imscpConfig{'ROOT_USER'},
            group     => $self->{'config'}->{'BIND_GROUP'},
            dirmode   => '2750',
            filemode  => '0640',
            recursive => 1
        }
    );
    $rs ||= setRights( $self->{'config'}->{'BIND_DB_ROOT_DIR'},
        {
            user      => $self->{'config'}->{'BIND_USER'},
            group     => $self->{'config'}->{'BIND_GROUP'},
            dirmode   => '2750',
            filemode  => '0640',
            recursive => 1
        }
    );
}

=item getEventServerName( )

 See iMSCP::Servers::Abstract::getEventServerName()

=cut

sub getEventServerName
{
    my ($self) = @_;

    'Bind9';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Bind %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

    $self->{'config'}->{'BIND_VERSION'};
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Named::addDomain()

=cut

sub addDomain
{
    my ($self, $moduleData) = @_;

    # Never process the same zone twice
    # Occurs only in few contexts (eg. when using BASE_SERVER_VHOST as customer domain)
    return 0 if $self->{'seen_zones'}->{$moduleData->{'DOMAIN_NAME'}};

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9AddDomain', $moduleData );
    $rs ||= $self->_addDmnConfig( $moduleData );
    return $rs if $rs;

    if ( $self->{'config'}->{'BIND_MODE'} eq 'master' ) {
        $rs = $self->_addDmnDb( $moduleData );
        return $rs if $rs;
    }

    $self->{'seen_zones'}->{$moduleData->{'DOMAIN_NAME'}} ||= 1;
    $self->{'eventManager'}->trigger( 'afterBind9AddDomain', $moduleData );
}

=item postaddDomain( \%moduleData )

 See iMSCP::Servers::Named::postaddDomain()

=cut

sub postaddDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostAddDomain', $moduleData );
    return $rs if $rs;

    if ( $main::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $rs = $self->addSubdomain( {
            # Listeners want probably know real parent domain name for the
            # DNS name being added even if that entry is added in another
            # zone. For instance, see the 20_named_dualstack.pl listener
            # file. (since 1.6.0)
            REAL_PARENT_DOMAIN_NAME => $moduleData->{'PARENT_DOMAIN_NAME'},
            PARENT_DOMAIN_NAME      => $main::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME             => $moduleData->{'ALIAS'} . '.' . $main::imscpConfig{'BASE_SERVER_VHOST'},
            MAIL_ENABLED            => 0,
            DOMAIN_IP               => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            # Listeners probably want to know the type of the entry being added (since 1.6.0)
            DOMAIN_TYPE             => 'sub',
            BASE_SERVER_PUBLIC_IP   => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            OPTIONAL_ENTRIES        => 0,
            STATUS                  => $moduleData->{'STATUS'} # (since 1.6.0)
        } );
        return $rs if $rs;
    }

    $self->{'reload'} ||= 1;
    $self->{'eventManager'}->trigger( 'afterBind9PostAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Named::disableDomain()

 When a domain is being disabled, we must ensure that the DNS data are still
 present for it (eg: when doing a full upgrade or reconfiguration). This
 explain here why we are executing the addDomain() method.

=cut

sub disableDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9DisableDomain', $moduleData );
    $rs ||= $self->addDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterBind9DisableDomain', $moduleData );
}

=item postdisableDomain( \%moduleData )

 See iMSCP::Servers::Named::postdisableDomain()

 See the ::disableDomain() method for explaination.

=cut

sub postdisableDomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostDisableDomain', $moduleData );
    $rs ||= $self->postaddDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterBind9PostDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Named::deleteDomain()

=cut

sub deleteDomain
{
    my ($self, $moduleData) = @_;

    return 0 if $moduleData->{'PARENT_DOMAIN_NAME'} eq $main::imscpConfig{'BASE_SERVER_VHOST'} && !$moduleData->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9DeleteDomain', $moduleData );
    $rs ||= $self->_deleteDmnConfig( $moduleData );
    return $rs if $rs;

    if ( $self->{'config'}->{'BIND_MODE'} eq 'master' ) {
        for ( "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db", "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$moduleData->{'DOMAIN_NAME'}.db" ) {
            next unless -f;

            $rs = iMSCP::File->new( filename => $_ )->delFile();
            return $rs if $rs;
        }
    }

    $self->{'eventManager'}->trigger( 'afterBind9DeleteDomain', $moduleData );
}

=item postdeleteDomain( \%moduleData )

 See iMSCP::Servers::Named::postdeleteDomain()

=cut

sub postdeleteDomain
{
    my ($self, $moduleData) = @_;

    return 0 if $moduleData->{'PARENT_DOMAIN_NAME'} eq $main::imscpConfig{'BASE_SERVER_VHOST'} && !$moduleData->{'FORCE_DELETION'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostDeleteDomain', $moduleData );
    return $rs if $rs;

    if ( $main::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $rs = $self->deleteSubdomain( {
            PARENT_DOMAIN_NAME => $main::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $moduleData->{'ALIAS'} . '.' . $main::imscpConfig{'BASE_SERVER_VHOST'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} ||= 1;
    $self->{'eventManager'}->trigger( 'afterBind9PostDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Named::addSubdomain()

=cut

sub addSubdomain
{
    my ($self, $moduleData) = @_;

    return 0 unless $self->{'config'}->{'BIND_MODE'} eq 'master';

    my $wrkDbFile = "$self->{'wrkDir'}/$moduleData->{'PARENT_DOMAIN_NAME'}.db";
    unless ( -f $wrkDbFile ) {
        error( sprintf( 'File %s not found. Run imscp-reconfigure script.', $wrkDbFile ));
        return 1;
    }

    $wrkDbFile = iMSCP::File->new( filename => $wrkDbFile );
    my $wrkDbFileContent = $wrkDbFile->get();
    unless ( defined $wrkDbFileContent ) {
        error( sprintf( "Couldn't read the %s file", $wrkDbFile->{'filename'} ));
        return 1;
    }

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind9', 'db_sub.tpl', \ my $subEntry, $moduleData );
    return $rs if $rs;

    unless ( defined $subEntry ) {
        $subEntry = iMSCP::File->new( filename => "$self->{'tplDir'}/db_sub.tpl" )->get();
        unless ( defined $subEntry ) {
            error( sprintf( "Couldn't read the %s file", "$self->{'tplDir'}/db_sub.tpl file" ));
            return 1;
        }
    }

    unless ( $self->{'serials'}->{$moduleData->{'PARENT_DOMAIN_NAME'}} ) {
        $rs = $self->_updateSOAserialNumber( $moduleData->{'PARENT_DOMAIN_NAME'}, \$wrkDbFileContent, \$wrkDbFileContent );
    }

    $rs ||= $self->{'eventManager'}->trigger( 'beforeBind9AddSubdomain', \$wrkDbFileContent, \$subEntry, $moduleData );
    return $rs if $rs;

    my $net = iMSCP::Net->getInstance();

    replaceBlocByRef(
        "; sub MAIL entry BEGIN\n",
        "; sub MAIL entry ENDING\n",
        ( $moduleData->{'MAIL_ENABLED'}
            ? process(
                {
                    BASE_SERVER_IP_TYPE => ( $net->getAddrVersion( $moduleData->{'BASE_SERVER_PUBLIC_IP'} ) eq 'ipv4' ) ? 'A' : 'AAAA',
                    BASE_SERVER_IP      => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
                    DOMAIN_NAME         => $moduleData->{'PARENT_DOMAIN_NAME'}
                },
                getBlocByRef( "; sub MAIL entry BEGIN\n", "; sub MAIL entry ENDING\n", \$subEntry )
            )
            : ''
        ),
        \$subEntry
    );

    if ( defined $moduleData->{'OPTIONAL_ENTRIES'} && !$moduleData->{'OPTIONAL_ENTRIES'} ) {
        replaceBlocByRef( "; sub OPTIONAL entries BEGIN\n", "; sub OPTIONAL entries ENDING\n", '', \$subEntry );
    }

    my $domainIP = $net->isRoutableAddr( $moduleData->{'DOMAIN_IP'} ) ? $moduleData->{'DOMAIN_IP'} : $moduleData->{'BASE_SERVER_PUBLIC_IP'};

    processByRef(
        {
            SUBDOMAIN_NAME => $moduleData->{'DOMAIN_NAME'},
            IP_TYPE        => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP      => $domainIP
        },
        \$subEntry
    );

    replaceBlocByRef(
        "; sub [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "; sub [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', \$wrkDbFileContent
    );
    replaceBlocByRef(
        "; sub [{SUBDOMAIN_NAME}] entry BEGIN\n", "; sub [{SUBDOMAIN_NAME}] entry ENDING\n", $subEntry, \$wrkDbFileContent, 'preserve'
    );

    $rs = $self->{'eventManager'}->trigger( 'afterBind9AddSubdomain', \$wrkDbFileContent, $moduleData );
    $rs ||= $wrkDbFile->set( $wrkDbFileContent );
    $rs ||= $wrkDbFile->save();
    $rs ||= $self->_compileZone( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item postaddSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postaddSubdomain()

=cut

sub postaddSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostAddSubdomain', $moduleData );
    return $rs if $rs;

    if ( $main::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $rs = $self->addSubdomain( {
            # Listeners want probably know real parent domain name for the
            # DNS name being added even if that entry is added in another
            # zone. For instance, see the 20_named_dualstack.pl listener
            # file. (since 1.6.0)
            REAL_PARENT_DOMAIN_NAME => $moduleData->{'PARENT_DOMAIN_NAME'},
            PARENT_DOMAIN_NAME      => $main::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME             => $moduleData->{'ALIAS'} . '.' . $main::imscpConfig{'BASE_SERVER_VHOST'},
            MAIL_ENABLED            => 0,
            DOMAIN_IP               => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            # Listeners want probably know type of the entry being added (since 1.6.0)
            DOMAIN_TYPE             => 'sub',
            BASE_SERVER_PUBLIC_IP   => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            OPTIONAL_ENTRIES        => 0,
            STATUS                  => $moduleData->{'STATUS'} # (since 1.6.0)
        } );
        return $rs if $rs;
    }

    $self->{'reload'} ||= 1;
    $self->{'eventManager'}->trigger( 'afterBind9PostAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Named::disableSubdomain()

 When a subdomain is being disabled, we must ensure that the DNS data are still present for it (eg: when doing a full
 upgrade or reconfiguration). This explain here why we are executing the addSubdomain() action.

=cut

sub disableSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9DisableSubdomain', $moduleData );
    $rs ||= $self->addSubdomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterBind9DisableSubdomain', $moduleData );
}

=item postdisableSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postdisableSubdomain()

 See the ::disableSubdomain( ) method for explaination.

=cut

sub postdisableSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostDisableSubdomain', $moduleData );
    $rs ||= $self->postaddSubdomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterBind9PostDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Named::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ($self, $moduleData) = @_;

    return 0 unless $self->{'config'}->{'BIND_MODE'} eq 'master';

    my $wrkDbFile = "$self->{'wrkDir'}/$moduleData->{'PARENT_DOMAIN_NAME'}.db";
    unless ( -f $wrkDbFile ) {
        error( sprintf( 'File %s not found. Run imscp-reconfigure script.', $wrkDbFile ));
        return 1;
    }

    $wrkDbFile = iMSCP::File->new( filename => $wrkDbFile );
    my $wrkDbFileContent = $wrkDbFile->get();
    unless ( defined $wrkDbFileContent ) {
        error( sprintf( "Couldn't read the %s file", $wrkDbFile->{'filename'} ));
        return 1;
    }

    unless ( $self->{'serials'}->{$moduleData->{'PARENT_DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSOAserialNumber( $moduleData->{'PARENT_DOMAIN_NAME'}, \$wrkDbFileContent, \$wrkDbFileContent );
        return $rs if $rs;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9DeleteSubdomain', \$wrkDbFileContent, $moduleData );
    return $rs if $rs;

    replaceBlocByRef(
        "; sub [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "; sub [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', \$wrkDbFileContent
    );

    $rs = $self->{'eventManager'}->trigger( 'afterBind9DeleteSubdomain', \$wrkDbFileContent, $moduleData );
    $rs ||= $wrkDbFile->set( $wrkDbFileContent );
    $rs ||= $wrkDbFile->save();
    $rs ||= $self->_compileZone( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item postdeleteSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postdeleteSubdomain()

=cut

sub postdeleteSubdomain
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9PostDeleteSubdomain', $moduleData );
    return $rs if $rs;

    if ( $main::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'BIND_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $rs = $self->deleteSubdomain( {
            PARENT_DOMAIN_NAME => $main::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $moduleData->{'ALIAS'} . '.' . $main::imscpConfig{'BASE_SERVER_VHOST'}
        } );
        return $rs if $rs;
    }

    $self->{'reload'} ||= 1;
    $self->{'eventManager'}->trigger( 'afterBind9PostDeleteSubdomain', $moduleData );
}

=item addCustomDNS( \%moduleData )

 See iMSCP::Servers::Named::addCustomDNS()

=cut

sub addCustomDNS
{
    my ($self, $moduleData) = @_;

    return 0 unless $self->{'config'}->{'BIND_MODE'} eq 'master';

    my $wrkDbFile = "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db";
    unless ( -f $wrkDbFile ) {
        error( sprintf( 'File %s not found. Run imscp-reconfigure script.', $wrkDbFile ));
        return 1;
    }

    $wrkDbFile = iMSCP::File->new( filename => $wrkDbFile );
    my $wrkDbFileContent = $wrkDbFile->get();
    unless ( defined $wrkDbFileContent ) {
        error( sprintf( "Couldn't read the %s file", $wrkDbFile->{'filename'} ));
        return 1;
    }

    unless ( $self->{'serials'}->{$moduleData->{'DOMAIN_NAME'}} ) {
        my $rs = $self->_updateSOAserialNumber( $moduleData->{'DOMAIN_NAME'}, \$wrkDbFileContent, \$wrkDbFileContent );
        return $rs if $rs;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9AddCustomDNS', \$wrkDbFileContent, $moduleData );
    return $rs if $rs;

    my @customDNS = ();
    push @customDNS, join "\t", @{$_} for @{$moduleData->{'DNS_RECORDS'}};

    my $fh;
    unless ( open( $fh, '<', \$wrkDbFileContent ) ) {
        error( sprintf( "Couldn't open in-memory file handle: %s", $! ));
        return 1;
    }

    my ($newWrkDbFileContent, $origin) = ( '', '' );
    while ( my $line = <$fh> ) {
        my $isOrigin = $line =~ /^\$ORIGIN\s+([^\s;]+).*\n$/;
        $origin = $1 if $isOrigin; # Update $ORIGIN if needed

        unless ( $isOrigin || index( $line, '$' ) == 0 || index( $line, ';' ) == 0 ) {
            # Process $ORIGIN substitutions
            $line =~ s/\@/$origin/g;
            $line =~ s/^(\S+?[^\s.])\s+/$1.$origin\t/;
            # Skip default SPF record line if SPF record for the same DNS name exists in @customDNS
            next if $line =~ /^(\S+)\s+.*?\s+"v=\bspf1\b.*?"/ && grep /^\Q$1\E\s+.*?\s+"v=\bspf1\b.*?"/, @customDNS;
        }

        $newWrkDbFileContent .= $line;
    }
    close( $fh );
    undef $wrkDbFileContent;

    replaceBlocByRef(
        "; custom DNS entries BEGIN\n",
        "; custom DNS entries ENDING\n",
        "; custom DNS entries BEGIN\n" . ( join "\n", @customDNS, '' ) . "; custom DNS entries ENDING\n",
        \$newWrkDbFileContent
    );

    $rs = $self->{'eventManager'}->trigger( 'afterBind9AddCustomDNS', \$newWrkDbFileContent, $moduleData );
    $rs ||= $wrkDbFile->set( $newWrkDbFileContent );
    $rs ||= $wrkDbFile->save();
    $rs ||= $self->_compileZone( $moduleData->{'DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
    $self->{'reload'} ||= 1 unless $rs;
    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Servers::Named::Bind9::Abstract

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ restart reload serials seen_zones cfgDir /} = ( 0, 0, {}, {}, "$main::imscpConfig{'CONF_DIR'}/bind" );
    @{$self}{qw/ bkpDir wrkDir tplDir /} = ( "$self->{'cfgDir'}/backup", "$self->{'cfgDir'}/working", "$self->{'cfgDir'}/parts" );
    $self->_mergeConfig() if defined $main::execmode && $main::execmode eq 'setup' && -f "$self->{'cfgDir'}/bind.data.dist";
    tie %{$self->{'config'}},
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/bind.data",
        readonly    => !( defined $main::execmode && $main::execmode eq 'setup' ),
        nodeferring => defined $main::execmode && $main::execmode eq 'setup';
    $self->SUPER::_init();
}

=item _mergeConfig( )

 Merge distribution configuration with production configuration

 Return void croak on failure

=cut

sub _mergeConfig
{
    my ($self) = @_;

    if ( -f "$self->{'cfgDir'}/bind.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/bind.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/bind.data", readonly => 1;

        debug( 'Merging old configuration with new configuration ...' );

        while ( my ($key, $value) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.data.dist" )->moveFile( "$self->{'cfgDir'}/bind.data" ) == 0 or croak(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );
}

=item _setVersion( )

 Set Bind9 version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _addDmnConfig( \%moduleData )

 Add domain DNS configuration

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Domain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _addDmnConfig
{
    my ($self, $moduleData) = @_;

    unless ( defined $self->{'config'}->{'BIND_MODE'} ) {
        error( 'Bind mode is not defined. Run imscp-reconfigure script.' );
        return 1;
    }

    my ($cfgFileName, $cfgFileDir) = fileparse( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} || $self->{'config'}->{'BIND_CONF_FILE'} );

    unless ( -f "$self->{'wrkDir'}/$cfgFileName" ) {
        error( sprintf( 'File %s not found. Run imscp-reconfigure script.', "$self->{'wrkDir'}/$cfgFileName" ));
        return 1;
    }

    my $cfgFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $cfgWrkFileContent = $cfgFile->get();
    unless ( defined $cfgWrkFileContent ) {
        error( sprintf( "Couldn't read the %s file", "$self->{'wrkDir'}/$cfgFileName" ));
        return 1;
    }

    my $tplFileName = "cfg_$self->{'config'}->{'BIND_MODE'}.tpl";
    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind9', $tplFileName, \ my $tplCfgEntryContent, $moduleData );
    return $rs if $rs;

    unless ( defined $tplCfgEntryContent ) {
        $tplCfgEntryContent = iMSCP::File->new( filename => "$self->{'tplDir'}/$tplFileName" )->get();
        unless ( defined $tplCfgEntryContent ) {
            error( sprintf( "Couldn't read the %s file", "$self->{'tplDir'}/$tplFileName" ));
            return 1;
        }
    }

    $rs = $self->{'eventManager'}->trigger( 'beforeBind9AddDmnConfig', \$cfgWrkFileContent, \$tplCfgEntryContent, $moduleData );
    return $rs if $rs;

    my $tags = {
        BIND_DB_FORMAT => $self->{'config'}->{'BIND_DB_FORMAT'} =~ s/=\d//r,
        DOMAIN_NAME    => $moduleData->{'DOMAIN_NAME'}
    };

    if ( $self->{'config'}->{'BIND_MODE'} eq 'master' ) {
        if ( $self->{'config'}->{'SECONDARY_DNS'} ne 'no' ) {
            $tags->{'SECONDARY_DNS'} = join( '; ', split( ';', $self->{'config'}->{'SECONDARY_DNS'} )) . '; localhost;';
        } else {
            $tags->{'SECONDARY_DNS'} = 'localhost;';
        }
    } else {
        $tags->{'PRIMARY_DNS'} = join( '; ', split( ';', $self->{'config'}->{'PRIMARY_DNS'} )) . ';';
    }

    replaceBlocByRef(
        "// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', \$cfgWrkFileContent
    );
    replaceBlocByRef( "// imscp [{ENTRY_ID}] entry BEGIN\n", "// imscp [{ENTRY_ID}] entry ENDING\n", <<"EOF", \$cfgWrkFileContent, 'preserve' );
// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN
@{ [ process( $tags, $tplCfgEntryContent ) ] }
// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING
EOF

    $rs = $self->{'eventManager'}->trigger( 'afterBind9AddDmnConfig', \$cfgWrkFileContent, $moduleData );
    $rs ||= $cfgFile->set( $cfgWrkFileContent );
    $rs ||= $cfgFile->save();
    $rs ||= $cfgFile->owner( $main::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $cfgFile->mode( 0640 );
    $rs ||= $cfgFile->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _deleteDmnConfig( \%moduleData )

 Delete domain DNS configuration

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Domain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _deleteDmnConfig
{
    my ($self, $moduleData) = @_;

    my ($cfgFileName, $cfgFileDir) = fileparse( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} || $self->{'config'}->{'BIND_CONF_FILE'} );

    unless ( -f "$self->{'wrkDir'}/$cfgFileName" ) {
        error( sprintf( 'File %s not found. Run imscp-reconfigure script.', "$self->{'wrkDir'}/$cfgFileName" ));
        return 1;
    }

    my $cfgFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $cfgWrkFileContent = $cfgFile->get();
    unless ( defined $cfgWrkFileContent ) {
        error( sprintf( "Couldn't read the %s file", "$self->{'wrkDir'}/$cfgFileName" ));
        return 1;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeBind9DelDmnConfig', \$cfgWrkFileContent, $moduleData );
    return $rs if $rs;

    replaceBlocByRef(
        "// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', \$cfgWrkFileContent
    );

    $rs = $self->{'eventManager'}->trigger( 'afterBind9DelDmnConfig', \$cfgWrkFileContent, $moduleData );
    $rs ||= $cfgFile->set( $cfgWrkFileContent );
    $rs ||= $cfgFile->save();
    $rs ||= $cfgFile->owner( $main::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
    $rs ||= $cfgFile->mode( 0640 );
    $rs ||= $cfgFile->copyFile( "$cfgFileDir$cfgFileName" );
}

=item _addDmnDb( \%moduleData )

 Add domain DNS zone file

 Param hashref \%moduleData Data as provided by the iMSCP::Modules::Domain|iMSCP::Modules::SubAlias modules
 Return int 0 on success, other on failure

=cut

sub _addDmnDb
{
    my ($self, $moduleData) = @_;

    my $wrkDbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db" );
    my $wrkDbFileContent;

    if ( -f $wrkDbFile->{'filename'} && !defined ( $wrkDbFileContent = $wrkDbFile->get()) ) {
        error( sprintf( "Couldn't read the %s file", $wrkDbFile->{'filename'} ));
        return 1;
    }

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind9', 'db.tpl', \ my $tplDbFileC, $moduleData );
    return $rs if $rs;

    unless ( defined $tplDbFileC ) {
        $tplDbFileC = iMSCP::File->new( filename => "$self->{'tplDir'}/db.tpl" )->get();
        unless ( defined $tplDbFileC ) {
            error( sprintf( "Couldn't read the %s file", "$self->{'tplDir'}/db.tpl" ));
            return 1;
        }
    }

    $rs = $self->_updateSOAserialNumber( $moduleData->{'DOMAIN_NAME'}, \$tplDbFileC, \$wrkDbFileContent );
    $rs ||= $self->{'eventManager'}->trigger( 'beforeBind9AddDomainDb', \$tplDbFileC, $moduleData );
    return $rs if $rs;

    my $nsRecordB = getBlocByRef( "; dmn NS RECORD entry BEGIN\n", "; dmn NS RECORD entry ENDING\n", \$tplDbFileC );
    my $glueRecordB = getBlocByRef( "; dmn NS GLUE RECORD entry BEGIN\n", "; dmn NS GLUE RECORD entry ENDING\n", \$tplDbFileC );

    my $net = iMSCP::Net->getInstance();
    my $domainIP = $net->isRoutableAddr( $moduleData->{'DOMAIN_IP'} ) ? $moduleData->{'DOMAIN_IP'} : $moduleData->{'BASE_SERVER_PUBLIC_IP'};

    unless ( $nsRecordB eq '' && $glueRecordB eq '' ) {
        my @nsIPs = ( $domainIP, ( ( $self->{'config'}->{'SECONDARY_DNS'} eq 'no' ) ? () : split ';', $self->{'config'}->{'SECONDARY_DNS'} ) );
        my ($nsRecords, $glueRecords) = ( '', '' );

        for my $ipAddrType( qw/ ipv4 ipv6 / ) {
            my $nsNumber = 1;

            for my $ipAddr( @nsIPs ) {
                next unless $net->getAddrVersion( $ipAddr ) eq $ipAddrType;
                $nsRecords .= process( { NS_NAME => 'ns' . $nsNumber }, $nsRecordB ) if $nsRecordB ne '';
                $glueRecords .= process(
                    {
                        NS_NAME    => 'ns' . $nsNumber,
                        NS_IP_TYPE => ( $ipAddrType eq 'ipv4' ) ? 'A' : 'AAAA',
                        NS_IP      => $ipAddr
                    },
                    $glueRecordB
                ) if $glueRecordB ne '';

                $nsNumber++;
            }
        }

        replaceBlocByRef( "; dmn NS RECORD entry BEGIN\n", "; dmn NS RECORD entry ENDING\n", $nsRecords, \$tplDbFileC ) if $nsRecordB ne '';

        if ( $glueRecordB ne '' ) {
            replaceBlocByRef( "; dmn NS GLUE RECORD entry BEGIN\n", "; dmn NS GLUE RECORD entry ENDING\n", $glueRecords, \$tplDbFileC );
        }
    }

    my $dmnMailEntry = '';
    if ( $moduleData->{'MAIL_ENABLED'} ) {
        $dmnMailEntry = process(
            {
                BASE_SERVER_IP_TYPE => ( $net->getAddrVersion( $moduleData->{'BASE_SERVER_PUBLIC_IP'} ) eq 'ipv4' ) ? 'A' : 'AAAA',
                BASE_SERVER_IP      => $moduleData->{'BASE_SERVER_PUBLIC_IP'}
            },
            getBlocByRef( "; dmn MAIL entry BEGIN\n", "; dmn MAIL entry ENDING\n", \$tplDbFileC )
        )
    }

    replaceBlocByRef( "; dmn MAIL entry BEGIN\n", "; dmn MAIL entry ENDING\n", $dmnMailEntry, \$tplDbFileC );

    processByRef(
        {
            DOMAIN_NAME => $moduleData->{'DOMAIN_NAME'},
            IP_TYPE     => ( $net->getAddrVersion( $domainIP ) eq 'ipv4' ) ? 'A' : 'AAAA',
            DOMAIN_IP   => $domainIP
        },
        \$tplDbFileC
    );

    unless ( !defined $wrkDbFileContent || defined $main::execmode && $main::execmode eq 'setup' ) {
        # Re-add subdomain entries
        replaceBlocByRef(
            "; sub entries BEGIN\n",
            "; sub entries ENDING\n",
            getBlocByRef( "; sub entries BEGIN\n", "; sub entries ENDING\n", \$wrkDbFileContent, 'with_tags' ),
            \$tplDbFileC
        );

        # Re-add custom DNS entries
        replaceBlocByRef(
            "; custom DNS entries BEGIN\n",
            "; custom DNS entries ENDING\n",
            getBlocByRef( "; custom DNS entries BEGIN\n", "; custom DNS entries ENDING\n", \$wrkDbFileContent, 'with_tags' ),
            \$tplDbFileC
        );
    }

    $rs = $self->{'eventManager'}->trigger( 'afterBind9AddDomainDb', \$tplDbFileC, $moduleData );
    $rs ||= $wrkDbFile->set( $tplDbFileC );
    $rs ||= $wrkDbFile->save();
    $rs ||= $self->_compileZone( $moduleData->{'DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item _updateSOAserialNumber( $zone, \$zoneFileContent, \$oldZoneFileContent )

 Update SOA serial number for the given zone
 
 Note: Format follows RFC 1912 section 2.2 recommendations.

 Param string zone Zone name
 Param scalarref \$zoneFileContent Reference to zone file content
 Param scalarref \$oldZoneFileContent Reference to old zone file content
 Return int 0 on success, other on failure

=cut

sub _updateSOAserialNumber
{
    my ($self, $zone, $zoneFileContent, $oldZoneFileContent) = @_;

    $oldZoneFileContent = $zoneFileContent unless defined ${$oldZoneFileContent};

    if ( ${$oldZoneFileContent} !~ /^\s+(?:(?<date>\d{8})(?<nn>\d{2})|(?<placeholder>\{TIMESTAMP\}))\s*;[^\n]*\n/m ) {
        error( sprintf( "Couldn't update SOA serial number for the %s DNS zone", $zone ));
        return 1;
    }

    my %rc = %+;
    my ($d, $m, $y) = ( gmtime() )[3 .. 5];
    my $nowDate = sprintf( "%d%02d%02d", $y+1900, $m+1, $d );

    if ( exists $+{'placeholder'} ) {
        $self->{'serials'}->{$zone} = $nowDate . '00';
        processByRef( { TIMESTAMP => $self->{'serials'}->{$zone} }, $zoneFileContent );
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
    ${$zoneFileContent} =~ s/^(\s+)(?:\d{10}|\{TIMESTAMP\})(\s*;[^\n]*\n)/$1$self->{'serials'}->{$zone}$2/m;
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
    my ($self, $zonename, $filename) = @_;

    local $UMASK = 027;
    my $rs = execute(
        [
            'named-compilezone', '-i', 'full', '-f', 'text', '-F', $self->{'config'}->{'BIND_DB_FORMAT'}, '-s', 'relative', '-o',
            "$self->{'config'}->{'BIND_DB_MASTER_DIR'}/$zonename.db", $zonename, $filename
        ],
        \ my $stdout,
        \ my $stderr
    );
    debug( $stdout ) if $stdout;
    error( sprintf( "Couldn't compile the %s zone: %s", $zonename, $stderr || 'Unknown error' )) if $rs;
    $rs;
}

=item _bkpConfFile($cfgFile)

 Backup configuration file

 Param string $cfgFile Configuration file path
 Return int 0 on success, other on failure

=cut

sub _bkpConfFile
{
    my ($self, $cfgFile) = @_;

    return 0 unless -f $cfgFile;

    my $file = iMSCP::File->new( filename => $cfgFile );
    my $filename = basename( $cfgFile );

    unless ( -f "$self->{'bkpDir'}/$filename.system" ) {
        my $rs = $file->copyFile( "$self->{'bkpDir'}/$filename.system", { preserve => 'no' } );
        return $rs;
    }

    $file->copyFile( "$self->{'bkpDir'}/$filename." . time, { preserve => 'no' } );
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    my ($self) = @_;

    eval {
        my @directories = (
            [ $self->{'config'}->{'BIND_DB_MASTER_DIR'}, $self->{'config'}->{'BIND_USER'}, $self->{'config'}->{'BIND_GROUP'}, 02750 ],
            [ $self->{'config'}->{'BIND_DB_SLAVE_DIR'}, $self->{'config'}->{'BIND_USER'}, $self->{'config'}->{'BIND_GROUP'}, 02750 ]
        );

        for my $directory( @directories ) {
            iMSCP::Dir->new( dirname => $directory->[0] )->make( {
                user  => $directory->[1],
                group => $directory->[2],
                mode  => $directory->[3]
            } );
        }

        iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_MASTER_DIR'} )->clear();
        iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_SLAVE_DIR'} )->clear() if $self->{'config'}->{'BIND_MODE'} ne 'slave';
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _buildConf( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConf
{
    my ($self) = @_;

    # default conffile (Debian/Ubuntu specific)
    if ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && exists $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} ) {
        $self->{'eventManager'}->registerOne(
            'beforeBind9BuildConfFile',
            sub {
                # Enable/disable local DNS resolver
                ${$_[0]} =~ s/RESOLVCONF=(?:no|yes)/RESOLVCONF=$self->{'config'}->{'LOCAL_DNS_RESOLVER'}/i;

                return 0 unless ${$_[0]} =~ /OPTIONS="(.*)"/;

                # Enable/disable IPV6 support
                ( my $options = $1 ) =~ s/\s*-[46]\s*//g;
                $options = '-4 ' . $options unless $self->{'config'}->{'BIND_IPV6'} eq 'yes';
                ${$_[0]} =~ s/OPTIONS=".*"/OPTIONS="$options"/;
                0;
            }
        );

        my $tplName = basename( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        my $rs = $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName" );
        $rs ||= iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copyFile( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        return $rs if $rs;

        eval {
            # Fix for #IP-1333
            # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=744304
            my $serviceMngr = iMSCP::Service->getInstance();
            if ( $serviceMngr->isSystemd() ) {
                if ( $self->{'config'}->{'LOCAL_DNS_RESOLVER'} eq 'yes' ) {
                    # Service will be started automatically when Bind9 will be restarted
                    $serviceMngr->enable( 'bind9-resolvconf' );
                } else {
                    $serviceMngr->stop( 'bind9-resolvconf' );
                    $serviceMngr->disable( 'bind9-resolvconf' );
                }
            }
        };
        if ( $@ ) {
            error( $@ );
            return 1;
        }
    }

    # option configuration file
    if ( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} ) {
        $self->{'eventManager'}->registerOne(
            'beforeBind9BuildConfFile',
            sub {
                ${$_[0]} =~ s/listen-on-v6\s+\{\s+any;\s+\};/listen-on-v6 { none; };/ if $_[5]->{'BIND_IPV6'} eq 'no';
                ${$_[0]} =~ s%//\s+(check-spf\s+ignore;)%$1% if version->parse( $self->getVersion()) >= version->parse( '9.9.3' );
                0;
            }
        );

        my $tplName = basename( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} );
        my $rs = $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef,
            {
                umask => 0027,
                mode  => 0640,
                group => $self->{'config'}->{'BIND_GROUP'}
            }
        );
        $rs ||= iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copyFile( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} );
        return $rs if $rs;
    }

    # master configuration file
    if ( $self->{'config'}->{'BIND_CONF_FILE'} ) {
        $self->{'eventManager'}->registerOne(
            'beforeBind9BuildConfFile',
            sub {
                return 0 if -f "$_[5]->{'BIND_CONF_DIR'}/bind.keys";
                ${$_[0]} =~ s%include\s+\Q"$_[5]->{'BIND_CONF_DIR'}\E/bind.keys";\n%%;
                0;
            }
        );

        my $tplName = basename( $self->{'config'}->{'BIND_CONF_FILE'} );
        my $rs = $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef,
            {
                umask => 0027,
                mode  => 0640,
                group => $self->{'config'}->{'BIND_GROUP'}
            }
        );
        $rs ||= iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copyFile( $self->{'config'}->{'BIND_CONF_FILE'} );
        return $rs if $rs;
    }

    # local configuration file
    if ( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} );
        my $rs = $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef,
            {
                umask => 0027,
                mode  => 0640,
                group => $self->{'config'}->{'BIND_GROUP'}
            }
        );
        $rs ||= iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copyFile( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} );
        return $rs if $rs;
    }

    0;
}

=item _checkIps(@ips)

 Check IP addresses

 Param list @ips List of IP addresses to check
 Return bool TRUE if all IPs are valid, FALSE otherwise

=cut

sub _checkIps
{
    my (undef, @ips) = @_;

    my $net = iMSCP::Net->getInstance();

    my $ValidationRegexp = main::setupGetQuestion( $main::imscpConfig{'IPV6_SUPPORT'} ) eq 'yes'
        ? qr/^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/ : qr/^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/;

    for my $ipAddr( @ips ) {
        return 0 unless $net->isValidAddr( $ipAddr ) && $net->getAddrType( $ipAddr ) =~ $ValidationRegexp;
    }

    1;
}

=item _removeConfig( )

 Remove configuration

 Return int 0 on success, other on failure

=cut

sub _removeConfig
{
    my ($self) = @_;

    if ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'Debian' && exists $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} ) {
        my ($filename, $dirname) = fileparse( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        next unless -d $dirname && -f "$self->{'bkpDir'}/$filename.system";

        my $rs = iMSCP::File->new( filename => "$self->{'bkpDir'}/$filename.system" )->copyFile(
            $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'}, { preserve => 'no' }
        );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        $rs = $file->mode( 0644 );
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_USER'} );
        return $rs if $rs;
    }

    for ( 'BIND_CONF_FILE', 'BIND_LOCAL_CONF_FILE', 'BIND_OPTIONS_CONF_FILE' ) {
        next unless exists $self->{'config'}->{$_};

        my ($filename, $dirname) = fileparse( $self->{'config'}->{$_} );

        next unless -d $dirname && -f "$self->{'bkpDir'}/$filename.system";

        my $rs = iMSCP::File->new( filename => "$self->{'bkpDir'}/$filename.system" )->copyFile( $self->{'config'}->{$_}, { preserve => 'no' } );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => $self->{'config'}->{$_} );
        $rs = $file->mode( 0640 );
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
        return $rs if $rs;
    }

    eval {
        iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_MASTER_DIR'} )->remove();
        iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_SLAVE_DIR'} )->remove();
        iMSCP::Dir->new( dirname => $self->{'wrkDir'} )->clear();
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
