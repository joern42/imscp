=head1 NAME

 iMSCP::Modules::WebDomain - Module for processing of Web domain entities

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

package iMSCP::Modules::WebDomain;

use strict;
use warnings;
use File::Spec;
use iMSCP::Boolean;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of domain entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Domain';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    return $self->_add() if $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change|enable)$/;
    return $self->_delete() if $self->{'_data'}->{'STATUS'} eq 'todelete';
    return $self->_disable() if $self->{'_data'}->{'STATUS'} eq 'todisable';
    return $self->_restore() if $self->{'_data'}->{'STATUS'} eq 'torestore';
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $entityId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        "
            SELECT
                t1.domainName, t1.domainAliases, t1.php, t1.cgi, t1.documentRoot, t1.forwardURL, t1.forwardType, t1.forwardKeepHost,
                t1.webFolderProtection,
                IFNULL(GROUP_CONCAT(t2.ipAddress), '0.0.0.0') AS ipAddresses,
                t3.privateKey, t3.certificate, t3.caBundle, t3.hsts, t3.hstsMaxAge, t3.hstsIncludeSubdomains
            FROM imscp_web_domain AS t1
            LEFT JOIN imscp_ip_addresses AS t2 ON(FIND_IN_SET(t2.ipAddressID, t1.ipAddresses) AND t2.status = 'ok')
            LEFT JOIN imscp_ssl_certificate AS t3 ON(t3.webDomainId = t1.webDomainId AND t3.status = 'ok')
            WHERE t1.webDomainId = 10
            GROUP BY
                t1.domainName, t1.domainAliases, t1.php, t1.cgi, t1.documentRoot, t1.forwardURL, t1.forwardType, t1.forwardKeepHost,
                t1.webFolderProtection,
                t3.privateKey, t3.certificate, t3.caBundle, t3.hsts, t3.hstsMaxAge, t3.hstsIncludeSubdomains
        ",
        undef, $entityId
    );
    $row or die( sprintf( 'Data not found for domain (ID %d)', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'domain_admin_id'} );
    my $homeDir = File::Spec->canonpath( "$::imscpConfig{'USER_WEB_DIR'}/$usergroup" );
    my ( $ssl, $hstsMaxAge, $hstsIncSub, $phpini ) = ( FALSE, 0, '', {} );

    if ( $row->{'certificate'} && -f "$::imscpConfig{'FRONTEND_ROOT_DIR'}/data/certs/$row->{'domain_name'}.pem" ) {
        $ssl = TRUE;
        if ( $row->{'allow_hsts'} eq 'on' ) {
            $hstsMaxAge = $row->{'hsts_max_age'} if length $row->{'hsts_max_age'};
            $hstsIncSub = $row->{'hsts_include_subdomains'} eq 'on' ? '; includeSubDomains' : '';
        }
    }

    if ( $row->{'domain_php'} eq 'yes' ) {
        $phpini = $self->{'_dbh'}->selectrow_hashref(
            "SELECT * FROM php_ini WHERE domain_id = ? AND domain_type = ?", undef, $row->{'domain_id'}, 'dmn'
        ) || {};
    }

    $self->{'_data'} = {
        STATUS                  => $row->{'domain_status'},
        BASE_SERVER_VHOST       => $::imscpConfig{'BASE_SERVER_VHOST'},
        BASE_SERVER_IP          => $::imscpConfig{'BASE_SERVER_IP'},
        BASE_SERVER_PUBLIC_IP   => $::imscpConfig{'BASE_SERVER_PUBLIC_IP'},

        DOMAIN_ADMIN_ID         => $row->{'domain_admin_id'},
        DOMAIN_ID               => $row->{'domain_id'},
        DOMAIN_NAME             => $row->{'domain_name'},
        DOMAIN_ALIASES          => $row->{'domain_aliases'},
        DOMAIN_IPS              => [ $::imscpConfig{'BASE_SERVER_IP'} eq '0.0.0.0' ? ( '0.0.0.0' ) : split ',', $row->{'domain_ips'} ],

        WEB_DIR                 => $homeDir,
        DOCUMENT_ROOT           => File::Spec->canonpath( "$homeDir/$row->{'document_root'}" ),

        USER                    => $usergroup,
        GROUP                   => $usergroup,

        PHP_SUPPORT             => $row->{'domain_php'},
        PHP_CONFIG_LEVEL        => $row->{'php_config_level'},
        PHP_CONFIG_LEVEL_DOMAIN => $row->{'domain_name'},
        CGI_SUPPORT             => $row->{'domain_cgi'},
        WEB_FOLDER_PROTECTION   => $row->{'web_folder_protection'},

        SSL_SUPPORT             => $ssl,
        HSTS_SUPPORT            => $ssl && $row->{'allow_hsts'} eq 'on',
        HSTS_MAX_AGE            => $hstsMaxAge,
        HSTS_INCLUDE_SUBDOMAINS => $hstsIncSub,

        ALIAS                   => 'dmn' . $row->{'domain_id'},

        FORWARD                 => $row->{'url_forward'} || 'no',
        FORWARD_TYPE            => $row->{'type_forward'} || '',
        FORWARD_PRESERVE_HOST   => $row->{'host_forward'} || 'Off',

        DISABLE_FUNCTIONS       => $phpini->{'disable_functions'} // '',
        MAX_EXECUTION_TIME      => $phpini->{'max_execution_time'} || 30,
        MAX_INPUT_TIME          => $phpini->{'max_input_time'} || 60,
        MEMORY_LIMIT            => $phpini->{'memory_limit'} || 128,
        ERROR_REPORTING         => $phpini->{'error_reporting'} || 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
        DISPLAY_ERRORS          => $phpini->{'display_errors'} || 'off',
        POST_MAX_SIZE           => $phpini->{'post_max_size'} || 8,
        UPLOAD_MAX_FILESIZE     => $phpini->{'upload_max_filesize'} || 2,
        ALLOW_URL_FOPEN         => $phpini->{'allow_url_fopen'} || 'off',
        PHP_FPM_LISTEN_PORT     => ( $phpini->{'id'} // 1 )-1,
    };
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'DOMAIN_ID'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@, $self->{'_data'}->{'DOMAIN_ID'} );
        return;
    }

    $self->{'_dbh'}->do( 'DELETE FROM domain WHERE domain_id = ?', undef, $self->{'_data'}->{'DOMAIN_ID'} );
}

