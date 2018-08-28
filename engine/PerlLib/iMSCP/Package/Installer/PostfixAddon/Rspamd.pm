=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::Rspamd - Rspamd - Advanced spam filtering system

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

package iMSCP::Package::Installer::PostfixAddon::Rspamd;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Crypt qw/ ALNUM randomStr /;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringInList isValidPassword /;
use iMSCP::DistPackageManager;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::LsbRelease;
use iMSCP::Rights qw/ setRights /;
use iMSCP::Service;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use Net::LibIDN qw/ idn_to_unicode /;
use Servers::cron;
use Servers::mta;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Provides the Rspamd advanced spam filtering system (Postfix MTA integration).
 
 Rspamd is an advanced spam filtering system that allows evaluation of messages
 by a number of rules including regular expressions, statistical analysis and
 custom services such as URL black lists. Each message is analysed by Rspamd
 and given a spam score.

 According to this spam score and the user's settings, Rspamd recommends an
 action for the MTA to apply to the message, for example, to pass, reject or
 add a header. Rspamd is designed to process hundreds of messages per second
 simultaneously, and provides a number of useful features.

 Site: https://rspamd.com/
 GitHub: https://github.com/rspamd/rspamd

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs },
        sub { $self->_askForModules( @_ ) },
        sub { $self->_askForWebUI( @_ ) },
        sub { $self->_askForWebUIPassword( @_ ) },
        sub { $self->_askForSpamLearningCronTask( @_ ) };
    0;
}

=item preinstall( )

 See iMSCP::AbstractInstallerActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $distCodename = lc iMSCP::LsbRelease->getInstance()->getCodename( TRUE );

    iMSCP::DistPackageManager->getInstance()
        ->addRepositories(
        [
            {
                repository         => "http://rspamd.com/apt-stable/ $distCodename main",
                repository_key_uri => 'https://rspamd.com/apt/gpg.key'

            }
        ],
        TRUE
    )->addAptPreferences(
        [
            {
                pinning_package      => '*',
                pinning_pin          => "release o=Rspamd,n=$distCodename",
                pinning_pin_priority => '1001'
            }
        ],
        TRUE
    )->installPackages( $self->_getDistPackages(), TRUE );

    my $rs = $self->{'eventManager'}->register( 'afterMtaBuildConf', \&configurePostfix, -100 );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->installFiles();
    $rs ||= $self->_mergeConfig();
    $rs ||= $self->_setupModules();
    $rs ||= $self->_setupWebUI();
    $rs ||= _setupCronTaskForSpamLearning() if $self->{'config'}->{'RSPAMD_SPAM_LEARNING_FROM_JUNK'} eq 'yes';
    $rs;
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    my $srvMngr = iMSCP::Service->getInstance();
    $srvMngr->enable( 'redis-server' );
    $srvMngr->enable( 'rspamd' );

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] },
                [
                    sub {
                        # Make sure that the Redis server (dependency) is running.
                        iMSCP::Service->getInstance()->start( 'redis-server' );
                        0;
                    },
                    'Redis server'
                ],
                [ sub { $self->restart(); }, 'Rspamd spam filtering system' ];
            0;
        },
        $self->getPriority()
    );
}

=item postuninstall( )

 See iMSCP::AbstractUninstallerActions::postuninstall() 

=cut

sub postuninstall
{
    my ( $self ) = @_;

    my $distCodename = lc iMSCP::LsbRelease->getInstance()->getCodename( TRUE );

    iMSCP::DistPackageManager
        ->getInstance()
        ->removeRepositories(
        [
            {
                repository         => "http://rspamd.com/apt-stable/ $distCodename main",
                repository_key_uri => 'https://rspamd.com/apt/gpg.key'

            }
        ],
        TRUE
    )->removeAptPreferences(
        [
            {
                pinning_package      => '*',
                pinning_pin          => "release o=Rspamd,n=$distCodename",
                pinning_pin_priority => '1001'
            }
        ],
        TRUE
    )->uninstallPackages(
        # Never uninstall the Redis server as it can be used by other services
        # Cover case where the administrator installed it manually
        [ grep ( $_ ne 'redis-server', @{ $self->_getDistPackages() } ) ],
        TRUE
    );
}

=item setEnginePermissons( )

 See iMSCP::AbstractInstallerActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    setRights( $self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'ROOT_GROUP'},
        dirmode   => '0755',
        filemode  => '0644',
        recursive => TRUE
    } );
}

