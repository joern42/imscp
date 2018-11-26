=head1 NAME

 iMSCP::Servers::Httpd::Nginx::Abstract - i-MSCP Nginx server abstract implementation

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

package iMSCP::Servers::Httpd::Nginx::Abstract;

use strict;
use warnings;
use Array::Utils qw/ unique /;
use autouse 'Date::Format' => qw/ time2str /;
use autouse 'iMSCP::Crypt' => qw/ ALNUM decryptRijndaelCBC randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Servers::Sqld /;
use File::Basename;
use File::Spec;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::File::Attributes qw/ :immutable /;
use iMSCP::Getopt;
use iMSCP::Mount qw/ mount umount isMountpoint addMountEntry removeMountEntry /;
use iMSCP::Net;
use iMSCP::Rights qw/ setRights /;
use iMSCP::SystemUser;
use iMSCP::TemplateParser qw/ replaceBlocByRef /;
use Scalar::Defer;
use parent qw/ iMSCP::Servers::Httpd /;

my $TMPFS = lazy
    {
        my $tmpfs = iMSCP::Dir->new( dirname => "$::imscpConfig{'IMSCP_HOMEDIR'}/tmp/nginx_tmpfs" )->make( { umask => 0027 } );
        return $tmpfs if isMountpoint( $tmpfs );

        mount(
            {
                fs_spec         => 'tmpfs',
                fs_file         => $tmpfs,
                fs_vfstype      => 'tmpfs',
                fs_mntops       => 'noexec,nosuid,size=32m',
                ignore_failures => 1 # Ignore failures in case tmpfs isn't supported/allowed
            }
        );

        $tmpfs;
    };

=head1 DESCRIPTION

 i-MSCP Nginx server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_setVersion();
    $rs ||= $self->_copyDomainDisablePages();
    $rs ||= $self->_setupVlogger();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_removeVloggerSqlUser();
}

=item setBackendPermissions( )

 See iMSCP::Servers::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    #    my $rs ||= setRights( "$::imscpConfig{'BACKEND_ROOT_DIR'}/traffic/vlogger",
    #        {
    #            user  => $::imscpConfig{'ROOT_USER'},
    #            group => $::imscpConfig{'ROOT_GROUP'},
    #            mode  => '0750'
    #        }
    #    );
    my $rs = setRights( $self->{'config'}->{'HTTPD_LOG_DIR'},
        {
            user      => $::imscpConfig{'ROOT_USER'},
            group     => $::imscpConfig{'ADM_GROUP'},
            dirmode   => '0755',
            filemode  => '0644',
            recursive => iMSCP::Getopt->fixPermissions
        }
    );
    $rs ||= setRights( "$::imscpConfig{'USER_WEB_DIR'}/domain_disabled_pages",
        {
            user      => $::imscpConfig{'ROOT_USER'},
            group     => $self->{'config'}->{'HTTPD_GROUP'},
            dirmode   => '0550',
            filemode  => '0440',
            recursive => iMSCP::Getopt->fixPermissions
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Nginx';
}

=item getServerHumanName( )

 See iMSCP::Servers::Abstract::getServerHumanName()

=cut

sub getServerHumanName
{
    my ( $self ) = @_;

    sprintf( "Nginx %s", $self->getServerVersion());
}

=item getServerVersion( )

 See iMSCP::Servers::Abstract::getServerVersion()

=cut

sub getServerVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'HTTPD_VERSION'};
}

=item addUser( \%moduleData )

 See iMSCP::Servers::Httpd::addUser()

=cut

sub addUser
{
    my ( $self, $moduleData ) = @_;

    return 0 if $moduleData->{'STATUS'} eq 'tochangepwd';

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxAddUser', $moduleData );
    $rs ||= iMSCP::SystemUser->new( username => $self->getRunningUser())->addToGroup( $moduleData->{'GROUP'} );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxAddUser', $moduleData );
}

=item deleteUser( \%moduleData )

 See iMSCP::Servers::Httpd::deleteUser()

=cut

sub deleteUser
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxDeleteUser', $moduleData );
    $rs ||= iMSCP::SystemUser->new( username => $self->getRunningUser())->removeFromGroup( $moduleData->{'GROUP'} );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxDeleteUser', $moduleData );
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Httpd::addDomain()

=cut

sub addDomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxAddDomain', $moduleData );
    $rs ||= $self->_addCfg( $moduleData );
    $rs ||= $self->_addFiles( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxAddDomain', $moduleData );
}

=item restoreDomain( \%moduleData )

 See iMSCP::Servers::Httpd::restoreDmn()

=cut

