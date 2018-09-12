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
use autouse 'File::Basename' => 'dirname';
use autouse 'iMSCP::Ext2Attributes' => qw/ isImmutable setImmutable clearImmutable /;
use autouse 'iMSCP::Rights' => 'setRights';
use Class::Autouse qw/ :nostat iMSCP::DistPackageManager Servers::httpd /;
use iMSCP::Boolean;
use iMSCP::Debug 'error';
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef process getBlocByRef replaceBlocByRef /;
use Scalar::Defer 'lazy';
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

    iMSCP::DistPackageManager->getInstance()->installPackags( $self->_getDistPackages());
    0;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_disableDefaultConfig();
    $rs ||= $self->_createCacheDir();
    $rs ||= $self->_setupApache2();
    $rs ||= $self->_setupCronTask();
    $rs ||= $self->_cleanup();
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->_deleteFiles();
    $rs ||= $self->_enableDefaultConfig();
}

=item postuninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub postuninstall
{
    my ( $self ) = @_;

    iMSCP::DistPackageManager->getInstance()->uninstallPackages( $self->_getDistPackages());
    0;
}

=item setEnginePermissions( )

 See iMSCP::Installer::AbstractActions::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ( $self ) = @_;

    my $rs = setRights( '/var/cache/awstats', {
        user      => $self->{'httpd'}->getRunningUser(),
        group     => $self->{'httpd'}->getRunningGroup(),
        dirmode   => '0750',
        filemode  => '0640',
        recursive => iMSCP::Getopt->fixPermissions
    } );
    $rs ||= setRights( '/etc/apache2/.imscp_awstats', {
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

    my $file = iMSCP::File->new( filename => '/etc/apache2/.imscp_awstats' );
    my $fileC = $file->getAsRef();
    ${ $fileC } = '' unless defined $fileC;
    ${ $fileC } =~ s/^(?:$data->{'USERNAME'}:[^\n]*)?\n//gm;
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
    $self->_createConfig( $data );
}

=item deleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::deleteDmn()

=cut

sub deleteDmn
{
    my ( $self, $data ) = @_;

    my $file = "/etc/awstats/awstats.$data->{'DOMAIN_NAME'}.conf";
    unlink $file or die( sprintf( "Couldn't delete the %s AWStats configuration file: %s", $file, $! || 'Unknown error' )) if -f $file;
    undef $file;

    return 0 unless -d '/var/cache/awstats';

    opendir my $dh, '/var/cache/awstats' or die( sprintf( "Couldn't open the /var/cache/awstats directory : %s", $! || 'Unknown error' ));
    my $cacheFileReg = qr/^(?:awstats[0-9]+|dnscachelastupdate)\Q.$data->{'DOMAIN_NAME'}.txt\E$/;
    while ( my $dentry = readdir $dh ) {
        next if $dentry !~ /$cacheFileReg/;
        unlink $dentry or die( sprintf( "Couldn't delete the %s AWStats cache file: %s", $dentry, $! || 'Unknown error' ));
    }
    closedir( $dh );
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
    $self->{'httpd'} = lazy { Servers::httpd->factory() };
    $self;
}

=item _getDistPackages( )

 Get list of distribution package to install or uninstall depending on context

 Return array Array containing list of distribution package

=cut

sub _getDistPackages
{
    [ 'awstats', 'libgeo-ipfree-perl' ];
}

=item _disableDefaultConfig( )

 Disable default configuration as provided by distribution package

 Return int 0 on success, other on failure

=cut

sub _disableDefaultConfig
{
    my ( $self ) = @_;

    return 0 unless -f '/etc/awstats/awstats.conf';

    iMSCP::File->new( filename => '/etc/awstats/awstats.conf' )->moveFile( '/etc/awstats/awstats.conf.disabled' );
}

=item _createCacheDir( )

 Create cache directory

 Return int 0 on success, die on failure

=cut

sub _createCacheDir
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => '/var/cache/awstats' )->make( {
        user  => $self->{'httpd'}->getRunningUser(),
        group => $self->{'httpd'}->getRunningGroup(),
        mode  => 0750
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
    my $file = iMSCP::File->new( filename => "/etc/apache2/.imscp_awstats" );
    $file->set( '' ); # Make sure to start with an empty file on update/reconfiguration
    my $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'httpd'}->getRunningGroup());
    $rs ||= $file->mode( 0640 );
    return $rs if $rs;

    # Enable required Apache2 modules
    $rs = $self->{'httpd'}->enableModules( 'rewrite', 'authn_core', 'authn_basic', 'authn_socache', 'proxy', 'proxy_http' );
    return $rs if $rs;

    # Create Apache2 vhost
    $rs = $self->{'httpd'}->buildConfFile( "$::imscpConfig{'PACKAGES_DIR'}/Webstats/AWStats/templates/01_awstats.conf" );
    $rs ||= $self->{'httpd'}->enableSites( '01_awstats.conf' );
}

