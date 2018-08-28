=head1 NAME

 iMSCP::Package::Webstats::AWStats - i-MSCP AWStats package

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

package iMSCP::Package::Webstats::AWStats;

use strict;
use warnings;
use Class::Autouse qw/ :nostat Servers::cron Servers::httpd /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use iMSCP::Boolean;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::Ext2Attributes qw/ isImmutable setImmutable clearImmutable /;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef process getBlocByRef replaceBlocByRef /;
use Scalar::Defer qw/ lazy /;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 AWStats package for i-MSCP.

 Advanced Web Statistics (AWStats) is a powerful Web server logfile analyzer
 written in perl that shows you all your Web statistics including visits,
 unique visitors, pages, hits, rush hours, search engines, keywords used to
 find your site, robots, broken links and more.

 Project homepage: http://awstats.sourceforge.net/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

=cut

sub preinstall
{
    my ( $self ) = @_;
    
    $self->_installDistPackages( $self->_getDistPackages() );
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_disableDefaultConfig();
    $rs ||= $self->_createCacheDir();
    $rs ||= $self->_setupApache2();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::AbstractInstallerActions::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->_addAwstatsCronTask();
}

=item uninstall( )

 See iMSCP::AbstractUninstallerActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->_deleteFiles();
    $rs ||= $self->_removeVhost();
    $rs ||= $self->_restoreDebianConfig();
}

=item postuninstall( )

 See iMSCP::AbstractUninstallerActions::uninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    $self->_uninstallDistPackages( $self->_getDistPackages() );
}

=item setEnginePermissions( )

 See iMSCP::AbstractInstallerActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    my $rs = setRights( "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Webstats/Awstats/Scripts/awstats_updateall.pl", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_USER'},
        mode  => '0700'
    } );
    $rs ||= setRights( $::imscpConfig{'AWSTATS_CACHE_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $self->{'httpd'}->getRunningGroup(),
        dirmode   => '02750',
        filemode  => '0640',
        recursive => TRUE
    } );
    $rs ||= setRights( "$self->{'httpd'}->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $self->{'httpd'}->getRunningGroup(),
        mode  => '0640'
    } );
}

=item addUser( \%data )

 See iMSCP::Modules::AbstractActions::addUser()

=cut

sub addUser
{
    my ( $self, $data ) = @_;

    my $filePath = "$self->{'httpd'}->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats";
    my $file = iMSCP::File->new( filename => $filePath );
    my $fileC = $file->getAsRef();
    ${ $fileC } = '' unless defined $fileC;
    ${ $fileC } =~ s/^$data->{'USERNAME'}:[^\n]*\n//gim;
    ${ $fileC } .= "$data->{'USERNAME'}:$data->{'PASSWORD_HASH'}\n";
    my $rs = $file->save();
    $self->{'httpd'}->{'restart'} = TRUE unless $rs;
    $rs;
}

=item addDmn( \%data )

 See iMSCP::Modules::AbstractActions::addDmn()

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    return $self->deleteDmn( $data ) if $data->{'FORWARD'} ne 'no';

    $self->_createAwstatsConfig( $data );
}

=item deleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::deleteDmn()

=cut

sub deleteDmn
{
    my ( $self, $data ) = @_;

    my $cfgFileName = "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.$data->{'DOMAIN_NAME'}.conf";
    if ( -f $cfgFileName ) {
        my $rs = iMSCP::File->new( filename => $cfgFileName )->delFile();
        return $rs if $rs;
    }

    return 0 unless -d $::imscpConfig{'AWSTATS_CACHE_DIR'};

    my @awstatsCacheFiles = iMSCP::Dir->new(
        dirname  => $::imscpConfig{'AWSTATS_CACHE_DIR'},
        fileType => '^(?:awstats[0-9]+|dnscachelastupdate)' . quotemeta( ".$data->{'DOMAIN_NAME'}.txt" )
    )->getFiles();

    return 0 unless @awstatsCacheFiles;

    for ( @awstatsCacheFiles ) {
        my $file = iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CACHE_DIR'}/$_" );
        my $rs = $file->delFile();
        return $rs if $rs;
    }

    0;
}

=item addSub( \%data )

 See iMSCP::Modules::AbstractActions::addSub()

=cut

sub addSub
{
    my ( $self, $data ) = @_;

    $self->addDmn( $data );
}

=item deleteSub( \%data )

 See iMSCP::Modules::AbstractActions::deleteSub()

