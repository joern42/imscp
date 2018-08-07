=head1 NAME

 Package::Setup::Rspamd - Rspamd spam filtering system

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package Package::Setup::Rspamd;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Crypt qw/ randomStr /;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isValidPassword /;
use iMSCP::EventManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Service;
use iMSCP::TemplateParser qw/ getBloc replaceBloc /;
use Net::LibIDN qw/ idn_to_unicode /;
use Servers::mta;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Provides spam filtering system.

 Project homepage: https://rspamd.com/

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( \%eventManager )

 Register setup event listeners

 Param iMSCP::EventManager \%eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    return 0 unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->_askForModules( @_ ) }, sub { $self->_askForWebUI( @_ ) }, sub { $self->_askForWebUIPassword( @_ ) };
        0;
    } );

}

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    my $rs = $self->stop();
    $rs ||= $self->{'eventManager'}->register( 'afterMtaBuildConf', \&configurePostfix, -100 );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    my $rs ||= $self->_setupModules();
    $rs ||= $self->_setupWebUI();
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        # FIXME: Redis server is a dependency. Should we provide a dedicated for it?
        $srvMngr->enable( 'redis-server' );
        $srvMngr->enable( 'rspamd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            # We do not want manage it further as this service could be used
            # by other service, outside of i-MSCP.
            push @{ $_[0] }, [ sub {
                eval { iMSCP::Service->getInstance()->start( 'redis-server' ); };
                if ( $@ ) {
                    error( $@ );
                    return 1
                }
                0;
            }, 'Redis server' ];
            push @{ $_[0] }, [ sub { $self->start(); }, 'Rspamd spam filtering system' ];
            0;
        },
        $self->getPriority()
    );
}

=item setEnginePermissons( )

 Set engine permlissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    setRights( $self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0644',
        recursive => TRUE
    } );
}

