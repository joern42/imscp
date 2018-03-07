=head1 NAME

 iMSCP::Packages::Webstats::Awstats::Awstats - i-MSCP AWStats package

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

package iMSCP::Packages::Webstats::Awstats::Awstats;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Packages::Webstats::Awstats::Installer iMSCP::Packages::Webstats::Awstats::Uninstaller iMSCP::Servers::Httpd /;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use parent 'iMSCP::Common::Singleton';

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

 Process install tasks

 Return void, die on failure 

=cut

sub install
{
    my ( $self ) = @_;

    iMSCP::Packages::Webstats::Awstats::Installer->getInstance( eventManager => $self->{'eventManager'} )->install();
}

=item postinstall( )

 Process post install tasks

 Return void, die on failure 

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Packages::Webstats::Awstats::Installer->getInstance( eventManager => $self->{'eventManager'} )->postinstall();
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure 

=cut

sub uninstall
{
    my ( $self ) = @_;

    iMSCP::Packages::Webstats::Awstats::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
}

=item setEnginePermissions( )

 Set engine permissions

 Return void, die on failure 

=cut

sub setEnginePermissions
{
    my $httpd = iMSCP::Servers::Httpd->factory();

    setRights( "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Scripts/awstats_updateall.pl", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_USER'},
        mode  => '0700'
    } );
    setRights( $::imscpConfig{'AWSTATS_CACHE_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $httpd->getRunningGroup(),
        dirmode   => '02750',
        filemode  => '0640',
        recursive => 1
    } );
    setRights( "$httpd->{'config'}->{'HTTPD_CONF_DIR'}/.imscp_awstats", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $httpd->getRunningGroup(),
        mode  => '0640'
    } );
}

=item getDistroPackages( )

 Get list of Debian packages

 Return list List of packages

=cut

sub getDistroPackages
{
    ( 'awstats', 'libnet-dns-perl' );
}

=item addUser( \%moduleData )

 Process addUser tasks

 Param hashref \%moduleData Data as provided by User module
 Return void, die on failure 

=cut

sub addUser
{
    my ( undef, $moduleData ) = @_;

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
    $httpd->{'reload'} ||= 1;

}

=item preaddDomain( )

 Process preaddDomain tasks

 Return void, die on failure 

=cut

sub preaddDomain
{
    my ( $self ) = @_;

    return if $self->{'_is_registered_event_listener'};

    $self->{'_is_registered_event_listener'} = 1;
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
    my ( undef, $moduleData ) = @_;

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

    $self->{'_is_registered_event_listener'} = 1;
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
    my ( undef, $moduleData ) = @_;

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

 Initialize instance

 Return iMSCP::Packages::Awstats

=cut

sub _init
{
    my ( $self ) = @_;

    @{ $self }{qw/ _is_registered_event_listener _admin_names /} = ( 0, {} );
    $self;
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
        filename => "$::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Config/awstats.imscp_tpl.conf"
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
            CMD_LOGRESOLVEMERGE => "perl $::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/iMSCP/Packages/Webstats/Awstats/Scripts/logresolvemerge.pl",
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
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return void, die on failure

=cut

sub beforeApacheBuildConfFile
{
    my ( undef, $cfgTpl, $filename, undef, $moduleData ) = @_;

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

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