=cut

sub deleteSub
{
    my ( $self, $data ) = @_;

    $self->deleteDmn( $data );
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterHttpdBuildConf( \$cfgTpl, $filename, \%data )

 Listener responsible to build and inject configuration snipped for
 AWStats in the given httpd vhost file.

 Param scalarref \$cfgTpl Template file content
 Param string $filename Template filename
 Param hash \%data Domain data
 Return int 0 on success, 1 on failure

=cut

sub afterHttpdBuildConf
{
    my ( $cfgTpl, $tplName, $data ) = @_;

    return 0 if $tplName ne 'domain.tpl' || $data->{'FORWARD'} ne 'no';

    replaceBlocByRef(
        "# SECTION addons BEGIN.\n",
        "# SECTION addons END.\n",
        "    # SECTION addons BEGIN.\n"
            . getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl )
            . process( { DOMAIN_NAME => $data->{'DOMAIN_NAME'} }, <<'EOF' )
    <Location /stats>
        ProxyErrorOverride On
        ProxyPreserveHost Off
        ProxyPass http://127.0.0.1:8889/stats/{DOMAIN_NAME} retry=1 acquire=3000 timeout=600 Keepalive=On
        ProxyPassReverse http://127.0.0.1:8889/stats/{DOMAIN_NAME}
    </Location>
EOF
            . "    # SECTION addons END.\n",
        $cfgTpl
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
    $self->{'eventManager'}->register( 'afterHttpdBuildConf', \&afterHttpdBuildConf );
    $self->{'httpd'} = lazy {
        require Servers::httpd;
        Servers::httpd->factory()
    };
    $self;
}

=item _getDistPackages( )

 Get list of distribution package to install or uninstall depending on context

 Return array Array containing list of distribution package

=cut

sub _getDistPackages
{
    [ 'awstats' ];
}

=item _createCacheDir( )

 Create cache directory

 Return int 0 on success, die on failure

=cut

sub _createCacheDir
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'} )->make( {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $self->{'httpd'}->getRunningGroup(),
        mode  => 02750
    } );
}

=item _setupApache2( )

 Setup Apache2 for AWStats

 Return int 0 on success, other on failure

=cut

sub _setupApache2
{
    my ( $self ) = @_;

    # Create Basic authentication file

    my $file = iMSCP::File->new( filename => "$self->{'httpd'}->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" );
    $file->set( '' ); # Make sure to start with an empty file on update/reconfiguration
    my $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'httpd'}->getRunningGroup());
    $rs ||= $file->mode( 0640 );
    return $rs if $rs;

    # Enable required Apache2 modules

    $rs = $self->{'httpd'}->enableModules( 'rewrite', 'authn_core', 'authn_basic', 'authn_socache', 'proxy', 'proxy_http' );
    return $rs if $rs;

    # Create Apache2 vhost

    $self->{'httpd'}->setData( {
        AWSTATS_AUTH_USER_FILE_PATH => "$self->{'httpd'}->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats",
        AWSTATS_ENGINE_DIR          => $::imscpConfig{'AWSTATS_ENGINE_DIR'},
        AWSTATS_WEB_DIR             => $::imscpConfig{'AWSTATS_WEB_DIR'}
    } );

    $rs = $self->{'httpd'}->buildConfFile( "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Webstats/Awstats/Config/01_awstats.conf" );
    $rs ||= $self->{'httpd'}->enableSites( '01_awstats.conf' );
}

=item _disableDefaultConfig( )

 Disable default configuration

 Return int 0 on success, other on failure

=cut

sub _disableDefaultConfig
{
    if ( -f "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf" ) {
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf" )->moveFile(
            "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled"
        );
        return $rs if $rs;
    }

    my $cronDir = Servers::cron->factory()->{'config'}->{'CRON_D_DIR'};
    -f "$cronDir/awstats" ? iMSCP::File->new( filename => "$cronDir/awstats" )->moveFile( "$cronDir/awstats.disable" ) : 0;
}

=item _addAwstatsCronTask( )

 Add AWStats cron task for dynamic mode

 Return int 0 on success, other on failure

=cut

sub _addAwstatsCronTask
{
    Servers::cron->factory()->addTask( {
        TASKID  => 'iMSCP::Package::Webstats::Awstats',
        MINUTE  => '15',
        HOUR    => '3-21/6',
        DAY     => '*',
        MONTH   => '*',
        DWEEK   => '*',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => 'nice -n 10 ionice -c2 -n5 ' .
            "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/iMSCP/Webstats/Awstats/Scripts/awstats_updateall.pl now " .
            "-awstatsprog=$::imscpConfig{'AWSTATS_ENGINE_DIR'}/awstats.pl > /dev/null 2>&1"
    } );
}

