=head1 NAME

 iMSCP::Packages::Setup::FileManagers::MonstaFTP - i-MSCP package

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

package iMSCP::Packages::Setup::FileManagers::MonstaFTP;

use strict;
use warnings;
use parent 'iMSCP::Packages::Abstract';
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Template::Processor qw/ processBlocByRef processVarsByRef /;
use iMSCP::Packages::Setup::FrontEnd;
use JSON;
our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP MonstaFTP package.

 MonstaFTP is a web-based FTP client written in PHP.

 Project homepage: http://www.monstaftp.com//

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Packages::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/monsta-ftp', '2.1.x' );
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
    $self->_buildConfig();
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

    'MonstaFTP';
}

=item getPackageHumanName( )

 See iMSCP::Packages::Abstract::getPackageHumanName()

=cut

sub getPackageHumanName
{
    my ( $self ) = @_;

    sprintf( 'MonstaFTP Filemanager (%s)', $self->getPackageVersion());
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

 See iMSCP::Packages::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontend'} = iMSCP::Packages::Setup::FrontEnd->getInstance();
    $self->SUPER::_init();
}

=item _installFiles( )

 Install MonstaFTP files in production directory

 Return void, die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/monsta-ftp";
    -d $packageDir or die( "Couldn't find the imscp/monsta-ftp package into the packages cache directory" );

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp" );
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/src" )->copy( "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp" );
}

=item _buildHttpdConfig( )

 Build Httpd configuration

 Return void, die on failure

=cut

sub _buildHttpdConfig
{
    my ( $self ) = @_;

    $self->{'frontend'}->buildConfFile(
        "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/monsta-ftp/iMSCP/nginx/imscp_monstaftp.conf",
        { GUI_PUBLIC_DIR => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public" },
        { destination => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_monstaftp.conf" }
    );
}

=item _buildConfig( )

 Build configuration file

 Return void, die on failure

=cut

sub _buildConfig
{
    my ( $self ) = @_;

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . $::imscpConfig{'SYSTEM_USER_MIN_UID'};

    # config.php file
    my $data = {
        TIMEZONE => ::setupGetQuestion( 'TIMEZONE', 'UTC' ),
        TMP_PATH => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/tmp"
    };
    my $file = iMSCP::File->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp/settings/config.php" );
    my $cfgTpl = $file->getAsRef( TRUE );

    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'monstaftp', 'config.php', $cfgTpl, $data );
    $file->getAsRef() unless length ${ $cfgTpl };

    processVarsByRef( $cfgTpl, $data );
    $file->save()->owner( $usergroup, $usergroup )->mode( 0440 );

    # settings.json file
    $data = {
        showDotFiles            => JSON::true,
        language                => 'en_us',
        editNewFilesImmediately => JSON::true,
        editableFileExtensions  => 'txt,htm,html,php,asp,aspx,js,css,xhtml,cfm,pl,py,c,cpp,rb,java,xml,json',
        hideProUpgradeMessages  => JSON::true,
        disableMasterLogin      => JSON::true,
        connectionRestrictions  => {
            types => [ 'ftp' ],
            ftp   => {
                host             => '127.0.0.1',
                port             => 21,
                # Enable passive mode excepted if the FTP daemon is VsFTPd
                # VsFTPd doesn't allows to operate on a per IP basic (IP masquerading)
                passive          => index( $::imscpConfig{'iMSCP::Servers::Ftpd'}, '::Vsftpd::' ) != -1 ? JSON::false : JSON::true,
                ssl              => ::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ? JSON::true : JSON::false,
                initialDirectory => '/' # Home directory as set for the FTP user
            }
        }
    };

    $file = iMSCP::File->new( filename => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp/settings/settings.json" );
    $cfgTpl = $file->getAsRef( TRUE );
    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'monstaftp', 'settings.json', $cfgTpl, $data );
    ${ $cfgTpl } = JSON->new()->utf8()->pretty( TRUE )->encode( $data ) unless length ${ $cfgTpl };
    $file->save()->owner( $usergroup, $usergroup )->mode( 0440 );
}

=item _unregisterConfig( )

 Remove include directive from frontEnd vhost files

 Return void, die on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/(^[\t ]+)?\Qinclude imscp_monstaftp.conf;\E\n//m;
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

    iMSCP::Dir->new( dirname => "$::imscpConfig{'FRONTEND_ROOT_DIR'}/public/tools/monstaftp" )->remove();
    iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_monstaftp.conf" )->remove();
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

    processBlocByRef( $tplContent, '# SECTION custom BEGIN.', '# SECTION custom ENDING.', <<"EOF", TRUE );
    include imscp_monstaftp.conf;
EOF
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
