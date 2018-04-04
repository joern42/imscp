=head1 NAME

 iMSCP::Packages::Webstats::Awstats - i-MSCP AWStats package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Packages::Webstats::Awstats;

use strict;
use warnings;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Servers::Cron iMSCP::Servers::Httpd /;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::File::Attributes qw/ :immutable /;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use version;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 AWStats package for i-MSCP.

 Advanced Web Statistics (AWStats) is a powerful Web server logfile analyzer
 written in perl that shows you all your Web statistics including visits,
 unique visitors, pages, hits, rush hours, search engines, keywords used to
 find your site, robots, broken links and more.

 Project homepage: http://awstats.sourceforge.net/

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_disableDefaultConfig();
    $self->_createCacheDir();
    $self->_setupApache();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Packages::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->_addAwstatsCronTask();
}

=item uninstall( )

 See iMSCP::Packages::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_deleteFiles();
    $self->_removeVhost();
    $self->_restoreDebianConfig();
}

=item setBackendPermissions( )

 See iMSCP::Packages::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    setRights( "$::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Scripts/awstats_updateall.pl", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_USER'},
        mode  => '0700'
    } );
    setRights( $::imscpConfig{'AWSTATS_CACHE_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $httpd->getRunningGroup(),
        dirmode   => '02750',
        filemode  => '0640',
        recursive => TRUE
    } );
    setRights( "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $httpd->getRunningGroup(),
        mode  => '0640'
    } );
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'AWStats';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'AWStats (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $::imscpConfig{'Version'};
}

=item getDistroPackages( )

 See iMSCP::Packages::Abstract::getDistroPackages()

=cut

sub getDistroPackages
{
    my ( $self ) = @_;

    return 'awstats' if $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';
    ();
}

=item addUser( \%moduleData )

 Process addUser tasks

 Param hashref \%moduleData Data as provided by User module
 Return void, die on failure 

=cut

sub addUser
{
    my ( $self, $moduleData ) = @_;

    my $httpd = iMSCP::Servers::Httpd->factory();
    my $file = iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" );
    my $fileContentRef;

    if ( -f "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" ) {
        $fileContentRef = $file->getAsRef();
    } else {
        my $fileContent = '';
        $fileContentRef = \$fileContent;
    }

    ${ $fileContentRef } =~ s/^$moduleData->{'USERNAME'}:[^\n]*\n//gim;
    ${ $fileContentRef } .= "$moduleData->{'USERNAME'}:$moduleData->{'PASSWORD_HASH'}\n";
    $file->save();
    $httpd->{'reload'} ||= TRUE;
}

=item preaddDomain( )

 Process preaddDomain tasks

 Return void, die on failure 

=cut

sub preaddDomain
{
    my ( $self ) = @_;

    return if $self->{'_is_registered_event_listener'};

    $self->{'_is_registered_event_listener'} = TRUE;
    $self->{'eventManager'}->register( 'beforeApacheBuildConfFile', $self );
}

=item addDomain( \%moduleData )

 Process addDomain tasks

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return void, die on failure 

=cut

sub addDomain
{
    my ( $self, $moduleData ) = @_;

    $self->_addAwstatsConfig( $moduleData );
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return void, die on failure 

=cut

sub deleteDomain
{
    my ( $self, $moduleData ) = @_;

    iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.$moduleData->{'DOMAIN_NAME'}.conf" )->remove();

    return unless -d $::imscpConfig{'AWSTATS_CACHE_DIR'};

    iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CACHE_DIR'}/$_" )->remove() for iMSCP::Dir->new(
        dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'}
    )->getFiles( qr/^(?:awstats[0-9]+|dnscachelastupdate)\Q.$moduleData->{'DOMAIN_NAME'}.txt\E$/ );
}

=item preaddSubdomain( )

 Process preaddSubdomain tasks

 Return void, die on failure 

=cut

sub preaddSubdomain
{
    my ( $self ) = @_;

    return if $self->{'_is_registered_event_listener'};

    $self->{'_is_registered_event_listener'} = TRUE;
    $self->{'eventManager'}->register( 'beforeApacheBuildConfFile', $self );
}

=item addSubdomain( \%moduleData )

 Process addSubdomain tasks

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return void, die on failure 

=cut

sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->_addAwstatsConfig( $moduleData );
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return int 0 on success, other or die on failure

=cut

