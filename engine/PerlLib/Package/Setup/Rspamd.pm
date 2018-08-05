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
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Service;
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

    return 0 unless $self->{'has_rspamd'};

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, sub { $self->_askForModules( @_ ) };
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

    return 0 unless $self->{'has_rspamd'};

    $self->stop();
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_rspamd'};

    my $rs = $self->{'eventManager'}->register( 'afterMtaBuildConf', \&_configurePostfix, -100 );

    # In case the i-MSCP SA plugin has just been installed or enabled, we need to
    # redo the job because that plugin puts its smtpd_milters and non_smtpd_milters
    # parameters at first position what we want avoid as mails must first pass
    # through the rspamd(8) spam filtering system.
    $rs ||= $self->{'eventManager'}->register( [ 'onAfterInstallPlugin', 'onAfterEnablePlugin' ], sub {
        return configurePostfix() if $_[0] eq 'SpamAssassin';
        0;
    } );
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_rspamd'};

    local $@;
    eval { iMSCP::Service->getInstance()->enable( 'rspamd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'Rspamd spam filtering system' ];
            0;
        },
        $self->getPriority()
    );
}

=item start( )

 Start Rspamd spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub start
{
    local $@;
    eval { iMSCP::Service->getInstance()->start( 'rspamd' ); };
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
    eval { iMSCP::Service->getInstance()->stop( 'rspamd' ); };
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
    eval { iMSCP::Service->getInstance()->restart( 'rspamd' ); };
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
    eval { iMSCP::Service->getInstance()->reload( 'rspamd' ); };
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

=item getManagedModules( )

 Get list of managed Rspamd modules

 Return list List of managed Rspamd module

=cut

sub getManagedModules
{
    my ( $self ) = @_;

    CORE::state @modules;

    unless ( scalar @modules ) {
        @modules = qw/ ASN Classifier_Bayesian DKIM_Signing DMARC Emails Greylist Milter_Headers Mime_Types MX_Check RBL Redis_History SPF Surbl /;
        push @modules, 'Antivirus' if $::imscpConfig{'ANTIVIRUS'} eq 'clamav';
    }

    @modules;
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

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'has_rspamd'} = iMSCP::Service->getInstance()->hasService( 'rspamd' );
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

=item _askForModules( $dialog )

 Ask for Rspamd modules to enable

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub _askForModules
{
    my ( $self, $dialog ) = @_;

    my $selectedModules = [ split /(?:[,; ]+)/, ::setupGetQuestion( 'RSPAMD_MODULES', $self->{'config'}->{'RSPAMD_MODULES'} ) ];
    my %choices = map { $_ => s/_/ /gr } $self->getManagedModules();

    if ( $::reconfigure =~ /^(?:antispam|all|forced)$/
        || !@{ $selectedModules }
        || grep { !exists $choices{$_} && $_ ne 'no' } @{ $selectedModules }
    ) {
        ( my $rs, $selectedModules ) = $dialog->checkbox(
            <<'EOF', \%choices, [ grep { exists $choices{$_} && $_ ne 'no' } @{ $selectedModules } ] );

Please select the Rspamd modules you want to enable.

Note that not all Rspamd modules are managed by i-MSCP yet.
You can always enable unmanaged modules manually.

See https://rspamd.com/doc/modules/ for further details.
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    @{ $selectedModules } = grep ( $_ ne 'no', @{ $selectedModules } );
    $self->{'config'}->{'RSPAMD_MODULES'} = @{ $selectedModules } ? join ' ', @{ $selectedModules } : 'no';
    0;
}

=item _setupRspamdModules

 Setup Rspamd modules

 Return int 0 on success, other on failure

=cut

sub _setupRspamdModules
{
    my ( $self ) = @_;

    my @selectedModules = split /(?:[,; ]+)/, $self->{'config'}->{'RSPAMD_MODULES'};
    for my $module ( $self->getManagedModules() ) {
        my $file = iMSCP::File->new( filename => $self->{'config'}->{'RSPAMD_LOCAL_CONFDIR'} . '/' . lc( $module ) . '.conf' );
        my $fileContent = $file->getAsRef();
        return 1 unless defined $fileContent;

        if ( grep ( $_ eq $module, @selectedModules ) ) {
            ${ $fileContent } =~ s/^enabled\s+=\s+false;/enabled = true;/;
        } else {
            ${ $fileContent } =~ s/^enabled\s+=\s+true;/enabled = false;/;
        }

        return 1 if $file->save();
    }

    0;
}

=item _configurePostfix

 Configure Postfix for use of RSPAMD(8) through milter

 Return int 0 on success, other on failure

=cut

sub _configurePostfix
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


=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
