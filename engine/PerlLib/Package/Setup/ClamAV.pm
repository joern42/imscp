=head1 NAME

 Package::Setup::ClamAV - ClamAV antivirus

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

package Package::Setup::ClamAV;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Service;
use iMSCP::TemplateParser qw/ process /;
use Servers::mta;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Provides SMTP antivirus.

 Project homepage: https://www.clamav.net/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_clamav'};

    $self->stop();
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_clamav'} && $::imscpConfig{'ANTIVIRUS'} ne 'rspamd';

    my $rs = $self->{'eventManager'}->register( 'afterMtaBuildConf', \&_configurePostfix, -100 );
    $rs ||= $self->_configureClamavMilter();
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    return 0 unless $self->{'has_clamav'};

    local $@;
    eval { iMSCP::Service->getInstance()->enable( 'clamav' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'ClamAV antivirus' ];
            0;
        },
        $self->getPriority()
    );
}

=item start( )

 Start ClamAV spam filtering system
 
 Return int 0 on success, other on failure

=cut

sub start
{
    my ( $self ) = @_;

    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->start( 'clamav-freshclam' );
        $srvMngr->start( 'clamav-milter' ) if $self->{'has_clamav_milter'};
        $srvMngr->start( 'clamav' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 Stop ClamAV Antivirus
 
 Return int 0 on success, other on failure

=cut

sub stop
{
    my ( $self ) = @_;

    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->stop( 'clamav-freshclam' );
        $srvMngr->stop( 'clamav-milter' ) if $self->{'has_clamav_milter'};
        $srvMngr->stop( 'clamav' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item restart( )

 Restart ClamAV antivirus
 
 Return int 0 on success, other on failure

=cut

sub restart
{
    my ( $self ) = @_;

    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->restart( 'clamav-freshclam' );
        $srvMngr->restart( 'clamav-milter' ) if $self->{'has_clamav_milter'};
        $srvMngr->restart( 'clamav' );
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
    my ( $self ) = @_;

    local $@;
    eval {
        my $srvMngr = iMSCP::Service->getInstance();
        $srvMngr->reload( 'clamav-freshclam' );
        $srvMngr->reload( 'clamav-milter' ) if $self->{'has_clamav_milter'};
        $srvMngr->reload( 'clamav' );
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

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Package::Setup::ClamAV

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'has_clamav'} = iMSCP::Service->getInstance()->hasService( 'clamav' );
    $self->{'has_clamav_milter'} = iMSCP::Service->getInstance()->hasService( 'clamav-milter' );

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/clamav";
    $self->_mergeConfig() if -f "$self->{'cfgDir'}/clamav.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/clamav.data",
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

    if ( -f "$self->{'cfgDir'}/clamav.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/clamav.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/clamav.data", readonly => TRUE;

        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/clamav.data.dist" )->moveFile( "$self->{'cfgDir'}/clamav.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => TRUE } ) || 'Unknown error'
    );
}

=item _initClamavDatabases( )

 Initialize ClamAV databases

 return int 0 on success, other on failure

=cut

sub _initClamavDatabases
{
    my ( $self ) = @_;

    local $@;
    eval {
        $self->stop();
        iMSCP::Service->getInstance()->stop( 'clamav-freshclam' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    my $rs = execute( 'freshclam', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( sprintf( "Couldn't initialize ClamAV databases: %s", $stderr || 'Unknown error' )) if $rs;
    $rs;
}

=item _configurePostfix( )

 Configure Postfix for use of ClamAV(8) through milter

 Return int 0 on success, other on failure

=cut

sub _configurePostfix
{
    my ( $self ) = @_;

    Servers::mta->factory()->postconf( (
        milter_default_action => {
            action => 'replace',
            values => [ 'accept' ]
        },
        smtpd_milters         => {
            action => 'add',
            values => [ $self->{'config'}->{'POSTFIX_CLAMAV_MILTER_SOCKET'} ]
        },
        non_smtpd_milters     => {
            action => 'add',
            values => [ $self->{'config'}->{'POSTFIX_CLAMAV_MILTER_SOCKET'} ]
        }
    ));
}

=item _configureClamavMilter( )

 Configure ClamAV milter

 Return int 0 on success, other on failure

=cut

sub _configureClamavMilter
{
    my ( $self ) = @_;

    unless ( -f $self->{'config'}->{'ClamavMilterConffilePath'} ) {
        error( 'File /etc/clamav/clamav-milter.conf not found' );
        return 1;
    }

    my $file = iMSCP::File->new( filename => $self->{'cfgDir'}->{'clamav-milter.conf.tpl'} );
    my $fileContent = $file->getAsRef();
    return 1 unless defined $fileContent;

    ${ $fileContent } = process( $self->{'config'}, ${ $fileContent } );
    $file->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