sub deleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.$moduleData->{'DOMAIN_NAME'}.conf" )->remove();

    return unless -d $::imscpConfig{'AWSTATS_CACHE_DIR'};

    iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CACHE_DIR'}/$_" )->remove() for iMSCP::Dir->new(
        dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'}
    )->getFiles( qr/^(?:awstats[0-9]+|dnscachelastupdate)\Q.$moduleData->{'DOMAIN_NAME'}.txt\E$/ );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Packages::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    @{ $self }{qw/ _is_registered_event_listener _admin_names /} = ( FALSE, {} );
    $self->SUPER::_init();
}

=item _disableDefaultConfig( )

 Disable default configuration

 Return void, die on failure

=cut

sub _disableDefaultConfig
{
    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';

    if ( -f "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf" ) {
        iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf" )->move(
            "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled"
        );
    }

    if ( -f '/etc/cron.d/awstats.disable' ) {
        # Transitional -- Will be removed in a later release
        iMSCP::File->new( filename => '/etc/cron.d/awstats.disable' )->move( '/etc/cron.d/awstats' );
    }

    iMSCP::Servers::Cron->factory()->disableSystemTask( 'awstats', 'cron.d' );
}

=item _createCacheDir( )

 Create cache directory

 Return void, die on failure

=cut

sub _createCacheDir
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'} )->make( {
        user  => $::imscpConfig{'ROOT_USER'},
        group => iMSCP::Servers::Httpd->factory()->getRunningGroup(),
        mode  => 02750
    } );
}

=item _setupApache( )

 Setup Apache for AWStats

 Return void, die on failure

=cut

sub _setupApache
{
    my ( $self ) = @_;

    my $httpd = iMSCP::Servers::Httpd->factory();

    # Create Basic authentication file
    iMSCP::File
        ->new( filename => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" )
        ->set( '' ) # Make sure to start with an empty file on update/reconfiguration
        ->save()
        ->owner( $::imscpConfig{'ROOT_USER'}, $httpd->getRunningGroup())
        ->mode( 0640 );

    $httpd->enableModules( 'authn_socache' );
    $httpd->buildConfFile(
        "$::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Config/01_awstats.conf",
        "$httpd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/01_awstats.conf",
        undef,
        {
            AWSTATS_AUTH_USER_FILE_PATH => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats",
            AWSTATS_ENGINE_DIR          => $::imscpConfig{'AWSTATS_ENGINE_DIR'},
            AWSTATS_WEB_DIR             => $::imscpConfig{'AWSTATS_WEB_DIR'}
        }
    );
    $httpd->enableSites( '01_awstats.conf' );
}

=item _addAwstatsCronTask( )

 Add AWStats cron task for dynamic mode

 Return void, die on failure

=cut

sub _addAwstatsCronTask
{
    iMSCP::Servers::Cron->factory()->addTask( {
        TASKID  => 'iMSCP::Packages::Webstats::Awstats',
        MINUTE  => '15',
        HOUR    => '3-21/6',
        DAY     => '*',
        MONTH   => '*',
        DWEEK   => '*',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => 'nice -n 10 ionice -c2 -n5 ' .
            "perl $::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Scripts/awstats_updateall.pl now " .
            "-awstatsprog=$::imscpConfig{'AWSTATS_ENGINE_DIR'}/awstats.pl > /dev/null 2>&1"
    } );
}

=item _cleanup()

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    for my $dir ( iMSCP::Dir->new( dirname => $::imscpConfig{'USER_WEB_DIR'} )->getDirs() ) {
        next unless -d "$::imscpConfig{'USER_WEB_DIR'}/$dir/statistics";
        clearImmutable( "$::imscpConfig{'USER_WEB_DIR'}/$dir" );
        iMSCP::Dir->new( dirname => "/var/www/virtual/$dir/statistics" )->remove();
    }
}

=item _addAwstatsConfig( \%moduleData )

 Add awstats configuration file for the given domain

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return void, die on failure 

=cut