=item _setupCronTask( )

 Setup AWStats cron task for dynamic mode

 Return int 0 on success, other on failure

=cut

sub _setupCronTask
{
    my $file = iMSCP::File->new( filename => '/etc/default/awstats' );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    # Scheduling priority
    ${ $fileC } =~ s/(AWSTATS_NICE)=[^\n]+/$1=10/;
    # Disable production of static html reports (we operate in dynamic mode only)
    ${ $fileC } =~ s/(AWSTATS_ENABLE_BUILDSTATICPAGES)=[^\n]+/$1="no"/;
    # Set language to english
    ${ $fileC } =~ s/(AWSTATS_LANG)=[^\n]+/$1=en/;
    # Enable the cron task
    ${ $fileC } =~ s/(AWSTATS_ENABLE_CRONTABS)=[^\n]+/$1="yes"/;

    $file->save();
}

=item _cleanup

 Process cleanup tasks

 Return int 0 on success, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return 0 unless version->parse( $::imscpConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    # We do not longer provide the static mode so we need to remove related
    # directories in client webdir
    while ( my $dentry = <$::imscpConfig{'USER_WEB_DIR'}/*/statistics> ) {
        next unless -d $dentry;
        my $dirname = dirname( $dentry );
        my $isImmutable = isImmutable( $dirname );
        clearImmutable( $dirname ) if $isImmutable;
        iMSCP::Dir->new( dirname => $dentry )->remove();
        setImmutable( $dirname ) if $isImmutable;
    }

    # Previously, the default cron task as provided by distribution package
    # was disabled in favour of our own cron task. This is no longer the case
    # since i-MSCP version 1.5.4
    return 0 unless -f '/etc/cron.d/awstats.disabled';
    iMSCP::File->new( filename => "/etc/cron.d/awstats.disabled" )->moveFile( '/etc/cron.d/awstats' );
}

=item _createConfig( \%data )

 Create AWStats configuration file for the given domain

 Param hash \%data Domain data
 Return int 0 on success, other or die on failure

=cut

sub _createConfig
{
    my ( $self, $data ) = @_;

    my $fileC = iMSCP::File->new( filename => "$::imscpConfig{'PACKAGES_DIR'}/Webstats/AWStats/templates/templates/awstats.conf.tpl" )->get();
    return 1 unless defined $fileC;

    my $rdbh = $self->{'dbh'};
    local $rdbh->{'RaiseError'} = TRUE;

    my $row = $rdbh->selectrow_hashref( 'SELECT admin_name FROM admin WHERE admin_id = ?', undef, $data->{'DOMAIN_ADMIN_ID'} );
    if ( !$row ) {
        error( sprintf( "Couldn't retrieve data from admin whith ID %d", $data->{'DOMAIN_ADMIN_ID'} ));
        return 1;
    }

    processByRef(
        {
            AUTH_USER    => $row->{'admin_name'},
            SITE_DOMAIN  => $data->{'DOMAIN_NAME'},
            HOST_ALIASES => $self->{'httpd'}->getData()->{'SERVER_ALIASES'}
        },
        \$fileC
    );

    my $file = iMSCP::File->new( filename => "/etc/awstats/awstats.$data->{'DOMAIN_NAME'}.conf" );
    $file->set( $fileC );
    my $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0644 );
}

=item _deleteFiles( )

 Delete files

 Return int 0 on success die on failure

=cut

sub _deleteFiles
{
    my ( $self ) = @_;

    if ( -f '/etc/apache2/.imscp_awstats' ) {
        unlink '/etc/apache2/.imscp_awstats' or die( "Couldn't delete the /etc/apache2/.imscp_awstats file: $!" );
    }

    while ( my $dentry = </etc/awstats/awstats.*.conf> ) {
        unlink $dentry or die( "Couldn't unlink the $dentry AWStats configuration file: $!" );
    }

    while ( my $dentry = </var/cache/awstats/*> ) {
        unlink $dentry or die( "Couldn't unlink the $dentry AWStats cache file: $!" );
    }

    return 0 unless -f '/etc/apache2/sistes-available/01_awstats.conf';

    my $rs = $self->{'httpd'}->disableSites( '01_awstats.conf' );
    return $rs if $rs;

    unlink '/etc/apache2/sistes-available/01_awstats.conf' or die( "Couldn't delete the '/etc/apache2/sistes-available/01_awstats.conf' file: $!" );
    0;
}

=item _enableDefaultConfig( )

 Enable default configuration as provided by distribution package

 Return int 0 on success, other on failure

=cut

sub _enableDefaultConfig
{
    my ( $self ) = @_;

    return 0 unless -f '/etc/awstats/awstats.conf.disabled';

    iMSCP::File->new( filename => '/etc/awstats/awstats.conf.disabled' )->moveFile( '/etc/awstats/awstats.conf' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
