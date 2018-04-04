=head1 NAME

 iMSCP::Packages::Setup::FileManager::Pydio - i-MSCP Pydio package

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

package iMSCP::Packages::Setup::FileManager::Pydio;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Packages::Setup::FrontEnd;
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use parent 'iMSCP::Packages::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP Pydio package.

 Pydio (formely AjaXplorer) is a software that can turn any web server into a
 powerfull file management system and an alternative to mainstream cloud storage
 providers.

 Project homepage: https://pyd.io/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/ajaxplorer', '0.2.0.*@dev' );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::Packages::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_installFiles();
    $self->_buildHttpdConfig();
}

=item uninstall( )

 See iMSCP::Packages::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_unregisterConfig();
    $self->_removeFiles();
}

=item getPackageName( )

 See iMSCP::Packages::Abstract::getPackageName()

=cut

sub getPackageName
{
    my ( $self ) = @_;

    'Pydio';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'Pydio Filemanager (%s)', $self->getPackageVersion());
}

=item getPackageVersion( )

 See iMSCP::Packages::Abstract::getPackageVersion()

=cut

sub getPackageVersion
{
    my ( $self ) = @_;

    $::imscpConfig{'Version'};
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Pydio::Installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontend'} = iMSCP::Packages::Setup::FrontEnd->getInstance();
    $self->SUPER::_init();
}

=item _installFiles( )

 Install files in production directory

 Return void, die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/ajaxplorer";
    -d $packageDir or die( "Couldn't find the imscp/ajaxplorer (Pydio) package into the packages cache directory" );

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/ftp" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/ftp" );
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/src" )->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/ftp" );
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return void, die on failure

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    $self->{'frontend'}->buildConfFile(
        "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/ajaxplorer/iMSCP/config/nginx/imscp_pydio.conf",
        { GUI_PUBLIC_DIR => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public" },
        { destination => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf" }
    );
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return void, die on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/[\t ]*include imscp_pydio.conf;\n//;
    $file->save();

    $self->{'frontend'}->{'reload'} ||= TRUE;
}

=item _removeFiles( )

 Remove files

 Return void, die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/ftp" )->remove();
    iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf" )->remove();
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterFrontEndBuildConfFile( \$tplContent, $filename )

 Include httpd configuration into frontEnd vhost files

 Param string \$tplContent Reference to template file content
 Param string $tplName Template name
 Return void, die on failure

=cut

sub afterFrontEndBuildConfFile
{
    my ( $tplContent, $tplName ) = @_;

    return unless ( $tplName eq '00_master.nginx' && ::setupGetQuestion( 'BASE_SERVER_VHOST_PREFIX' ) ne 'https://' )
        || $tplName eq '00_master_ssl.nginx';

    replaceBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", <<"EOF", $tplContent );
    # SECTION custom BEGIN.
@{ [ getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent ) ] }
    include imscp_pydio.conf;
    # SECTION custom END.
EOF
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