=item start( )

 Start Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub start
{
    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->start( 'rspamd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 Stop Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub stop
{
    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->stop( 'rspamd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 Restart Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->restart( 'rspamd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item reload( )

 Reload Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub reload
{
    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->reload( 'rspamd' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    7;
}

=back

=head1 EVENT LISTENERS

=over 4

=item configurePostfix( )

 Configure Postfix for use of RSPAMD(8) through milter

 Return int 0 on success, other on failure

=cut

sub configurePostfix
{
    Servers::mta->factory()->postconf( (
        # Our i-MSCP SA, ClamAV ... plugins set this value to 'tempfail'
        # but 'accept' is OK if we want ignore milter failures and accept
        # the mails, even if those are potentially SPAMs.
        milter_default_action => {
            action => 'replace',
            values => [ 'accept' ]
        },
        # We want filter incoming mails, that is, those that arrive via
        # smtpd(8) server.
        smtpd_milters         => {
            action => 'add',
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/,
            values => [ 'inet:localhost:11332' ]
        },
        # we want also filter customer outbound mails, that is,
        # those that arrive via sendmail(1).
        non_smtpd_milters     => {
            action => 'add',
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/,
            values => [ 'inet:localhost:11332' ]
        },
        # MILTER mail macros required for rspamd(8)
        # There should be no clash with our i-MSCP SA, ClamAV ... plugins as
        # these don't make use of those macros.
        milter_mail_macros    => {
            action => 'replace',
            values => [ 'i {mail_addr} {client_addr} {client_name} {auth_authen}' ]
        },
        # This should be default value already. We add it here for safety only.
        # (see postconf -d milter_protocol)
        milter_protocol       => {
            action => 'replace',
            values => [ 6 ]
        }
    ));
}

=item afterFrontEndBuildConfFile( \$tplContent, $filename )

 Include httpd configuration into frontEnd vhost files

 Param string \$tplContent Template file tplContent
 Param string $tplName Template name
 Return int 0 on success, other on failure

=cut

sub afterFrontEndBuildConfFile
{
    my ( $tplContent, $tplName ) = @_;

    return 0 unless grep ( $_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx' );

    my $locationSnippet = <<'EOF';
    location = /rspamd {
        return 301 /rspamd/;
    }

    location /rspamd/ {
        proxy_pass       http://localhost:11334/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For "";
    }
EOF
    ${ $tplContent } = replaceBloc(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBloc( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", ${ $tplContent } )
            . "$locationSnippet\n"
            . "    # SECTION custom END.\n",
        ${ $tplContent }
    );

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Package::Setup::Rspamd

=cut

sub _init
{
    my ( $self ) = @_;

    return $self unless $::imscpConfig{'ANTISPAM'} eq 'rspamd';

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/rspamd";
    $self->_mergeConfig() if -f "$self->{'cfgDir'}/rspamd.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/rspamd.data",
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

    if ( -f "$self->{'cfgDir'}/rspamd.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rspamd.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rspamd.data", readonly => TRUE;

        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/rspamd.data.dist" )->moveFile( "$self->{'cfgDir'}/rspamd.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item _getManagedModules( )

 Get list of managed Rspamd modules

 Return list List of managed Rspamd module

=cut

sub _getManagedModules
{
    my ( $self ) = @_;

    CORE::state @modules;

    return @modules if @modules;

    @modules = (
        $::imscpConfig{'ANTIVIRUS'} eq 'clamav' ? 'Antivirus' : (), 'ASN', 'DKIM', 'DKIM Signing', 'DMARC', 'Emails', 'Greylisting', 'Milter Headers',
        'Mime Types', 'MX Check', 'RBL', 'Redis History', 'SPF', 'Surbl'
    );
}

=item _askForModules( $dialog )

 Ask for Rspamd modules to enable

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub _askForModules
{
    my ( $self, $dialog ) = @_;

    my $selectedModules = [ grep ( $_ ne 'Antivirus', split /[,;]/, ::setupGetQuestion( 'RSPAMD_MODULES', $self->{'config'}->{'RSPAMD_MODULES'} ) ) ];
    my %choices = map { $_ => $_ } grep ( $_ ne 'Antivirus', $self->_getManagedModules() );

    if (
        isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'all', 'forced' ] )
            || grep { !exists $choices{$_} && $_ ne 'none' } @{ $selectedModules }
    ) {
        ( my $rs, $selectedModules ) = $dialog->checkbox(
            <<'EOF', \%choices, [ grep { exists $choices{$_} && $_ ne 'none' } @{ $selectedModules } ] );

Please select the Rspamd modules you want to enable.

Note that some of Rspamd modules are not managed yet.
You can always enable unmanaged modules manually.

The Rspamd antivirus module is managed internally and enabled only if you choose ClamAV as antivirus solution.

See https://rspamd.com/doc/modules/ for further details.
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $selectedModules } = grep ( $_ ne 'none', @{ $selectedModules } );
    push @{ $selectedModules }, 'Antivirus' if $::imscpConfig{'ANTIVIRUS'} eq 'clamav';
    $self->{'config'}->{'RSPAMD_MODULES'} = @{ $selectedModules } ? join ',', sort @{ $selectedModules } : 'none';
    0;
}


=item _askForWebUI( \%dialog )

 Ask for Rspamd Web UI

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub _askForWebUI
{
    my ( $self, $dialog ) = @_;

    my $webInterface = ::setupGetQuestion( 'RSPAMD_WEBUI', $self->{'config'}->{'RSPAMD_WEBUI'} );
    my $rs = 0;

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'all', 'forced' ] )
        || $webInterface eq 'yes' && $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} eq ''
    ) {
        my $port = $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'} eq 'http://'
            ? $::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'};
        my $vhost = idn_to_unicode( $::imscpConfig{'BASE_SERVER_VHOST'}, 'utf-8' );

        $rs = $dialog->yesno( <<"EOF", $webInterface eq 'no' ? 1 : 0 );
Do you want to enable the Rspamd Web interface?

The Rspamd Web interface provides basic functions for setting metric actions, scores, viewing statistic and learning.

If enabled, the Web interface is made available at $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'}$vhost:$port/rspamd
EOF
        return $rs if $rs >= 30;
    }

    $self->{'config'}->{'RSPAMD_WEBUI'} = $rs ? 'no' : 'yes';
    0;
}

=item _askForWebUIPassword( \%dialog )

 Ask for Rspamd Web interface password

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub _askForWebUIPassword
{
    my ( $self, $dialog ) = @_;

    return 0 unless $self->{'config'}->{'RSPAMD_WEBUI'} eq 'yes';

    my ( $rs, $msg, $password ) = ( 0, '', ::setupGetQuestion( 'RSPAMD_WEBUI_PASSWORD', $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} ) );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'all', 'forced' ] )
        || $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} eq ''
    ) {
        do {
            $password = '';
            ( $rs, $password ) = $dialog->inputbox( <<"EOF", randomStr( 16, iMSCP::Crypt::ALNUM ));

Please enter a password for the Rspamd Web interface:$msg
EOF
            $msg = isValidPassword( $password ) ? '' : $iMSCP::Dialog::InputValidation::lastValidationError;
        } while $rs < 30 && $msg;

        return $rs if $rs >= 30;
    }

    ::setupSetQuestion( 'RSPAMD_UI_PASSWORD', $password );
    0;
}