=item _cleanup

 Proces cleanup tasks

 Return int 0 on success, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return 0 unless version->parse( $::imscpConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    for my $dir ( iMSCP::Dir->new( dirname => $::imscpConfig{'USER_WEB_DIR'} )->getDirs() ) {
        next unless -d "$::imscpConfig{'USER_WEB_DIR'}/$dir/statistics";
        my $isImmutable = isImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" );
        clearImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" ) if $isImmutable;
        iMSCP::Dir->new( dirname => "$::imscpConfig{'USER_WEB_DIR'}/$dir/statistics" )->remove();
        setImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" ) if $isImmutable;
    }

    0;
}

=item _createAwstatsConfig( \%data )

 Create AWStats configuration file for the given domain

 Param hash \%data Domain data
 Return int 0 on success, other or die on failure

=cut

sub _createAwstatsConfig
{
    my ( $self, $data ) = @_;

    my $awstatsPackageRootDir = "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Package/Webstats/Awstats";
    my $fileC = iMSCP::File->new( filename => "$awstatsPackageRootDir/Config/awstats.imscp_tpl.conf" )->get();
    return 1 unless defined $fileC;

    my $rdbh = $self->{'dbh'};
    local $rdbh->{'RaiseError'} = TRUE;

    my $row = $rdbh->selectrow_hashref( 'SELECT admin_name FROM admin WHERE admin_id = ?', undef, $data->{'DOMAIN_ADMIN_ID'} );
    if ( !$row ) {
        error( sprintf( "Couldn't retrieve data from admin whith ID %d", $data->{'DOMAIN_ADMIN_ID'} ));
        return 1;
    }

    my $tags = {
        AUTH_USER           => "$row->{'admin_name'}",
        AWSTATS_CACHE_DIR   => $::imscpConfig{'AWSTATS_CACHE_DIR'},
        AWSTATS_ENGINE_DIR  => $::imscpConfig{'AWSTATS_ENGINE_DIR'},
        AWSTATS_WEB_DIR     => $::imscpConfig{'AWSTATS_WEB_DIR'},
        CMD_LOGRESOLVEMERGE => "perl $awstatsPackageRootDir/Scripts/logresolvemerge.pl",
        DOMAIN_NAME         => $data->{'DOMAIN_NAME'},
        HOST_ALIASES        => $self->{'httpd'}->getData()->{'SERVER_ALIASES'},
        LOG_DIR             => "$self->{'httpd'}->{'config'}->{'HTTPD_LOG_DIR'}/$data->{'DOMAIN_NAME'}"
    };

    processByRef( $tags, \$fileC );

    my $file = iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.$data->{'DOMAIN_NAME'}.conf" );
    $file->set( $fileC );
    my $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0644 );
}

=item _deleteFiles( )

 Delete files

 Return int 0 on success other on failure

=cut

sub _deleteFiles
{
    my $httpd = Servers::httpd->factory();

    if ( -f "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" ) {
        my $rs = iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" )->delFile();
        return $rs if $rs;
    }

    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'} )->remove();

    return 0 unless -d $::imscpConfig{'AWSTATS_CONFIG_DIR'};

    my $rs = execute( "rm -f $::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.*.conf", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=item _removeVhost( )

 Remove global vhost file

 Return int 0 on success, other on failure

=cut

sub _removeVhost
{
    my $httpd = Servers::httpd->factory();

    return 0 unless -f "$httpd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/01_awstats.conf";

    my $rs = $httpd->disableSites( '01_awstats.conf' );
    $rs ||= iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/01_awstats.conf" )->delFile();
}

=item _restoreDebianConfig( )

 Restore default configuration

 Return int 0 on success, other on failure

=cut

sub _restoreDebianConfig
{
    if ( -f "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" ) {
        my $rs = iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" )->moveFile(
            "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf"
        );
        return $rs if $rs;
    }

    my $cronDir = Servers::cron->factory()->{'config'}->{'CRON_D_DIR'};
    return 0 unless -f "$cronDir/awstats.disable";
    iMSCP::File->new( filename => "$cronDir/awstats.disable" )->moveFile( "$cronDir/awstats" );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