=item restart( )

 Restart Rspamd spam filtering system
 
 Return int 0 on success, die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'rspamd' );
    0;
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

    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . <<'EOF'
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
            . "    # SECTION custom END.\n",
        $tplContent
    );

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Package::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/rspamd";

    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/rspamd.data",
        readonly    => iMSCP::Getopt->context() ne 'installer',
        nodeferring => iMSCP::Getopt->context() eq 'installer',
        nodie       => iMSCP::Getopt->context() eq 'installer';

    $self;
}

=item _installFiles( )

 Install files

 Return int 0 on success, other on failure

=cut

sub _installFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Installer/PostfixAddon/Rspamd/config" )->rcopy(
        '/', { preserve => 'no' }
    );
}

=item _mergeConfig( )

 Merge old config with new configuration file

 Return int 0 on success, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rspamd.data.dist";

    debug( 'Merging old configuration with new configuration...' );
    while ( my ( $key, $value ) = each( %{ $self->{'config'} } ) ) {
        next unless exists $newConfig{$key};
        $newConfig{$key} = $value;
    }

    untie %{ $self->{'config'} };
    untie %newConfig;

    iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.data.dist" )->moveFile( "$self->{'cfgDir'}/bind.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );

    tie %{ $self->{'config'} }, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/rspamd.data", nodeferring => TRUE;
    0;
}

=item _getManagedModules( )

 Get list of managed Rspamd modules

 Return list List of managed Rspamd module

=cut

sub _getManagedModules
{

    my ( $self ) = @_;

    (
        $::imscpConfig{'ANTIVIRUS'} eq 'clamav' ? 'Antivirus' : (), 'ASN', 'DKIM', 'DKIM Signing', 'DMARC', 'Emails', 'Greylisting', 'Milter Headers',
        'Mime Types', 'MX Check', 'RBL', 'Redis History', 'SPF', 'Surbl'
    );
}

=item _askForModules( $dialog )

 Ask for Rspamd modules to enable

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForModules
{
    my ( $self, $dialog ) = @_;

    my $selectedModules = [
        grep ( $_ ne 'Antivirus', split /[,;]/, ::setupGetQuestion( 'RSPAMD_MODULES', $self->{'config'}->{'RSPAMD_MODULES'} ) )
    ];
    my %choices = map { $_ => $_ } grep ( $_ ne 'Antivirus', $self->_getManagedModules() );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'all' ] )
        || grep { !exists $choices{$_} && $_ ne 'none' } @{ $selectedModules }
    ) {
        ( my $rs, $selectedModules ) = $dialog->checklist(
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

=item _askForWebUI( $dialog )

 Ask for Rspamd Web UI

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForWebUI
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'RSPAMD_WEBUI', $self->{'config'}->{'RSPAMD_WEBUI'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'alternatives', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $port = $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'} eq 'http://'
            ? $::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'};
        my $vhost = idn_to_unicode( $::imscpConfig{'BASE_SERVER_VHOST'}, 'utf-8' );

        my $rs = $dialog->yesno( <<"EOF", $value eq 'no', TRUE );

Do you want to enable the Rspamd Web interface?

The Rspamd Web interface is a simple control interface that provide basic functions for setting metric actions, scores, viewing statistic and learning.

If enabled, the Web interface is made available at $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'}$vhost:$port/rspamd/
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    $self->{'config'}->{'RSPAMD_WEBUI'} = $value;
    0;
}

=item _askForWebUIPassword( $dialog )

 Ask for Rspamd Web interface password

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub _askForWebUIPassword
{
    my ( $self, $dialog ) = @_;

    return 20 unless $self->{'config'}->{'RSPAMD_WEBUI'} eq 'yes';

    my $password = ::setupGetQuestion( 'RSPAMD_WEBUI_PASSWORD', $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} );
    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'alternatives', 'all' ] )
        || $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} eq ''
        || ( !$self->_isExpectedWebUIPasswordHash( $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} ) && !isValidPassword( $password ) )
    ) {
        do {
            ( my $rs, $password ) = $dialog->inputbox( <<"EOF", randomStr( 16, ALNUM ));
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the Rspamd Web interface:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidPassword( $password );
    }

    ::setupSetQuestion( 'RSPAMD_UI_PASSWORD', $password );
    0;
}

