=head1 NAME

 iMSCP::Packages::Setup::FileManager::MonstaFTP::Installer - i-MSCP MonstaFTP package installer

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

package iMSCP::Packages::Setup::FileManager::MonstaFTP::Installer;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Composer;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::TemplateParser qw/ getBlocByRef processByRef replaceBlocByRef /;
use JSON;
use iMSCP::Packages::FrontEnd;
use parent 'iMSCP::Common::Singleton';

our $VERSION = '2.1.x';

=head1 DESCRIPTION

 i-MSCP MonstaFTP package installer.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->{'frontend'}->getComposer()->requirePackage( 'imscp/monsta-ftp', $VERSION );
    $self->{'eventManager'}->register( 'afterFrontEndBuildConfFile', \&afterFrontEndBuildConfFile );
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    $self->_installFiles();
    $self->_buildHttpdConfig();
    $self->_buildConfig();
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
    include imscp_monstaftp.conf;
    # SECTION custom END.
EOF
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Setup::FileManager::MonstaFTP::Installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self;
}

=item _installFiles( )

 Install MonstaFTP files in production directory

 Return void, die on failure

=cut

sub _installFiles
{
    my $packageDir = "$::imscpConfig{'IMSCP_HOMEDIR'}/packages/vendor/imscp/monsta-ftp";
    -d $packageDir or die( "Couldn't find the imscp/monsta-ftp package into the packages cache directory" );

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" )->remove();
    iMSCP::Dir->new( dirname => "$packageDir/src" )->copy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" );
    iMSCP::Dir->new( dirname => "$packageDir/iMSCP/src" )->copy( "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" );
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
        { GUI_PUBLIC_DIR => $::imscpConfig{'GUI_PUBLIC_DIR'} },
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
        TMP_PATH => "$::imscpConfig{'GUI_ROOT_DIR'}/data/tmp"
    };
    my $file = iMSCP::File->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp/settings/config.php" );
    my $cfgTpl = $file->getAsRef( TRUE );

    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'monstaftp', 'config.php', $cfgTpl, $data );
    $file->getAsRef() unless length ${ $cfgTpl };

    processByRef( $data, $cfgTpl );
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

    $file = iMSCP::File->new( filename => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp/settings/settings.json" );
    $cfgTpl = $file->getAsRef( TRUE );
    $self->{'eventManager'}->trigger( 'onLoadTemplate', 'monstaftp', 'settings.json', $cfgTpl, $data );
    ${ $cfgTpl } = JSON->new()->utf8( 1 )->pretty( 1 )->encode( $data ) unless length ${ $cfgTpl };
    $file->save()->owner( $usergroup, $usergroup )->mode( 0440 );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