sub restoreDomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxRestoreDomain', $moduleData );

    unless ( $moduleData->{'DOMAIN_TYPE'} eq 'als' ) {
        eval {
            # Restore the first backup found
            for ( iMSCP::Dir->new( dirname => "$moduleData->{'HOME_DIR'}/backups" )->getFiles() ) {
                next if -l "$moduleData->{'HOME_DIR'}/backups/$_"; # Don't follow symlinks (See #IP-990)
                next unless /^web-backup-.+?\.tar(?:\.(bz2|gz|lzma|xz))?$/;

                my $archFormat = $1 || '';

                # Since we are now using immutable bit to protect some folders, we
                # must in order do the following to restore a backup archive:
                #
                # - Un-protect user homedir (clear immutable flag recursively)
                # - Restore web files
                # - Update status of sub, als and alssub, entities linked to the
                #   domain to 'torestore'
                #
                # The third and last task allow to set correct permissions and set
                # immutable flag on folders if needed for each entity

                if ( $archFormat eq 'bz2' ) {
                    $archFormat = 'bzip2';
                } elsif ( $archFormat eq 'gz' ) {
                    $archFormat = 'gzip';
                }

                # Un-protect homedir recursively
                clearImmutable( $moduleData->{'HOME_DIR'}, TRUE );

                my $cmd;
                if ( length $archFormat ) {
                    $cmd = [ 'tar', '-x', '-p', "--$archFormat", '-C', $moduleData->{'HOME_DIR'}, '-f', "$moduleData->{'HOME_DIR'}/backups/$_" ];
                } else {
                    $cmd = [ 'tar', '-x', '-p', '-C', $moduleData->{'HOME_DIR'}, '-f', "$moduleData->{'HOME_DIR'}/backups/$_" ];
                }

                $rs = execute( $cmd, \my $stdout, \my $stderr );
                debug( $stdout ) if length $stdout;
                $rs == 0 or croak( $stderr || 'Unknown error' );
                last;
            }
        };
        if ( $@ ) {
            error( $@ );
            return 1;
        }
    }

    $rs = $self->_addFiles( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxRestoreDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Httpd::disableDomain()

=cut

sub disableDomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxDisableDomain', $moduleData );
    return $rs if $rs;

    eval {
        if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' ) {
            # Sets the status of any subdomain that belongs to this domain to 'todisable'.
            $self->{'dbh'}->do(
                "UPDATE subdomain SET subdomain_status = 'todisable' WHERE domain_id = ? AND subdomain_status <> 'todelete'",
                undef, $moduleData->{'DOMAIN_ID'}
            );
        } else {
            # Sets the status of any subdomain that belongs to this domain alias to 'todisable'.
            $self->{'dbh'}->do(
                "UPDATE subdomain_alias SET subdomain_alias_status = 'todisable' WHERE alias_id = ? AND subdomain_alias_status <> 'todelete'",
                undef, $moduleData->{'DOMAIN_ID'}
            );
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $rs = $self->_disableDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Httpd::deleteDomain()

=cut

sub deleteDomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxDeleteDomain', $moduleData );
    $rs ||= $self->_deleteDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Httpd::addSubdomain()

=cut

sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxAddSubdomain', $moduleData );
    $rs ||= $self->_addCfg( $moduleData );
    $rs ||= $self->_addFiles( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxAddSubdomain', $moduleData );
}

=item restoreSubdomain( \%moduleData )

 See iMSCP::Servers::Httpd::restoreSubdomain()

=cut

sub restoreSubdomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxRestoreSubdomain', $moduleData );
    $rs ||= $self->_addFiles( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxRestoreSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Httpd::disableSubdomain()

=cut

sub disableSubdomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxDisableSubdomain', $moduleData );
    $rs ||= $self->_disableDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Httpd::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxDeleteSubdomain', $moduleData );
    $rs ||= $self->_deleteDomain( $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxDeleteSubdomain', $moduleData );
}

=item addHtpasswd( \%moduleData )

 See iMSCP::Servers::Httpd::addHtpasswd()

=cut

sub addHtpasswd
{
    my ( $self, $moduleData ) = @_;

    return 0;

    eval {
        clearImmutable( $moduleData->{'WEB_DIR'} );

        my $file = iMSCP::File->new( filename => "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_USERS_FILENAME'}" );
        my $fileContentRef;
        if ( -f $file->{'filename'} ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxAddHtpasswd', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        ${ $fileContentRef } =~ s/^$moduleData->{'HTUSER_NAME'}:[^\n]*\n//gim;
        ${ $fileContentRef } .= "$moduleData->{'HTUSER_NAME'}:$moduleData->{'HTUSER_PASS'}\n";

        $self->{'eventManager'}->trigger( 'afterNginxAddHtpasswd', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        $file->save( 0027 )->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'HTTPD_GROUP'} )->mode( 0640 );

        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
        return 1;
    }

    $self->{'reload'} ||= 1;

    0;
}

=item deleteHtpasswd( \%moduleData )

 See iMSCP::Servers::Httpd::deleteHtpasswd()

=cut

sub deleteHtpasswd
{
    my ( $self, $moduleData ) = @_;

    return 0;

    eval {
        return unless -f "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_USERS_FILENAME'}";

        clearImmutable( $moduleData->{'WEB_DIR'} );

        my $file = iMSCP::File->new( filename => "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_USERS_FILENAME'}" );
        my $fileContentRef;
        if ( -f $file->{'filename'} ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxDeleteHtpasswd', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        ${ $fileContentRef } =~ s/^$moduleData->{'HTUSER_NAME'}:[^\n]*\n//gim;

        $self->{'eventManager'}->trigger( 'afterNginxDeleteHtpasswd', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        $file->save()->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'HTTPD_GROUP'} )->mode( 0640 );

        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
        return 1;
    }

    0;
}

=item addHtgroup( \%moduleData )

 See iMSCP::Servers::Httpd::addHtgroup()

=cut

sub addHtgroup
{
    my ( $self, $moduleData ) = @_;

    return 0;

    eval {
        clearImmutable( $moduleData->{'WEB_DIR'} );

        my $file = iMSCP::File->new( filename => "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_GROUPS_FILENAME'}" );
        my $fileContentRef;
        if ( -f $file->{'filename'} ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxAddHtgroup', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        ${ $fileContentRef } =~ s/^$moduleData->{'HTGROUP_NAME'}:[^\n]*\n//gim;
        ${ $fileContentRef } .= "$moduleData->{'HTGROUP_NAME'}:$moduleData->{'HTGROUP_USERS'}\n";

        $self->{'eventManager'}->trigger( 'afterNginxAddHtgroup', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        $file->save( 0027 )->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'HTTPD_GROUP'} )->mode( 0640 );

        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
        return 1;
    }

    0;
}

=item deleteHtgroup( \%moduleData )

 See iMSCP::Servers::Httpd::deleteHtgroup()

=cut

sub deleteHtgroup
{
    my ( $self, $moduleData ) = @_;

    return 0;

    eval {
        return 0 unless -f "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_GROUPS_FILENAME'}";

        clearImmutable( $moduleData->{'WEB_DIR'} );

        my $file = iMSCP::File->new( filename => "$moduleData->{'WEB_DIR'}/$self->{'config'}->{'HTTPD_HTACCESS_GROUPS_FILENAME'}" );
        my $fileContentRef;
        if ( -f $file->{'filename'} ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxDeleteHtgroup', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        ${ $fileContentRef } =~ s/^$moduleData->{'HTGROUP_NAME'}:[^\n]*\n//gim;

        $self->{'eventManager'}->trigger( 'afterNginxDeleteHtgroup', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        $file->save()->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'HTTPD_GROUP'} )->mode( 0640 );

        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
        return 1;
    }

    0;
}

=item addHtaccess( \%moduleData )

 See iMSCP::Servers::Httpd::addHtaccess()

=cut

sub addHtaccess
{
    my ( $self, $moduleData ) = @_;

    return 0;
    return 0 unless -d $moduleData->{'AUTH_PATH'};

    my $isImmutable = isImmutable( $moduleData->{'AUTH_PATH'} );

    eval {
        clearImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;

        my $file = iMSCP::File->new( filename => "$moduleData->{'AUTH_PATH'}/.htaccess" );
        my $fileContentRef;
        if ( -f $file->{'filename'} ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxAddHtaccess', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        my $bTag = "### START i-MSCP PROTECTION ###\n";
        my $eTag = "### END i-MSCP PROTECTION ###\n";
        my $tagContent = <<"EOF";
AuthType $moduleData->{'AUTH_TYPE'}
AuthName "$moduleData->{'AUTH_NAME'}"
AuthBasicProvider file
AuthUserFile $moduleData->{'HOME_PATH'}/$self->{'config'}->{'HTTPD_HTACCESS_USERS_FILENAME'}
EOF

        unless ( length $moduleData->{'HTUSERS'} ) {
            $tagContent .= <<"EOF";
AuthGroupFile $moduleData->{'HOME_PATH'}/$self->{'config'}->{'HTTPD_HTACCESS_GROUPS_FILENAME'}
Require group $moduleData->{'HTGROUPS'}
EOF
        } else {
            $tagContent .= <<"EOF";
Require user $moduleData->{'HTUSERS'}
EOF
        }

        replaceBlocByRef( $bTag, $eTag, '', $fileContentRef );
        ${ $fileContentRef } = $bTag . $tagContent . $eTag . ${ $fileContentRef };

        $self->{'eventManager'}->trigger( 'afterNginxAddHtaccess', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        $file->save( 0027 )->owner( $moduleData->{'USER'}, $moduleData->{'GROUP'} )->mode( 0640 );

        setImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;
        return 1;
    }

    0;
}

=item deleteHtaccess( \%moduleData )

 See iMSCP::Servers::Httpd::deleteHtaccess()

=cut

sub deleteHtaccess
{
    my ( $self, $moduleData ) = @_;

    return 0 unless -d $moduleData->{'AUTH_PATH'} && -f "$moduleData->{'AUTH_PATH'}/.htaccess";

    my $isImmutable = isImmutable( $moduleData->{'AUTH_PATH'} );

    eval {
        clearImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;

        my $file = iMSCP::File->new( filename => "$moduleData->{'AUTH_PATH'}/.htaccess" );
        my $fileExist = -f $file->{'filename'};
        my $fileContentRef;

        if ( $fileExist ) {
            $fileContentRef = $file->getAsRef();
        } else {
            my $stamp = '';
            $fileContentRef = \$stamp;
        }

        $self->{'eventManager'}->trigger( 'beforeNginxDeleteHtaccess', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        replaceBlocByRef( "### START i-MSCP PROTECTION ###\n", "### END i-MSCP PROTECTION ###\n", '', $fileContentRef );

        $self->{'eventManager'}->trigger( 'afterNginxDeleteHtaccess', $fileContentRef, $moduleData ) == 0 or die(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        if ( length ${ $fileContentRef } ) {
            $file->save()->owner( $moduleData->{'USER'}, $moduleData->{'GROUP'} )->mode( 0640 );
        } elsif ( $fileExist ) {
            $file->remove();
        }

        setImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'AUTH_PATH'} ) if $isImmutable;
        return 1;
    }

    0;
}

=item buildConfFile( $srcFile, $trgFile, [, \%mdata = { } [, \%sdata [, \%params = { } ] ] ] )

 See iMSCP::Servers::Abstract::buildConfFile()

=cut

sub buildConfFile
{
    my ( $self, $srcFile, $trgFile, $mdata, $sdata, $params ) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeNginxBuildConfFile',
        sub {
            return 0 unless grep ( $_ eq $_[1], ( 'domain.tpl', 'domain_disabled.tpl' ) );

            if ( grep ( $_ eq $sdata->{'VHOST_TYPE'}, 'domain', 'domain_disabled' ) ) {
                replaceBlocByRef( '# SECTION ssl BEGIN.', '# SECTION ssl ENDING.', '', $_[0] );
                replaceBlocByRef( '# SECTION fwd BEGIN.', '# SECTION fwd ENDING.', '', $_[0] );
            } elsif ( grep ( $_ eq $sdata->{'VHOST_TYPE'}, 'domain_fwd', 'domain_ssl_fwd', 'domain_disabled_fwd' ) ) {
                if ( $sdata->{'VHOST_TYPE'} ne 'domain_ssl_fwd' ) {
                    replaceBlocByRef( '# SECTION ssl BEGIN.', '# SECTION ssl ENDING.', '', $_[0] );
                }

                replaceBlocByRef( '# SECTION dmn BEGIN.', '# SECTION dmn ENDING.', '', $_[0] );
            } elsif ( grep ( $_ eq $sdata->{'VHOST_TYPE'}, 'domain_ssl', 'domain_disabled_ssl' ) ) {
                replaceBlocByRef( '# SECTION fwd BEGIN.', '# SECTION fwd ENDING.', '', $_[0] );
            }

            0;
        },
        100
    );
    $rs ||= $self->SUPER::buildConfFile( $srcFile, $trgFile, $mdata, $sdata, $params );

    # On configuration file change, schedule server reload
    $self->{'reload'} ||= 1 unless $rs;
    $rs;
}

=item getTraffic( \%trafficDb )

 See iMSCP::Servers::Httpd::getTraffic()

=cut

sub getTraffic
{
    my ( undef, $trafficDb ) = @_;

    my $ldate = time2str( '%Y%m%d', time());

    debug( sprintf( 'Collecting HTTP traffic data' ));

    eval {
        $self->{'dbh'}->begin_work();
        my $sth = $self->{'dbh'}->prepare( 'SELECT vhost, bytes FROM httpd_vlogger WHERE ldate <= ? FOR UPDATE' );
        $sth->execute( $ldate );

        while ( my $row = $sth->fetchrow_hashref() ) {
            next unless exists $trafficDb->{$row->{'vhost'}};
            $trafficDb->{$row->{'vhost'}} += $row->{'bytes'};
        }

        $self->{'dbh'}->do( 'DELETE FROM httpd_vlogger WHERE ldate <= ?', undef, $ldate );
        $self->{'dbh'}->commit();
    };
    if ( $@ ) {
        $self->{'dbh'}->rollback();
        %{ $trafficDb } = ();
        croak( sprintf( "Couldn't collect traffic data: %s", $@ ));
    }

    0;
}

=item getRunningUser( )

 See iMSCP::Servers::Httpd::getRunningUser()

=cut

sub getRunningUser
{
    my ( $self ) = @_;

    $self->{'config'}->{'HTTPD_USER'};
}

=item getRunningGroup( )

 See iMSCP::Servers::Httpd::getRunningGroup()

=cut

sub getRunningGroup
{
    my ( $self ) = @_;

    $self->{'config'}->{'HTTPD_GROUP'};
}

=item enableModules( @modules )

 Enable the given modules
 
 Param list @modules List of modules to enable
 Return int 0 on success, other on failure

=cut

sub enableModules
{
    my ( $self ) = @_;

    croak( sprintf( 'The %s class must implement the enableModules() method', ref $self ));
}

=item disableModules( @modules )

 Disable the given modules
 
 Param list @modules List of modules to disable
 Return int 0 on success, other on failure

=cut

sub disableModules
{
    my ( $self ) = @_;

    croak( sprintf( 'The %s class must implement the disableModules() method', ref $self ));
}

=item enableConfs( @conffiles )

 Enable the given configuration files
 
 Param list @conffiles List of configuration files to enable
 Return int 0 on success, other on failure

=cut

sub enableConfs
{
    my ( $self ) = @_;

    croak( sprintf( 'The %s class must implement the enableConfs() method', ref $self ));
}

=item disableConfs( @conffiles )

 Disable the given configuration files
 
 Param list @conffiles List of configuration files to disable
 Return int 0 on success, other on failure

=cut

sub disableConfs
{
    my ( $self ) = @_;

    croak( sprintf( 'The %s class must implement the disableConfs() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Httpd::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{ $self }{qw/ restart reload _templates cfgDir _web_folder_skeleton /} = ( 0, 0, {}, "$::imscpConfig{'CONF_DIR'}/apache", undef );
    $self->{'eventManager'}->register( 'afterNginxBuildConfFile', $self, -999 );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Nginx version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    croak( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _deleteDomain( \%moduleData )

 Process deleteDomain tasks

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return int 0 on success, other or die on failure

=cut

sub _deleteDomain
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->disableSites( "$moduleData->{'DOMAIN_NAME'}.conf", "$moduleData->{'DOMAIN_NAME'}_ssl.conf" );
    return $rs if $rs;

    for ( "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf",
        "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}_ssl.conf",
        "$self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf"
    ) {
        iMSCP::File->new( filename => $_ )->remove();
    }

    $rs = $self->_umountLogsFolder( $moduleData );
    return $rs if $rs;

    unless ( $moduleData->{'SHARED_MOUNT_POINT'} || !-d $moduleData->{'WEB_DIR'} ) {
        ( my $userWebDir = $::imscpConfig{'USER_WEB_DIR'} ) =~ s%/+$%%;
        my $parentDir = dirname( $moduleData->{'WEB_DIR'} );

        clearImmutable( $parentDir );
        clearImmutable( $moduleData->{'WEB_DIR'}, TRUE );

        eval { iMSCP::Dir->new( dirname => $moduleData->{'WEB_DIR'} )->remove(); };
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        if ( $parentDir ne $userWebDir ) {
            eval {
                my $dir = iMSCP::Dir->new( dirname => $parentDir );
                if ( $dir->isEmpty() ) {
                    clearImmutable( dirname( $parentDir ));
                    $dir->remove();
                }
            };
            if ( $@ ) {
                error( $@ );
                return 1;
            }
        }

        if ( $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes' && $parentDir ne $userWebDir ) {
            do {
                setImmutable( $parentDir ) if -d $parentDir;
            } while ( $parentDir = dirname( $parentDir ) ) ne $userWebDir;
        }
    }

    eval {
        for ( "$moduleData->{'HOME_DIR'}/logs/$moduleData->{'DOMAIN_NAME'}",
            "$self->{'config'}->{'HTTPD_LOG_DIR'}/$moduleData->{'DOMAIN_NAME'}"
        ) {
            iMSCP::Dir->new( dirname => $_ )->remove();
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _mountLogsFolder( \%moduleData )

 Mount httpd logs folder for the domain as referred to by module data

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub _mountLogsFolder
{
    my ( $self, $moduleData ) = @_;

    my $fields = {
        fs_spec    => "$self->{'config'}->{'HTTPD_LOG_DIR'}/$moduleData->{'DOMAIN_NAME'}",
        fs_file    => "$moduleData->{'HOME_DIR'}/logs/$moduleData->{'DOMAIN_NAME'}",
        fs_vfstype => 'none',
        fs_mntops  => 'bind'
    };

    iMSCP::Dir->new( dirname => $fields->{'fs_file'} )->make( {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $moduleData->{'GROUP'},
        mode  => 0750
    } );

    addMountEntry( "$fields->{'fs_spec'} $fields->{'fs_file'} $fields->{'fs_vfstype'} $fields->{'fs_mntops'}" );
    mount( $fields ) unless isMountpoint( $fields->{'fs_file'} );
}

=item _umountLogsFolder( \%moduleData )

 Umount httpd logs folder for the domain as referred to by module data

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return void, die on failure

=cut

sub _umountLogsFolder
{
    my ( undef, $moduleData ) = @_;

    my $recursive = 1;
    my $fsFile = "$moduleData->{'HOME_DIR'}/logs";

    # We operate recursively only if domain type is 'dmn' (full account)
    if ( $moduleData->{'DOMAIN_TYPE'} ne 'dmn' ) {
        $recursive = 0;
        $fsFile .= "/$moduleData->{'DOMAIN_NAME'}";
    }

    removeMountEntry( qr%.*?[ \t]+\Q$fsFile\E(?:/|[ \t]+)[^\n]+% );
    umount( $fsFile, $recursive );
}

=item _disableDomain( \%moduleData )

 Disable a domain

 Param hashref \%moduleData Data as provided by the Alias|Domain modules
 Return int 0 on success, other or die on failure

=cut

sub _disableDomain
{
    my ( $self, $moduleData ) = @_;

    eval {
        iMSCP::Dir->new( dirname => "$self->{'config'}->{'HTTPD_LOG_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->make( {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ADM_GROUP'},
            mode  => 0755
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    my $net = iMSCP::Net->getInstance();
    my @domainIPs = ( @{$moduleData->{'DOMAIN_IPS'}}, ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' ? $moduleData->{'BASE_SERVER_IP'} : () ) );

    my $rs = $self->{'eventManager'}->trigger( 'onNginxAddVhostIps', $moduleData, \@domainIPs );
    return $rs if $rs;

    # If INADDR_ANY is found, map it to the wildcard sign and discard any other
    # IP, else, remove any duplicate IP address from the list
    @domainIPs = sort grep ($_ eq '0.0.0.0', @domainIPs) ? ( '*' ) : unique( map { $net->compressAddr( $_ ) } @domainIPs );

    my $serverData = {
        DOMAIN_IPS      => join( ' ', map { ( ( $_ eq '*' || $net->getAddrVersion( $_ ) eq 'ipv4' ) ? $_ : "[$_]" ) . ':80' } @domainIPs ),
        HTTP_URI_SCHEME => 'http://',
        HTTPD_LOG_DIR   => $self->{'config'}->{'HTTPD_LOG_DIR'},
        USER_WEB_DIR    => $::imscpConfig{'USER_WEB_DIR'},
        SERVER_ALIASES  => "www.$moduleData->{'DOMAIN_NAME'}" . ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes'
            ? " $moduleData->{'ALIAS'}.$::imscpConfig{'BASE_SERVER_VHOST'}" : ''
        )
    };

    # Create http vhost

    if ( $moduleData->{'HSTS_SUPPORT'} ) {
        @{ $serverData }{qw/ FORWARD FORWARD_TYPE VHOST_TYPE /} = ( "https://$moduleData->{'DOMAIN_NAME'}/", 301, 'domain_disabled_fwd' );
    } else {
        $serverData->{'VHOST_TYPE'} = 'domain_disabled';
    }

    $rs = $self->buildConfFile( 'parts/domain_disabled.tpl', "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf",
        $moduleData, $serverData, { cached => TRUE }
    );

    $rs ||= $self->enableSites( "$moduleData->{'DOMAIN_NAME'}.conf" );
    return $rs if $rs;

    # Create https vhost (or delete it if SSL is disabled)

    if ( $moduleData->{'SSL_SUPPORT'} ) {
        @{ $serverData }{qw/ CERTIFICATE DOMAIN_IPS HTTP_URI_SCHEME VHOST_TYPE /} = (
            "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/certs/$moduleData->{'DOMAIN_NAME'}.pem",
            join( ' ', map { ( ( $_ eq '*' || $net->getAddrVersion( $_ ) eq 'ipv4' ) ? $_ : "[$_]" ) . ':443' } @domainIPs ),
            'https://',
            'domain_disabled_ssl'
        );

        $rs = $self->buildConfFile( 'parts/domain_disabled.tpl',
            "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}_ssl.conf", $moduleData, $serverData, { cached => TRUE }
        );
        $rs ||= $self->enableSites( "$moduleData->{'DOMAIN_NAME'}_ssl.conf" );
        return $rs if $rs;
    } else {
        # Try to disable the site in any case to cover possible dangling symlink
        $rs = $self->disableSites( "$moduleData->{'DOMAIN_NAME'}_ssl.conf" );
        return $rs if $rs;

        iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}_ssl.conf" )->remove();
    }

    # Make sure that custom httpd conffile exists (cover case where file has been removed for any reasons)
    unless ( -f "$self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf" ) {
        $serverData->{'SKIP_TEMPLATE_CLEANER'} = 1;
        $rs = $self->buildConfFile( 'parts/custom.conf.tpl', "$self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf",
            $moduleData, $serverData, { cached => TRUE }
        );
        return $rs if $rs;
    }

    # Transitional - Remove deprecated 'domain_disable_page' directory if any
    if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' && -d $moduleData->{'WEB_DIR'} ) {
        clearImmutable( $moduleData->{'WEB_DIR'} );
        eval { iMSCP::Dir->new( dirname => "$moduleData->{'WEB_DIR'}/domain_disable_page" )->remove(); };
        if ( $@ ) {
            error( $@ );
            $rs = 1;
        }

        # Set immutable bit if needed (even on error)
        setImmutable( $moduleData->{'WEB_DIR'} ) if $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes';
        return $rs if $rs;
    }

    0;
}

=item _addCfg( \%data )

 Add configuration files for the given domain

 Param hashref \%data Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return int 0 on success, other or die on failure

=cut

sub _addCfg
{
    my ( $self, $moduleData ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxAddCfg', $moduleData );
    return $rs if $rs;

    my $net = iMSCP::Net->getInstance();
    my @domainIPs = ( @{$moduleData->{'DOMAIN_IPS'}}, ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' ? $moduleData->{'BASE_SERVER_IP'} : () ) );

    $rs = $self->{'eventManager'}->trigger( 'onNginxAddVhostIps', $moduleData, \@domainIPs );
    return $rs if $rs;

    # If INADDR_ANY is found, map it to the wildcard sign and discard any other
    # IP, else, remove any duplicate IP address from the list
    @domainIPs = sort grep ($_ eq '0.0.0.0', @domainIPs) ? ( '*' ) : unique( map { $net->compressAddr( $_ ) } @domainIPs );

    my $serverData = {
        DOMAIN_IPS             => join( ' ', map { ( ( $_ eq '*' || $net->getAddrVersion( $_ ) eq 'ipv4' ) ? $_ : "[$_]" ) . ':80' } @domainIPs ),
        HTTPD_CUSTOM_SITES_DIR => $self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'},
        HTTPD_LOG_DIR          => $self->{'config'}->{'HTTPD_LOG_DIR'},
        SERVER_ALIASES         => "www.$moduleData->{'DOMAIN_NAME'}" . (
            $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' ? " $moduleData->{'ALIAS'}.$::imscpConfig{'BASE_SERVER_VHOST'}" : ''
        )
    };

    # Create http vhost

    if ( $moduleData->{'HSTS_SUPPORT'} ) {
        @{ $serverData }{qw/ FORWARD FORWARD_TYPE VHOST_TYPE /} = ( "https://$moduleData->{'DOMAIN_NAME'}/", 301, 'domain_fwd' );
    } elsif ( $moduleData->{'FORWARD'} ne 'no' ) {
        $serverData->{'VHOST_TYPE'} = 'domain_fwd';
        @{ $serverData }{qw/ X_FORWARDED_PROTOCOL X_FORWARDED_PORT /} = ( 'http', 80 ) if $moduleData->{'FORWARD_TYPE'} eq 'proxy';
    } else {
        $serverData->{'VHOST_TYPE'} = 'domain';
    }

    $rs = $self->buildConfFile( 'parts/domain.tpl', "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf", $moduleData,
        $serverData, { cached => TRUE }
    );

    $rs ||= $self->enableSites( "$moduleData->{'DOMAIN_NAME'}.conf" );
    return $rs if $rs;

    # Create https vhost (or delete it if SSL is disabled)

    if ( $moduleData->{'SSL_SUPPORT'} ) {
        @{ $serverData }{qw/ CERTIFICATE DOMAIN_IPS /} = (
            "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/certs/$moduleData->{'DOMAIN_NAME'}.pem",
            join( ' ', map { ( ( $_ eq '*' || $net->getAddrVersion( $_ ) eq 'ipv4' ) ? $_ : "[$_]" ) . ':443' } @domainIPs )
        );

        if ( $moduleData->{'FORWARD'} ne 'no' ) {
            @{ $serverData }{qw/ FORWARD FORWARD_TYPE VHOST_TYPE /} = ( $moduleData->{'FORWARD'}, $moduleData->{'FORWARD_TYPE'}, 'domain_ssl_fwd' );
            @{ $serverData }{qw/ X_FORWARDED_PROTOCOL X_FORWARDED_PORT /} = ( 'https', 443 ) if $moduleData->{'FORWARD_TYPE'} eq 'proxy';
        } else {
            $serverData->{'VHOST_TYPE'} = 'domain_ssl';
        }

        $rs = $self->buildConfFile( 'parts/domain.tpl', "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}_ssl.conf",
            $moduleData, $serverData, { cached => TRUE }
        );
        $rs ||= $self->enableSites( "$moduleData->{'DOMAIN_NAME'}_ssl.conf" );
        return $rs if $rs;
    } else {
        # Try to disable the site in any case to cover possible dangling symlink
        $rs = $self->disableSites( "$moduleData->{'DOMAIN_NAME'}_ssl.conf" );
        return $rs if $rs;

        iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$moduleData->{'DOMAIN_NAME'}_ssl.conf" )->remove();
    }

    unless ( -f "$self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf" ) {
        $serverData->{'SKIP_TEMPLATE_CLEANER'} = 1;
        $rs = $self->buildConfFile( 'parts/custom.conf.tpl', "$self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'}/$moduleData->{'DOMAIN_NAME'}.conf",
            $moduleData, $serverData, { cached => TRUE }
        );
    }

    $rs ||= $self->{'eventManager'}->trigger( 'afterNginxAddCfg', $moduleData );
}


=item _getWebfolderSkeleton( \%moduleData )

 Get Web folder skeleton

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return string Path to Web folder skeleton on success, croak on failure

=cut

sub _getWebfolderSkeleton
{
    my ( undef, $moduleData ) = @_;

    my $webFolderSkeleton = $moduleData->{'DOMAIN_TYPE'} eq 'dmn' ? 'domain' : ( $moduleData->{'DOMAIN_TYPE'} eq 'als' ? 'alias' : 'subdomain' );

    unless ( -d "$TMPFS/$webFolderSkeleton" ) {
        iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/skel/$webFolderSkeleton" )->copy( "$TMPFS/$webFolderSkeleton" );

        if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' ) {
            for ( qw/ errors logs / ) {
                next if -d "$TMPFS/$webFolderSkeleton/$_";
                iMSCP::Dir->new( dirname => "$TMPFS/$webFolderSkeleton/$_" )->make();
            }
        }

        iMSCP::Dir->new( dirname => "$TMPFS/$webFolderSkeleton/htdocs" )->make() unless -d "$TMPFS/$webFolderSkeleton/htdocs";
    }

    "$TMPFS/$webFolderSkeleton";
}

=item _addFiles( \%moduleData )

 Add default directories and files for the given domain

 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Return int 0 on sucess, other on failure

=cut

sub _addFiles
{
    my ( $self, $moduleData ) = @_;

    eval {
        $self->{'eventManager'}->trigger( 'beforeNginxAddFiles', $moduleData ) == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        iMSCP::Dir->new( dirname => "$self->{'config'}->{'HTTPD_LOG_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->make( {
            user  => $::imscpConfig{'ROOT_USER'},
            group => $::imscpConfig{'ADM_GROUP'},
            mode  => 0755
        } );

        # Whether or not permissions must be fixed recursively
        my $fixPermissions = iMSCP::Getopt->fixPermissions || grep ( $moduleData->{'ACTION'} eq $_, 'restoreDomain', 'restoreSubdomain' );

        #
        ## Prepare Web folder
        #

        my $webFolderSkeleton = $self->_getWebfolderSkeleton( $moduleData );
        my $workingWebFolder = File::Temp->newdir( DIR => $TMPFS );

        iMSCP::Dir->new( dirname => $webFolderSkeleton )->copy( $workingWebFolder );

        if ( -d "$moduleData->{'WEB_DIR'}/htdocs" ) {
            iMSCP::Dir->new( dirname => "$workingWebFolder/htdocs" )->remove();
        } else {
            # Always fix permissions recursively for newly created Web folders
            $fixPermissions = 1;
        }

        if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' && -d "$moduleData->{'WEB_DIR'}/errors" ) {
            iMSCP::Dir->new( dirname => "$workingWebFolder/errors" )->remove();
        }

        # Make sure that parent Web folder exists
        my $parentDir = dirname( $moduleData->{'WEB_DIR'} );
        unless ( -d $parentDir ) {
            clearImmutable( dirname( $parentDir ));
            iMSCP::Dir->new( dirname => $parentDir )->make( {
                user  => $moduleData->{'USER'},
                group => $moduleData->{'GROUP'},
                mode  => 0750
            } );
        } else {
            clearImmutable( $parentDir );
        }

        clearImmutable( $moduleData->{'WEB_DIR'} ) if -d $moduleData->{'WEB_DIR'};

        if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' ) {
            $self->_umountLogsFolder( $moduleData ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

            if ( $self->{'config'}->{'HTTPD_MOUNT_CUSTOMER_LOGS'} ne 'yes' ) {
                iMSCP::Dir->new( dirname => "$moduleData->{'WEB_DIR'}/logs" )->remove();
                iMSCP::Dir->new( dirname => "$workingWebFolder/logs" )->remove();
            }
        }

        #
        ## Create Web folder
        #

        iMSCP::Dir->new( dirname => $workingWebFolder )->copy( $moduleData->{'WEB_DIR'} );

        # Set ownership and permissions

        # Set ownership and permissions for the Web folder root
        # Web folder root vuxxx:vuxxx 0750 (no recursive)
        setRights( $moduleData->{'WEB_DIR'},
            {
                user  => $moduleData->{'USER'},
                group => $moduleData->{'GROUP'},
                mode  => '0750'
            }
        ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );

        # Get list of possible files inside Web folder root
        my @files = iMSCP::Dir->new( dirname => $webFolderSkeleton )->getAll();

        # Set ownership for Web folder
        for ( @files ) {
            next unless -e "$moduleData->{'WEB_DIR'}/$_";
            setRights( "$moduleData->{'WEB_DIR'}/$_",
                {
                    user      => $moduleData->{'USER'},
                    group     => $moduleData->{'GROUP'},
                    recursive => $fixPermissions
                }
            ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
        }

        if ( $moduleData->{'DOMAIN_TYPE'} eq 'dmn' ) {
            # Set ownership and permissions for .htgroup and .htpasswd files
            for ( qw/ .htgroup .htpasswd / ) {
                next unless -f "$moduleData->{'WEB_DIR'}/$_";
                setRights( "$moduleData->{'WEB_DIR'}/$_",
                    {
                        user  => $::imscpConfig{'ROOT_USER'},
                        group => $self->getRunningGroup(),
                        mode  => '0640'
                    }
                ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
            }

            # Set ownership for logs directory
            if ( $self->{'config'}->{'HTTPD_MOUNT_CUSTOMER_LOGS'} eq 'yes' ) {
                setRights( "$moduleData->{'WEB_DIR'}/logs",
                    {
                        user      => $::imscpConfig{'ROOT_USER'},
                        group     => $moduleData->{'GROUP'},
                        recursive => $fixPermissions
                    }
                ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
            }
        }

        # Set permissions for Web folder
        for my $file ( @files ) {
            next unless -e "$moduleData->{'WEB_DIR'}/$file";
            setRights( "$moduleData->{'WEB_DIR'}/$file",
                {
                    dirmode   => '0750',
                    filemode  => '0640',
                    recursive => $file =~ /^(?:00_private|cgi-bin|htdocs)$/ ? 0 : $fixPermissions
                }
            ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
        }

        if ( $self->{'config'}->{'HTTPD_MOUNT_CUSTOMER_LOGS'} eq 'yes' ) {
            $self->_mountLogsFolder( $moduleData ) == 0 or croak( getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error' );
        }

        $self->{'eventManager'}->trigger( 'afterNginxAddFiles', $moduleData ) == 0 or croak(
            getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
        );

        # Set immutable bit if needed
        if ( $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes' ) {
            my $dir = $moduleData->{'WEB_DIR'};
            my $userWebDir = File::Spec->canonpath( $::imscpConfig{'USER_WEB_DIR'} );
            do {
                setImmutable( $dir );
            } while ( $dir = dirname( $dir ) ) ne $userWebDir;
        }
    };
    if ( $@ ) {
        error( $@ );

        # Set immutable bit if needed (even on error)
        if ( $moduleData->{'WEB_FOLDER_PROTECTION'} eq 'yes' ) {
            my $dir = $moduleData->{'WEB_DIR'};
            my $userWebDir = File::Spec->canonpath( $::imscpConfig{'USER_WEB_DIR'} );
            do {
                setImmutable( $dir );
            } while ( $dir = dirname( $dir ) ) ne $userWebDir;
        }

        return 1;
    }

    0;
}

=item _copyDomainDisablePages( )

 Copy pages for disabled domains

 Return int 0 on success, other on failure

=cut

sub _copyDomainDisablePages
{
    eval {
        iMSCP::Dir->new( dirname => "$::imscpConfig{'CONF_DIR'}/skel/domain_disabled_pages" )->copy(
            "$::imscpConfig{'USER_WEB_DIR'}/domain_disabled_pages"
        );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _setupVlogger( )

 Setup vlogger

 Return int 0 on success, other on failure

=cut

sub _setupVlogger
{
    my ( $self ) = @_;

    {
        my $dbSchemaFile = File::Temp->new();
        print $dbSchemaFile <<"EOF";
USE `{DATABASE_NAME}`;

CREATE TABLE IF NOT EXISTS httpd_vlogger (
  vhost varchar(255) NOT NULL,
  ldate int(8) UNSIGNED NOT NULL,
  bytes int(32) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY(vhost,ldate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
EOF
        $dbSchemaFile->close();
        my $rs = $self->buildConfFile( $dbSchemaFile, $dbSchemaFile, undef, { DATABASE_NAME => ::setupGetQuestion( 'DATABASE_NAME' ) },
            { srcname => 'vlogger.sql' }
        );
        return $rs if $rs;

        my $mysqlDefaultsFile = File::Temp->new();
        print $mysqlDefaultsFile <<"EOF";
[mysql]
host = {HOST}
port = {PORT}
user = "{USER}"
password = "{PASSWORD}"
EOF
        $mysqlDefaultsFile->close();
        $rs = $self->buildConfFile( $mysqlDefaultsFile, $mysqlDefaultsFile, undef,
            {
                HOST     => ::setupGetQuestion( 'DATABASE_HOST' ),
                PORT     => ::setupGetQuestion( 'DATABASE_PORT' ),
                USER     => ::setupGetQuestion( 'DATABASE_USER' ) =~ s/"/\\"/gr,
                PASSWORD => decryptRijndaelCBC( $::imscpKEY, $::imscpIV, ::setupGetQuestion( 'DATABASE_PASSWORD' )) =~ s/"/\\"/gr
            },
            { srcname => 'mysql-defaults-file' }
        );
        return $rs if $rs;

        $rs = execute( "mysql --defaults-file=$mysqlDefaultsFile < $dbSchemaFile", \my $stdout, \my $stderr );
        debug( $stdout ) if length $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    my $dbHost = ::setupGetQuestion( 'DATABASE_HOST' );
    $dbHost = '127.0.0.1' if $dbHost eq 'localhost';
    my $dbPort = ::setupGetQuestion( 'DATABASE_PORT' );
    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = 'vlogger_user';
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    $dbUserHost = '127.0.0.1' if $dbUserHost eq 'localhost';
    my $oldUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = randomStr( 16, ALNUM );

    eval {
        my $sqlServer = iMSCP::Servers::Sqld->factory();

        for my $host ( $dbUserHost, $oldUserHost, 'localhost' ) {
            next unless length $host;
            $sqlServer->dropUser( $dbUser, $host );
        }

        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );

        # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
        my $qDbName = $self->{'dbh'}->quote_identifier( $dbName );
        $self->{'dbh'}->do( "GRANT SELECT, INSERT, UPDATE ON $qDbName.httpd_vlogger TO ?\@?", undef, $dbUser, $dbUserHost );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    my $conffile = File::Temp->new();
    print $conffile <<'EOF';
# vlogger configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
dsn    dbi:mysql:database={DATABASE_NAME};host={DATABASE_HOST};port={DATABASE_PORT}
user   {DATABASE_USER}
pass   {DATABASE_PASSWORD}
dump   30
EOF
    $conffile->close();
    $self->buildConfFile( $conffile, "$self->{'config'}->{'HTTPD_CONF_DIR'}/vlogger.conf", undef,
        {
            DATABASE_NAME         => $dbName,
            DATABASE_HOST         => $dbHost,
            DATABASE_PORT         => $dbPort,
            DATABASE_USER         => $dbUser,
            DATABASE_PASSWORD     => $dbPass,
            SKIP_TEMPLATE_CLEANER => 1
        },
        {
            umask   => 0027,
            mode    => 0640,
            srcname => 'vlogger.conf'
        }
    );
}

=item _removeVloggerSqlUser( )

 Remove vlogger SQL user

 Return int 0

=cut

sub _removeVloggerSqlUser
{
    if ( $::imscpConfig{'DATABASE_USER_HOST'} eq 'localhost' ) {
        return iMSCP::Servers::Sqld->factory()->dropUser( 'vlogger_user', '127.0.0.1' );
    }

    iMSCP::Servers::Sqld->factory()->dropUser( 'vlogger_user', $::imscpConfig{'DATABASE_USER_HOST'} );
}

=back

=head1 EVENT LISTENERS

=over 4

=item afterNginxBuildConfFile( $nginxServer, \$cfgTpl, $filename, \$trgFile, \%moduleData, \%nginxServerData, \%nginxServerConfig, \%parameters )

 Event listener that cleanup production files

 Param scalar $nginxServer iMSCP::Servers::Httpd::Nginx::Prefork instance
 Param scalar \$scalar Reference to Nginx conffile
 Param string $filename Nginx template name
 Param scalar \$trgFile Target file path
 Param hashref \%moduleData Data as provided by the Alias|Domain|Subdomain|SubAlias modules
 Param hashref \%nginxServerData Nginx server data
 Param hashref \%nginxServerConfig Nginx server data
 Param hashref \%parameters OPTIONAL Parameters:
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return int 0 on success, other on failure

=cut

sub afterNginxBuildConfFile
{
    my ( $self, $cfgTpl, $filename, undef, $moduleData, $nginxServerData ) = @_;

    return $nginxServerData->{'SKIP_TEMPLATE_CLEANER'} = 0 if $nginxServerData->{'SKIP_TEMPLATE_CLEANER'};

    if ( $filename eq 'domain.tpl' ) {
        if ( index( $nginxServerData->{'VHOST_TYPE'}, 'fwd' ) == -1 ) {
            if ( $self->{'config'}->{'HTTPD_MPM'} eq 'itk' ) {
                replaceBlocByRef( '# SECTION suexec BEGIN.', '# SECTION suexec ENDING.', '', $cfgTpl );
            } else {
                replaceBlocByRef( '# SECTION itk BEGIN.', '# SECTION itk ENDING.', '', $cfgTpl );
            }

            if ( $moduleData->{'CGI_SUPPORT'} ne 'yes' ) {
                replaceBlocByRef( '# SECTION cgi BEGIN.', '# SECTION cgi ENDING.', '', $cfgTpl );
            }
        } elsif ( $moduleData->{'FORWARD'} ne 'no' ) {
            if ( $moduleData->{'FORWARD_TYPE'} eq 'proxy'
                && ( !$moduleData->{'HSTS_SUPPORT'} || index( $nginxServerData->{'VHOST_TYPE'}, 'ssl' ) != -1 )
            ) {
                replaceBlocByRef( '# SECTION std_fwd BEGIN.', '# SECTION std_fwd ENDING.', '', $cfgTpl );

                if ( index( $moduleData->{'FORWARD'}, 'https' ) != 0 ) {
                    replaceBlocByRef( '# SECTION ssl_proxy BEGIN.', '# SECTION ssl_proxy ENDING.', '', $cfgTpl );
                }
            } else {
                replaceBlocByRef( '# SECTION proxy_fwd BEGIN.', '# SECTION proxy_fwd ENDING.', '', $cfgTpl );
            }
        } else {
            replaceBlocByRef( '# SECTION proxy_fwd BEGIN.', '# SECTION proxy_fwd ENDING.', '', $cfgTpl );
        }
    }

    ${ $cfgTpl } =~ s/^\s*(?:[#;].*)?\n//gm;
    0;
}

=back

=head1 CLEANUP TASKS

=over 4

=item DESTROY

 Umount and remove tmpfs

=cut

sub DESTROY
{
    my ( $self ) = @_;

    my $tmpfs = "$::imscpConfig{'IMSCP_HOMEDIR'}/tmp/nginx_tmpfs";
    umount( $tmpfs ) if isMountpoint( $tmpfs );
    iMSCP::Dir->new( dirname => $tmpfs )->remove();

    $self->SUPER::DESTROY();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