sub _addAwstatsConfig
{
    my ( $self, $moduleData ) = @_;

    unless ( $self->{'_admin_names'}->{$moduleData->{'DOMAIN_ADMIN_ID'}} ) {
        $self->{'_admin_names'}->{$moduleData->{'DOMAIN_ADMIN_ID'}} = iMSCP::Database->getInstance()->selectrow_hashref(
            'SELECT admin_name FROM admin WHERE admin_id = ?', undef, $moduleData->{'DOMAIN_ADMIN_ID'}
        );
        $self->{'_admin_names'}->{$moduleData->{'DOMAIN_ADMIN_ID'}} or die(
            sprintf( "Couldn't retrieve data for admin with ID %d", $moduleData->{'DOMAIN_ADMIN_ID'} )
        );
    }

    my $file = iMSCP::File->new(
        filename => "$::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Config/awstats.imscp_tpl.conf"
    );
    my $fileContentRef = $file->getAsRef();

    my $httpd = iMSCP::Servers::Httpd->factory();

    processByRef(
        {
            ALIAS               => $moduleData->{'ALIAS'},
            AUTH_USER           => "$self->{'_admin_names'}->{$moduleData->{'DOMAIN_ADMIN_ID'}}->{'admin_name'}",
            AWSTATS_CACHE_DIR   => $::imscpConfig{'AWSTATS_CACHE_DIR'},
            AWSTATS_ENGINE_DIR  => $::imscpConfig{'AWSTATS_ENGINE_DIR'},
            AWSTATS_WEB_DIR     => $::imscpConfig{'AWSTATS_WEB_DIR'},
            CMD_LOGRESOLVEMERGE => "perl $::imscpConfig{'BACKEND_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Scripts/logresolvemerge.pl",
            DOMAIN_NAME         => $moduleData->{'DOMAIN_NAME'},
            LOG_DIR             => "$httpd->{'config'}->{'HTTPD_LOG_DIR'}/$moduleData->{'DOMAIN_NAME'}"
        },
        $fileContentRef
    );

    iMSCP::File
        ->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.$moduleData->{'DOMAIN_NAME'}.conf" )
        ->set( $file->get )
        ->save()
        ->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} )
        ->mode( 0644 );
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterApacheBuildConfFile( $awstats, \$cfgTpl, $filename, \$trgFile, \%moduleData, \%apacheServerData, \%apacheServerConfig, \%parameters )

 Event listener that inject AWstats configuration in Apache vhosts

 Param scalar $awstats iMSCP::Packages::Webstats::Awstats::Awstats instance
 Param scalar \$scalar Reference to Apache conffile
 Param string $filename Apache template name
 Param scalar \$trgFile Target file path
 Param hashref \%moduleData Data as provided by Alias|Domain|Subdomain|SubAlias modules
 Param hashref \%apacheServerData Apache server data
 Param hashref \%apacheServerConfig Apache server data
 Param hashref \%parameters OPTIONAL Parameters:
  - user   : File owner (default: root)
  - group  : File group (default: root
  - mode   : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return void, die on failure

=cut

sub beforeApacheBuildConfFile
{
    my ( $awstats, $cfgTpl, $filename, $trgFile, $moduleData ) = @_;

    return if $filename ne 'domain.tpl' || $moduleData->{'FORWARD'} ne 'no';

    debug( sprintf( 'Injecting AWStats configuration in Apache vhost for the %s domain', $moduleData->{'DOMAIN_NAME'} ));

    replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ] }
    <Location /stats>
        ProxyErrorOverride On
        ProxyPreserveHost Off
        ProxyPass http://127.0.0.1:8889/stats/{DOMAIN_NAME} retry=0 acquire=3000 timeout=30 Keepalive=On
        ProxyPassReverse http://127.0.0.1:8889/stats/{DOMAIN_NAME}
    </Location>
    # SECTION addons END.
EOF
}

=item _deleteFiles( )

 Delete files

 Return void, die on failure

=cut

sub _deleteFiles
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats" )->remove();
    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CACHE_DIR'} )->remove();

    return unless -d $::imscpConfig{'AWSTATS_CONFIG_DIR'};

    iMSCP::Dir->new( dirname => $::imscpConfig{'AWSTATS_CONFIG_DIR'} )->clear( qr/^awstats.*\.conf$/ );
}

=item _removeVhost( )

 Remove global vhost file if any

 Return void, die on failure

=cut

sub _removeVhost
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    $httpd->disableSites( '01_awstats.conf' );

    iMSCP::File->new( filename => "$httpd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/01_awstats.conf" )->remove();
}

=item _restoreDebianConfig( )

 Restore default configuration

 Return void, die on failure

=cut

sub _restoreDebianConfig
{
    return unless $::imscpConfig{'DISTRO_FAMILY'} eq 'Debian';

    if ( -f "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" ) {
        iMSCP::File->new( filename => "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf.disabled" )->move(
            "$::imscpConfig{'AWSTATS_CONFIG_DIR'}/awstats.conf"
        );
    }

    iMSCP::Servers::Cron->factory()->enableSystemTask( 'awstats', 'cron.d' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