#=item _disable()
#
# See iMSCP::Modules::Abstract::_disable()
#
#=cut
#
#sub _disable
#{
#    my ( $self ) = @_;
#
#    eval {
#        if ( $self->{'_data'}->{'DOMAIN_TYPE'} eq 'dmn' ) {
#            $self->{'_dbh'}->do(
#                "UPDATE subdomain SET subdomain_status = 'todisable' WHERE domain_id = ? AND subdomain_status <> 'todelete'",
#                undef, $self->{'_data'}->{'DOMAIN_ID'}
#            );
#        } else {
#            $self->{'_dbh'}->do(
#                "UPDATE subdomain_alias SET subdomain_alias_status = 'todisable' WHERE alias_id = ? AND subdomain_alias_status <> 'todelete'",
#                undef, $self->{'_data'}->{'DOMAIN_ID'}
#            );
#        }
#
#        $self->SUPER::_disable();
#    };
#    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'DOMAIN_ID'} );
#}

=item _restore()

 See iMSCP::Modules::Abstract::_restore()

=cut

sub _restore
{
    my ( $self ) = @_;

    eval {
        eval {
            $self->{'_dbh'}->begin_work();
            $self->{'_dbh'}->do( 'UPDATE subdomain SET subdomain_status = ? WHERE domain_id = ?', undef, 'torestore', $self->{'_data'}->{'DOMAIN_ID'} );
            $self->{'_dbh'}->do( 'UPDATE domain_aliases SET alias_status = ? WHERE domain_id = ?', undef, 'torestore', $self->{'_data'}->{'DOMAIN_ID'} );
            $self->{'_dbh'}->do(
                "
                    UPDATE subdomain_alias
                    SET subdomain_alias_status = 'torestore'
                    WHERE alias_id IN (SELECT alias_id FROM domain_aliases WHERE domain_id = ?)
                ",
                undef, $self->{'_data'}->{'DOMAIN_ID'}
            );
            $self->{'_dbh'}->commit();
        };
        if ( $@ ) {
            $self->{'_dbh'}->rollback();
            die;
        }

        $self->SUPER::_restore();
    };
    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'DOMAIN_ID'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
