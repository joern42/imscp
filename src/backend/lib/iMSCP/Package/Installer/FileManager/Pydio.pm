=head1 NAME

 iMSCP::Package::Installer::FileManager::Pydio - i-MSCP Pydio package

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

package iMSCP::Package::Installer::FileManager::Pydio;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Debug 'error';
use iMSCP::Dir;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Package::Installer::FrontEnd;
use iMSCP::Rights 'setRights';
use iMSCP::TemplateParser qw/ getBlocByRef replaceBlocByRef /;
use parent 'iMSCP::Package::Abstract';

our $VERSION = '0.2.0.*@dev';

=head1 DESCRIPTION

 i-MSCP Pydio package.

 Pydio ( formely AjaXplorer ) is a software that can turn any web server into a
 powerfull file management system and an alternative to mainstream cloud
 storage providers.

 Project homepage: https://pyd.io/

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Installer::AbstractActions::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    my $rs = iMSCP::Composer->getInstance()->registerPackage( 'imscp/ajaxplorer', $VERSION );
    $rs ||= $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_installFiles();
    $rs ||= $self->_buildHttpdConfig();
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $rs = $self->_unregisterConfig();
    $rs ||= $self->_removeFiles();
}

=item setGuiPermissions( )

 See iMSCP::Installer::AbstractActions::setGuiPermissions()

=cut

sub setGuiPermissions
{
    my ( $self ) = @_;

    my $panelUserGroup = $::imscpConfig{'USER_PREFIX'} . $::imscpConfig{'USER_MIN_UID'};

    my $rs = setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0550',
        filemode  => '0440',
        recursive => TRUE
    } );
    $rs ||= setRights( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp/data", {
        user      => $panelUserGroup,
        group     => $panelUserGroup,
        dirmode   => '0750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterFrontEndBuildConfFile( \$tplContent, $filename )

 Include httpd configuration into frontEnd vhost files

 Param string \$tplContent Template file tplContent
 Param string $tplName Template name
 Return int 0 on success, other on failure

=cut

sub afterFrontEndBuildConfFile
{
    my ( $tplContent, $tplName ) = @_;

    return 0 unless grep ($_ eq $tplName, '00_master.nginx', '00_master_ssl.nginx');

    replaceBlocByRef(
        "# SECTION custom BEGIN.\n",
        "# SECTION custom END.\n",
        "    # SECTION custom BEGIN.\n"
            . getBlocByRef( "# SECTION custom BEGIN.\n", "# SECTION custom END.\n", $tplContent )
            . "    include imscp_pydio.conf;\n"
            . "    # SECTION custom END.\n",
        $tplContent
    );
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _installFiles( )

 Install files in production directory

 Return int 0 on success, other or die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/ajaxplorer";
    unless ( -d $packageDir ) {
        error( "Couldn't find the imscp/ajaxplorer (Pydio) package into the packages cache directory" );
        return 1;
    }

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" );
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/src" )->copy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" );
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return int 0 on success, other on failure

=cut

sub _buildHttpdConfig
{
    my $frontEnd = iMSCP::Package::Installer::FrontEnd->getInstance();
    $frontEnd->buildConfFile(
        "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/ajaxplorer/iMSCP/config/nginx/imscp_pydio.conf",
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
        { destination => "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf" }
    );
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return int 0 on success, other on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    my $frontEnd = iMSCP::Package::Installer::FrontEnd->getInstance();

    return 0 unless -f "$frontEnd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_";

    my $file = iMSCP::File->new( filename => "$frontEnd->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } =~ s/[\t ]*include imscp_pydio.conf;\n//;

    my $rs = $file->save();
    return $rs if $rs;

    $frontEnd->{'reload'} = TRUE;
    0;
}

=item _removeFiles( )

 Remove files

 Return int 0 on success, other or die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" )->remove();

    my $frontEnd = iMSCP::Package::Installer::FrontEnd->getInstance();

    return 0 unless -f "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf";

    iMSCP::File->new( filename => "$frontEnd->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf" )->delFile();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
