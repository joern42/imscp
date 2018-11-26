=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::ClamAV - ClamAV SMTP antivirus

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

package iMSCP::Package::Installer::PostfixAddon::ClamAV;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Server::mta;
use iMSCP::Service;
use iMSCP::TemplateParser 'processByRef';
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Provides ClamAV SMTP antivirus.

 Project homepage: https://www.clamav.net/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance()->installPackages( $self->_getDistPackages(), TRUE );
    0;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    return 0 if grep ( 'Rspamd' eq $_, split ',', $::imscpConfig{'ANTISPAM_PACKAGES'} );

    my $rs = iMSCP::Server::mta->factory()->postconf( (
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
    $rs ||= $self->_configureClamavMilter();
}

=item postinstall( )

 See iMSCP::Installer::AbstractActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'clamav-daemon' );

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->restart(); }, 'ClamAV antivirus' ];
            0;
        },
        $self->getPriority()
    );
}

=item restart( )

 Restart ClamAV antivirus
 
 Return int 0 on success, die on failure

=cut

sub restart
{
    my ( $self ) = @_;

    my $srvMngr = iMSCP::Service->getInstance();
    $srvMngr->restart( 'clamav-freshclam' );
    $srvMngr->restart( 'clamav-milter' ) if $srvMngr->hasService( 'clamav-milter' );
    $srvMngr->restart( 'clamav-daemon' );
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
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/packages/ClamAV";

    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/clamav.data.dist";
    tie %{ $self->{'config'} },
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/clamav.data",
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

=item _getDistPackages( )

 Get list of distribution packages to install or uninstall, depending on context

 Return array List of distribution packages

=cut

sub _getDistPackages
{
    my ( $self ) = @_;

    my $packages = [ 'clamav', 'clamav-freshclam', 'clamdscan', 'clamav-daemon', 'clamav-milter' ];
    pop @{ $packages } if iMSCP::Getopt->context() eq 'installer' && grep ( $_ eq 'rspamd', split( ',', $::imscpConfig{'ANTISPAM_PACKAGES'} ) );
    $dumpvar::dumpPackages;
}

=item _initClamavDatabases( )

 Initialize ClamAV databases

 return int 0 on success, other on failure

=cut

sub _initClamavDatabases
{
    my ( $self ) = @_;

    my $rs = execute( 'freshclam', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( sprintf( "Couldn't initialize ClamAV databases: %s", $stderr || 'Unknown error' )) if $rs;
    $rs;
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
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    processByRef( $self->{'config'}, $fileC );
    $file->save();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