=item _askForSpamLearningCronTask( $dialog )

 Ask for Rspamd spam learning cron task

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSpamLearningCronTask
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'RSPAMD_SPAM_LEARNING_FROM_JUNK', $self->{'config'}->{'RSPAMD_SPAM_LEARNING_FROM_JUNK'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'antispam', 'alternatives', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<"EOF", $value eq 'no', TRUE );

Do you want to enable the cron task for automatic spam learning?

If enabled, Rspamd will learn spam by analyzing the client .Junk mailboxes at regular interval time (every 12 hours by default).
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    $self->{'config'}->{'RSPAMD_SPAM_LEARNING_FROM_JUNK'} = $value;
    0;
}

=item _getDistPackages( )

 Get list of distribution packages to install or uninstall, depending on context

 Return array List of distribution packages

=cut

sub _getDistPackages
{
    my ( $self ) = @_;

    [ 'redis-server', 'rspamd' ];
}

=item _getModuleConffilesMap( )

 Get configuration files map for Rspamd modules

 Return hash Rspamd module configuration files map

=cut

sub _getModuleConffilesMap
{
    my ( $self ) = @_;

    (
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

    my %fileMap = $self->_getModuleConffilesMap();
    my @selectedModules = grep ( $_ ne 'none', split /[,;]/, $self->{'config'}->{'RSPAMD_MODULES'} );

    for my $module ( $self->_getManagedModules() ) {
        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}/$fileMap{$module}" );
        my $fileC = $file->getAsRef();
        return 1 unless defined $fileC;

        ${ $fileC } =~ s/^(enabled\s*=)[^\n]+/$1 @{ [ grep ( $_ eq $module, @selectedModules ) ? 'true' : 'false' ] };/m;
        return 1 if $file->save();
    }

    0;
}

=item _setupWebUI( )

 Setup Rspamd Web UI

 Return int 0 on success, other on failure

=cut

sub _setupWebUI
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}/worker-controller.inc" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    if ( $self->{'config'}->{'RSPAMD_WEBUI'} eq 'yes' ) {
        my $rs = execute(
            [ 'rspamadm', 'pw', '--quiet', '--encrypt', '--password', ::setupGetQuestion( 'RSPAMD_UI_PASSWORD' ) ], \my $stdout, \my $stderr
        );
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;

        chomp( $stdout );
        ${ $fileC } =~ s/^(enabled\s*=)[^\n]+/$1 true;/m;
        ${ $fileC } =~ s/^(password\s*=)[^\n]+/$1 "$stdout";/m;
        $self->{'config'}->{'RSPAMD_WEBUI_PASSWORD'} = $stdout;
    } else {
        ${ $fileC } =~ s/^(enabled\s*=)[^\n]+/$1 false;/m;
        ${ $fileC } =~ s/^(password\s*=)[^\n]+/$1 "";/m;
    }

    $file->save();
}

=item _setupCronTaskForSpamLearning

 Setup a cron task for Rspamd SPAM learning

 Return int 0 on success, other on failure

=cut

sub _setupCronTaskForSpamLearning
{
    my ( $self ) = @_;

    my $mtaConfig = Servers::mta->factory()->{'config'};

    Servers::cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '0',
        HOUR    => $self->{'RSPAMD_SPAM_LEARNING_FROM_JUNK_INTERVAL'} || '*/12',
        DAY     => '*',
        MONTH   => '*',
        DWEEK   => '*',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 find $mtaConfig->{'MTA_VIRTUAL_MAIL_DIR'}/*/*/.Junk/cur -type f -exec /usr/bin/rspamc -h 127.0.0.1:11334 learn_spam -- {} \\+"
    } );
}

=item _isExpectedWebUIPasswordHash( $passwordHash )

 Checks that the given password hash matches with the the password hash from the worker controller configuration file

 Param string $passwordHash Password hash to check against worker controller password hash
 Return boolean TRUE if passwords match, FALSE otherwise, die on failure

=cut

sub _isExpectedWebUIPasswordHash
{
    my ( $self, $passwordHash ) = @_;

    return FALSE if $passwordHash eq '';

    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'}/worker-controller.inc" );
    my $fileC = $file->getAsRef();
    defined $fileC or die( getMessageByType( 'error', { amount => 1, remove => TRUE } ));
    !!$fileC =~ /^password\s+=\s+"\Q$passwordHash\E"\n/m;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