=item _getModuleConffilesMap( )

 Get configuration files map for Rspamd modules

 Return hash Rspamd module configuration files map

=cut

sub _getModuleConffilesMap
{
    my ( $self ) = @_;

    CORE::state %map;

    return %map if %map;

    %map = (
        Antivirus        => 'antivirus.conf',
        ASN              => 'asn.conf',
        DKIM             => 'dkim.conf',
        'DKIM Signing'   => 'dkim_signing.conf',
        DMARC            => 'dmarc.conf',
        Emails           => 'emails.conf',
        Greylisting      => 'greylist.conf',
        'Milter Headers' => 'milter_headers.conf',
        'Mime Types'     => 'mime_types.conf',
        'MX Check'       => 'mx_check.conf',
        RBL              => 'rbl.conf',
        'Redis History'  => 'history_redis.conf',
        SPF              => 'spf.conf',
        Surbl            => 'surbl.conf'
    );
}

=item _setupModules( )

 Setup Rspamd modules

 Return int 0 on success, other on failure

=cut

sub _setupModules
{
    my ( $self ) = @_;

    my %conffilesMap = $self->_getModuleConffilesMap();
    my @selectedModules = grep ( $_ ne 'none', split /[,;]/, $self->{'config'}->{'RSPAMD_MODULES'} );

    for my $module ( $self->_getManagedModules() ) {
        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}/$conffilesMap{$module}" );
        my $fileContent = $file->getAsRef();
        return 1 unless defined $fileContent;

        ${ $fileContent } =~ s/^(enabled\s*=)[^\n]+/$1 @{ [ grep ( $_ eq $module, @selectedModules ) ? 'true' : 'false' ] };/m;

        return 1 if $file->save();
    }

    0;
}

=item _setupWebUI( )

 Setup Rspamd Web interface

 Return int 0 on success, other on failure

=cut

sub _setupWebUI
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}/worker-controller.inc" );
    my $fileContent = $file->getAsRef();
    return 1 unless defined $fileContent;

    if ( $self->{'config'}->{'RSPAMD_WEBUI'} eq 'yes' ) {
        my $rs = execute(
            [ 'rspamadm', 'pw', '--quiet', '--encrypt', '--password', ::setupGetQuestion( 'RSPAMD_UI_PASSWORD' ) ], \my $stdout, \my $stderr
        );
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;

        chomp( $stdout );

        ${ $fileContent } =~ s/^(enabled\s*=)[^\n]+/$1 true;/m;
        ${ $fileContent } =~ s/^(count\s*=)[^\n]+/$1 $self->{'config'}->{'RSPAMD_WEBUI_PROCESS_COUNT'};/m;
        ${ $fileContent } =~ s/^(password\s*=)[^\n]+/$1 "$stdout";/m;
        $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} = $stdout;
    } else {
        ${ $fileContent } =~ s/^(enabled\s*=)[^\n]+/$1 false;/m;
        ${ $fileContent } =~ s/^password\s*=[^\n]+/$1 "";/m;
    }

    return 1 if $file->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
